#!/usr/bin/env zsh
# motd-helpers.zsh — Color conversion and formatting utilities for motd() function
# 
# This file contains helper functions for the motd() system health dashboard display.
# Helpers include color conversion, bar chart rendering, and column formatting.
#
# Functions (all prefixed with _motd_):
#   _motd_hex_to_ansi()         — Convert hex color to ANSI 256-color code
#   _motd_get_darker_color()    — Calculate 10% darker ANSI color variant
#   _motd_text_color()          — Determine white/black text for contrast
#   _motd_render_bar_chart()    — Render disk usage bar chart
#   _motd_format_column()       — Format text in fixed-width column
#
# See motd.zsh for main orchestration function.

# Default Franklin signature accent for the MOTD banner (Cello 600)
: "${MOTD_DEFAULT_HEX:=#4C627D}"
: "${MOTD_DEFAULT_ANSI:=66}"

# ==============================================================================
# Helper 1: Hex to ANSI 256-Color Conversion
# ==============================================================================

_motd_hex_to_ansi() {
    local hex_color="${1:-$MOTD_DEFAULT_HEX}"

    # Remove '#' prefix and convert to uppercase for consistency
    hex_color="${hex_color#\#}"

    # Validate hex format (6 hex digits)
    if [[ ! "$hex_color" =~ ^[0-9A-Fa-f]{6}$ ]]; then
        # Invalid format, return default Franklin accent ANSI code
        echo "$MOTD_DEFAULT_ANSI"
        return 0
    fi

    # Extract RGB components (2 hex digits each)
    local r_hex="${hex_color:0:2}"
    local g_hex="${hex_color:2:2}"
    local b_hex="${hex_color:4:2}"

    # Convert hex to decimal (0-255)
    local r=$((16#$r_hex))
    local g=$((16#$g_hex))
    local b=$((16#$b_hex))

    # Quantize each component to 0-5 range (6 levels for ANSI 256)
    # Formula: round(value / 255 * 5)
    r=$(((r * 5 + 127) / 255))  # Rounding: add 127 then divide by 255
    g=$(((g * 5 + 127) / 255))
    b=$(((b * 5 + 127) / 255))

    # Calculate ANSI 256 color code using standard formula
    # ANSI 256-color: 0-15 (standard), 16-231 (6×6×6 RGB cube), 232-255 (grayscale)
    # For RGB cube: code = 16 + (36 * R + 6 * G + B)
    local ansi_code=$((16 + (36 * r) + (6 * g) + b))

    echo "$ansi_code"
}

# ==============================================================================
# Helper 1b: Hex to RGB (truecolor support)
# ==============================================================================

_motd_hex_to_rgb() {
    local hex_color="${1:-$MOTD_DEFAULT_HEX}"
    hex_color="${hex_color#'#'}"

    if [[ ! "$hex_color" =~ ^[0-9A-Fa-f]{6}$ ]]; then
        # Default Franklin accent (76, 98, 125)
        echo "76 98 125"
        return 0
    fi

    local r=$((16#${hex_color:0:2}))
    local g=$((16#${hex_color:2:2}))
    local b=$((16#${hex_color:4:2}))

    printf "%d %d %d" "$r" "$g" "$b"
}

# ==============================================================================
# Helper 2b: Darker RGB Calculation (10% darker truecolor variant)
# ==============================================================================

_motd_get_darker_rgb() {
    local hex_color="$1"
    local factor="${2:-90}"  # percentage

    read -r r g b <<< "$(_motd_hex_to_rgb "$hex_color")"

    r=$((r * factor / 100))
    g=$((g * factor / 100))
    b=$((b * factor / 100))

    # Clamp to valid range
    (( r < 0 )) && r=0
    (( g < 0 )) && g=0
    (( b < 0 )) && b=0

    printf "%d %d %d" "$r" "$g" "$b"
}

# ==============================================================================
# Helper 2: Darker Color Calculation (10% darker ANSI variant)
# ==============================================================================

_motd_get_darker_color() {
    local ansi_code="$1"
    local factor="${2:-90}"  # percentage scaling of RGB components

    if [[ $ansi_code -lt 16 ]]; then
        echo "$ansi_code"
        return 0
    fi

    local code=$((ansi_code - 16))
    local r=$(((code / 36) % 6))
    local g=$(((code / 6) % 6))
    local b=$((code % 6))

    r=$((r * 255 / 5))
    g=$((g * 255 / 5))
    b=$((b * 255 / 5))

    r=$((r * factor / 100))
    g=$((g * factor / 100))
    b=$((b * factor / 100))

    if [[ $r -lt 0 ]]; then r=0; elif [[ $r -gt 255 ]]; then r=255; fi
    if [[ $g -lt 0 ]]; then g=0; elif [[ $g -gt 255 ]]; then g=255; fi
    if [[ $b -lt 0 ]]; then b=0; elif [[ $b -gt 255 ]]; then b=255; fi

    r=$(((r * 5 + 127) / 255))
    g=$(((g * 5 + 127) / 255))
    b=$(((b * 5 + 127) / 255))

    local darker_code=$((16 + (36 * r) + (6 * g) + b))
    echo "$darker_code"
}

# ==============================================================================
# Helper 3: Text Color Determination (White or Black for contrast)
# ==============================================================================

_motd_text_color() {
    local raw="$1"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        if (( raw < 8 )); then
            echo "white"
        else
            echo "black"
        fi
        return 0
    fi

    local hex="${raw#'#'}"
    if [[ ${#hex} -ne 6 ]]; then
        echo "white"
        return 0
    fi

    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    local luminance=$(((299 * r + 587 * g + 114 * b) / 1000))

    if [[ $luminance -gt 128 ]]; then
        echo "black"
    else
        echo "white"
    fi
}

# ==============================================================================
# Helper 4: Bar Chart Rendering (Disk usage visualization)
# ==============================================================================

_motd_render_bar_chart() {
    local percent="${1:-0}"
    local width="${2:-10}"

    # Ensure percent is in valid range
    if [[ $percent -lt 0 ]]; then
        percent=0
    elif [[ $percent -gt 100 ]]; then
        percent=100
    fi

    # Determine color based on percentage
    local reset="${NC:-\033[0m}"
    local ok_color="${GREEN:-\033[38;2;143;177;75m}"
    local warn_color="${YELLOW:-\033[38;2;249;197;116m}"
    local danger_color="${RED:-\033[38;2;220;58;56m}"
    local frame_color="${CAMPFIRE_PRIMARY_BAR:-\033[38;2;62;79;102m}"
    local empty_color="${CAMPFIRE_PRIMARY_TEXT_DARK:-\033[38;2;43;48;59m}"

    if [[ "${FRANKLIN_TEST_MODE:-0}" -eq 1 ]]; then
        reset=""
        ok_color=""
        warn_color=""
        danger_color=""
        frame_color=""
        empty_color=""
    fi

    local color_code="$ok_color"
    if [[ $percent -lt 60 ]]; then
        color_code="$ok_color"
    elif [[ $percent -lt 80 ]]; then
        color_code="$warn_color"
    else
        color_code="$danger_color"
    fi

    # Calculate filled characters (with rounding)
    local filled=$(((percent * width + 50) / 100))

    # Ensure filled is within bounds
    if [[ $filled -gt $width ]]; then
        filled=$width
    fi

    # Calculate empty characters
    local empty=$((width - filled))

    # Build the bar with full (█) and empty (░) blocks, with color
    local bar="|"
    bar+="${frame_color}"

    # Add filled blocks
    for ((i = 0; i < filled; i++)); do
        bar+="${color_code}█"
    done

    # Add empty blocks
    for ((i = 0; i < empty; i++)); do
        bar+="${empty_color}░"
    done

    bar+="${frame_color}|${reset}"

    echo "$bar"
}

# ==============================================================================
# Helper 5: Column Text Formatting (Fixed-width padding)
# ==============================================================================

_motd_format_column() {
    local text="$1"
    local width="${2:-26}"

    # Truncate if text is too long
    if [[ ${#text} -gt $width ]]; then
        text="${text:0:$((width - 3))}..."
    fi

    # Use printf for left-aligned padding
    printf "%-${width}s" "$text"
}
