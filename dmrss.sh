#!/bin/bash

# ==================================================
# dmrss.sh - 蜜柑计划动漫下载脚本
# 功能：通过番组详情页提取下载链接，支持搜索番组、查看字幕组列表（含最新种子标题、大小、时间），
#       交互选择下载条目，或通过命令行参数快速下载。
# 用法：详见 help 信息
# ==================================================

# -------------------- 配置变量 --------------------
BASE_DOWNLOAD_DIR="/home/tiny/dm"
TRANSMISSION_AUTH="tiny:200612031"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
MIKAN_BASE_URL="https://mikanani.me"
TEMP_FILE="/tmp/mikan_rss_$$"
SEARCH_TEMP_FILE="/tmp/mikan_search_$$"
CACHE_DIR="${HOME}/.cache/dmrss"

mkdir -m 775 -p "$CACHE_DIR" 2>/dev/null

# -------------------- 辅助函数 --------------------
# 解码Unicode实体（将形如 &#x4E00; 转换为汉字）
decode_unicode() {
    if command -v perl >/dev/null 2>&1; then
        perl -CS -pe 's/&#x([0-9a-fA-F]+);/chr(hex($1))/ge' <<< "$1" 2>/dev/null || echo "$1"
    else
        echo "$1" | sed 's/&#x[0-9a-fA-F]\+;//g'
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

选项:
  -i, --id ID          蜜柑计划的bangumi ID（可选，与 -s 二选一）
  -s, --search KEYWORD 搜索关键词（可选，与 -i 二选一）
  -g, --subgroup ID    字幕组ID（可选，配合 -i 直接下载该组的第一个或全部）
  -n, --name NAME      下载目录名称（可选，用于下载时）
  -a, --all            下载全部文件（仅当有 -g 时有效）
  -h, --help           显示此帮助信息

示例:
  $0 -s 一拳超人                     # 搜索番组，选择后进入交互下载
  $0 -i 3739 -g 534 -n 一拳超人       # 下载字幕组534的第一个文件（自动检查是否为新条目）
  $0 -i 3739 -g 534 -n 一拳超人 -a    # 下载字幕组534的全部文件（不检查缓存）
  $0 -i 3739                          # 查看番组信息和字幕组列表，并进入交互选择

如果没有 -i 或 -s，将显示此帮助信息。
EOF
}

# 清理临时文件
cleanup() {
    rm -f "$TEMP_FILE" "${TEMP_FILE}.torrent" "$SEARCH_TEMP_FILE" 2>/dev/null
}
trap cleanup EXIT

# -------------------- 参数解析 --------------------
parse_args() {
    BANGUMI_ID=""
    SEARCH_KEYWORD=""
    SUBGROUP_ID=""
    DIR_NAME=""
    DOWNLOAD_ALL=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--id)
                BANGUMI_ID="$2"
                shift 2
                ;;
            -s|--search)
                SEARCH_KEYWORD="$2"
                shift 2
                ;;
            -g|--subgroup)
                SUBGROUP_ID="$2"
                shift 2
                ;;
            -n|--name)
                DIR_NAME="$2"
                shift 2
                ;;
            -a|--all)
                DOWNLOAD_ALL=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "错误: 未知选项 $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 检查必需参数：必须有 -i 或 -s
    if [ -z "$BANGUMI_ID" ] && [ -z "$SEARCH_KEYWORD" ]; then
        echo "错误: 必须提供 -i 或 -s"
        show_help
        exit 1
    fi
    if [ -n "$BANGUMI_ID" ] && [ -n "$SEARCH_KEYWORD" ]; then
        echo "错误: -i 和 -s 不能同时使用"
        show_help
        exit 1
    fi

    if [ -z "$DIR_NAME" ]; then
        if [ -n "$BANGUMI_ID" ]; then
            DIR_NAME="$BANGUMI_ID"
        else
            DIR_NAME="$SEARCH_KEYWORD"
        fi
    fi
}

