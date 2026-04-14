#!/usr/bin/env python3

import os
import sys
import argparse
import mimetypes
import urllib.parse
from datetime import datetime, timezone
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom

# 支持的音频扩展名
AUDIO_EXTENSIONS = {'.mp4', '.webm', '.mp3', '.m4a', '.m4b', '.ogg', '.opus', '.flac', '.wav'}
# 支持的封面图片扩展名
COVER_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp'}

def get_audio_files_with_cover(directory):
    """
    递归扫描目录，返回列表，每个元素为 (音频路径, 封面URL或None)
    封面URL：如果存在同名图片文件（扩展名不同），则生成URL；否则为None
    """
    items = []
    for root, _, filenames in os.walk(directory):
        # 先收集所有音频文件
        audio_files = []
        for fname in filenames:
            ext = os.path.splitext(fname)[1].lower()
            if ext in AUDIO_EXTENSIONS:
                full_path = os.path.join(root, fname)
                audio_files.append((full_path, fname))
        # 对每个音频文件查找同名封面
        for audio_path, audio_fname in audio_files:
            base = os.path.splitext(audio_fname)[0]
            cover_path = None
            # 在同一目录下查找同名图片
            for cover_ext in COVER_EXTENSIONS:
                candidate = os.path.join(root, base + cover_ext)
                if os.path.isfile(candidate):
                    cover_path = candidate
                    break
            items.append((audio_path, cover_path))
    # 按音频文件修改时间倒序
    items.sort(key=lambda x: os.path.getmtime(x[0]), reverse=True)
    return items

def file_to_url(file_path, base_url, root_dir):
    """将本地文件路径转换为可访问的 URL"""
    rel_path = os.path.relpath(file_path, root_dir)
    encoded_path = '/'.join(urllib.parse.quote(part, safe='') for part in rel_path.split(os.sep))
    return urllib.parse.urljoin(base_url, encoded_path)

def format_rfc2822(timestamp):
    dt = datetime.fromtimestamp(timestamp, tz=timezone.utc)
    return dt.strftime('%a, %d %b %Y %H:%M:%S %z')

def generate_rss(items, base_url, root_dir, feed_title, feed_description, feed_link, output_path, channel_cover_url=None):
    """
    items: 列表，每个元素为 (audio_path, cover_path_or_None)
    """
    rss = Element('rss', version='2.0', attrib={'xmlns:itunes': 'http://www.itunes.com/dtds/podcast-1.0.dtd'})
    channel = SubElement(rss, 'channel')

    # 频道基本信息
    SubElement(channel, 'title').text = feed_title
    SubElement(channel, 'link').text = feed_link
    SubElement(channel, 'description').text = feed_description
    SubElement(channel, 'language').text = 'zh-cn'
    SubElement(channel, 'lastBuildDate').text = format_rfc2822(datetime.now().timestamp())

    # 频道级封面（如果有）
    if channel_cover_url:
        itunes_image = SubElement(channel, 'itunes:image', attrib={'href': channel_cover_url})
        image_elem = SubElement(channel, 'image')
        SubElement(image_elem, 'url').text = channel_cover_url
        SubElement(image_elem, 'title').text = feed_title
        SubElement(image_elem, 'link').text = feed_link

    # iTunes 分类（示例）
    itunes_category = SubElement(channel, 'itunes:category', attrib={'text': 'Society & Culture'})
    SubElement(itunes_category, 'itunes:category', attrib={'text': 'Personal Journals'})

    for audio_path, cover_path in items:
        url = file_to_url(audio_path, base_url, root_dir)
        filename = os.path.basename(audio_path)
        stat = os.stat(audio_path)
        file_size = stat.st_size
        mod_time = stat.st_mtime

        title = os.path.splitext(filename)[0]
        pub_date = datetime.fromtimestamp(mod_time, tz=timezone.utc).strftime('%Y-%m-%d')
        description = f"文件大小: {file_size // 1024} KB，修改日期: {pub_date}"

        mime_type, _ = mimetypes.guess_type(audio_path)
        if not mime_type:
            mime_type = 'audio/mpeg'

        item = SubElement(channel, 'item')
        SubElement(item, 'title').text = title
        SubElement(item, 'link').text = url
        SubElement(item, 'description').text = description
        SubElement(item, 'guid', attrib={'isPermaLink': 'false'}).text = url
        SubElement(item, 'pubDate').text = format_rfc2822(mod_time)
        enclosure = SubElement(item, 'enclosure', attrib={
            'url': url,
            'length': str(file_size),
            'type': mime_type
        })

        # 单集封面：如果存在封面文件，添加 itunes:image
        if cover_path:
            cover_url = file_to_url(cover_path, base_url, root_dir)
            SubElement(item, 'itunes:image', attrib={'href': cover_url})

    # 格式化输出
    rough_string = tostring(rss, 'utf-8')
    reparsed = minidom.parseString(rough_string)
    pretty_xml = reparsed.toprettyxml(indent='  ')

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(pretty_xml)

def main():
    parser = argparse.ArgumentParser(description='为目录中的音频文件生成播客 RSS（支持单集封面）')
    parser.add_argument('--dir', required=True, help='存放音频文件的目录')
    parser.add_argument('--base-url', required=True, help='音频文件的基础 URL，例如 https://your.domain.com/')
    parser.add_argument('--output', required=True, help='输出的 RSS XML 文件路径')
    parser.add_argument('--title', default='我的播客', help='RSS 频道的标题')
    parser.add_argument('--description', default='由本地音频文件自动生成的播客', help='RSS 频道的描述')
    parser.add_argument('--link', default='', help='RSS 频道对应的网站链接（可选，默认使用 base-url）')
    parser.add_argument('--cover', help='播客频道封面图片的 URL（可选）')
    args = parser.parse_args()

    if not os.path.isdir(args.dir):
        print(f'错误: 目录不存在或不是目录: {args.dir}', file=sys.stderr)
        sys.exit(1)

    feed_link = args.link if args.link else args.base_url

    items = get_audio_files_with_cover(args.dir)
    if not items:
        print('警告: 没有找到任何音频文件', file=sys.stderr)
        # 生成空 RSS
        generate_rss([], args.base_url, args.dir, args.title, args.description, feed_link, args.output, args.cover)
        print(f'已生成空的 RSS: {args.output}')
    else:
        generate_rss(items, args.base_url, args.dir, args.title, args.description, feed_link, args.output, args.cover)
        print(f'成功生成 RSS，包含 {len(items)} 个音频条目: {args.output}')

if __name__ == '__main__':
    main()
