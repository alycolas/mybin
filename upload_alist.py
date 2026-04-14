#!/usr/bin/env python3
"""
Transmission下载完成后自动上传视频文件到Alist
优化版本：支持 copy 或 copy+delete（模拟 move）两种模式
        支持配置多个“仅重命名不上传”关键词
        支持生成默认配置文件
        支持Debug模式（默认干跑）
        支持手动指定测试目录
        支持自定义Transmission环境变量名
修正：文件夹季信息优先于文件名季
"""

import os
import sys
import json
import time
import logging
import hashlib
import re
import shutil
import argparse
from pathlib import Path
from typing import List, Dict, Tuple, Optional
import requests
import subprocess
from datetime import datetime

# 全局日志记录器
logger = logging.getLogger(__name__)

# 邮件通知
def send_simple_notification(torrent_name: str, torrent_dir: str, dry_run: bool = False):
    """发送简单的下载完成通知"""
    recipient = "alycolas@163.com"
    dry_note = " [干跑模式]" if dry_run else ""
    subject = f"[Transmission] {dry_note}"
    body = f"""种子名称: {torrent_name}
下载目录: {torrent_dir}
完成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""
    mail_content = f"Subject: {subject}\n\n{body}"
    try:
        proc = subprocess.Popen(['sendmail', recipient], stdin=subprocess.PIPE)
        proc.communicate(mail_content.encode('utf-8'))
        if proc.returncode == 0:
            logger.debug("邮件通知已发送")
    except Exception as e:
        logger.error(f"邮件发送失败: {e}")

def setup_logging(debug: bool = False):
    """配置日志系统 - 仅控制台输出"""
    log_level = logging.DEBUG if debug else logging.INFO
    logger.handlers.clear()
    logger.setLevel(log_level)

    console_handler = logging.StreamHandler()
    console_handler.setLevel(log_level)
    formatter = logging.Formatter(
        '%(asctime)s.%(msecs)03d %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    logging.getLogger("requests").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)

class Config:
    """配置管理器"""

    DEFAULT_CONFIG = {
        "alist_url": "http://localhost:5244",
        "alist_username": "admin",
        "alist_password": "password",
        "remote_base_path": "/139/影视",
        "upload_video_only": True,
        "max_retries": 3,
        "retry_delay": 5,
        "rename_video_files": True,
        "default_season": "S01",
        "video_extensions": [
            "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm",
            "m4v", "mpg", "mpeg", "3gp", "rmvb", "rm", "ts",
            "ass", "srt", "m2ts", "vob", "ogv", "divx", "xvid"
        ],
        "local_base_path": "/home/tiny/upload_alist",
        "alist_mount_base": "/local/upload_alist",
        "upload_keyword": "upload_alist",
        "no_upload_keywords": [],
        "lock_timeout": 60,
        "use_move_api": False,          # True: 复制后删除源文件 (模拟move), False: 仅复制
        "skip_existing_files": True,
        "dry_run": False,
        "include_total_episodes": True,
        "min_episode_number": 0,
        "max_episode_number": 1899,
        "tr_torrent_dir_env": "TR_TORRENT_DIR",
        "tr_torrent_name_env": "TR_TORRENT_NAME"
    }

    def __init__(self, config_file: str = None):
        self.config_file = config_file or os.path.expanduser("~/.config/transmission_alist_upload.json")
        self.config = self.load_config()

    def load_config(self) -> Dict:
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                return {**self.DEFAULT_CONFIG, **config}
            except Exception as e:
                logger.error(f"加载配置文件失败: {e}")
                return self.DEFAULT_CONFIG
        else:
            logger.info(f"配置文件不存在，将使用默认配置: {self.config_file}")
            return self.DEFAULT_CONFIG

    @staticmethod
    def generate_default_config(config_path: str = None):
        if config_path is None:
            config_path = os.path.expanduser("~/.config/transmission_alist_upload.json")
        config_dir = os.path.dirname(config_path)
        if config_dir:
            os.makedirs(config_dir, exist_ok=True)
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(Config.DEFAULT_CONFIG, f, indent=4, ensure_ascii=False)
        print(f"默认配置文件已生成: {config_path}")
        sys.exit(0)

class FileLocker:
    """文件锁管理器"""

    def __init__(self, lock_dir: str = "/tmp/transmission_alist_locks"):
        self.lock_dir = lock_dir
        os.makedirs(self.lock_dir, exist_ok=True)

    def get_lock_file(self, torrent_dir: str) -> str:
        dir_hash = hashlib.md5(torrent_dir.encode()).hexdigest()
        return os.path.join(self.lock_dir, f"{dir_hash}.lock")

    def acquire_lock(self, torrent_dir: str, timeout: int = 60) -> Optional[str]:
        lock_file = self.get_lock_file(torrent_dir)
        start_time = time.time()
        while os.path.exists(lock_file):
            elapsed = time.time() - start_time
            if elapsed >= timeout:
                logger.warning(f"等待锁超时 ({timeout}秒)，退出")
                return None
            logger.info(f"等待锁释放 ({elapsed:.0f}/{timeout} 秒)...")
            time.sleep(5)
        with open(lock_file, 'w') as f:
            f.write(f"{os.getpid()} {torrent_dir} {datetime.now()}")
        logger.debug(f"获取锁成功: {lock_file}")
        return lock_file

    def release_lock(self, lock_file: str):
        if lock_file and os.path.exists(lock_file):
            os.remove(lock_file)
            logger.debug(f"释放锁: {lock_file}")

    def cleanup_old_locks(self, max_age_minutes: int = 60):
        try:
            for lock_file in Path(self.lock_dir).glob("*.lock"):
                if lock_file.stat().st_mtime < time.time() - (max_age_minutes * 60):
                    lock_file.unlink()
                    logger.debug(f"清理过期锁文件: {lock_file}")
        except Exception as e:
            logger.warning(f"清理旧锁文件失败: {e}")

class UniversalAnimeInfoExtractor:
    """通用动漫信息提取器 - 修正：文件夹季优先"""

    def __init__(self, config: Dict):
        self.config = config
        self.default_season = config.get("default_season", "S01")
        self.cn_map = {
            '一': '1', '二': '2', '三': '3', '四': '4', '五': '5',
            '六': '6', '七': '7', '八': '8', '九': '9', '十': '10',
            '1': '1', '2': '2', '3': '3', '4': '4', '5': '5',
            '6': '6', '7': '7', '8': '8', '9': '9', '10': '10',
        }

    def extract_info_from_filename(self, filename: str) -> Dict[str, str]:
        """从文件名中提取季数、集数和总集数"""
        result = {
            "season": self.default_season,
            "episode": "",
            "total_episode": "",
            "raw_episode": "",
            "has_episode_info": False,
        }

        clean_name = re.sub(
            r'1920x1080|1280x720|1080p|720p|2160p|4k|202[0-9]|'
            r'x264|hevc|10bit|aac|mp4|mkv|avc|webrip|web-dl|webdl|'
            r'srt|ass|cht|chs|big5|gb|bahamut|viutv|cr|abema|'
            r'remux|opus|pgs|简繁|双语|内封|内嵌|'
            r'\[.*?\]|\(.*?\)|【.*?】',
            '', filename, flags=re.I
        )

        # 季
        season_patterns = [
            r'[Ss](?:eason)?[\s_]*(\d{1,2})',
            r'第\s*([一二三四五六七八九十\d]+)\s*季',
            r'Part\s*(\d{1,2})',
            r'Vol\.\s*(\d{1,2})',
            r'(\d+)[季部]',
        ]
        for pattern in season_patterns:
            match = re.search(pattern, clean_name, re.I)
            if match:
                s_val = match.group(1)
                season_num = self.cn_map.get(s_val, s_val)
                try:
                    result["season"] = f"S{int(season_num):02d}"
                    break
                except ValueError:
                    continue

        # 总集数
        total_match = re.search(r'\((\d{2,4})\)', filename)
        if total_match:
            result["total_episode"] = total_match.group(1)

        # 集数
        ep_patterns = [
            r'\[(\d{1,3}(?:\.5)?)(?:v\d+)?(?:[ _].*?)?\]',
            r'【(\d{1,3}(?:\.5)?)】',
            r' - (\d{1,3}(?:-\d{1,3})?)',
            r'第\s*(\d+(?:\.5)?)\s*[集话]',
            r'\](\d{1,3})\[',
            r'\s(\d{1,3})\s\[',
            r'(\d{1,3})\.(?!\d{3,4}[pP])',
        ]
        for p in ep_patterns:
            m = re.search(p, filename, re.I)
            if m:
                ep_value = m.group(1)
                result["raw_episode"] = ep_value
                min_ep = self.config.get("min_episode_number", 1)
                max_ep = self.config.get("max_episode_number", 999)
                if '-' in ep_value:
                    try:
                        start_ep, end_ep = map(int, ep_value.split('-'))
                        if min_ep <= start_ep <= max_ep and min_ep <= end_ep <= max_ep:
                            result["episode"] = ep_value
                            result["has_episode_info"] = True
                    except ValueError:
                        pass
                else:
                    try:
                        ep_num = int(ep_value)
                        if min_ep <= ep_num <= max_ep:
                            result["episode"] = f"E{ep_num:02d}"
                            result["has_episode_info"] = True
                    except ValueError:
                        pass
                break

        if not result["has_episode_info"]:
            additional_patterns = [
                r'\s(\d{1,3})\s',
                r'(\d{1,3})[\]\)]',
            ]
            for p in additional_patterns:
                m = re.search(p, clean_name)
                if m:
                    ep_value = m.group(1)
                    result["raw_episode"] = ep_value
                    min_ep = self.config.get("min_episode_number", 1)
                    max_ep = self.config.get("max_episode_number", 999)
                    try:
                        ep_num = int(ep_value)
                        if min_ep <= ep_num <= max_ep:
                            result["episode"] = f"E{ep_num:02d}"
                            result["has_episode_info"] = True
                            break
                    except ValueError:
                        continue

        if not result["has_episode_info"] and '-' in result["raw_episode"]:
            try:
                start_ep, end_ep = map(int, result["raw_episode"].split('-'))
                min_ep = self.config.get("min_episode_number", 1)
                max_ep = self.config.get("max_episode_number", 999)
                if min_ep <= start_ep <= max_ep and min_ep <= end_ep <= max_ep:
                    result["episode"] = result["raw_episode"]
                    result["has_episode_info"] = True
            except ValueError:
                pass

        return result

    def extract_season_from_folder(self, folder_name: str) -> Tuple[str, bool]:
        """从文件夹名提取季数，返回 (季字符串, 是否找到)"""
        upload_keyword = self.config.get("upload_keyword", "upload_alist")
        clean_folder = folder_name.replace(upload_keyword, "")

        season_patterns = [
            r'[Ss](?:eason)?[\s_]*(\d{1,2})',
            r'第\s*([一二三四五六七八九十\d]+)\s*季',
            r'Part\s*(\d{1,2})',
            r'(\d+)[季部]',
        ]

        for pattern in season_patterns:
            match = re.search(pattern, clean_folder, re.I)
            if match:
                s_val = match.group(1)
                season_num = self.cn_map.get(s_val, s_val)
                try:
                    return (f"S{int(season_num):02d}", True)
                except ValueError:
                    continue

        return (self.default_season, False)

    def clean_series_name(self, folder_name: str) -> str:
        upload_keyword = self.config.get("upload_keyword", "upload_alist")
        cleaned = folder_name.replace(upload_keyword, "")
        patterns = [
            r'[第]?[一二三四五六七八九十\d]+季',
            r'[Ss](eason)?[\s_]*\d{1,2}',
            r'[Pp](art)?[\s_]*\d{1,2}',
            r'[Cc]omplete',
            r'全集',
            r'\[.*?\]',
            r'\(.*?\)',
            r'【.*?】',
        ]
        for pattern in patterns:
            cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r'[._\-]+', ' ', cleaned)
        cleaned = cleaned.strip()
        return cleaned if cleaned else folder_name

    def format_episode_string(self, season: str, episode: str) -> str:
        if not episode:
            return ""
        if '-' in episode:
            parts = episode.split('-')
            if len(parts) == 2:
                try:
                    start_ep = int(parts[0])
                    end_ep = int(parts[1])
                    return f"E{start_ep:02d}-E{end_ep:02d}"
                except ValueError:
                    return episode
        elif episode.startswith('E'):
            return episode
        else:
            try:
                ep_num = int(episode)
                return f"E{ep_num:02d}"
            except ValueError:
                return episode

    def extract_series_info(self, folder_name: str, filename: str) -> Dict[str, str]:
        """提取完整的剧集信息，文件夹季优先"""
        folder_season, folder_found = self.extract_season_from_folder(folder_name)
        file_info = self.extract_info_from_filename(filename)

        # 决定最终季
        if folder_found:
            season = folder_season
        else:
            if file_info["season"] != self.default_season:
                season = file_info["season"]
            else:
                season = self.default_season

        formatted_episode = ""
        if file_info["has_episode_info"]:
            formatted_episode = self.format_episode_string(season, file_info["episode"])

        series_name = self.clean_series_name(folder_name)

        return {
            "series_name": series_name,
            "season": season,
            "episode": formatted_episode,
            "raw_episode": file_info["raw_episode"],
            "total_episode": file_info["total_episode"],
            "original_filename": filename,
            "has_episode_info": file_info["has_episode_info"],
        }

class FileScanner:
    """文件扫描器"""

    def __init__(self, config: Dict):
        self.config = config
        self.video_extensions = set(ext.lower() for ext in config.get("video_extensions", []))

    def is_video_file(self, filename: str) -> bool:
        ext = os.path.splitext(filename)[1].lower().lstrip('.')
        return ext in self.video_extensions

    def scan_directory(self, torrent_dir: str) -> List[Dict]:
        files_to_process = []
        try:
            for root, dirs, filenames in os.walk(torrent_dir):
                for filename in filenames:
                    if self.is_video_file(filename):
                        file_path = os.path.join(root, filename)
                        files_to_process.append({
                            "path": file_path,
                            "filename": filename,
                            "relative_path": os.path.relpath(file_path, torrent_dir)
                        })
            logger.debug(f"在目录 {torrent_dir} 中找到 {len(files_to_process)} 个视频文件")
        except Exception as e:
            logger.error(f"扫描目录失败: {e}")
        return files_to_process

class AlistUploader:
    """Alist上传器"""

    def __init__(self, config: Dict):
        self.config = config
        self.base_url = config["alist_url"].rstrip('/')
        self.token = None
        self.token_expire = 0
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": "Transmission-Alist-Uploader/1.0"})

    def login(self) -> bool:
        try:
            login_url = f"{self.base_url}/api/auth/login"
            payload = {
                "username": self.config["alist_username"],
                "password": self.config["alist_password"]
            }
            response = self.session.post(login_url, json=payload, timeout=30)
            if response.status_code == 200:
                result = response.json()
                if result.get("code") == 200:
                    self.token = result["data"]["token"]
                    self.token_expire = time.time() + 3600
                    logger.info("Alist登录成功")
                    return True
                else:
                    logger.error(f"Alist登录失败: {result.get('message')}")
            else:
                logger.error(f"Alist登录HTTP错误: {response.status_code}")
        except Exception as e:
            logger.error(f"Alist登录异常: {e}")
        return False

    def ensure_token(self) -> bool:
        if not self.token or time.time() > self.token_expire - 300:
            return self.login()
        return True

    def ensure_directory(self, remote_path: str) -> bool:
        if not self.ensure_token():
            return False
        try:
            mkdir_url = f"{self.base_url}/api/fs/mkdir"
            headers = {"Authorization": self.token}
            response = self.session.post(mkdir_url, json={"path": remote_path},
                                        headers=headers, timeout=30)
            if response.status_code == 200:
                result = response.json()
                if result.get("code") == 200:
                    logger.debug(f"目录创建成功: {remote_path}")
                    return True
                else:
                    error_msg = result.get("message", "")
                    if "already exists" in error_msg.lower() or "目录已存在" in error_msg:
                        logger.debug(f"目录已存在: {remote_path}")
                        return True
                    logger.error(f"目录创建失败: {error_msg}")
            else:
                logger.error(f"目录创建HTTP错误: {response.status_code}")
        except Exception as e:
            logger.error(f"创建目录异常: {e}")
        return False

    def check_file_exists(self, remote_dir: str, filename: str) -> bool:
        if not self.ensure_token():
            return False
        try:
            list_url = f"{self.base_url}/api/fs/list"
            headers = {"Authorization": self.token}
            response = self.session.post(list_url, json={"path": remote_dir},
                                        headers=headers, timeout=30)
            if response.status_code == 200:
                result = response.json()
                if result.get("code") == 200:
                    for item in result.get("data", {}).get("content", []):
                        if not item.get("is_dir", True) and item.get("name") == filename:
                            return True
            return False
        except Exception as e:
            logger.error(f"检查文件存在异常: {e}")
            return False

    def copy_files(self, src_dir: str, dst_dir: str, filenames: List[str]) -> bool:
        """复制文件到目标目录（源文件保留）"""
        if not self.ensure_token():
            return False
        try:
            copy_url = f"{self.base_url}/api/fs/copy"
            headers = {"Authorization": self.token}
            payload = {
                "src_dir": src_dir,
                "dst_dir": dst_dir,
                "names": filenames
            }
            response = self.session.post(copy_url, json=payload, headers=headers, timeout=3600)
            if response.status_code == 200:
                result = response.json()
                if result.get("code") == 200:
                    logger.info(f"文件复制成功: {len(filenames)} 个文件")
                    return True
                else:
                    logger.error(f"文件复制失败: {result.get('message')}")
            else:
                logger.error(f"文件复制HTTP错误: {response.status_code}")
        except Exception as e:
            logger.error(f"文件复制异常: {e}")
        return False

    def delete_files(self, src_dir: str, filenames: List[str]) -> bool:
        """删除源目录中的指定文件"""
        if not self.ensure_token():
            return False
        try:
            remove_url = f"{self.base_url}/api/fs/remove"
            headers = {"Authorization": self.token}
            payload = {
                "dir": src_dir,
                "names": filenames
            }
            response = self.session.post(remove_url, json=payload, headers=headers, timeout=3600)
            if response.status_code == 200:
                result = response.json()
                if result.get("code") == 200:
                    logger.info(f"文件删除成功: {len(filenames)} 个文件")
                    return True
                else:
                    logger.error(f"文件删除失败: {result.get('message')}")
            else:
                logger.error(f"文件删除HTTP错误: {response.status_code}")
        except Exception as e:
            logger.error(f"文件删除异常: {e}")
        return False

def parse_arguments():
    parser = argparse.ArgumentParser(description="Transmission下载完成后自动处理视频文件")
    parser.add_argument("--generate-config", action="store_true", help="生成默认配置文件并退出")
    parser.add_argument("--config", type=str, default=None, help="指定配置文件路径")
    parser.add_argument("--debug", action="store_true", help="启用Debug模式（默认干跑）")
    parser.add_argument("--torrent-dir", "-d", type=str, default=None, help="手动指定种子目录（测试模式）")
    parser.add_argument("--torrent-name", type=str, default=None, help="手动指定种子名称")
    parser.add_argument("--dry-run", action="store_true", help="启用干跑模式")
    parser.add_argument("--no-dry-run", action="store_true", help="禁用干跑模式")
    parser.add_argument("--tr-dir-env", type=str, default=None, help="Transmission目录环境变量名")
    parser.add_argument("--tr-name-env", type=str, default=None, help="Transmission名称环境变量名")
    return parser.parse_args()

def main():
    args = parse_arguments()
    if args.generate_config:
        Config.generate_default_config(args.config)
        return

    setup_logging(debug=args.debug)

    try:
        config_manager = Config(args.config)
        config = config_manager.config

        # 干跑模式确定
        if args.dry_run:
            dry_run = True
        elif args.no_dry_run:
            dry_run = False
        else:
            if args.torrent_dir is not None:
                dry_run = True
                logger.debug("测试模式自动启用干跑")
            elif args.debug:
                dry_run = True
                logger.debug("Debug模式自动启用干跑")
            else:
                dry_run = config.get("dry_run", False)
        config["dry_run"] = dry_run

        # 获取种子目录
        if args.torrent_dir is not None:
            torrent_dir = os.path.abspath(args.torrent_dir)
            if not os.path.isdir(torrent_dir):
                logger.error(f"测试目录不存在: {torrent_dir}")
                sys.exit(1)
            torrent_name = args.torrent_name if args.torrent_name else os.path.basename(torrent_dir)
            logger.info(f"测试模式: {torrent_dir}")
        else:
            tr_dir_env = args.tr_dir_env or config.get("tr_torrent_dir_env", "TR_TORRENT_DIR")
            tr_name_env = args.tr_name_env or config.get("tr_torrent_name_env", "TR_TORRENT_NAME")
            torrent_dir = os.environ.get(tr_dir_env, '')
            torrent_name = os.environ.get(tr_name_env, '')
            if not torrent_dir:
                logger.error(f"未找到环境变量 {tr_dir_env}")
                sys.exit(1)
            logger.info(f"从环境变量获取种子目录: {tr_dir_env}={torrent_dir}")

        logger.info(f"处理种子: {torrent_name}")
        # ✅ 发送简单的下载完成通知
        send_simple_notification(torrent_name, torrent_dir, dry_run)
        # 关键词过滤
        no_upload_keywords = config.get("no_upload_keywords", [])
        no_upload_mode = False
        if no_upload_keywords:
            for kw in no_upload_keywords:
                if kw and kw in torrent_dir:
                    no_upload_mode = True
                    logger.info(f"目录包含仅重命名关键词'{kw}'，执行【仅重命名不上传】")
                    break

        if not no_upload_mode:
            upload_keyword = config.get("upload_keyword", "upload_alist")
            if upload_keyword:
                if upload_keyword not in torrent_dir:
                    logger.info(f"目录不包含上传关键词'{upload_keyword}'，跳过")
                    sys.exit(0)

        logger.info(f"处理种子: {torrent_name}")
        logger.info(f"操作模式: {'仅重命名' if no_upload_mode else '重命名+上传'}")
        logger.info(f"干跑模式: {'开启' if dry_run else '关闭'}")

        locker = FileLocker()
        lock_file = locker.acquire_lock(torrent_dir, config.get("lock_timeout", 60))
        if not lock_file:
            sys.exit(0)

        try:
            scanner = FileScanner(config)
            extractor = UniversalAnimeInfoExtractor(config)
            last_folder = os.path.basename(os.path.normpath(torrent_dir))
            files = scanner.scan_directory(torrent_dir)

            if not files:
                logger.info("没有需要处理的视频文件")
                sys.exit(0)

            processed_files = []
            for f in files:
                original_filename = f['filename']
                original_path = f['path']
                logger.debug(f"处理: {original_filename}")

                info = extractor.extract_series_info(last_folder, original_filename)

                if info["has_episode_info"] and info["episode"]:
                    ext = os.path.splitext(original_filename)[1].lower() or ".mkv"
                    new_name = f"{info['series_name']}.{info['season']}{info['episode']}"
                    if config.get("include_total_episodes", True) and info['total_episode']:
                        new_name += f"({info['total_episode']})"
                    new_name += ext
                    new_name = re.sub(r'[\\/*?:"<>|]', '', new_name)
                    new_path = os.path.join(torrent_dir, new_name)
                    action = "重命名并移动"
                else:
                    new_name = original_filename
                    new_path = os.path.join(torrent_dir, original_filename) if original_path != os.path.join(torrent_dir, original_filename) else original_path
                    action = "移动" if new_path != original_path else "保持原状"

                if os.path.exists(new_path) and new_path != original_path:
                    name, ext = os.path.splitext(new_name)
                    new_name = f"{name}_{int(time.time()%10000):04d}{ext}"
                    new_path = os.path.join(torrent_dir, new_name)
                    logger.info(f"目标已存在，添加时间戳: {new_name}")

                if not dry_run and new_path != original_path:
                    try:
                        shutil.move(original_path, new_path)
                        logger.info(f"{action}: {original_filename} -> {new_name}")
                    except Exception as e:
                        logger.error(f"移动失败: {e}")
                        new_path = original_path
                        new_name = original_filename
                elif dry_run and new_path != original_path:
                    logger.info(f"[干跑] 将{action}: {original_filename} -> {new_name}")

                # 保存系列信息用于后续上传
                processed_files.append({
                    "original_filename": original_filename,
                    "new_filename": new_name,
                    "path": new_path,
                    "renamed": info["has_episode_info"] and info["episode"] != "",
                    "series_info": info  # 保存以便获取系列名
                })

            # 上传部分
            if not no_upload_mode and config.get("use_copy_api", True) and processed_files:
                logger.info("开始上传/移动文件")
                uploader = AlistUploader(config)

                if not uploader.login():
                    logger.error("无法登录Alist")
                    sys.exit(1)

                local_base = config.get("local_base_path", "/home/tiny/upload_alist")
                alist_mount = config.get("alist_mount_base", "/local/upload_alist")
                remote_base = config["remote_base_path"]

                rel_path = os.path.relpath(torrent_dir, local_base)
                src_dir = f"{alist_mount}/{rel_path}" if rel_path != "." else alist_mount
                src_dir = src_dir.replace('\\', '/')

                series_name = None
                for pf in processed_files:
                    if pf["renamed"]:
                        series_name = pf["series_info"].get("series_name")
                        break
                if series_name:
                    dst_dir = f"{remote_base.rstrip('/')}/{series_name}"
                else:
                    dst_dir = f"{remote_base.rstrip('/')}/{last_folder.replace(config.get('upload_keyword', ''), '').strip()}"

                logger.info(f"源目录: {src_dir}")
                logger.info(f"目标目录: {dst_dir}")

                filenames_to_upload = []
                for pf in processed_files:
                    filename = pf["new_filename"]
                    if config.get("skip_existing_files", True):
                        if uploader.check_file_exists(dst_dir, filename):
                            logger.info(f"文件已存在，跳过: {filename}")
                            continue
                    filenames_to_upload.append(filename)

                if not filenames_to_upload:
                    logger.info("所有文件已存在，无需操作")
                else:
                    if not uploader.ensure_directory(dst_dir):
                        logger.error("无法创建目标目录")
                        sys.exit(1)

                    use_move = config.get("use_move_api", False)
                    batch_size = 5
                    success_count = 0
                    copied_batches = []  # 记录成功复制的批次，用于后续删除

                    for i in range(0, len(filenames_to_upload), batch_size):
                        batch = filenames_to_upload[i:i+batch_size]
                        logger.info(f"批次 {i//batch_size+1}: 复制 {len(batch)} 个文件")
                        if not dry_run:
                            if uploader.copy_files(src_dir, dst_dir, batch):
                                success_count += len(batch)
                                copied_batches.append(batch)  # 记录成功复制的批次
                            else:
                                logger.error(f"批次 {i//batch_size+1} 复制失败，跳过删除")
                        else:
                            logger.info(f"[干跑] 将复制: {batch}")
                            success_count += len(batch)
                            copied_batches.append(batch)

                    logger.info(f"复制完成: 成功 {success_count}/{len(processed_files)} 个文件")

                    # 如果是 move 模式，删除已成功复制的源文件
                    if use_move and copied_batches and not dry_run:
                        logger.info("开始删除已复制的源文件（模拟移动）")
                        delete_success = 0
                        for batch in copied_batches:
                            if uploader.delete_files(src_dir, batch):
                                delete_success += len(batch)
                            else:
                                logger.error(f"删除批次 {batch} 失败")
                        logger.info(f"源文件删除完成: 成功 {delete_success}/{success_count} 个文件")
                    elif use_move and dry_run:
                        total = sum(len(b) for b in copied_batches)
                        logger.info(f"[干跑] 将删除 {total} 个源文件")

            elif no_upload_mode:
                logger.info("仅重命名模式，跳过上传")

            renamed = sum(1 for f in processed_files if f["renamed"])
            logger.info(f"处理完成: 共 {len(processed_files)} 文件，重命名 {renamed} 个")

        finally:
            locker.release_lock(lock_file)
            locker.cleanup_old_locks()

    except Exception as e:
        logger.error(f"运行出错: {e}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