# -------------------- 工具函数：从<tbody>中提取每个<tr>块（跨行） --------------------
extract_tr_blocks() {
    local tbody="$1"
    echo "$tbody" | awk '
        BEGIN { in_tr = 0; block = "" }
        {
            for (i = 1; i <= length; i++) {
                char = substr($0, i, 1)
                block = block char
                if (!in_tr && index(block, "<tr>")) {
                    in_tr = 1
                    pos = index(block, "<tr>")
                    block = substr(block, pos)
                }
                if (in_tr && index(block, "</tr>")) {
                    end_pos = index(block, "</tr>") + 4
                    print substr(block, 1, end_pos)
                    in_tr = 0
                    block = substr(block, end_pos + 1)
                }
            }
        }
    '
}

# -------------------- 从已下载的临时文件中显示字幕组列表（不重新下载） --------------------
display_subgroup_list_from_file() {
    if [ ! -f "$TEMP_FILE" ]; then
        echo "错误: 缓存文件不存在，请先获取番组信息"
        return 1
    fi

    # 提取并解码番组标题
    local title=$(grep -oP '<title>\K[^<]+' "$TEMP_FILE" | head -1 | sed 's/Mikan Project - //')
    title=$(decode_unicode "$title")
    echo "番组标题: $title"
    echo ""

    # 提取所有字幕组块（来自左侧边栏）
    local blocks=$(sed -n '/<li class="leftbar-item">/,/<\/li>/p' "$TEMP_FILE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '\n' ' ' | sed 's/<\/li>/<\/li>\n/g' | grep -v '^$')

    echo "$blocks" | while read -r block; do
        # 提取字幕组ID
        id=$(echo "$block" | grep -oP 'subgroup-name subgroup-\K[0-9]+')
        [ -z "$id" ] && continue

        # 提取名称（可能包含Unicode实体）
        name=$(echo "$block" | grep -oP 'subgroup-name subgroup-[0-9]+"[^>]*>\K[^<]+')
        name=$(decode_unicode "$name")

        # 定位到该字幕组的 episode-table 区域
        seed_section=$(sed -n "/<div class=\"subgroup-text\" id=\"$id\"/,/subgroup-scroll-end-$id/p" "$TEMP_FILE")

        # 提取最新种子标题
        seed_title=$(echo "$seed_section" | grep -m1 '<a class="magnet-link-wrap"' | sed 's/.*<a[^>]*>\([^<]*\)<.*/\1/')
        if [ -n "$seed_title" ]; then
            seed_title=$(decode_unicode "$seed_title")
            # 提取文件大小和更新时间（第三个和第四个<td>）
            size_time=$(echo "$seed_section" | awk '
                BEGIN { in_tbody = 0; tr_count = 0; td_count = 0; size = ""; time = ""; }
                /<tbody>/ { in_tbody = 1; next; }
                /<\/tbody>/ { exit; }
                in_tbody && /<tr>/ {
                    tr_count++;
                    if (tr_count == 1) {
                        in_first_tr = 1;
                        td_count = 0;
                        next;
                    }
                }
                in_first_tr && /<td/ {
                    # 提取当前<td>标签内的所有内容（可能跨行）
                    td_content = $0;
                    while (td_content !~ /<\/td>/) {
                        getline next_line;
                        td_content = td_content " " next_line;
                    }
                    gsub(/<[^>]*>/, "", td_content);
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", td_content);
                    td_count++;
                    if (td_count == 3) { size = td_content; }
                    if (td_count == 4) { time = td_content; }
                    if (td_count >= 4) {
                        printf "%s\t%s", size, time;
                        exit;
                    }
                }
                in_first_tr && /<\/tr>/ { exit; }
            ')
            if [ -n "$size_time" ]; then
                seed_size=$(echo "$size_time" | cut -f1)
                seed_time=$(echo "$size_time" | cut -f2)
            else
                seed_size="N/A"
                seed_time="N/A"
            fi
        else
            seed_title="(无种子)"
            seed_size="N/A"
            seed_time="N/A"
        fi

        echo "ID: $id"
        echo "字幕组名称: $name"
        echo "最新种子: $seed_title"
        echo "文件大小: $seed_size"
        echo "更新时间: $seed_time"
        echo ""
    done
}

# -------------------- 下载并首次显示字幕组列表 --------------------
fetch_and_display() {
    local bangumi_id="$1"
    local url="${MIKAN_BASE_URL}/Home/Bangumi/${bangumi_id}"

    echo "获取番组信息: $url"
    echo ""

    if ! curl -sL -A "$USER_AGENT" "$url" > "$TEMP_FILE"; then
        echo "错误: 无法获取页面"
        exit 1
    fi

    display_subgroup_list_from_file
}

# -------------------- 交互下载某个字幕组的所有条目 --------------------
interactive_download() {
    local subgroup_id="$1"
    local bangumi_id="$2"
    echo ""
    echo "正在获取字幕组 $subgroup_id 的发布条目..."

    # 定位字幕组区域
    local seed_section=$(sed -n "/<div class=\"subgroup-text\" id=\"$subgroup_id\"/,/subgroup-scroll-end-$subgroup_id/p" "$TEMP_FILE")
    if [ -z "$seed_section" ]; then
        seed_section=$(sed -n "/<div class=\"subgroup-text\".*id=\"$subgroup_id\"/,/subgroup-scroll-end-$subgroup_id/p" "$TEMP_FILE")
    fi

    if [ -z "$seed_section" ]; then
        echo "错误: 未找到字幕组 ID $subgroup_id 的区域"
        return
    fi

    # 提取<tbody>区域
    local tbody=$(echo "$seed_section" | sed -n '/<tbody>/,/<\/tbody>/p')
    if [ -z "$tbody" ]; then
        echo "错误: 未找到<tbody>标签"
        return
    fi

    # 提取每个<tr>块
    local tr_blocks=$(extract_tr_blocks "$tbody")
    if [ -z "$tr_blocks" ]; then
        echo "该字幕组暂无发布条目"
        return
    fi

    # 将条目存入数组
    local titles=() sizes=() times=() torrents=() magnets=()
    local count=0
    while IFS= read -r tr; do
        [ -z "$tr" ] && continue
        count=$((count+1))

        # 提取标题
        title=$(echo "$tr" | grep -oP '<a class="magnet-link-wrap"[^>]*>\K[^<]+' | head -1)
        [ -z "$title" ] && title=$(echo "$tr" | grep -oP 'target="_blank"[^>]*>\K[^<]+' | head -2 | tail -1)
        title=$(decode_unicode "$title")
        titles+=("$title")

        # 提取所有<td>内容
        tds=$(echo "$tr" | grep -oP '<td>\K[^<]*' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        size=$(echo "$tds" | sed -n '3p'); [ -z "$size" ] && size="N/A"
        time=$(echo "$tds" | sed -n '4p'); [ -z "$time" ] && time="N/A"
        sizes+=("$size")
        times+=("$time")

        # 提取下载链接
        torrent_path=$(echo "$tr" | grep -oP 'href="\K/Download/[^"]+\.torrent')
        if [ -n "$torrent_path" ]; then
            torrents+=("${MIKAN_BASE_URL}${torrent_path}")
        else
            torrents+=("")
        fi

        magnet=$(echo "$tr" | grep -oP 'data-magnet="\K[^"]+')
        magnets+=("$magnet")
    done <<< "$tr_blocks"

    if [ $count -eq 0 ]; then
        echo "未找到任何有效条目"
        return
    fi

    # 显示条目列表
    echo ""
    echo "找到 $count 个发布条目:"
    for ((i=0; i<count; i++)); do
        printf "%3d. %s\n" $((i+1)) "${titles[i]}"
        printf "    大小: %-8s  时间: %s\n" "${sizes[i]}" "${times[i]}"
    done

    # 下载选择循环
    while true; do
        echo ""
        read -p "请输入要下载的序号 (例如 1,3,5 或 1-5 或 all，输入0返回): " choice
        if [ "$choice" = "0" ]; then
            echo "返回字幕组列表"
            return
        fi
        if [ "$choice" = "all" ]; then
            selected_indices=$(seq 1 $count)
            break
        fi

        # 解析用户输入
        selected_indices=""
        IFS=',' read -ra parts <<< "$choice"
        valid=1
        for part in "${parts[@]}"; do
            if [[ "$part" =~ ^[0-9]+$ ]]; then
                if [ "$part" -ge 1 ] && [ "$part" -le "$count" ]; then
                    selected_indices+="$part "
                else
                    echo "错误: 序号 $part 超出范围 (1-$count)"
                    valid=0
                    break
                fi
            elif [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                start=${BASH_REMATCH[1]}
                end=${BASH_REMATCH[2]}
                if [ "$start" -ge 1 ] && [ "$start" -le "$count" ] && [ "$end" -ge 1 ] && [ "$end" -le "$count" ] && [ "$start" -le "$end" ]; then
                    for ((i=start; i<=end; i++)); do
                        selected_indices+="$i "
                    done
                else
                    echo "错误: 范围 $start-$end 无效"
                    valid=0
                    break
                fi
            else
                echo "错误: 输入格式无效"
                valid=0
                break
            fi
        done
        if [ "$valid" -eq 1 ]; then
            break
        fi
    done

    # 去重排序
    selected_indices=$(echo "$selected_indices" | tr ' ' '\n' | sort -nu | tr '\n' ' ')

    echo ""
    echo "将下载以下条目:"
    for idx in $selected_indices; do
        echo "$idx: ${titles[$((idx-1))]}"
    done

    read -p "是否继续? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "取消下载"
        return
    fi

    # 准备下载目录
    local dir_name="$bangumi_id"
    read -p "请输入下载目录名 (直接回车使用番组ID '$bangumi_id'): " custom_dir
    if [ -n "$custom_dir" ]; then
        dir_name="$custom_dir"
    fi
    local download_dir="${BASE_DOWNLOAD_DIR}/${dir_name}"
    mkdir -m 775 -p "$download_dir" 2>/dev/null

    # 逐个下载
    local total=$(echo "$selected_indices" | wc -w)
    local current=0
    for idx in $selected_indices; do
        current=$((current+1))
        i=$((idx-1))
        echo ""
        echo "[$current/$total] 处理条目 $idx: ${titles[i]}"

        if [ -n "${torrents[i]}" ]; then
            echo "使用 torrent 链接: ${torrents[i]}"
            if wget -q -O "${TEMP_FILE}.torrent" "${torrents[i]}"; then
                if transmission-remote -n "$TRANSMISSION_AUTH" -w "$download_dir" -a "${TEMP_FILE}.torrent" >/dev/null 2>&1; then
                    echo "✓ 添加成功"
                else
                    echo "✗ 添加失败"
                fi
                rm -f "${TEMP_FILE}.torrent"
            else
                echo "✗ 下载 torrent 文件失败"
            fi
        elif [ -n "${magnets[i]}" ]; then
            echo "使用磁力链接"
            if transmission-remote -n "$TRANSMISSION_AUTH" -w "$download_dir" -a "${magnets[i]}" >/dev/null 2>&1; then
                echo "✓ 添加成功"
            else
                echo "✗ 添加失败"
            fi
        else
            echo "✗ 无可用下载链接"
        fi
    done

    echo ""
    echo "下载任务处理完成。"
}

# -------------------- 非交互下载（通过 -i 和 -g 参数） --------------------
download_subgroup() {
    local bangumi_id="$1"
    local subgroup_id="$2"
    local dir_name="$3"
    local download_all="$4"

    # 下载番组详情页
    local page_url="${MIKAN_BASE_URL}/Home/Bangumi/${bangumi_id}"
    echo "获取番组详情页: $page_url"

    if ! curl -sL -A "$USER_AGENT" "$page_url" > "$TEMP_FILE"; then
        echo "错误: 无法获取页面"
        exit 1
    fi

    # 定位到指定字幕组的 episode-table 区域
    local seed_section=$(sed -n "/<div class=\"subgroup-text\" id=\"$subgroup_id\"/,/subgroup-scroll-end-$subgroup_id/p" "$TEMP_FILE")
    if [ -z "$seed_section" ]; then
        echo "错误: 未找到字幕组 ID $subgroup_id 的种子区域"
        exit 1
    fi

    # 提取<tbody>区域
    local tbody=$(echo "$seed_section" | sed -n '/<tbody>/,/<\/tbody>/p')
    if [ -z "$tbody" ]; then
        echo "错误: 未找到<tbody>标签"
        exit 1
    fi

    # 提取所有<tr>块
    local tr_blocks=$(extract_tr_blocks "$tbody")
    if [ -z "$tr_blocks" ]; then
        echo "错误: 该字幕组暂无种子"
        exit 1
    fi

    local download_dir="${BASE_DOWNLOAD_DIR}/${dir_name}"
    mkdir -m 775 -p "$download_dir" 2>/dev/null

    if [ "$download_all" = true ]; then
        echo "模式: 下载全部文件"
        echo "下载目录: $download_dir"
        local count=0
        local max_items=10
        echo "$tr_blocks" | head -$max_items | while read -r tr; do
            count=$((count + 1))
            torrent_path=$(echo "$tr" | grep -oP 'href="\K/Download/[^"]+\.torrent')
            if [ -n "$torrent_path" ]; then
                torrent_url="${MIKAN_BASE_URL}${torrent_path}"
                echo "正在下载第 $count 个torrent..."
                if wget -q -O "${TEMP_FILE}.torrent" "$torrent_url"; then
                    if transmission-remote -n "$TRANSMISSION_AUTH" -w "$download_dir" -a "${TEMP_FILE}.torrent" >/dev/null 2>&1; then
                        echo "✓ 已添加第 $count 个torrent"
                    else
                        echo "✗ 添加第 $count 个torrent失败"
                    fi
                    rm -f "${TEMP_FILE}.torrent"
                else
                    echo "✗ 下载第 $count 个torrent失败"
                fi
            else
                magnet=$(echo "$tr" | grep -oP 'data-magnet="\K[^"]+')
                if [ -n "$magnet" ]; then
                    echo "正在添加第 $count 个磁力链接..."
                    if transmission-remote -n "$TRANSMISSION_AUTH" -w "$download_dir" -a "$magnet" >/dev/null 2>&1; then
                        echo "✓ 已添加第 $count 个磁力链接"
                    else
                        echo "✗ 添加第 $count 个磁力链接失败"
                    fi
                else
                    echo "✗ 第 $count 个条目无有效下载链接"
                fi
            fi
        done
        echo "完成: 共处理 $count 个文件"
        return
    fi

    # 单条下载模式（带缓存检查）
    local first_tr=$(echo "$tr_blocks" | head -1)
    torrent_path=$(echo "$first_tr" | grep -oP 'href="\K/Download/[^"]+\.torrent')
    if [ -n "$torrent_path" ]; then
        item_id="${MIKAN_BASE_URL}${torrent_path}"
        download_link="$item_id"
        use_torrent=true
    else
        magnet=$(echo "$first_tr" | grep -oP 'data-magnet="\K[^"]+')
        if [ -n "$magnet" ]; then
            item_id="$magnet"
            download_link="$magnet"
            use_torrent=false
        else
            echo "错误: 第一个条目无有效下载链接"
            exit 1
        fi
    fi

    cache_key="${bangumi_id}_${subgroup_id}"
    cache_file="${CACHE_DIR}/${cache_key}"
    if [ -f "$cache_file" ]; then
        last_id=$(cat "$cache_file")
        if [ "$last_id" = "$item_id" ]; then
            echo "没有新条目，跳过下载"
            return 0
        fi
    fi

    echo "发现新条目，开始下载..."
    echo "模式: 下载第一个文件"
    echo "下载目录: $download_dir"

    if [ "$use_torrent" = true ]; then
        echo "找到torrent: $download_link"
        if wget -q -O "${TEMP_FILE}.torrent" "$download_link"; then
            if transmission-remote -n "$TRANSMISSION_AUTH" -w "$download_dir" -a "${TEMP_FILE}.torrent" >/dev/null 2>&1; then
                echo "✓ 成功添加torrent到transmission"
                echo "$item_id" > "$cache_file"
            else
                echo "✗ 添加torrent到transmission失败"
                exit 1
            fi
        else
            echo "✗ 下载torrent文件失败"
            exit 1
        fi
    else
        echo "找到磁力链接: $download_link"
        if transmission-remote -n "$TRANSMISSION_AUTH" -w "$download_dir" -a "$download_link" >/dev/null 2>&1; then
            echo "✓ 成功添加磁力链接到transmission"
            echo "$item_id" > "$cache_file"
        else
            echo "✗ 添加磁力链接到transmission失败"
            exit 1
        fi
    fi
}

# -------------------- 搜索番组并让用户选择 --------------------
# -------------------- 搜索番组并让用户选择 --------------------
search_and_select() {
    local keyword="$1"

    echo "搜索关键词: $keyword"
    echo ""

    # 使用 curl 的 --data-urlencode 自动编码关键词，并获取响应
    if ! curl -sL -A "$USER_AGENT" --get --data-urlencode "searchstr=$keyword" "${MIKAN_BASE_URL}/Home/Search" > "$SEARCH_TEMP_FILE"; then
        echo "错误: 无法获取搜索结果"
        exit 1
    fi

    # 提取所有 ID（已验证可工作）
    mapfile -t ids < <(grep -oP 'href="/Home/Bangumi/\K\d+' "$SEARCH_TEMP_FILE" | sort -u)
    if [ ${#ids[@]} -eq 0 ]; then
        echo "未找到相关番组"
        exit 1
    fi

    declare -A id_to_title
    local count=0

    # 遍历每个 ID，查找对应的标题
    for id in "${ids[@]}"; do
        # 尝试匹配该 ID 的 <a> 标签（单行或跨行）
        # 方法1：单行匹配
        a_tag=$(grep -oP "<a\s+[^>]*href=\"/Home/Bangumi/$id\"[^>]*>.*?</a>" "$SEARCH_TEMP_FILE" | tr -d '\n')
        if [ -z "$a_tag" ]; then
            # 方法2：跨行匹配
            a_tag=$(sed -n "/<a\s\+[^>]*href=\"\/Home\/Bangumi\/$id\"/,/<\/a>/p" "$SEARCH_TEMP_FILE" | tr -d '\n')
        fi

        if [ -n "$a_tag" ]; then
            # 提取 title 属性
            title=$(echo "$a_tag" | grep -oP 'title="\K[^"]+')
            if [ -z "$title" ]; then
                # 若无 title，取标签内纯文本
                title=$(echo "$a_tag" | sed 's/<[^>]*>//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            fi
            title=$(decode_unicode "$title")
            id_to_title["$id"]="$title"
            ((count++))
        else
            # 保底：用 ID 作为标题
            id_to_title["$id"]="ID: $id"
            ((count++))
        fi
    done

    if [ $count -eq 0 ]; then
        echo "未找到有效番组条目"
        exit 1
    fi

    # 转换为数组，按 ID 排序
    ids=()
    titles=()
    for id in "${!id_to_title[@]}"; do
        ids+=("$id")
        titles+=("${id_to_title[$id]}")
    done
    # 冒泡排序（按数字 ID）
    for ((i=0; i<count; i++)); do
        for ((j=i+1; j<count; j++)); do
            if [ "${ids[$i]}" -gt "${ids[$j]}" ]; then
                tmp_id="${ids[$i]}"; ids[$i]="${ids[$j]}"; ids[$j]="$tmp_id"
                tmp_title="${titles[$i]}"; titles[$i]="${titles[$j]}"; titles[$j]="$tmp_title"
            fi
        done
    done

    # 显示列表
    echo "找到 $count 个相关番组:"
    for ((i=0; i<count; i++)); do
        printf "%3d. [ID: %s] %s\n" $((i+1)) "${ids[i]}" "${titles[i]}"
    done

    # 用户选择
    while true; do
        echo ""
        read -p "请选择番组序号 (输入0退出): " choice
        if [ "$choice" = "0" ]; then
            echo "退出"
            exit 0
        fi
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ]; then
            echo "错误: 请输入1-$count之间的数字"
            continue
        fi
        selected_id="${ids[$((choice-1))]}"
        break
    done

    echo "已选择: [ID: $selected_id] ${titles[$((choice-1))]}"
    echo ""

    # 下载该ID的详情页并进入交互
    fetch_and_display "$selected_id"
    # 交互循环
    while true; do
        echo ""
        echo "Bangumi：$selected_id"
        read -p "请输入字幕组ID (输入0退出): " subgroup_choice
        if [ "$subgroup_choice" = "0" ]; then
            echo "退出脚本"
            break
        fi
        if ! [[ "$subgroup_choice" =~ ^[0-9]+$ ]]; then
            echo "错误: 请输入数字ID"
            continue
        fi
        # 验证ID是否存在
        valid_ids=$(sed -n 's/.*subgroup-name subgroup-\([0-9]*\)".*/\1/p' "$TEMP_FILE" | sort -u)
        if ! echo "$valid_ids" | grep -qw "$subgroup_choice"; then
            echo "错误: 无效的字幕组ID"
            continue
        fi
        # 进入该字幕组的交互下载
        interactive_download "$subgroup_choice" "$selected_id"
        # 返回后重新显示字幕组列表
        display_subgroup_list_from_file
    done
}

# -------------------- 主函数 --------------------
main() {
    parse_args "$@"

    if [ -n "$SEARCH_KEYWORD" ]; then
        # 搜索模式
        search_and_select "$SEARCH_KEYWORD"
    elif [ -n "$BANGUMI_ID" ] && [ -n "$SUBGROUP_ID" ]; then
        # 有 -i 和 -g，直接下载字幕组
        download_subgroup "$BANGUMI_ID" "$SUBGROUP_ID" "$DIR_NAME" "$DOWNLOAD_ALL"
    elif [ -n "$BANGUMI_ID" ]; then
        # 只有 -i，显示字幕组列表并进入交互
        fetch_and_display "$BANGUMI_ID"
        # 交互循环
        while true; do
            echo ""
            echo "Bangumi：$BANGUMI_ID"
            read -p "请输入字幕组ID (输入0退出): " subgroup_choice
            if [ "$subgroup_choice" = "0" ]; then
                echo "退出脚本"
                break
            fi
            if ! [[ "$subgroup_choice" =~ ^[0-9]+$ ]]; then
                echo "错误: 请输入数字ID"
                continue
            fi
            # 验证ID是否存在
            valid_ids=$(sed -n 's/.*subgroup-name subgroup-\([0-9]*\)".*/\1/p' "$TEMP_FILE" | sort -u)
            if ! echo "$valid_ids" | grep -qw "$subgroup_choice"; then
                echo "错误: 无效的字幕组ID"
                continue
            fi
            # 进入该字幕组的交互下载
            interactive_download "$subgroup_choice" "$BANGUMI_ID"
            # 返回后重新显示字幕组列表
            display_subgroup_list_from_file
        done
    else
        # 不应到达这里
        show_help
        exit 1
    fi
}

main "$@"
