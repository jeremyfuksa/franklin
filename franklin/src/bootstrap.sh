#!/bin/bash
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

# --- Minimal UI Functions (Bash) ---
# NOTE: This is intentionally duplicated from lib/ui.sh because bootstrap runs
# BEFORE the library is downloaded. Keep this minimal - just what bootstrap needs.

_UI_USE_COLOR=false
[ -t 2 ] && [ -z "${NO_COLOR:-}" ] && _UI_USE_COLOR=true

ui_header()  { printf "⏺ %s\n" "$*" >&2; }
ui_branch()  { printf "⎿  %s\n" "$*" >&2; }
ui_section_end() { printf "\n" >&2; }

ui_error() {
    if [ "$_UI_USE_COLOR" = true ]; then
        printf "⎿  \033[38;2;191;97;106m✗ %s\033[0m\n" "$*" >&2
    else
        printf "⎿  ✗ %s\n" "$*" >&2
    fi
    exit 1
}

ui_success() {
    if [ "$_UI_USE_COLOR" = true ]; then
        printf "⎿  \033[38;2;163;190;140m✔ %s\033[0m\n" "$*" >&2
    else
        printf "⎿  ✔ %s\n" "$*" >&2
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
    exec bash "franklin/src/install.sh"
else
    ui_error "Installation script not found at franklin/src/install.sh"
fi
