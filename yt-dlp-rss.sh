#!/bin/bash

# 用法: ./download.sh [-x] [-l <列表文件> | -n <名称> <链接>] [下载数量]
#   -x               只下载音频（直接传递给 yt-dlp）
#   -l <列表文件>    从文件中读取条目（每行格式：名称 链接）
#   -n <名称> <链接> 指定单个条目的名称和链接（与 -l 互斥）
#   下载数量         正整数，默认为 1

set -e

# ---------- 配置 ----------
BILIBILI_COOKIE="/home/tiny/yt-dlp-cookie/bilibili.txt"
YOUTUBE_COOKIE="/home/tiny/yt-dlp-cookie/youtube.txt"

AUDIO_BASE_DIR="/home/tiny/139/podcast"
VIDEO_BASE_DIR="/home/tiny/139/video"

ARCHIVE_DIR="/home/tiny/yt-dlp-cookie"
# mkdir -p "$ARCHIVE_DIR"

PODCAST_CMD="python3 /home/tiny/bin/podcast.py --dir /home/tiny/139/podcast --base-url 'http://admin:vBNOzoT0@96.44.177.198:5245/dav/139/podcast/' --output /home/tiny/139/podcast/feed.xml"

# ---------- 函数：显示用法 ----------
usage() {
    echo "用法: $0 [-x] [-l <列表文件> | -n <名称> <链接>] [下载数量]"
    echo "  -x               只下载音频（直接传递给 yt-dlp）"
    echo "  -l <列表文件>    从文件中读取条目（每行格式：名称 链接）"
    echo "  -n <名称> <链接> 指定单个条目的名称和链接（与 -l 互斥）"
    echo "  下载数量         正整数，默认为 1"
    exit 1
}

# ---------- 解析命令行参数 ----------
AUDIO_ONLY=false
LIST_FILE=""
CUSTOM_NAME=""

while getopts "x l: n:" opt; do
    case $opt in
        x) AUDIO_ONLY=true ;;
        l) LIST_FILE="$OPTARG" ;;
        n) CUSTOM_NAME="$OPTARG" ;;
        *) usage ;;
    esac
done

shift $((OPTIND-1))

# 检查互斥：-l 和 -n 不能同时使用
if [ -n "$LIST_FILE" ] && [ -n "$CUSTOM_NAME" ]; then
    echo "错误：-l 和 -n 不能同时使用"
    usage
fi

# ---------- 处理三种模式：列表文件 / 自定义名称 / 自动名称 ----------
declare -a ITEM_NAMES
declare -a ITEM_URLS

