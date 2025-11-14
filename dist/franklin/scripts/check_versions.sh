#!/bin/bash
# Verify that installed dependencies match the latest upstream releases
# and (optionally) upgrade mismatched components.

set -euo pipefail

# shellcheck disable=SC2155
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SRC_DIR/.." && pwd)"

# Shared UI helpers
: "${FRANKLIN_UI_QUIET:=0}"
# shellcheck source=../lib/colors.sh
. "$SRC_DIR/lib/colors.sh"
# shellcheck source=../lib/ui.sh
. "$SRC_DIR/lib/ui.sh"

APPLY_UPDATES=0
JSON_OUTPUT=0
OFFLINE_MODE=${FRANKLIN_VERSION_CHECK_OFFLINE:-0}
VERBOSE=${FRANKLIN_VERSION_CHECK_VERBOSE:-0}
GITHUB_API="${GITHUB_API:-https://api.github.com}"

log_info() { franklin_ui_log info "[VERSIONS]" "$@"; }
log_success() { franklin_ui_log success "  OK " "$@"; }
log_warning() { franklin_ui_log warning " WARN " "$@"; }
log_error() { franklin_ui_log error " ERR " "$@"; }

usage() {
  cat <<'EOF'
Usage: scripts/check_versions.sh [--apply] [--json] [--offline] [--quiet]

Options:
  --apply      Upgrade components that are behind the latest release
  --json       Emit machine-readable JSON output
  --offline    Skip network calls (assume current versions)
  --quiet      Suppress Franklin UI logging (stderr only)
  --help       Show this message

Environment:
  FRANKLIN_VERSION_CHECK_OFFLINE=1  Force offline mode
  FRANKLIN_VERSION_CHECK_VERBOSE=1  Show debug logs
  GITHUB_API=<url>                Override GitHub API endpoint
EOF
}

log_debug() {
  if [ "$VERBOSE" -eq 1 ]; then
    franklin_ui_log debug "[VERSIONS]" "$@"
  fi
}

normalize_version() {
  local version="$1"
  # Strip leading 'v' or 'V' if present
  version="${version#v}"
  version="${version#V}"
  echo "$version"
}

fetch_latest_tag() {
  local repo="$1"
  local fallback="$2"

  if [ "$OFFLINE_MODE" -eq 1 ]; then
    echo "$fallback"
    return 0
  fi

  local response
  if ! response=$(curl -fsSL "$GITHUB_API/repos/$repo/releases/latest" 2>/dev/null); then
    log_debug "Failed to fetch latest tag for $repo, using fallback"
    echo "$fallback"
    return 1
  fi

  local tag
  tag=$(echo "$response" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

  if [ -z "$tag" ]; then
    log_debug "No tag_name found in response for $repo, using fallback"
    echo "$fallback"
    return 1
  fi

  echo "$tag"
}

fetch_latest_npm_version() {
  local package="$1"
  local fallback="$2"
  if [ "$OFFLINE_MODE" -eq 1 ]; then
    echo "$fallback"
    return 0
  fi
  if ! command -v npm >/dev/null 2>&1; then
    echo "$fallback"
    return 0
  fi
  local version
  if version=$(npm view "$package" version 2>/dev/null); then
    echo "$version"
  else
    echo "$fallback"
  fi
}

get_nvm_info() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  local install_type="absent"
  local version=""

  if [ -d "$nvm_dir/.git" ]; then
    install_type="git"
    version=$(cd "$nvm_dir" && git describe --tags "$(git rev-parse HEAD)" 2>/dev/null || true)
  elif [ -d "$nvm_dir" ]; then
    install_type="dir"
  fi

  echo "$version|$install_type|$nvm_dir"
}

upgrade_nvm_git() {
  local latest="$1"
  local dir="$2"

  if [ ! -d "$dir/.git" ]; then
    log_debug "NVM git directory missing at $dir"
    return 1
  fi

  (
    cd "$dir"
    git fetch --quiet --tags origin
    git checkout -q "$latest"
  )
}

upgrade_nvm_install_script() {
  local latest="$1"
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${latest}/install.sh" | bash >/dev/null 2>&1
}

