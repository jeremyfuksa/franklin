#!/usr/bin/env bash
# Franklin Campfire UI Library (Bash)
#
# Purpose: Shared UI helpers for Franklin shell scripts
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/ui.sh"
#
# All output goes to stderr to preserve stdout for machine-readable data.

# --- Glyphs ---
GLYPH_ACTION="⏺"
GLYPH_BRANCH="⎿"
GLYPH_LOGIC="∴"
GLYPH_WAIT="✻"
GLYPH_SUCCESS="✔"
GLYPH_WARNING="⚠"
GLYPH_ERROR="✗"

# --- Colors (ANSI 24-bit) ---
COLOR_ERROR="\033[38;2;191;97;106m"    # #bf616a
COLOR_SUCCESS="\033[38;2;163;190;140m"  # #a3be8c
COLOR_INFO="\033[38;2;136;192;208m"     # #88c0d0
COLOR_WARNING="\033[38;2;235;203;139m"  # #ebcb8b
COLOR_RESET="\033[0m"

# --- TTY Detection ---
# Check if we're in a TTY for color support
if [ -t 2 ]; then
    FRANKLIN_UI_USE_COLOR=true
else
    FRANKLIN_UI_USE_COLOR=false
fi

# Respect NO_COLOR standard
if [ -n "${NO_COLOR:-}" ] || [ -n "${FRANKLIN_NO_COLOR:-}" ]; then
    FRANKLIN_UI_USE_COLOR=false
fi

# --- UI Functions ---

ui_header() {
    # ⏺ text
    printf "%s %s\n" "${GLYPH_ACTION}" "$*" >&2
}

ui_branch() {
    # ⎿  text (2-space indent to align under parent glyph)
    printf "%s  %s\n" "${GLYPH_BRANCH}" "$*" >&2
}

ui_logic() {
    # ∴ text
    printf "%s %s\n" "${GLYPH_LOGIC}" "$*" >&2
}

ui_section_end() {
    # Blank line for breathing room between sections
    printf "\n" >&2
}

ui_error() {
    # ⎿  ✗ text (in red, then exit)
    if [ "$FRANKLIN_UI_USE_COLOR" = true ]; then
        printf "%s  %b%s %s%b\n" "${GLYPH_BRANCH}" "${COLOR_ERROR}" "${GLYPH_ERROR}" "$*" "${COLOR_RESET}" >&2
    else
        printf "%s  %s %s\n" "${GLYPH_BRANCH}" "${GLYPH_ERROR}" "$*" >&2
    fi
    exit 1
}

ui_error_noexit() {
    # ⎿  ✗ text (in red, no exit)
    if [ "$FRANKLIN_UI_USE_COLOR" = true ]; then
        printf "%s  %b%s %s%b\n" "${GLYPH_BRANCH}" "${COLOR_ERROR}" "${GLYPH_ERROR}" "$*" "${COLOR_RESET}" >&2
    else
        printf "%s  %s %s\n" "${GLYPH_BRANCH}" "${GLYPH_ERROR}" "$*" >&2
    fi
}

ui_success() {
    # ⎿  ✔ text (in green)
    if [ "$FRANKLIN_UI_USE_COLOR" = true ]; then
        printf "%s  %b%s %s%b\n" "${GLYPH_BRANCH}" "${COLOR_SUCCESS}" "${GLYPH_SUCCESS}" "$*" "${COLOR_RESET}" >&2
    else
        printf "%s  %s %s\n" "${GLYPH_BRANCH}" "${GLYPH_SUCCESS}" "$*" >&2
    fi
}

ui_warning() {
    # ⎿  ⚠ text (in yellow)
    if [ "$FRANKLIN_UI_USE_COLOR" = true ]; then
        printf "%s  %b%s %s%b\n" "${GLYPH_BRANCH}" "${COLOR_WARNING}" "${GLYPH_WARNING}" "$*" "${COLOR_RESET}" >&2
    else
        printf "%s  %s %s\n" "${GLYPH_BRANCH}" "${GLYPH_WARNING}" "$*" >&2
    fi
}

ui_info() {
    # ⎿  text (in blue)
    if [ "$FRANKLIN_UI_USE_COLOR" = true ]; then
        printf "%s  %b%s%b\n" "${GLYPH_BRANCH}" "${COLOR_INFO}" "$*" "${COLOR_RESET}" >&2
    else
        printf "%s  %s\n" "${GLYPH_BRANCH}" "$*" >&2
    fi
}

ui_final_success() {
    # ✔ text (standalone, no branch, in green)
    if [ "$FRANKLIN_UI_USE_COLOR" = true ]; then
        printf "%b%s %s%b\n" "${COLOR_SUCCESS}" "${GLYPH_SUCCESS}" "$*" "${COLOR_RESET}" >&2
    else
        printf "%s %s\n" "${GLYPH_SUCCESS}" "$*" >&2
    fi
}

# --- Color Display Helper ---
# Convert hex color to ANSI 24-bit color code and display a colored swatch
show_color() {
    local name="$1"
    local hex="$2"

    # Strip # from hex
    hex="${hex#\#}"

    # Convert hex to RGB
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    # ANSI 24-bit color: \033[38;2;R;G;Bm for foreground
    printf "  \033[38;2;%d;%d;%dm████\033[0m  %-15s (#%s)\n" "$r" "$g" "$b" "$name" "$hex" >&2
}
