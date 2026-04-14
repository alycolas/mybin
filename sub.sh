#!/bin/bash
# Transmission下载完成后自动上传视频文件到Alist (Alist V3 API) - 修复版
# 使用 /api/fs/form 接口，经测试最可靠

# 配置参数
CONFIG_FILE="$HOME/.config/transmission_alist_upload.conf"

# 默认配置
setup_default_config() {
    cat > "$CONFIG_FILE" << 'EOF'
# Alist V3配置
ALIST_URL="http://localhost:5244"
ALIST_USER="admin"
ALIST_PASS="password"

# 上传配置
REMOTE_BASE_PATH="/139/影视"
UPLOAD_VIDEO_ONLY="yes"
MAX_RETRIES=3
RETRY_DELAY=5

# 重命名配置
RENAME_VIDEO_FILES="yes"  # 是否重命名视频文件
DEFAULT_SEASON="S01"      # 默认季数

# 视频文件扩展名（空格分隔）
VIDEO_EXTENSIONS="mp4 mkv avi mov wmv flv webm m4v mpg mpeg 3gp rmvb rm ts m2ts vob ogv divx xvid"

# 日志设置
LOG_FILE="/tmp/transmission_alist_upload.log"
EOF
    echo "已创建默认配置文件: $CONFIG_FILE"
    echo "请编辑配置文件后重新运行"
    exit 0
}

# 加载配置
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        setup_default_config
    fi

    # 加载配置
    source "$CONFIG_FILE"

    # 设置日志文件
    if [ -z "$LOG_FILE" ]; then
        LOG_FILE="/tmp/transmission_alist_upload.log"
    fi
}

# 日志函数
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$1"
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# 检查下载目录是否包含upload_alist
check_upload_alist_condition() {
    local torrent_dir="$1"

    # 检查目录是否包含"upload_alist"
    if [[ "$torrent_dir" == *upload_alist* ]]; then
        log "下载目录包含 'upload_alist'，继续执行"
        return 0
    else
        log "下载目录不包含 'upload_alist'，跳过处理"
        return 1
    fi
}

# 获取下载目录的最后一个文件夹名
get_last_folder_name() {
    local torrent_dir="$1"

    # 移除末尾的斜杠
    torrent_dir="${torrent_dir%/}"

    # 获取最后一个文件夹名
    local last_folder=$(basename "$torrent_dir")

    echo "$last_folder"
}

# 清理剧集名称：移除季数信息
clean_series_name() {
    local folder_name="$1"

    # 移除常见的季数标识
    local cleaned_name=$(echo "$folder_name" | sed -E 's/[[:space:]]*[第]?[一二三四五六七八九十1234567890]+季[[:space:]]*//g')
    cleaned_name=$(echo "$cleaned_name" | sed -E 's/[[:space:]]*[Ss]([0-9]{1,2})[[:space:]]*//g')
    cleaned_name=$(echo "$cleaned_name" | sed -E 's/[[:space:]]*[Ss]eason[[:space:]]*[0-9]+[[:space:]]*//gi')
    cleaned_name=$(echo "$cleaned_name" | sed -E 's/[[:space:]]*[.]?[Cc]omplete[[:space:]]*//gi')

    # 移除upload_alist标识
    cleaned_name=$(echo "$cleaned_name" | sed 's/upload_alist//g')

    # 移除开头和结尾的空格和点
    cleaned_name=$(echo "$cleaned_name" | sed 's/^[[:space:].]*//;s/[[:space:].]*$//')

    # 如果清理后为空，则返回原始名称
    if [ -z "$cleaned_name" ]; then
        echo "$folder_name"
    else
        echo "$cleaned_name"
    fi
}

