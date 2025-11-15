#!/usr/bin/env zsh
# motd.zsh — System Message of the Day (motd) display function
#
# This file contains the main motd() function and related helpers for displaying
# a formatted system health dashboard including hostname, IP, disk/memory metrics,
# and optional service status.
#
# Main Function:
#   motd()                      — Orchestrate dashboard rendering
#
# Metric Collection Helpers (all prefixed with _motd_):
#   _motd_get_server_info()     — Get hostname, IP, platform
#   _motd_get_disk_metrics()    — Get root filesystem usage
#   _motd_get_memory_metrics()  — Get system memory usage
#   _motd_get_services()        — Get Docker containers and custom services
#
# Rendering Helpers (all prefixed with _motd_):
#   _motd_render_banner()       — Render colored 3-row banner
#   _motd_render_metrics()      — Render metrics display line
#   _motd_render_divider()      — Render 80-column divider
#   _motd_render_services()     — Render 3-column services table
#
# Dependencies:
#   - lib/motd-helpers.zsh (color conversion, bar chart, formatting)
#   - lib/os_detect.zsh (platform detection via $OS_FAMILY)
#   - Standard Unix utilities: df, hostname, (optional: docker, systemctl)
#
# Environment Variables:
#   - $MOTD_COLOR (optional):   Banner hex color (default: Franklin Cello #4C627D)
#   - $MOTD_SERVICES (optional): Array of custom services to monitor
#   - $OS_FAMILY (required):    Platform from os_detect.zsh (darwin, ubuntu, etc.)
#
# Exit Code: Always 0 (informational function; missing metrics not a failure)

setopt function_argzero 2>/dev/null || true

_motd_franklin_root() {
    if [[ -n "${FRANKLIN_ROOT:-}" && -d "${FRANKLIN_ROOT}" ]]; then
        echo "$FRANKLIN_ROOT"
        return
    fi
    local src="${(%):-%N}"
    if [[ -n "$src" && -e "$src" ]]; then
        local lib_dir="${src:h}"
        echo "${lib_dir:h}"
        return
    fi
    if [[ -d "$HOME/.local/share/franklin" ]]; then
        echo "$HOME/.local/share/franklin"
        return
    fi
    echo "$HOME/.franklin"
}

# ==============================================================================
# Metric Collection: T3.1 - Get Server Information
# ==============================================================================

