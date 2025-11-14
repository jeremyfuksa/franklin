#!/usr/bin/env bash
# Franklin bootstrap installer

set -euo pipefail

OWNER=${FRANKLIN_BOOTSTRAP_OWNER:-jeremyfuksa}
REPO=${FRANKLIN_BOOTSTRAP_REPO:-franklin}
INSTALL_ROOT=${FRANKLIN_INSTALL_ROOT:-$HOME/.local/share/franklin}
REQUESTED_RELEASE=${FRANKLIN_BOOTSTRAP_RELEASE:-latest}
INSTALL_ARGS=()
TMP_DIR=""
ARCHIVE_URL=${FRANKLIN_BOOTSTRAP_ARCHIVE:-}
BOOTSTRAP_UI_QUIET=${BOOTSTRAP_UI_QUIET:-0}
BOOTSTRAP_BADGE_WIDTH=16
BOOTSTRAP_UI_WIDTH=80

NC=$'\033[0m'
CAMPFIRE_INFO_BG=$'\033[48;2;54;68;86m'
CAMPFIRE_INFO_FG=$'\033[38;2;247;248;249m'
CAMPFIRE_SUCCESS_BG=$'\033[48;2;90;111;45m'
CAMPFIRE_SUCCESS_FG=$'\033[38;2;245;247;249m'
CAMPFIRE_WARNING_BG=$'\033[48;2;239;153;31m'
CAMPFIRE_WARNING_FG=$'\033[38;2;52;31;25m'
CAMPFIRE_ERROR_BG=$'\033[48;2;190;43;41m'
CAMPFIRE_ERROR_FG=$'\033[38;2;250;246;245m'

bootstrap_emit() {
  local text="$1"
  local newline="${2:-1}"
  if [ "$BOOTSTRAP_UI_QUIET" -eq 1 ]; then
    return
  fi
  if [ "$newline" -eq 1 ]; then
    printf '%b\n' "$text" >&2
  else
    printf '%b' "$text" >&2
  fi
}

bootstrap_visible_length() {
  local text="$1"
  local i=0
  local visible=0
  local len=${#text}
  while [ $i -lt $len ]; do
    local char=${text:i:1}
    if [ "$char" = $'\033' ]; then
      i=$((i + 1))
      while [ $i -lt $len ]; do
        char=${text:i:1}
        if [[ "$char" =~ [@-~] ]]; then
          i=$((i + 1))
          break
        fi
        i=$((i + 1))
      done
      continue
    fi
    visible=$((visible + 1))
    i=$((i + 1))
  done
  printf '%d' "$visible"
}

bootstrap_pad_badge() {
  local text="$1"
  local width="${2:-$BOOTSTRAP_BADGE_WIDTH}"
  local visible padding needed
  visible=$(bootstrap_visible_length "$text")
  needed=$((width - visible))
  if [ "$needed" -gt 0 ]; then
    printf -v padding '%*s' "$needed" ''
    printf '%b' "${text}${padding}"
  else
    printf '%b' "$text"
  fi
}

bootstrap_badge() {
  local level="$1"
  local label="$2"
  local bg fg icon
  case "$level" in
    success)
      bg="$CAMPFIRE_SUCCESS_BG"
      fg="$CAMPFIRE_SUCCESS_FG"
      icon='✓'
      ;;
    warning)
      bg="$CAMPFIRE_WARNING_BG"
      fg="$CAMPFIRE_WARNING_FG"
      icon='⚠'
      ;;
    error)
      bg="$CAMPFIRE_ERROR_BG"
      fg="$CAMPFIRE_ERROR_FG"
      icon='✗'
      ;;
    *)
      bg="$CAMPFIRE_INFO_BG"
      fg="$CAMPFIRE_INFO_FG"
      icon='↺'
      ;;
  esac
  local raw="${bg}${fg} ${icon} ${label} ${NC}"
  bootstrap_pad_badge "$raw"
}

bootstrap_log() {
  local level="$1"
  local label="$2"
  shift 2
  local message="$*"
  bootstrap_emit "$(printf '%b %s' "$(bootstrap_badge "$level" "$label")" "$message")"
}

log_info() { bootstrap_log info "[BOOT]" "$@"; }
log_success() { bootstrap_log success " DONE " "$@"; }
log_warning() { bootstrap_log warning " WARN " "$@"; }
log_error() { bootstrap_log error " ERR " "$@"; }
bootstrap_blank_line() { bootstrap_emit "" ; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "Required command '$1' not found in PATH."
    exit 1
  fi
}