# 从目录名中提取季数
extract_season_from_folder() {
    local folder_name="$1"

    # 尝试匹配各种季数格式
    local season=""

    # 1. 匹配 "第一季"、"第1季" 等中文格式
    if echo "$folder_name" | grep -qE "第[一二三四五六七八九十1234567890]+季"; then
        season=$(echo "$folder_name" | grep -oE "第[一二三四五六七八九十1234567890]+季" | head -1)
        # 转换中文数字为阿拉伯数字
        season=$(echo "$season" | sed 's/第一季/S01/;s/第1季/S01/;s/第二季/S02/;s/第2季/S02/;s/第三季/S03/;s/第3季/S03/;s/第四季/S04/;s/第4季/S04/;s/第五季/S05/;s/第5季/S05/;s/第六季/S06/;s/第6季/S06/;s/第七季/S07/;s/第7季/S07/;s/第八季/S08/;s/第8季/S08/;s/第九季/S09/;s/第9季/S09/;s/第十季/S10/;s/第10季/S10/')
        # 确保格式为S01
        season=$(echo "$season" | sed 's/第\([0-9]\)季/S0\1/;s/第\([0-9][0-9]\)季/S\1/')
    # 2. 匹配 "S1"、"S01"、"Season 1" 等格式
    elif echo "$folder_name" | grep -qiE "[Ss][0-9]{1,2}"; then
        season=$(echo "$folder_name" | grep -oiE "[Ss][0-9]{1,2}" | head -1)
        # 统一格式为大写S，两位数
        season=$(echo "$season" | tr '[:lower:]' '[:upper:]')
        if [ ${#season} -eq 2 ]; then  # S1 -> S01
            season="S0${season:1}"
        fi
    # 3. 匹配 "Season 1"、"season 01" 等格式
    elif echo "$folder_name" | grep -qiE "[Ss]eason[[:space:]]*[0-9]+"; then
        season=$(echo "$folder_name" | grep -oiE "[Ss]eason[[:space:]]*[0-9]+" | head -1)
        local num=$(echo "$season" | grep -oE "[0-9]+")
        if [ ${#num} -eq 1 ]; then
            season="S0${num}"
        else
            season="S${num}"
        fi
    fi

    # 如果提取不到季数，使用默认值
    if [ -z "$season" ]; then
        season="$DEFAULT_SEASON"
    fi

    echo "$season"
}

# 从文件名中提取集数
extract_episode_from_filename() {
    local filename="$1"

    # 移除扩展名
    local basename=$(basename "$filename")
    basename="${basename%.*}"

    local episode=""

    # 1. 匹配 "S01E01"、"S1E1" 格式
    if echo "$basename" | grep -qE "[Ss][0-9]{1,2}[Ee][0-9]{1,2}"; then
        episode=$(echo "$basename" | grep -oE "[Ss][0-9]{1,2}[Ee][0-9]{1,2}" | head -1)
        # 提取集数部分
        episode=$(echo "$episode" | grep -oE "[Ee][0-9]{1,2}")
        episode=$(echo "$episode" | tr '[:lower:]' '[:upper:]')
        if [ ${#episode} -eq 2 ]; then  # E1 -> E01
            episode="E0${episode:1}"
        fi
    # 2. 匹配 "E01"、"E1" 格式
    elif echo "$basename" | grep -qE "[Ee][0-9]{1,2}"; then
        episode=$(echo "$basename" | grep -oE "[Ee][0-9]{1,2}" | head -1)
        episode=$(echo "$episode" | tr '[:lower:]' '[:upper:]')
        if [ ${#episode} -eq 2 ]; then  # E1 -> E01
            episode="E0${episode:1}"
        fi
    # 3. 匹配 "第01集"、"第1集" 格式
    elif echo "$basename" | grep -qE "第[0-9]{1,2}集"; then
        episode=$(echo "$basename" | grep -oE "第[0-9]{1,2}集" | head -1)
        local num=$(echo "$episode" | grep -oE "[0-9]+")
        if [ ${#num} -eq 1 ]; then
            episode="E0${num}"
        else
            episode="E${num}"
        fi
    # 4. 匹配纯数字集数 "01"、"1"
    elif echo "$basename" | grep -qE "(^|[^0-9])[0-9]{1,2}([^0-9]|$)"; then
        # 提取第一个连续的数字序列（忽略年份等大数字）
        local all_numbers=$(echo "$basename" | grep -oE "[0-9]+")
        for num in $all_numbers; do
            # 假设集数通常在1-99之间
            if [ "$num" -gt 0 ] && [ "$num" -lt 100 ]; then
                if [ ${#num} -eq 1 ]; then
                    episode="E0${num}"
                else
                    episode="E${num}"
                fi
                break
            fi
        done
    fi

    # 如果提取不到集数，尝试其他模式
    if [ -z "$episode" ]; then
        # 尝试匹配 "EP01"、"Ep01" 格式
        if echo "$basename" | grep -qiE "[Ee][Pp][0-9]{1,2}"; then
            episode=$(echo "$basename" | grep -oiE "[Ee][Pp][0-9]{1,2}" | head -1)
            episode=$(echo "$episode" | tr '[:lower:]' '[:upper:]')
            if [ ${#episode} -eq 3 ]; then  # EP1 -> EP01
                episode="EP0${episode:2}"
            fi
        # 尝试匹配 " - 01"、" - 1" 格式
        elif echo "$basename" | grep -qE "[[:space:]]*-[[:space:]]*[0-9]{1,2}"; then
            episode=$(echo "$basename" | grep -oE "[[:space:]]*-[[:space:]]*[0-9]{1,2}" | head -1)
            local num=$(echo "$episode" | grep -oE "[0-9]+")
            if [ ${#num} -eq 1 ]; then
                episode="E0${num}"
            else
                episode="E${num}"
            fi
        fi
    fi

    # 如果还是提取不到，使用E01作为默认
    if [ -z "$episode" ]; then
        episode="E01"
    fi

    echo "$episode"
}

# 智能重命名文件
smart_rename_file() {
    local file_path="$1"
    local series_name="$2"
    local season="$3"

    # 从文件名提取集数
    local episode=$(extract_episode_from_filename "$file_path")

    # 获取文件扩展名
    local extension="${file_path##*.}"
    extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')

    # 构建新文件名
    local new_filename="${series_name}.${season}${episode}.${extension}"

    # 清理文件名中的非法字符（Windows/Linux文件系统不允许的字符）
    new_filename=$(echo "$new_filename" | sed 's/[\/\\:*?"<>|]//g')

    echo "$new_filename"
}

# 检查是否为视频文件
is_video_file() {
    local filename="$1"
    local extension="${filename##*.}"
    extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')

    for ext in $VIDEO_EXTENSIONS; do
        if [ "$extension" = "$ext" ]; then
            return 0
        fi
    done
    return 1
}

# URL编码函数
urlencode() {
    local string="$1"

    # 使用python进行URL编码
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import urllib.parse; print(urllib.parse.quote('''$string''', safe=''))"
    elif command -v python >/dev/null 2>&1; then
        python -c "import urllib.parse; print(urllib.parse.quote('''$string''', safe=''))"
    else
        # 简单的URL编码实现
        local length="${#string}"
        local encoded=""

        for (( i = 0; i < length; i++ )); do
            local c="${string:$i:1}"
            case $c in
                [a-zA-Z0-9.~_-])
                    encoded+="$c"
                    ;;
                *)
                    encoded+=$(printf '%%%02X' "'$c")
                    ;;
            esac
        done

        echo "$encoded"
    fi
}

# 登录Alist获取token
alist_login() {
    log "正在登录Alist..."

    local response=$(curl -s -X POST "${ALIST_URL}/api/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${ALIST_USER}\",\"password\":\"${ALIST_PASS}\"}" \
        --max-time 30 2>/dev/null)

    if [ $? -ne 0 ]; then
        log "连接Alist失败"
        return 1
    fi

    local code=$(echo "$response" | jq -r '.code' 2>/dev/null)

    if [ "$code" = "200" ]; then
        ALIST_TOKEN=$(echo "$response" | jq -r '.data.token')
        log "Alist登录成功"
        return 0
    else
        local error_msg=$(echo "$response" | jq -r '.message // "未知错误"')
        log "Alist登录失败: $error_msg"
        return 1
    fi
}

# 确保远程目录存在
ensure_remote_directory() {
    local remote_path="$1"

    # 创建目录
    local response=$(curl -s -X POST "${ALIST_URL}/api/fs/mkdir" \
        -H "Authorization: ${ALIST_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"path\":\"${remote_path}\"}" \
        --max-time 30 2>/dev/null)

    if [ $? -ne 0 ]; then
        log "创建目录失败: 网络错误"
        return 1
    fi

    local code=$(echo "$response" | jq -r '.code' 2>/dev/null)

    if [ "$code" = "200" ]; then
        return 0
    else
        local error_msg=$(echo "$response" | jq -r '.message // "未知错误"')
        log "目录操作失败: $error_msg"
        return 1
    fi
}

# 上传文件到Alist - 使用form接口（经测试最可靠）
upload_file_via_form() {
    local local_file="$1"
    local remote_path="$2"

    if [ ! -f "$local_file" ]; then
        log "文件不存在: $local_file"
        return 1
    fi

    # 获取文件大小
    local file_size
    if [ "$(uname)" = "Darwin" ]; then
        file_size=$(stat -f%z "$local_file" 2>/dev/null)
    else
        file_size=$(stat -c%s "$local_file" 2>/dev/null)
    fi

    if [ $? -ne 0 ]; then
        log "无法获取文件大小"
        return 1
    fi

    # 对远程路径进行URL编码
    local encoded_path=$(urlencode "$remote_path")

    log "上传文件: $local_file (大小: $file_size bytes) -> $remote_path"

    # 使用表单上传API (/api/fs/form) - 经测试最可靠
    local response=$(curl -s -X PUT "${ALIST_URL}/api/fs/form" \
        -H "Authorization: ${ALIST_TOKEN}" \
        -H "file-path: ${encoded_path}" \
        -F "file=@${local_file}" \
        --max-time 3600 \
        --connect-timeout 30 \
        --retry 0 \
        --show-error \
        2>&1)

    local curl_exit_code=$?

    if [ $curl_exit_code -eq 0 ]; then
        # 检查响应
        local code=$(echo "$response" | jq -r '.code' 2>/dev/null)

        if [ "$code" = "200" ]; then
            log "上传成功: $remote_path"
            return 0
        else
            local error_msg=$(echo "$response" | jq -r '.message // "未知错误"' 2>/dev/null)
            log "上传失败 (API错误): $error_msg"
            return 1
        fi
    else
        log "上传失败 (curl错误 $curl_exit_code): $response"
        return 1
    fi
}

# 备选上传方法 - 使用原始脚本的方法
upload_file_via_put() {
    local local_file="$1"
    local remote_path="$2"

    log "尝试备选上传方法..."

    local response=$(curl -s -T "$local_file" "${ALIST_URL}/api/fs/put" \
        -H "Authorization: ${ALIST_TOKEN}" \
        -H "File-Path: ${remote_path}" \
        --max-time 3600 \
        --connect-timeout 30 \
        --retry 0 \
        --show-error \
        2>&1)

    local curl_exit_code=$?

    if [ $curl_exit_code -eq 0 ]; then
        # 检查响应
        local code=$(echo "$response" | jq -r '.code' 2>/dev/null)

        if [ "$code" = "200" ]; then
            log "备选方法上传成功: $remote_path"
            return 0
        else
            local error_msg=$(echo "$response" | jq -r '.message // "未知错误"' 2>/dev/null)
            log "备选方法上传失败: $error_msg"
            return 1
        fi
    else
        log "备选方法上传失败 (curl错误 $curl_exit_code): $response"
        return 1
    fi
}

# 主上传函数 - 自动选择最佳方法
upload_file() {
    local local_file="$1"
    local remote_path="$2"

    # 首先尝试form接口
    if upload_file_via_form "$local_file" "$remote_path"; then
        return 0
    fi

    log "Form接口上传失败，尝试备选方法..."

    # 如果form接口失败，尝试put接口
    if upload_file_via_put "$local_file" "$remote_path"; then
        return 0
    fi

    log "所有上传方法均失败"
    return 1
}

# 主函数
main() {
    # 加载配置
    load_config

    # 检查依赖
    for cmd in curl jq sed grep; do
        if ! command -v $cmd >/dev/null 2>&1; then
            log "错误: 需要安装 $cmd"
            exit 1
        fi
    done

    # 获取种子信息
    local torrent_id="${1:-$TR_TORRENT_ID}"
    local torrent_name="${TR_TORRENT_NAME:-}"
    local torrent_dir="${TR_TORRENT_DIR:-}"

    # 如果没有从环境变量获取到信息，尝试从命令行参数获取
    if [ -z "$torrent_id" ] || [ -z "$torrent_name" ] || [ -z "$torrent_dir" ]; then
        log "错误: 未找到Transmission环境变量"
        log "请确保脚本由Transmission调用或提供种子ID参数"
        exit 1
    fi

    log "开始处理种子: $torrent_name (ID: $torrent_id)"
    log "下载目录: $torrent_dir"

    # 检查下载目录是否包含"upload_alist"
    if ! check_upload_alist_condition "$torrent_dir"; then
        exit 0
    fi

    # 获取下载目录的最后一个文件夹名
    local last_folder=$(get_last_folder_name "$torrent_dir")
    log "下载目录最后一个文件夹名: $last_folder"

    # 提取剧集名称和季数
    local series_name=$(clean_series_name "$last_folder")
    local season=$(extract_season_from_folder "$last_folder")

    log "提取的剧集名称: $series_name"
    log "提取的季数: $season"

    # 登录Alist
    if ! alist_login; then
        log "无法登录Alist，退出"
        exit 1
    fi

    # 构建远程路径：基础路径 + 剧集名称
    local remote_base="${REMOTE_BASE_PATH}"
    if [ "${remote_base:0:1}" != "/" ]; then
        remote_base="/${remote_base}"
    fi

    # 添加剧集名称到远程路径
    remote_base="${remote_base%/}/${series_name}"
    log "远程基础路径: $remote_base"

    # 确保远程基础目录存在
    if ! ensure_remote_directory "$remote_base"; then
        log "无法创建远程基础目录"
        exit 1
    fi

    # 查找视频文件
    log "查找视频文件..."

    # 定义查找命令
    local find_cmd="find \"$torrent_dir\" -type f"

    # 构建扩展名条件
    local ext_condition=""
    for ext in $VIDEO_EXTENSIONS; do
        if [ -z "$ext_condition" ]; then
            ext_condition="-name \"*.$ext\""
        else
            ext_condition="$ext_condition -o -name \"*.$ext\""
        fi
    done

    if [ -n "$ext_condition" ]; then
        find_cmd="$find_cmd \\( $ext_condition \\)"
    fi

    # 执行查找
    local files
    files=$(eval "$find_cmd 2>/dev/null")

    if [ -z "$files" ]; then
        log "未找到视频文件"
        exit 0
    fi

    # 处理每个文件
    local file_count=0
    local success_count=0

    echo "$files" | while IFS= read -r local_file; do
        if [ -f "$local_file" ]; then
            ((file_count++))
            local original_filename=$(basename "$local_file")

            # 如果配置了只上传视频文件，检查文件类型
            if [ "$UPLOAD_VIDEO_ONLY" = "yes" ] && ! is_video_file "$original_filename"; then
                log "跳过非视频文件: $original_filename"
                continue
            fi

            # 智能重命名文件
            local new_filename=""
            if [ "$RENAME_VIDEO_FILES" = "yes" ]; then
                new_filename=$(smart_rename_file "$local_file" "$series_name" "$season")
                log "重命名: $original_filename -> $new_filename"
            else
                new_filename="$original_filename"
            fi

            # 构建远程路径：远程基础路径 + 新文件名
            local remote_file="${remote_base}/${new_filename}"

            # 上传文件（带重试机制）
            local success=0
            for ((retry=1; retry<=MAX_RETRIES; retry++)); do
                log "开始上传 (尝试 $retry/$MAX_RETRIES): $new_filename"

                if upload_file "$local_file" "$remote_file"; then
                    success=1
                    ((success_count++))
                    break
                else
                    log "上传失败，等待 ${RETRY_DELAY}秒后重试..."
                    if [ $retry -lt $MAX_RETRIES ]; then
                        sleep $RETRY_DELAY
                    fi
                fi
            done

            if [ $success -eq 0 ]; then
                log "上传失败，已达到最大重试次数: $new_filename"
            fi
        fi
    done

    log "处理完成: 找到 $file_count 个文件，成功上传 $success_count 个"

    # 发送邮件通知
    local subject="[Transmission] 上传完成: ${series_name}"
    local body="种子名称: ${torrent_name}\n下载目录: ${torrent_dir}\n剧集名称: ${series_name}\n季数: ${season}\n文件总数: ${file_count}\n成功上传: ${success_count}\n时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "Subject: ${subject}\n\n${body}" | sendmail alycolas@163.com
    log "已发送邮件通知到 alycolas@163.com"
}

# 执行主函数
main "$@"