upgrade_nvm() {
  local latest="$1"
  local install_type="$2"
  local dir="$3"

  case "$install_type" in
    git)
      upgrade_nvm_git "$latest" "$dir"
      ;;
    dir|absent)
      upgrade_nvm_install_script "$latest"
      ;;
    *)
      return 1
      ;;
  esac
}

get_antigen_info() {
  local antigen_dir="${FRANKLIN_ANTIGEN_DIR:-$HOME/.antigen}"
  local version=""
  local install_type="absent"
  local source_path=""

  if command -v brew >/dev/null 2>&1 && brew list --versions antigen >/dev/null 2>&1; then
    install_type="brew"
    version=$(brew list --versions antigen 2>/dev/null | awk '{print $2}' | head -n1)
    source_path="$(brew --prefix antigen 2>/dev/null)"
  elif [ -d "$antigen_dir/.git" ]; then
    install_type="git"
    source_path="$antigen_dir"
    version=$(cd "$antigen_dir" && git describe --tags "$(git rev-parse HEAD)" 2>/dev/null || true)
  elif [ -f "$antigen_dir/antigen.zsh" ]; then
    install_type="file"
    source_path="$antigen_dir/antigen.zsh"
    local version_file="$antigen_dir/.antigen-version"
    if [ -f "$version_file" ]; then
      version=$(cat "$version_file" 2>/dev/null || true)
    fi
  elif [ -f "/usr/share/zsh-antigen/antigen.zsh" ]; then
    install_type="system"
    source_path="/usr/share/zsh-antigen/antigen.zsh"
  fi

  echo "$version|$install_type|$source_path"
}

upgrade_antigen() {
  local latest="$1"
  local install_type="$2"
  local source_path="$3"
  local antigen_dir="${FRANKLIN_ANTIGEN_DIR:-$HOME/.antigen}"

  case "$install_type" in
    brew)
      brew upgrade antigen >/dev/null 2>&1
      ;;
    git)
      (
        cd "$source_path"
        if [ -n "$(git status --porcelain)" ]; then
          log_warning "Antigen repo has local modifications; skipping git checkout."
          exit 0
        fi
        git fetch --quiet --tags origin
        git checkout -q "$latest"
      )
      ;;
    file|absent|system)
      mkdir -p "$antigen_dir"
      if curl -fsSL "https://raw.githubusercontent.com/zsh-users/antigen/${latest}/antigen.zsh" -o "$antigen_dir/antigen.zsh"; then
        echo "$latest" > "$antigen_dir/.antigen-version"
      else
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

get_brew_package_info() {
  local package="$1"
  if ! command -v brew >/dev/null 2>&1; then
    echo "|absent|"
    return
  fi
  local version
  version=$(brew list --versions "$package" 2>/dev/null | awk '{print $2}' | tail -n1)
  if [ -n "$version" ]; then
    echo "$version|brew|$package"
  else
    echo "|absent|"
  fi
}

upgrade_brew_package() {
  local package="$1"
  if command -v brew >/dev/null 2>&1; then
    brew upgrade "$package" >/dev/null 2>&1 || true
  fi
}

get_uv_info() {
  local uv_binary=""
  if command -v uv >/dev/null 2>&1; then
    uv_binary="$(command -v uv)"
  elif [ -x "$HOME/.local/bin/uv" ]; then
    uv_binary="$HOME/.local/bin/uv"
  fi

  if [ -n "$uv_binary" ]; then
    local version
    version=$("$uv_binary" --version 2>/dev/null | awk '{print $2}' | head -n1)
    echo "$version|system|$uv_binary"
  else
    get_brew_package_info "uv"
  fi
}

upgrade_uv() {
  upgrade_brew_package "uv"
}

get_bat_info() {
  local binary=""
  if command -v bat >/dev/null 2>&1; then
    binary="bat"
  elif command -v batcat >/dev/null 2>&1; then
    binary="batcat"
  fi

  if [ -n "$binary" ]; then
    local version
    version=$("$binary" --version 2>/dev/null | awk '{print $2}' | head -n1)
    echo "$version|system|$binary"
  else
    get_brew_package_info "bat"
  fi
}

upgrade_bat() {
  upgrade_brew_package "bat"
}

get_fzf_info() {
  if command -v fzf >/dev/null 2>&1; then
    local version
    version=$(fzf --version 2>/dev/null | awk 'NR==1 {print $1}')
    echo "$version|system|fzf"
  else
    get_brew_package_info "fzf"
  fi
}