_motd_get_server_info() {
    local hostname=$(hostname 2>/dev/null || echo "unknown")
    local ip_address="0.0.0.0"
    local platform="${OS_FAMILY:-unknown}"

    # Truncate hostname to 40 characters max to fit in banner
    if [[ ${#hostname} -gt 40 ]]; then
        hostname="${hostname:0:40}"
    fi

    # Get IP address based on platform
    if [[ "$platform" == "macos" || "$platform" == "darwin" ]]; then
        # macOS: try multiple interfaces (en0, en1, en2, etc.) and use first non-empty
        for iface in en0 en1 en2 en3; do
            ip_address=$(ipconfig getifaddr "$iface" 2>/dev/null)
            if [[ -n "$ip_address" ]]; then
                break
            fi
        done
        # Fallback if no interface found
        if [[ -z "$ip_address" ]]; then
            ip_address="0.0.0.0"
        fi
    else
        # Linux: use hostname -I or hostname -i
        ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [[ -z "$ip_address" ]]; then
            ip_address=$(hostname -i 2>/dev/null || echo "0.0.0.0")
        fi
    fi

    echo "$hostname $ip_address $platform"
}

# ==============================================================================
# Metric Collection: T3.2 - Get Disk Metrics
# ==============================================================================

_motd_get_disk_metrics() {
    local target="${MOTD_DISK_PATH:-$HOME}"
    local df_output=$(df -Pk "$target" 2>/dev/null | tail -1)

    if [[ -z "$df_output" ]]; then
        echo "0 0.0 0.0"
        return 0
    fi

    local metrics=$(echo "$df_output" | awk '{
        total_k = $2
        used_k  = $3
        pct_str = $5
        gsub(/%/, "", pct_str)

        total_gb = total_k / 1048576
        used_gb  = used_k  / 1048576

        printf "%d %.1f %.1f", pct_str, used_gb, total_gb
    }')

    if [[ -z "$metrics" ]]; then
        echo "0 0.0 0.0"
    else
        echo "$metrics"
    fi
}

# ==============================================================================
# Metric Collection: T3.3 - Get Memory Metrics
# ==============================================================================

_motd_get_memory_metrics() {
    local platform="${OS_FAMILY:-unknown}"
    local mem_used=0
    local mem_total=0

    if [[ "$platform" == "macos" || "$platform" == "darwin" ]]; then
        # macOS: use vm_stat (reports in pages, 4KB default)
        local vm_stat_output=$(vm_stat 2>/dev/null)
        if [[ -n "$vm_stat_output" ]]; then
            local page_size=4096  # bytes per page

            # Extract memory stats from vm_stat (remove periods and ensure numeric)
            local mem_free=$(echo "$vm_stat_output" | grep "Pages free:" | awk '{print $3}' | tr -d '.')
            local mem_active=$(echo "$vm_stat_output" | grep "Pages active:" | awk '{print $3}' | tr -d '.')
            local mem_inactive=$(echo "$vm_stat_output" | grep "Pages inactive:" | awk '{print $3}' | tr -d '.')
            local mem_wired=$(echo "$vm_stat_output" | grep "Pages wired down:" | awk '{print $4}' | tr -d '.')

            # Set defaults if empty
            mem_active=${mem_active:-0}
            mem_wired=${mem_wired:-0}

            # Total physical memory (sysctl) - use awk to handle large numbers
            local mem_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
            mem_total=$(echo "$mem_bytes" | awk '{printf "%.1f", $1/1073741824}')

            # Used = active + wired (inactive is reclaimable on macOS)
            # Convert pages to GB: (pages * 4096 bytes/page) / 1073741824 bytes/GB
            mem_used=$(echo "$mem_active $mem_wired $page_size" | awk '{
                pages = $1 + $2
                bytes = pages * $3
                gb = bytes / 1073741824
                printf "%.1f", gb
            }')
        fi
    else
        # Linux: use /proc/meminfo
        if [[ -f /proc/meminfo ]]; then
            local memtotal=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
            local memavail=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}')

            if [[ -n "$memtotal" && -n "$memavail" ]]; then
                # Use awk for floating-point arithmetic to avoid integer truncation
                local mem_metrics=$(awk -v total="$memtotal" -v avail="$memavail" 'BEGIN {
                    total_gb = total / 1048576
                    avail_gb = avail / 1048576
                    used_gb = total_gb - avail_gb
                    printf "%.1f %.1f", used_gb, total_gb
                }')
                mem_used=$(echo "$mem_metrics" | cut -d' ' -f1)
                mem_total=$(echo "$mem_metrics" | cut -d' ' -f2)
            fi
        fi
    fi

    # Output with 1 decimal place
    printf "%.1f %.1f" "$mem_used" "$mem_total"
}

_motd_get_version_info() {
    local root="$(_motd_franklin_root)"
    local version_script="$root/scripts/current_franklin_version.sh"
    local version_file="$root/VERSION"
    local current_version="unknown"
    local latest_version="unknown"
    local version_status="unknown"

    if [[ -x "$version_script" ]]; then
        current_version=$("$version_script" 2>/dev/null || echo "unknown")
    elif [[ -f "$version_file" ]]; then
        current_version=$(cat "$version_file" 2>/dev/null || echo "unknown")
    else
        current_version=$(git -C "$root" describe --tags --dirty --always 2>/dev/null || echo "unknown")
    fi

    if command -v gh >/dev/null 2>&1; then
        latest_version=$(gh release view --json tagName -q '.tagName' 2>/dev/null || echo "unknown")
    else
        latest_version=$(curl -fsSL "https://api.github.com/repos/jeremyfuksa/franklin/releases/latest" 2>/dev/null \
            | grep -m1 '"tag_name"' \
            | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^\"]+)".*/\1/' 2>/dev/null || echo "unknown")
    fi

    if [[ "$current_version" != "unknown" && "$latest_version" != "unknown" ]]; then
        if [[ "$current_version" == "$latest_version" ]]; then
            version_status="current"
        else
            version_status="outdated"
        fi
    fi

    echo "$version_status|$current_version|$latest_version"
}

# ==============================================================================
# Rendering: T3.4 - Render Banner (3-row colored header)
# ==============================================================================

_motd_render_banner() {
    local hostname="$1"
    local ip_address="$2"
    local bg_sequence="$3"
    local fg_sequence="$4"
    local text_color="$5"
    local width="${6:-80}"

    if [[ -z "$width" || "$width" -le 0 ]]; then
        width=80
    elif [[ "$width" -gt 80 ]]; then
        width=80
    fi

    # ANSI escape sequences for colors (already built)
    local fg_darker="$fg_sequence"
    local bg_main="$bg_sequence"
    local light_text="${CAMPFIRE_PRIMARY_TEXT_LIGHT:-\033[38;2;247;248;249m}"
    local dark_text="${CAMPFIRE_NEUTRAL_950:-\033[38;2;28;31;38m}"
    local text_color_code="$light_text"
    if [[ "$text_color" == "base" ]]; then
        text_color_code="$dark_text"          # Dark text
    fi

    local bold="\033[1m"
    local reset="${NC:-\033[0m}"

    # Top row: width × ▄ in darker foreground color (no background)
    local top_row="${fg_darker}"
    for ((i = 0; i < width; i++)); do
        top_row+="▄"
    done
    top_row+="${reset}"

    # Middle row: space + hostname + space + (IP address) in main color
    local label=" ${hostname} (${ip_address})"
    local visible_len=${#label}
    local padding=0
    if [[ $visible_len -gt $width ]]; then
        label="${label:0:$width}"
        visible_len=${#label}
    fi
    if [[ $visible_len -lt $width ]]; then
        padding=$((width - visible_len))
    fi

    local spaces=""
    if [[ $padding -gt 0 ]]; then
        spaces=$(printf "%*s" "$padding" "")
    fi

    local middle_row="${bg_main}${text_color_code}${bold}${label}${spaces}${reset}"

    # Bottom row: width × ▀ in darker foreground color (no background)
    local bottom_row="${fg_darker}"
    for ((i = 0; i < width; i++)); do
        bottom_row+="▀"
    done
    bottom_row+="${reset}"

    # Output all three rows
    echo "$top_row"
    echo "$middle_row"
    echo "$bottom_row"
}

# ==============================================================================
# Rendering: T3.6 - Render Status Line
# ==============================================================================

_motd_build_status_line() {
    local disk_percent="$1"
    local disk_used_gb="$2"
    local disk_total_gb="$3"
    local memory_used_gb="$4"
    local memory_total_gb="$5"
    local version_info="$6"
    local width="${7:-80}"

    local bar_colored=$(_motd_render_bar_chart "$disk_percent" 10)
    local bar_plain=$(echo "$bar_colored" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')

    local disk_icon=""
    local mem_icon=" "

    local reset="${NC:-\033[0m}"
    local disk_color="${CAMPFIRE_SECONDARY_ACCENT:-}"
    local mem_color="${CAMPFIRE_SAGE_ACCENT:-}"
    local version_color="${CAMPFIRE_INFO_ACCENT:-}"
    if [[ "${FRANKLIN_TEST_MODE:-0}" -eq 1 ]]; then
        reset=""
        disk_color=""
        mem_color=""
        version_color=""
    fi

    # Format disk size (use MB if < 1GB)
    local disk_used_display disk_total_display
    disk_used_display=$(awk -v val="$disk_used_gb" 'BEGIN {
        if (val < 1) printf "%.0fM", val * 1024
        else printf "%.0fG", val
    }')
    disk_total_display=$(awk -v val="$disk_total_gb" 'BEGIN {
        if (val < 1) printf "%.0fM", val * 1024
        else printf "%.0fG", val
    }')
    local disk_stats="${disk_color}${disk_percent}% ${disk_used_display}/${disk_total_display}${reset}"
    local disk_text=" ${disk_color}${disk_icon}${reset} ${bar_colored} ${disk_stats}"
    local disk_plain=" ${disk_icon} ${bar_plain} ${disk_percent}% ${disk_used_display}/${disk_total_display}"
    local disk_len=${#disk_plain}

    # Format memory size (use MB if < 1GB)
    local memory_used_display memory_total_display
    memory_used_display=$(awk -v val="$memory_used_gb" 'BEGIN {
        if (val < 1) printf "%.0fM", val * 1024
        else printf "%.0fG", val
    }')
    memory_total_display=$(awk -v val="$memory_total_gb" 'BEGIN {
        if (val < 1) printf "%.0fM", val * 1024
        else printf "%.0fG", val
    }')
    local memory_plain="${mem_icon} ${memory_used_display}/${memory_total_display}"
    local memory_text="${mem_color}${memory_plain}${reset}"
    local memory_len=${#memory_plain}

    local version_status="unknown"
    local current_version="unknown"
    local latest_version="unknown"
    if [[ -n "$version_info" ]]; then
        IFS='|' read -r version_status current_version latest_version <<<"$version_info"
    fi
    if [[ -z "$current_version" || "$current_version" == "unknown" ]]; then
        current_version="unknown"
    fi
    local franklin_plain="🐢 ${current_version}  "
    if [[ "$version_status" == "outdated" && "$latest_version" != "unknown" ]]; then
        franklin_plain+=" (latest: ${latest_version})"
    fi
    local franklin_text="${version_color}${franklin_plain}${reset}"
    local franklin_len=${#franklin_plain}

    local min_spacing=2
    local required=$((disk_len + memory_len + franklin_len + min_spacing))
    if (( width <= required )); then
        echo "${disk_text} ${memory_text} ${franklin_text}"
        return
    fi

    local remaining=$((width - disk_len - memory_len - franklin_len))
    local gap1=$((remaining / 2))
    local gap2=$((remaining - gap1))
    if (( gap1 < 1 )); then gap1=1; fi
    if (( gap2 < 1 )); then gap2=1; fi

    local colored_line
    printf -v colored_line "%s%*s%s%*s%s" \
        "$disk_text" "$gap1" "" \
        "$memory_text" "$gap2" "" \
        "$franklin_text"

    local plain_length=$((disk_len + gap1 + memory_len + gap2 + franklin_len))
    printf "%s|||%d\n" "$colored_line" "$plain_length"
}

# ==============================================================================
# Rendering: T3.8 - Render Divider Line
# ==============================================================================

_motd_render_divider() {
    local width="${1:-80}"
    if [[ -z "$width" || "$width" -le 0 ]]; then
        width=80
    fi

    # width × ─ character
    local fg="${CAMPFIRE_PRIMARY_BAR:-\033[38;2;62;79;102m}"
    local bg="${CAMPFIRE_PRIMARY_200_BG:-}"
    local reset="${NC:-\033[0m}"
    local divider="${bg}${fg}"
    for ((i = 0; i < width; i++)); do
        divider+="─"
    done
    divider+="${reset}"
    echo -e "$divider"
}

# ==============================================================================
# Metric Collection / Rendering: Services & Containers
# ==============================================================================

_motd_detect_service_state() {
    local service="$1"
    local state="unknown"

    if [[ -z "$service" ]]; then
        echo "$state"
        return
    fi

    if command -v systemctl >/dev/null 2>&1; then
        state=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
    elif command -v service >/dev/null 2>&1; then
        if service "$service" status >/dev/null 2>&1; then
            state="active"
        else
            state="inactive"
        fi
    elif [[ "$OS_FAMILY" == "macos" || "$OS_FAMILY" == "darwin" ]] && command -v launchctl >/dev/null 2>&1; then
        if launchctl list | grep -q "$service"; then
            state="active"
        else
            state="inactive"
        fi
    fi

    echo "$state"
}

_motd_simplify_ports() {
    local ports="$1"
    [[ -z "$ports" ]] && return

    local -a entries formatted=()
    IFS=',' read -rA entries <<<"$ports"

    local entry
    for entry in "${entries[@]}"; do
        entry="${entry// /}"
        [[ -z "$entry" ]] && continue
        if [[ "$entry" == *"/udp"* ]]; then
            continue
        fi
        entry=${entry%/tcp}
        entry=${entry%/TCP}
        if [[ "$entry" == *"->"* ]]; then
            local left="${entry%%->*}"
            local right="${entry##*->}"
            left="${left##*:}"
            right="${right##*:}"
            formatted+=("${left}→${right}")
        else
            entry="${entry##*:}"
            formatted+=("$entry")
        fi
    done

    (( ${#formatted[@]} == 0 )) && return

    local IFS=', '
    echo "${formatted[*]}"
}

_motd_service_icon() {
    local svc_status="$1"
    svc_status=$(printf '%s' "$svc_status" | tr '[:upper:]' '[:lower:]')
    local reset="${NC:-\033[0m}"

    case "$svc_status" in
        running*|up*|active*|healthy*)
            printf '\033[32m● %s' "$reset"  # Green
            ;;
        exited*|dead*|inactive*|failed*|created*|down*|unhealthy*)
            printf '\033[31m● %s' "$reset"  # Red
            ;;
        restarting*|start*|activating*)
            printf '\033[33m● %s' "$reset"  # Yellow
            ;;
        *)
            printf '\033[37m● %s' "$reset"  # Gray
            ;;
    esac
}

_motd_get_services() {
    local -a entries=()

    if command -v docker >/dev/null 2>&1; then
        local docker_output
        docker_output=$(docker ps -a --format '{{.Names}}|{{.Status}}|{{.Ports}}' 2>/dev/null)
        if [[ -n "$docker_output" ]]; then
            local name entry_status ports
            while IFS='|' read -r name entry_status ports; do
                [[ -z "$name" ]] && continue
                entries+=("docker|$entry_status|$name|$ports")
            done <<<"$docker_output"
        fi
    fi

    local -a custom_services=()
    local decl
    if decl=$(typeset -p MOTD_SERVICES 2>/dev/null); then
        if [[ "$decl" == *"typeset -a"* ]]; then
            custom_services=("${MOTD_SERVICES[@]}")
        elif [[ -n "${MOTD_SERVICES:-}" ]]; then
            custom_services=(${=MOTD_SERVICES})
        fi
    elif [[ -n "${MOTD_SERVICES:-}" ]]; then
        custom_services=(${=MOTD_SERVICES})
    fi

    if (( ${#custom_services[@]} > 0 )); then
        local svc state
        for svc in "${custom_services[@]}"; do
            [[ -z "$svc" ]] && continue
            state=$(_motd_detect_service_state "$svc")
            entries+=("service|$state|$svc|")
        done
    fi

    (( ${#entries[@]} == 0 )) && return

    printf '%s\n' "${entries[@]}"
}

_motd_render_services() {
    local width="${1:-80}"
    shift
    local -a entries=("$@")

    (( ${#entries[@]} == 0 )) && return

    echo "Services"

    local columns=3
    if (( width < columns * 24 )); then
        columns=$(( width / 20 ))
        (( columns < 1 )) && columns=1
    fi
    local column_width=$(( width / columns ))
    if (( column_width < 20 )); then
        column_width=20
    fi
    local rows=$(( ( ${#entries[@]} + columns - 1 ) / columns ))

    local -a cells=()
    local entry type entry_status name ports icon port_display cell
    for entry in "${entries[@]}"; do
        IFS='|' read -r type entry_status name ports <<<"$entry"
        icon=$(_motd_service_icon "$entry_status")
        port_display=$(_motd_simplify_ports "$ports")
        cell="${icon}${name}"
        if [[ -n "$port_display" ]]; then
            cell+=" ${port_display}"
        fi
        cells+=("$cell")
    done

    local count=${#cells[@]}
    local row col idx
    for ((row = 0; row < rows; row++)); do
        local line=""
        for ((col = 0; col < columns; col++)); do
            idx=$(( row + col * rows + 1 ))  # Zsh arrays are 1-indexed
            if (( idx <= count )); then
                cell="${cells[idx]}"
                # Calculate visible length (strip ANSI codes for measurement)
                local cell_plain=$(echo "$cell" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')
                local visible_len=${#cell_plain}

                if (( visible_len > column_width - 1 )); then
                    local truncate_len=$(( column_width > 2 ? column_width - 2 : column_width ))
                    cell_plain="${cell_plain:0:$truncate_len}…"
                    cell="$cell_plain"  # Use plain version if truncated
                    visible_len=${#cell_plain}
                fi

                # Pad based on visible length
                local padding_needed=$(( column_width - visible_len ))
                if (( padding_needed > 0 )); then
                    local spaces=$(printf "%*s" "$padding_needed" "")
                    line+="${cell}${spaces}"
                else
                    line+="$cell"
                fi
            fi
        done
        echo -e "$line"
    done
}

# ==============================================================================
# Main Orchestration: T3.9 - motd() Function
# ==============================================================================

motd() {
    # Get banner color from environment or use default
    local default_hex="${MOTD_DEFAULT_HEX:-#89B4FA}"
    local motd_color="${MOTD_COLOR:-$default_hex}"

    # Convert hex color to ANSI codes / sequences
    local banner_bg_seq=""
    local banner_fg_seq=""
    local use_truecolor=1

    if [[ $use_truecolor -eq 1 ]]; then
        read -r bg_r bg_g bg_b <<< "$(_motd_hex_to_rgb "$motd_color")"
        read -r fg_r fg_g fg_b <<< "$(_motd_get_darker_rgb "$motd_color")"
        banner_bg_seq=$(printf '\033[48;2;%s;%s;%sm' "$bg_r" "$bg_g" "$bg_b")
        banner_fg_seq=$(printf '\033[38;2;%s;%s;%sm' "$fg_r" "$fg_g" "$fg_b")
    else
        local ansi_color_bg=$(_motd_hex_to_ansi "$motd_color")
        local ansi_color_darker=$(_motd_get_darker_color "$ansi_color_bg")
        banner_bg_seq=$(printf '\033[48;5;%sm' "$ansi_color_bg")
        banner_fg_seq=$(printf '\033[38;5;%sm' "$ansi_color_darker")
    fi
    local text_color_choice=$(_motd_text_color "$motd_color")
    local text_color_key="text"
    if [[ "$text_color_choice" == "black" ]]; then
        text_color_key="base"
    fi

    local motd_width="${COLUMNS:-}"
    if [[ -z "$motd_width" || "$motd_width" -le 0 ]]; then
        motd_width=$(tput cols 2>/dev/null || echo 80)
    fi
    if [[ -z "$motd_width" || "$motd_width" -le 0 ]]; then
        motd_width=80
    elif [[ "$motd_width" -gt 80 ]]; then
        motd_width=80
    fi

    if [[ "${MOTD_DEBUG_COLORS:-0}" -eq 1 ]]; then
        printf 'motd debug: hex=%s use_truecolor=%s\n' "$motd_color" "$use_truecolor" >&2
        printf 'motd debug: banner_bg_seq=%q\n' "$banner_bg_seq" >&2
        printf 'motd debug: banner_fg_seq=%q\n' "$banner_fg_seq" >&2
        printf 'motd debug: text_color=%s\n' "$text_color_key" >&2
    fi

    # Collect metrics
    local server_info=$(_motd_get_server_info)
    local disk_metrics=$(_motd_get_disk_metrics)
    local memory_metrics=$(_motd_get_memory_metrics)
    local version_info=$(_motd_get_version_info)

    # Parse server info
    local hostname=$(echo "$server_info" | cut -d' ' -f1)
    local ip_address=$(echo "$server_info" | cut -d' ' -f2)
    local platform=$(echo "$server_info" | cut -d' ' -f3)

    # Parse disk metrics
    local disk_percent=$(echo "$disk_metrics" | cut -d' ' -f1)
    local disk_used_gb=$(echo "$disk_metrics" | cut -d' ' -f2)
    local disk_total_gb=$(echo "$disk_metrics" | cut -d' ' -f3)

    # Parse memory metrics
    local memory_used_gb=$(echo "$memory_metrics" | cut -d' ' -f1)
    local memory_total_gb=$(echo "$memory_metrics" | cut -d' ' -f2)

    local status_payload=$(_motd_build_status_line "$disk_percent" "$disk_used_gb" "$disk_total_gb" "$memory_used_gb" "$memory_total_gb" "$version_info" "$motd_width")
    local status_line=${status_payload%%|||*}
    local status_len=${status_payload##*|||}
    if [[ -n "$status_len" && "$status_len" =~ ^[0-9]+$ && $status_len -gt $motd_width ]]; then
        motd_width=$status_len
        status_payload=$(_motd_build_status_line "$disk_percent" "$disk_used_gb" "$disk_total_gb" "$memory_used_gb" "$memory_total_gb" "$version_info" "$motd_width")
        status_line=${status_payload%%|||*}
    fi

    _motd_render_banner "$hostname" "$ip_address" "$banner_bg_seq" "$banner_fg_seq" "$text_color_key" "$motd_width"
    echo -e "$status_line"
    _motd_render_divider "$motd_width"

    local services_payload=$(_motd_get_services)
    if [[ -n "$services_payload" ]]; then
        local -a _motd_services
        _motd_services=("${(f)services_payload}")
        _motd_render_services "$motd_width" "${_motd_services[@]}"
    fi

    # Always exit with 0 (success), even if some metrics unavailable
    return 0
}
