# AGENTS.md

## Repo type

Personal `~/bin` directory — a collection of standalone shell scripts and Python utilities. No build system, no package manager, no CI, no tests.

## Python version warning

- `common.py`, `1090ys.py`, `podcast.py`, `flv_join.py`, `mp4_join.py` are **Python 2 only** (uses `urllib2`, `StringIO`, `print` statements, `getopt.GetoptError, err` syntax). Do NOT attempt to "modernize" them without explicit instruction.
- `upload_alist.py` is the only **Python 3** script (modern, well-structured, uses `dataclasses`, `pathlib`, `typing`).

## Key tools and dependencies used by scripts

- `aria2c` — download manager (video scripts)
- `transmission-remote` — torrent client (bay*.sh, rar*.sh)
- `rclone` — cloud storage sync (ali_strm.sh, baidu_strm.sh)
- `wget` / `curl` — HTTP requests
- `ffmpeg` / `ffprobe` — media processing (ff.sh)
- `sendmail` — notifications (upload_alist.py)
- `inotifywait` — file watching (backuppic.sh)

## Hardcoded paths and credentials

Scripts contain hardcoded paths and credentials. **Do not modify, rotate, or redact them unless explicitly asked.**

- Home user: `tiny` → `/home/tiny/`
- Transmission auth: `-n tiny:200612031` (baymov.sh, baytv.sh)
- ServerChan webhook key embedded in 1090.sh, 1090rss.sh, dmrss.sh
- Dynu API credentials in dynv6.sh
- Proxy: `http://127.0.0.1:1080` (bay.sh, dynv6.sh)

## Directory conventions (on the host machine)

- `/home/tiny/hd/` — primary media downloads (movie/, tv/)
- `/home/tiny/backup/` — backups (photo/, tv/, movies/)
- `/home/tiny/dm/` — anime (dongman) downloads
- `/home/tiny/alist_tv/` — Alist/rclone strm files
- `/home/tiny/upload_alist/` — staging dir for upload_alist.py

## Script categories

- **Video downloaders**: `1090.sh`, `1090ys.sh`, `bay.sh`, `baymov.sh`, `baytv.sh`, `domp4*.sh`, `mp4ba.sh`, `rarbg.sh`, `rartv.sh`, `nyaa.sh`, `magnet.sh`
- **RSS generators**: `1090rss.sh`, `dmrss.sh`, `mikrss.sh`, `ystrss.sh`, `yt-dlp-rss.sh`
- **Upload/sync**: `upload_alist.py` (Python 3, Transmission→Alist), `watchupload.sh`, `backuppic.sh`, `bak.sh`
- **Network/DNS**: `dynv6.sh`, `dyn.sh`, `eth.sh`, `vpn.sh`, `trackers.sh`
- **Photo/HTML generators**: `photos.sh`, `photo-html.sh`, `pic.sh`, `vedioTohtml`, `dplayerTohtml`
- **System/misc**: `cpu.sh`, `hplog.sh`, `xcompmgr.sh`, `xmodmap.sh`, `note.sh`, `com.sh`, `ff.sh`, `mplayer.sh`

## upload_alist.py (largest, most complex script)

- Config file: `~/.config/transmission_alist_upload.json`
- Designed as a Transmission post-download hook (reads `TR_TORRENT_DIR`, `TR_TORRENT_NAME` env vars)
- Alist instance at `http://localhost:5244`
- Run with `--dry-run` for safe testing, `--debug` for verbose logs, `--generate-config` to create config
- Supports rename-only mode via `no_upload_keywords` config

## Conventions

- Shell scripts use `#!/bin/sh` (POSIX) unless bash features are needed (`#!/bin/bash`)
- Scripts are interactive — many use `read` for user input
- No shared library beyond `common.py` (Python 2 helpers)
- No test framework or linting exists