upgrade_fzf() {
  upgrade_brew_package "fzf"
}

get_npm_cli_info() {
  if ! command -v npm >/dev/null 2>&1; then
    echo "|absent|"
    return
  fi
  local version
  version=$(npm --version 2>/dev/null || echo "")
  echo "$version|node|npm"
}

upgrade_npm_cli() {
  if command -v npm >/dev/null 2>&1; then
    npm install -g npm@latest >/dev/null 2>&1 || true
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY_UPDATES=1
      shift
      ;;
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    --offline)
      OFFLINE_MODE=1
      shift
      ;;
    --quiet)
      FRANKLIN_UI_QUIET=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

COMPONENTS=(
  "NVM|nvm-sh/nvm|get_nvm_info|upgrade_nvm"
  "Antigen|zsh-users/antigen|get_antigen_info|upgrade_antigen"
  "uv|astral-sh/uv|get_uv_info|upgrade_uv"
  "bat|sharkdp/bat|get_bat_info|upgrade_bat"
  "fzf|junegunn/fzf|get_fzf_info|upgrade_fzf"
  "npm|npm:npm|get_npm_cli_info|upgrade_npm_cli"
)
STATUS_ITEMS=()
OVERALL_STATUS=0

for component in "${COMPONENTS[@]}"; do
  IFS='|' read -r name repo info_fn upgrade_fn <<< "$component"
  IFS='|' read -r installed install_type source_path <<< "$($info_fn)"

  if [ -z "$installed" ]; then
    installed="not_installed"
  fi
  latest=""
  if [[ "$repo" == npm:* ]]; then
    latest=$(fetch_latest_npm_version "${repo#npm:}" "$installed")
  else
    latest=$(fetch_latest_tag "$repo" "$installed")
  fi
  
  # Normalize versions for comparison (strip leading 'v')
  installed_normalized=$(normalize_version "$installed")
  latest_normalized=$(normalize_version "$latest")
  
  status="current"

  if [ "$installed" = "not_installed" ]; then
    status="not_installed"
  elif [ "$latest_normalized" != "$installed_normalized" ]; then
    if [ "$install_type" = "system" ]; then
      status="lagging"
    else
      status="update_available"
    fi
  fi

  if [ "$APPLY_UPDATES" -eq 1 ] && [ "$status" = "update_available" ]; then
    if $upgrade_fn "$latest" "$install_type" "$source_path"; then
      sleep 1
      IFS='|' read -r installed install_type source_path <<< "$($info_fn)"
      installed_normalized=$(normalize_version "$installed")
      status="current"
      if [ "$latest_normalized" != "$installed_normalized" ]; then
        status="update_pending"
        OVERALL_STATUS=1
      fi
    else
      status="upgrade_failed"
      OVERALL_STATUS=1
    fi
  elif [ "$status" = "update_available" ]; then
    OVERALL_STATUS=1
  fi

  STATUS_ITEMS+=("$name|$installed|$latest|$status|$install_type")
done

if [ "$JSON_OUTPUT" -eq 1 ]; then
  echo "["
  for idx in "${!STATUS_ITEMS[@]}"; do
    IFS='|' read -r name installed latest status install_type <<< "${STATUS_ITEMS[$idx]}"
    printf '  {"component":"%s","installed":"%s","latest":"%s","status":"%s","installType":"%s"}' "$name" "$installed" "$latest" "$status" "$install_type"
    if [ "$idx" -lt $((${#STATUS_ITEMS[@]} - 1)) ]; then
      printf ','
    fi
    printf '\n'
  done
  echo "]"
else
  printf "%-10s %-18s %-12s %-18s %-10s\n" "Component" "Installed" "Latest" "Status" "Type"
  printf "%-10s %-18s %-12s %-18s %-10s\n" "---------" "---------" "------" "------" "----"
  for item in "${STATUS_ITEMS[@]}"; do
    IFS='|' read -r name installed latest status install_type <<< "$item"
    printf "%-10s %-18s %-12s %-18s %-10s\n" "$name" "$installed" "$latest" "$status" "$install_type"
  done
fi

exit $OVERALL_STATUS
