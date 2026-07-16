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

set -euo pipefail

# --- Defaults ---
INSTALL_DIR="${HOME}/.local/share/franklin"
GIT_REF="main"
REPO_URL="https://github.com/jeremyfuksa/franklin.git"

# --- Parse Arguments ---
while [ $# -gt 0 ]; do
    case "$1" in
        --dir)
            if [ $# -lt 2 ]; then
                echo "ERROR: --dir requires an argument" >&2
                exit 1
            fi
            INSTALL_DIR="$2"
            shift 2
            ;;
        --ref)
            if [ $# -lt 2 ]; then
                echo "ERROR: --ref requires an argument" >&2
                exit 1
            fi
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

# --- Validate --dir ---
# bootstrap.sh later runs `rm -rf "$INSTALL_DIR"` if the path exists, so a
# typo or unset $HOME could nuke important data. Require the resolved
# target to be safely scoped (under $HOME, /tmp, or /var/tmp) and refuse
# obvious foot-guns ('', '/', $HOME itself).
_bootstrap_validate_install_dir() {
    local raw="$1"
    if [ -z "$raw" ]; then
        echo "ERROR: --dir cannot be empty" >&2
        exit 1
    fi
    # Strip trailing slash for comparisons (but keep '/' as '/').
    local normalized="$raw"
    case "$normalized" in
        */) normalized="${normalized%/}" ;;
    esac
    [ -z "$normalized" ] && normalized="/"
    case "$normalized" in
        /|"$HOME"|"")
            echo "ERROR: --dir refuses unsafe target: $raw" >&2
            exit 1
            ;;
    esac
    case "$normalized" in
        "$HOME"/*|/tmp/*|/var/tmp/*) ;;
        *)
            echo "ERROR: --dir must be under \$HOME, /tmp, or /var/tmp; got: $raw" >&2
            echo "       (refused because bootstrap.sh will 'rm -rf' this path)" >&2
            exit 1
            ;;
    esac
}
_bootstrap_validate_install_dir "$INSTALL_DIR"

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

# --- Auto-install helper ---
# Attempts to install a missing package via the detected platform's package
# manager. On macOS, requires Homebrew (and guides toward xcode-select if
# absent). On Linux, uses apt-get or dnf. Any failure is reported but passed
# back to the caller via non-zero return so the preflight loop can decide.
_bootstrap_install_pkg() {
    local pkg="$1"
    case "$OS" in
        Darwin)
            if command -v brew >/dev/null 2>&1; then
                ui_branch "Installing $pkg via Homebrew..."
                brew install "$pkg" 2>&1 | sed 's/^/    /' >&2
                return $?
            else
                ui_branch "Homebrew not found. Franklin needs one of:"
                ui_branch "  - Xcode Command Line Tools: xcode-select --install  (provides git + curl)"
                ui_branch "  - Homebrew:                 https://brew.sh"
                return 1
            fi
            ;;
        Linux)
            if command -v apt-get >/dev/null 2>&1; then
                ui_branch "Installing $pkg via apt..."
                sudo apt-get update -qq 2>&1 | sed 's/^/    /' >&2
                sudo apt-get install -y -qq "$pkg" 2>&1 | sed 's/^/    /' >&2
                return $?
            elif command -v dnf >/dev/null 2>&1; then
                ui_branch "Installing $pkg via dnf..."
                sudo dnf install -y -q "$pkg" 2>&1 | sed 's/^/    /' >&2
                return $?
            else
                ui_branch "No supported package manager found (apt-get / dnf)."
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Check for required commands; auto-install if missing. On Debian/Ubuntu
# python3 also needs the python3-venv package so install.sh can create the
# Franklin venv later.
_bootstrap_ensure() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    ui_branch "$cmd not found; attempting auto-install..."
    if _bootstrap_install_pkg "$pkg" && command -v "$cmd" >/dev/null 2>&1; then
        ui_branch "$cmd installed"
        return 0
    fi
    ui_error "Failed to install $cmd automatically. Please install it manually and rerun."
}

_bootstrap_ensure git
_bootstrap_ensure curl
_bootstrap_ensure python3

# Debian/Ubuntu ships `python3-venv` separately from `python3`; install.sh
# will need it. Best-effort: if apt is available and the venv module isn't
# importable, pull python3-venv in.
if [ "$OS" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then
    if ! python3 -c "import venv" >/dev/null 2>&1; then
        ui_branch "python3-venv module not available; installing..."
        sudo apt-get install -y -qq python3-venv 2>&1 | sed 's/^/    /' >&2 || \
            ui_branch "Could not install python3-venv; install.sh may need to do it later."
    fi
fi

ui_success "Pre-flight checks passed"
ui_section_end

# --- Fetch Franklin ---
ui_header "Fetching Franklin"
ui_branch "Repository: $REPO_URL (ref: $GIT_REF)"

# Remove existing directory if present, preserving backups (install.sh stores
# pre-install snapshots at $INSTALL_DIR/backups — they must survive reinstalls).
BACKUP_STASH=""
if [ -d "$INSTALL_DIR" ]; then
    if [ -d "$INSTALL_DIR/backups" ]; then
        BACKUP_STASH="$(mktemp -d "${TMPDIR:-/tmp}/franklin-backups.XXXXXX")"
        ui_branch "Preserving existing backups"
        mv "$INSTALL_DIR/backups" "$BACKUP_STASH/backups"
    fi
    ui_branch "Removing existing installation at $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
fi

# Clone repository. The `if !` guard catches the failure under bash+pipefail;
# the .git check below catches it when running under a plain `sh` whose
# `set -o pipefail` isn't effective (the pipe makes the exit status sed's).
mkdir -p "$(dirname "$INSTALL_DIR")"
CLONE_OK=true
if ! git clone --branch "$GIT_REF" --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>&1 | \
    sed 's/^/  /' >&2; then
    CLONE_OK=false
fi

if [ "$CLONE_OK" = false ] || [ ! -d "$INSTALL_DIR/.git" ]; then
    if [ -n "$BACKUP_STASH" ]; then
        mkdir -p "$INSTALL_DIR"
        mv "$BACKUP_STASH/backups" "$INSTALL_DIR/backups"
        rmdir "$BACKUP_STASH" 2>/dev/null || true
    fi
    ui_error "git clone failed (ref: $GIT_REF). Check the ref name and network connectivity."
fi

# Restore preserved backups into the fresh clone
if [ -n "$BACKUP_STASH" ]; then
    mv "$BACKUP_STASH/backups" "$INSTALL_DIR/backups"
    rmdir "$BACKUP_STASH" 2>/dev/null || true
    ui_branch "Restored previous backups to $INSTALL_DIR/backups"
fi

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
