#!/bin/sh
# Franklin Bootstrap Script (Stage 1)
#
# Purpose: Fetch Franklin from GitHub and hand off to install.sh
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/USER/franklin/main/src/bootstrap.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/USER/franklin/main/src/bootstrap.sh | sh -s -- --dir /custom/path --ref v2.0.0
#
# Flags:
#   --dir DIR   Installation directory (default: ~/.local/share/franklin)
#   --ref REF   Git branch or tag to checkout (default: main)

set -e

# --- Defaults ---
INSTALL_DIR="${HOME}/.local/share/franklin"
GIT_REF="main"
REPO_URL="https://github.com/jeremyfuksa/franklin.git"

# --- Parse Arguments ---
while [ $# -gt 0 ]; do
    case "$1" in
        --dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --ref)
            GIT_REF="$2"
            shift 2
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            echo "Usage: bootstrap.sh [--dir DIR] [--ref REF]" >&2
            exit 1
            ;;
    esac
done

# --- Campfire UI Functions (Bash) ---
# Mirror the Python Campfire UI library for consistent visual hierarchy

# Glyphs
GLYPH_ACTION="⏺"
GLYPH_BRANCH="⎿"
GLYPH_LOGIC="∴"
GLYPH_SUCCESS="✔"
GLYPH_ERROR="✗"

# Colors (ANSI)
COLOR_ERROR="\033[38;2;191;97;106m"    # #bf616a
COLOR_SUCCESS="\033[38;2;163;190;140m"  # #a3be8c
COLOR_RESET="\033[0m"

# Check if we're in a TTY for color support
if [ -t 2 ]; then
    USE_COLOR=true
else
    USE_COLOR=false
fi

ui_header() {
    # ⏺ text
    printf "%s %s\n" "${GLYPH_ACTION}" "$*" >&2
}

ui_branch() {
    # ⎿  text (2-space indent)
    printf "%s  %s\n" "${GLYPH_BRANCH}" "$*" >&2
}

ui_section_end() {
    # Blank line for breathing room between sections
    printf "\n" >&2
}

ui_error() {
    # ⎿  ✗ text (in red, then exit)
    if [ "$USE_COLOR" = true ]; then
        printf "%s  %b%s %s%b\n" "${GLYPH_BRANCH}" "${COLOR_ERROR}" "${GLYPH_ERROR}" "$*" "${COLOR_RESET}" >&2
    else
        printf "%s  %s %s\n" "${GLYPH_BRANCH}" "${GLYPH_ERROR}" "$*" >&2
    fi
    exit 1
}

ui_success() {
    # ⎿  ✔ text (in green)
    if [ "$USE_COLOR" = true ]; then
        printf "%s  %b%s %s%b\n" "${GLYPH_BRANCH}" "${COLOR_SUCCESS}" "${GLYPH_SUCCESS}" "$*" "${COLOR_RESET}" >&2
    else
        printf "%s  %s %s\n" "${GLYPH_BRANCH}" "${GLYPH_SUCCESS}" "$*" >&2
    fi
}

ui_final_success() {
    # ✔ text (standalone, no branch, in green)
    if [ "$USE_COLOR" = true ]; then
        printf "%b%s %s%b\n" "${COLOR_SUCCESS}" "${GLYPH_SUCCESS}" "$*" "${COLOR_RESET}" >&2
    else
        printf "%s %s\n" "${GLYPH_SUCCESS}" "$*" >&2
    fi
}

# --- Pre-flight Checks ---
ui_header "Franklin Bootstrap"

# Check OS is supported
OS="$(uname -s)"
case "$OS" in
    Darwin)
        ui_branch "Detected macOS"
        ;;
    Linux)
        ui_branch "Detected Linux"
        # Verify it's a supported distro by checking /etc/os-release
        if [ ! -f /etc/os-release ]; then
            ui_error "Cannot determine Linux distribution (/etc/os-release not found)"
        fi
        ;;
    *)
        ui_error "Unsupported operating system: $OS (Franklin supports macOS, Debian, and RHEL)"
        ;;
esac

# Check for required commands
for cmd in git curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        ui_error "$cmd is required but not found. Please install it and try again."
    fi
done

# Check for Python 3
if ! command -v python3 >/dev/null 2>&1; then
    ui_error "Python 3 is required but not found. Please install Python 3 and try again."
fi

ui_success "Pre-flight checks passed"
ui_section_end

# --- Fetch Franklin ---
ui_header "Fetching Franklin"
ui_branch "Repository: $REPO_URL (ref: $GIT_REF)"

# Remove existing directory if present
if [ -d "$INSTALL_DIR" ]; then
    ui_branch "Removing existing installation at $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
fi

# Clone repository
mkdir -p "$(dirname "$INSTALL_DIR")"
git clone --branch "$GIT_REF" --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>&1 | \
    sed 's/^/  /' >&2

ui_success "Franklin fetched to $INSTALL_DIR"
ui_section_end

# --- Hand off to installer ---
ui_branch "Starting installation..."

cd "$INSTALL_DIR"

if [ -f "franklin/src/install.sh" ]; then
    exec sh "franklin/src/install.sh"
else
    ui_error "Installation script not found at franklin/src/install.sh"
fi