if [ -n "$LIST_FILE" ]; then
    # 模式1：从列表文件读取
    if [ ! -f "$LIST_FILE" ]; then
        echo "错误：列表文件不存在: $LIST_FILE"
        exit 1
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
            continue
        fi
        name=$(echo "$line" | cut -d' ' -f1)
        url=$(echo "$line" | cut -d' ' -f2-)
        if [ -z "$name" ] || [ -z "$url" ]; then
            echo "警告：无效行，已跳过: $line"
            continue
        fi
        ITEM_NAMES+=("$name")
        ITEM_URLS+=("$url")
    done < "$LIST_FILE"

    if [ ${#ITEM_NAMES[@]} -eq 0 ]; then
        echo "错误：列表文件中没有有效的条目"
        exit 1
    fi

    # 下载数量：如果有位置参数则使用，否则默认1
    if [ $# -ge 1 ]; then
        COUNT="$1"
    else
        COUNT=1
    fi
    echo "从列表文件读取到 ${#ITEM_NAMES[@]} 个条目，每个最多下载 $COUNT 个视频"

elif [ -n "$CUSTOM_NAME" ]; then
    # 模式2：自定义名称（-n 后面跟名称，然后位置参数中第一个是链接，第二个可选数量）
    if [ $# -lt 1 ]; then
        echo "错误：使用 -n 时必须提供链接"
        usage
    fi
    URL="$1"
    if [ $# -ge 2 ]; then
        COUNT="$2"
    else
        COUNT=1
    fi
    ITEM_NAMES=("$CUSTOM_NAME")
    ITEM_URLS=("$URL")
    echo "自定义条目: 名称='$CUSTOM_NAME', 链接='$URL', 下载数量=$COUNT"

else
    # 自动名称（不创建子目录）
    if [ $# -lt 1 ]; then
        echo "错误：请提供视频地址"
        usage
    fi
    URL="$1"
    COUNT="${2:-1}"   # 默认1
    ITEM_NAMES=("")   # 空名称
    ITEM_URLS=("$URL")
    echo "单个链接模式（不创建子目录），最多下载 $COUNT 个视频"
fi

# 验证 COUNT 为正整数
if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -eq 0 ]; then
    echo "错误：下载数量必须是正整数"
    exit 1
fi

# ---------- 定义下载函数 ----------
download_one() {
    local name="$1"
    local url="$2"
    local count="$3"

    echo "======================================="
    echo "[$(date '+%Y-%m-%d %H:%M:%S')]"
    echo "处理条目: $name"
    echo "链接: $url"
    echo "======================================="

    # 根据来源选择 Cookie 和归档文件
    if [[ "$url" =~ bilibili ]]; then
        COOKIE_FILE="$BILIBILI_COOKIE"
        ARCHIVE_FILE="$ARCHIVE_DIR/bilibili_archive.txt"
        echo "检测到 Bilibili 链接"
    elif [[ "$url" =~ youtube ]]; then
        COOKIE_FILE="$YOUTUBE_COOKIE"
        ARCHIVE_FILE="$ARCHIVE_DIR/youtube_archive.txt"
        echo "检测到 YouTube 链接"
    else
		# 其他所有链接：不设置 Cookie，使用通用归档文件
		COOKIE_FILE=""
		ARCHIVE_FILE="$ARCHIVE_DIR/general_archive.txt"
		echo "检测到普通链接（无需 Cookie）: $url"
        # echo "警告：无法识别链接来源，跳过: $url"
        # return 1
    fi

	# 仅在需要 Cookie 时检查文件
	if [ -n "$COOKIE_FILE" ] && [ ! -f "$COOKIE_FILE" ]; then
		echo "错误：Cookie 文件不存在: $COOKIE_FILE"
		return 1
	fi

    # 根据模式设置输出目录和额外参数
    if [ "$AUDIO_ONLY" = true ]; then
        BASE_DIR="$AUDIO_BASE_DIR"
        # 下载音频，嵌入封面，临时文件存 /tmp
        mkdir -p /tmp/yt-dlp-temp
        EXTRA_ARGS="-x --embed-thumbnail --paths thumbnail:/tmp/yt-dlp-temp --paths temp:/tmp/yt-dlp-temp"
        echo "模式：仅下载音频（临时文件存 /tmp，最终移到 $BASE_DIR）"
    else
        BASE_DIR="$VIDEO_BASE_DIR"
        EXTRA_ARGS="--paths temp:/var/tmp/yt-dlp-temp"
        echo "模式：下载视频"
    fi

	if [ -n "$name" ]; then
		SAFE_NAME=$(echo "$name" | sed 's/[\/:*?"<>|]/_/g')
		OUTPUT_DIR="$BASE_DIR/$SAFE_NAME"
		echo "保存到子目录: $OUTPUT_DIR"
	else
		OUTPUT_DIR="$BASE_DIR"
		echo "保存到基础目录: $OUTPUT_DIR"
	fi
	mkdir -p "$OUTPUT_DIR"
    echo "保存到: $OUTPUT_DIR"

    echo "开始下载（最多 $count 个）..."
	cmd="yt-dlp \
		--playlist-end $count \
		--download-archive \"$ARCHIVE_FILE\" \
		--no-overwrites \
		--continue \
        -N 8 \
		-P \"$OUTPUT_DIR\" \
		$EXTRA_ARGS"

	# 如果 COOKIE_FILE 非空，则添加 --cookies 参数
	if [ -n "$COOKIE_FILE" ]; then
		cmd="$cmd --cookies \"$COOKIE_FILE\" --sleep-interval 10 --max-sleep-interval 15"
	fi

	# 添加 URL 并执行
	cmd="$cmd \"$url\""
	eval "$cmd"

    # yt-dlp \
    #     --cookies "$COOKIE_FILE" \
    #     --playlist-end "$count" \
    #     --download-archive "$ARCHIVE_FILE" \
    #     --ignore-errors \
    #     --no-overwrites \
    #     --continue \
    #     --sleep-interval 15 \
    #     --max-sleep-interval 30 \
    #     -P "$OUTPUT_DIR" \
    #     $EXTRA_ARGS \
    #     "$url"

    if [ $? -ne 0 ]; then
        echo "警告：下载 $name 时出现错误"
        return 1
    fi
    echo "完成: $name"
    return 0
}

# ---------- 执行下载（遍历所有条目） ----------
for i in "${!ITEM_NAMES[@]}"; do
    download_one "${ITEM_NAMES[$i]}" "${ITEM_URLS[$i]}" "$COUNT" || true
done

# ---------- 仅当音频模式时才更新播客 RSS ----------
if [ "$AUDIO_ONLY" = true ]; then
    echo "所有下载完成，正在更新播客 RSS..."

	if pidof rclone >/dev/null 2>&1; then
		kill -SIGHUP $(pidof rclone) || true
		sleep 2
		echo "已发送 SIGHUP 信号给 rclone，并等待 2 秒"
	else
		echo "未找到 rclone 进程"
	fi

    eval "$PODCAST_CMD"
else
    echo "所有视频下载完成（不更新 RSS）"
fi

echo "全部完成！"