usage() {
  cat <<'USAGE'
Usage: bootstrap.sh [options] [-- install.sh args]

Options:
  --release TAG       Install a specific release tag (default: latest)
  --install-root DIR  Target directory for Franklin checkout (default: ~/.local/share/franklin)
  --owner NAME        GitHub owner/org (default: jeremyfuksa)
  --repo  NAME        GitHub repository (default: franklin)
  --archive URL       Use a custom archive URL (skip release lookup)
  --quiet             Suppress Franklin UI-style logging
  --help              Show this help message

To pass flags to install.sh, append them after --, e.g.:
  bootstrap.sh -- --motd-color mauve
USAGE
}

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

validate_platform() {
  local uname_out
  uname_out=$(uname -s || true)
  case "$uname_out" in
    Darwin)
      return 0
      ;;
    Linux)
      if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}" in
          ubuntu|debian|pop|elementary|linuxmint|neon|fedora)
            return 0
            ;;
        esac
      fi
      ;;
  esac
  log_warning "Franklin may not fully support this platform. Supported: macOS, Debian/Ubuntu, RHEL/Fedora."
}

resolve_release_tag() {
  local requested="$1"
  if [ "$requested" != "latest" ]; then
    printf '%s' "$requested"
    return
  fi

  local api_url="https://api.github.com/repos/$OWNER/$REPO/releases/latest"
  local tag
  if tag=$(curl -fsSL "$api_url" | awk -F '"' '/"tag_name"/ {print $4; exit}'); then
    if [ -n "$tag" ]; then
      printf '%s' "$tag"
      return
    fi
  fi

  log_error "Unable to fetch latest release tag from GitHub."
  exit 1
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --release)
        if [ $# -lt 2 ]; then
          log_error "--release requires a value"
          exit 1
        fi
        REQUESTED_RELEASE="$2"
        shift 2
        ;;
      --install-root)
        if [ $# -lt 2 ]; then
          log_error "--install-root requires a value"
          exit 1
        fi
        INSTALL_ROOT="$2"
        shift 2
        ;;
      --owner)
        if [ $# -lt 2 ]; then
          log_error "--owner requires a value"
          exit 1
        fi
        OWNER="$2"
        shift 2
        ;;
      --repo)
        if [ $# -lt 2 ]; then
          log_error "--repo requires a value"
          exit 1
        fi
        REPO="$2"
        shift 2
        ;;
      --archive)
        if [ $# -lt 2 ]; then
          log_error "--archive requires a value"
          exit 1
        fi
        ARCHIVE_URL="$2"
        shift 2
        ;;
      --quiet)
        BOOTSTRAP_UI_QUIET=1
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      --)
        shift
        INSTALL_ARGS=("$@")
        break
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

download_release() {
  local tag="$1"
  local url="$ARCHIVE_URL"
  if [ -z "$url" ]; then
    url="https://github.com/$OWNER/$REPO/releases/download/$tag/franklin.tar.gz"
  fi
  TMP_DIR=$(mktemp -d)
  local tarball="$TMP_DIR/franklin.tar.gz"
  log_info "Downloading Franklin release ($tag)..."
  curl -fL "$url" -o "$tarball"
  printf '%s' "$tarball"
}

extract_release() {
  local tarball="$1"
  log_info "Extracting to $INSTALL_ROOT"
  rm -rf "$INSTALL_ROOT"
  mkdir -p "$INSTALL_ROOT"
  tar -xzf "$tarball" -C "$INSTALL_ROOT"
}

run_installer() {
  log_info "Running install.sh"
  if [ ${#INSTALL_ARGS[@]} -gt 0 ]; then
    (cd "$INSTALL_ROOT" && FRANKLIN_UI_QUIET="$BOOTSTRAP_UI_QUIET" bash install.sh "${INSTALL_ARGS[@]}")
  else
    (cd "$INSTALL_ROOT" && FRANKLIN_UI_QUIET="$BOOTSTRAP_UI_QUIET" bash install.sh)
  fi
}

main() {
  require_cmd curl
  require_cmd tar
  require_cmd bash
  parse_args "$@"
  validate_platform
  local release_tag
  if [ -n "$ARCHIVE_URL" ]; then
    release_tag="custom"
  else
    release_tag=$(resolve_release_tag "$REQUESTED_RELEASE")
  fi
  local tarball
  tarball=$(download_release "$release_tag")
  extract_release "$tarball"
  run_installer
  log_success "Franklin installation complete."
}

main "$@"
