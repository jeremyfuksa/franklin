#!/bin/bash
# Franklin Bootstrap Installation Script
#
# Installs Franklin on macOS, Ubuntu, Debian, and RHEL/Fedora.
# Safe to re-run (idempotent); non-destructive (uses symlinks).
#
# Usage:
#   bash install.sh [--verbose] [--quiet] [--help]
#
# Exit codes:
#   0 - Success
#   1 - Warning (optional dependency skipped)
#   2 - Error (required dependency missing)
#   3 - Abort (user cancelled)

set -e

# Cleanup handler for signals and exit
_franklin_install_cleanup() {
  local exit_code=$?

  # Clear any remaining sudo credentials
  if command -v sudo >/dev/null 2>&1; then
    sudo -k >/dev/null 2>&1 || true
  fi

  # Restore terminal state (show cursor, clear line)
  tput cnorm 2>/dev/null || true
  printf '\r\033[K' >&2

  # If interrupted, show message
  if [ $exit_code -eq 130 ]; then
    echo "" >&2
    echo "Installation interrupted by user." >&2
  fi

  exit $exit_code
}

trap _franklin_install_cleanup EXIT INT TERM

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="Franklin"
PROJECT_SLUG="franklin"
FRANKLIN_HOME="$SCRIPT_DIR"
ZSHRC_PATH="${HOME}/.zshrc"
ZSHRC_BACKUP="${HOME}/.zshrc.bak"
VERBOSE=${VERBOSE:-0}
FRANKLIN_CONFIG_DIR="${FRANKLIN_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/franklin}"
export FRANKLIN_CONFIG_DIR
FRANKLIN_LOCAL_CONFIG="${FRANKLIN_LOCAL_CONFIG:-$HOME/.franklin.local.zsh}"
export FRANKLIN_LOCAL_CONFIG
FRANKLIN_MOTD_COLOR="${FRANKLIN_MOTD_COLOR:-}"
USER_MOTD_COLOR="$FRANKLIN_MOTD_COLOR"
FRANKLIN_SIGNATURE_PALETTE="${FRANKLIN_SIGNATURE_PALETTE:-ember}"

# Use XDG-compliant backup location (outside repo)
FRANKLIN_BACKUP_DIR="${FRANKLIN_BACKUP_DIR:-}"
BACKUP_ROOT="${FRANKLIN_BACKUP_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/franklin/backups}"
BACKUP_TIMESTAMP="${BACKUP_TIMESTAMP:-$(date +"%Y%m%d-%H%M%S")}"

# Shared resources
# shellcheck source=lib/colors.sh
. "$SCRIPT_DIR/lib/colors.sh"
# shellcheck source=lib/versions.sh
. "$SCRIPT_DIR/lib/versions.sh"
# shellcheck source=lib/ui.sh
. "$SCRIPT_DIR/lib/ui.sh"
FRANKLIN_LIB_DIR="$SCRIPT_DIR/lib"
export FRANKLIN_LIB_DIR
FRANKLIN_VERSION_CHECK_VERBOSE="${FRANKLIN_VERSION_CHECK_VERBOSE:-$VERBOSE}"
FRANKLIN_TEST_MODE="${FRANKLIN_TEST_MODE:-0}"
FRANKLIN_UI_QUIET=${FRANKLIN_UI_QUIET:-0}

# ============================================================================
# Helper Functions
# ============================================================================

INSTALL_BADGE="[INSTALL]"
INSTALL_DEBUG="[DEBUG]"

log_info() { franklin_ui_log info "$INSTALL_BADGE" "$@"; }
log_success() { franklin_ui_log success "  OK " "$@"; }
log_warning() { franklin_ui_log warning " WARN " "$@"; }
log_error() { franklin_ui_log error " ERR " "$@"; }
log_debug() {
  if [ "$VERBOSE" -eq 1 ]; then
    franklin_ui_log debug "$INSTALL_DEBUG" "$@"
  fi
}

install_log_spacer() {
  if [ "${FRANKLIN_SUPPRESS_INSTALL_SPACER:-0}" -ne 1 ]; then
    franklin_ui_blank_line
  fi
}

begin_install_phase() {
  franklin_ui_blank_line
  franklin_ui_section "$1"
}

franklin_slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g;s/^-+|-+$//g'
}

franklin_title_case() {
  local input="$1"
  if [ -z "$input" ]; then
    printf ''
    return
  fi
  printf '%s' "$input" | awk '{print toupper(substr($0,1,1)) substr($0,2)}'
}

declare -a FRANKLIN_SIGNATURE_COLOR_METADATA=(
  "clay|Clay|Dusty Rose"
  "flamingo|Flamingo|Earthy Red"
  "terracotta|Terracotta|Warm Clay"
  "ember|Ember|Deep Orange"
  "golden-amber|Golden Amber|Warm Gold"
  "hay|Hay|Muted Yellow"
  "sage|Sage|Natural Green"
  "moss|Moss|Deep Green"
  "pine|Pine|Earthy Teal"
  "cello|Cello|Slate Blue"
  "blue-calx|Blue Calx|Muted Blue"
  "dusk|Dusk|Earthy Lavender"
  "mauve-earth|Mauve Earth|Dusty Mauve"
  "stone|Stone|Warm Gray"
)

declare -a FRANKLIN_SIGNATURE_PALETTE_METADATA=(
  "ember|Ember|Radiant adobe + ember glow"
  "ash|Ash|Smoky muted earthtones"
)

franklin_palette_hex() {
  local palette_slug
  palette_slug=$(franklin_slugify "${1:-$FRANKLIN_SIGNATURE_PALETTE}")
  local color_slug
  color_slug=$(franklin_slugify "$2")
  case "${palette_slug}:${color_slug}" in
    ember:clay) echo "#d4a89a" ;;
    ember:flamingo) echo "#e76663" ;;
    ember:terracotta) echo "#c8755e" ;;
    ember:ember) echo "#e89635" ;;
    ember:golden-amber) echo "#f5a838" ;;
    ember:hay) echo "#e8c872" ;;
    ember:sage) echo "#8fae5a" ;;
    ember:moss) echo "#6b8540" ;;
    ember:pine) echo "#5a9194" ;;
    ember:cello) echo "#6284a0" ;;
    ember:blue-calx) echo "#a8b8d0" ;;
    ember:dusk) echo "#9d87b3" ;;
    ember:mauve-earth) echo "#b37e94" ;;
    ember:stone) echo "#8a909e" ;;
    ash:clay) echo "#c89c8d" ;;
    ash:flamingo) echo "#dc3a38" ;;
    ash:terracotta) echo "#a8654f" ;;
    ash:ember) echo "#d97706" ;;
    ash:golden-amber) echo "#ef991f" ;;
    ash:hay) echo "#d4b86a" ;;
    ash:sage) echo "#739038" ;;
    ash:moss) echo "#5a6f2d" ;;
    ash:pine) echo "#4a7c7e" ;;
    ash:cello) echo "#4c627d" ;;
    ash:blue-calx) echo "#a3b2c9" ;;
    ash:dusk) echo "#8b7a9f" ;;
    ash:mauve-earth) echo "#9b6b7f" ;;
    ash:stone) echo "#747b8a" ;;
    *) return 1 ;;
  esac
}

franklin_hex_to_rgb() {
  local hex="${1#'#'}"
  [[ ${#hex} -eq 6 ]] || return 1
  printf '%d %d %d\n' "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}

franklin_rgb_to_hex() {
  printf '#%02x%02x%02x\n' "$1" "$2" "$3"
}

franklin_adjust_hex() {
  local hex="$1"
  local mode="$2"
  local percent="${3:-15}"
  local r g b
  read -r r g b <<<"$(franklin_hex_to_rgb "$hex")"
  if [ "$mode" = "darken" ]; then
    r=$(( r * (100 - percent) / 100 ))
    g=$(( g * (100 - percent) / 100 ))
    b=$(( b * (100 - percent) / 100 ))
  else
    r=$(( r + (255 - r) * percent / 100 ))
    g=$(( g + (255 - g) * percent / 100 ))
    b=$(( b + (255 - b) * percent / 100 ))
  fi
  franklin_rgb_to_hex "$r" "$g" "$b"
}

franklin_hex_for_name() {
  local input="$1"
  if [ -z "$input" ]; then
    return 1
  fi

  local raw_slug
  raw_slug=$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

  if printf '%s' "$input" | grep -Eq '^#?[0-9A-Fa-f]{6}$'; then
    printf '#%s\n' "${raw_slug#'#'}"
    return 0
  fi

  if printf '%s' "$input" | grep -Eq '^#?[0-9A-Fa-f]{3}$'; then
    raw_slug="${raw_slug#'#'}"
    printf '#%s%s%s%s%s%s\n' \
      "${raw_slug:0:1}" "${raw_slug:0:1}" \
      "${raw_slug:1:1}" "${raw_slug:1:1}" \
      "${raw_slug:2:1}" "${raw_slug:2:1}"
    return 0
  fi

  local palette_hint=""
  local color_name="$input"
  if [[ "$input" == *:* ]]; then
    palette_hint="${input%%:*}"
    color_name="${input#*:}"
  fi

  local palette_slug
  if [ -n "$palette_hint" ]; then
    palette_slug=$(franklin_slugify "$palette_hint")
  else
    palette_slug="$FRANKLIN_SIGNATURE_PALETTE"
  fi

  local color_slug
  color_slug=$(franklin_slugify "$color_name")

  if franklin_palette_hex "$palette_slug" "$color_slug" >/dev/null 2>&1; then
    franklin_palette_hex "$palette_slug" "$color_slug"
    return 0
  fi

  # Allow bare color slug to default to ember palette
  if [ "$palette_slug" != "ember" ] && franklin_palette_hex "ember" "$color_slug" >/dev/null 2>&1; then
    franklin_palette_hex "ember" "$color_slug"
    return 0
  fi

  return 1
}

print_franklin_palette() {
  local palette_slug="$1"
  local palette_label="$2"
  echo "$palette_label palette:"
  local idx=1
  for entry in "${FRANKLIN_SIGNATURE_COLOR_METADATA[@]}"; do
    IFS='|' read -r slug label desc <<<"$entry"
    local base_hex
    if ! base_hex=$(franklin_palette_hex "$palette_slug" "$slug" 2>/dev/null); then
      continue
    fi
    local darker_hex
    darker_hex=$(franklin_adjust_hex "$base_hex" "darken" 15)
    local br bg bb dr dg db
    read -r br bg bb <<<"$(franklin_hex_to_rgb "$base_hex")"
    read -r dr dg db <<<"$(franklin_hex_to_rgb "$darker_hex")"
    printf "  %2d) %-13s %-14s \033[48;2;%d;%d;%dm  \033[0m \033[48;2;%d;%d;%dm  \033[0m\n" \
      "$idx" "$label" "$base_hex" "$br" "$bg" "$bb" "$dr" "$dg" "$db"
    ((idx++))
  done
  echo "                     base            darker blend"
}

resolve_motd_color_input() {
  franklin_hex_for_name "$1"
}

configure_motd_color() {
  if [ "${FRANKLIN_TEST_MODE:-0}" -eq 1 ]; then
    log_debug "Skipping MOTD color configuration (test mode)"
    return 0
  fi

  local config_dir="$FRANKLIN_CONFIG_DIR"
  local config_file="${config_dir}/motd.env"
  local selection="$USER_MOTD_COLOR"
  local chosen_hex=""

  if [ -n "$selection" ]; then
    selection=$(printf '%s' "$selection" | tr -d '[:space:]')
    chosen_hex=$(resolve_motd_color_input "$selection") || {
      log_warning "Invalid --motd-color value '$selection'; skipping MOTD banner configuration"
      return 0
    }
  elif [ -t 0 ] || [ -r /dev/tty ]; then
    echo ""
    log_info "Configure Franklin signature banner colors"

    local active_palette="$FRANKLIN_SIGNATURE_PALETTE"
    echo ""
    echo "Available Palettes:"
    local palette_index=1
    for entry in "${FRANKLIN_SIGNATURE_PALETTE_METADATA[@]}"; do
      IFS='|' read -r slug label desc <<<"$entry"
      printf "  %d) %-6s — %s\n" "$palette_index" "$label" "$desc"
      ((palette_index++))
    done
    printf "Choose palette [%s]: " "$(franklin_title_case "$active_palette")"
    local palette_choice=""
    read -r palette_choice </dev/tty 2>/dev/null || palette_choice=""
    palette_choice="${palette_choice:-$active_palette}"
    local choice_slug
    choice_slug=$(franklin_slugify "$palette_choice")
    local idx=1
    for entry in "${FRANKLIN_SIGNATURE_PALETTE_METADATA[@]}"; do
      IFS='|' read -r slug label desc <<<"$entry"
      if [[ "$palette_choice" =~ ^[0-9]+$ ]]; then
        if [ "$palette_choice" -eq "$idx" ]; then
          active_palette="$slug"
          break
        fi
      elif [ "$choice_slug" = "$slug" ]; then
        active_palette="$slug"
        break
      fi
      ((idx++))
    done

    local -a color_entries=("${FRANKLIN_SIGNATURE_COLOR_METADATA[@]}")
    local -a color_hexes=()
    local default_slug="cello"
    local default_index=0
    for ((i = 0; i < ${#color_entries[@]}; i++)); do
      IFS='|' read -r slug label desc <<<"${color_entries[$i]}"
      local hex
      hex=$(franklin_palette_hex "$active_palette" "$slug") || continue
      color_hexes+=("$hex")
      if [ "$slug" = "$default_slug" ]; then
        default_index=$i
      fi
    done

    local total_colors=${#color_entries[@]}
    local custom_option=$((total_colors + 1))

    local input_fd=0
    if [ ! -t 0 ] && [ -r /dev/tty ]; then
      exec 3</dev/tty
      input_fd=3
    fi

    while true; do
      echo ""
      echo "Palette: $(franklin_title_case "$active_palette") — choose a shade:"
      for ((i = 0; i < total_colors; i++)); do
        IFS='|' read -r slug label desc <<<"${color_entries[$i]}"
        local hex="${color_hexes[$i]}"
        local darker_hex
        darker_hex=$(franklin_adjust_hex "$hex" "darken" 15)
        local br bg bb dr dg db
        read -r br bg bb <<<"$(franklin_hex_to_rgb "$hex")"
        read -r dr dg db <<<"$(franklin_hex_to_rgb "$darker_hex")"
        printf "  %2d) %-13s %-14s \033[48;2;%d;%d;%dm  \033[0m \033[48;2;%d;%d;%dm  \033[0m\n" \
          $((i + 1)) "$label" "$hex" "$br" "$bg" "$bb" "$dr" "$dg" "$db"
      done
      printf "  %2d) %-13s %s\n" "$custom_option" "Custom hex" "#RRGGBB"

      local prompt_default=$((default_index + 1))
      printf "Select a color by number [%d]: " "$prompt_default"
      local menu_choice=""
      read -r menu_choice <&$input_fd || menu_choice=""
      menu_choice="${menu_choice:-$prompt_default}"

      if ! [[ $menu_choice =~ ^[0-9]+$ ]]; then
        log_warning "Please enter a number from the list."
        continue
      fi

      if [ "$menu_choice" -ge 1 ] && [ "$menu_choice" -le "$total_colors" ]; then
        chosen_hex="${color_hexes[$((menu_choice - 1))]}"
        break
      fi

      if [ "$menu_choice" -eq "$custom_option" ]; then
        while true; do
          printf "Enter a custom hex value (#RRGGBB): "
          local custom_hex=""
          read -r custom_hex <&$input_fd || custom_hex=""
          custom_hex=$(printf '%s' "$custom_hex" | tr -d '[:space:]')
          local resolved_hex=""
          if resolved_hex=$(resolve_motd_color_input "$custom_hex" 2>/dev/null); then
            chosen_hex="$resolved_hex"
            break 2
          fi
          log_warning "'$custom_hex' is not a valid hex color."
        done
      else
        log_warning "Please choose a number between 1 and $custom_option."
      fi
    done

    if [ "$input_fd" -eq 3 ]; then
      exec 3<&-
    fi
  else
    log_info "Skipping MOTD color prompt (non-interactive). Re-run with --motd-color <value> to configure."
    return 0
  fi

  mkdir -p "$config_dir"
cat > "$config_file" <<EOF
# Generated by Franklin install.sh on $(date +%Y-%m-%dT%H:%M:%S%z)
export MOTD_COLOR="$chosen_hex"
EOF
  chmod 600 "$config_file" 2>/dev/null || true
  export MOTD_COLOR="$chosen_hex"
  log_success "Saved MOTD banner color ($chosen_hex) to $config_file"
}

check_command() {
  local cmd="$1"
  local msg="${2:-}"

  if command -v "$cmd" >/dev/null 2>&1; then
    log_debug "Command found: $cmd"
    return 0
  else
    if [ -n "$msg" ]; then
      log_error "$msg"
    else
      log_error "Required command not found: $cmd"
    fi
    return 1
  fi
}

check_command_optional() {
  local cmd="$1"
  local msg="${2:-}"

  if command -v "$cmd" >/dev/null 2>&1; then
    log_debug "Optional command found: $cmd"
    return 0
  else
    if [ -n "$msg" ]; then
      log_warning "$msg"
    else
      log_warning "Optional command not found: $cmd"
    fi
    return 1
  fi
}

backup_file() {
  local file="$1"

  if [ -f "$file" ] && [ ! -L "$file" ]; then
    log_info "Backing up $file to ${file}.bak"
    mv "$file" "${file}.bak"
    log_success "Backed up"
    return 0
  elif [ -L "$file" ]; then
    log_debug "File is symlink, removing: $file"
    rm "$file"
    return 0
  fi

  return 0
}

backup_asset() {
  local path="$1"
  local label="$2"

  if [ ! -e "$path" ]; then
    return 0
  fi

  local dest_dir="$BACKUP_ROOT/$BACKUP_TIMESTAMP"
  local dest_path="$dest_dir/$label"

  mkdir -p "$(dirname "$dest_path")"
  log_info "Backing up $label to $dest_path"
  if cp -a "$path" "$dest_path"; then
    log_success "$label backed up"
    return 0
  fi

  log_error "Failed to back up $label"
  return 2
}

backup_existing_shell_assets() {
  log_info "Creating backups under $BACKUP_ROOT/$BACKUP_TIMESTAMP"
  local status=0

  backup_asset "$HOME/.zshrc" ".zshrc" || status=2
  backup_asset "$HOME/.zshenv" ".zshenv" || status=2
  backup_asset "$HOME/.zprofile" ".zprofile" || status=2
  backup_asset "$HOME/.config/starship.toml" ".config/starship.toml" || status=2
  backup_asset "$HOME/.antigen" ".antigen" || status=2

  return $status
}

create_symlink() {
  local target="$1"
  local link="$2"

  if [ ! -e "$target" ]; then
    log_error "Target does not exist: $target"
    return 2
  fi

  # Remove existing link or file
  if [ -e "$link" ] || [ -L "$link" ]; then
    backup_file "$link"
  fi

  # Create symlink
  if ln -s "$target" "$link"; then
    if [ ! -e "$link" ]; then
      log_error "Created symlink but target is missing: $link -> $target"
      return 2
    fi
    log_success "Created symlink: $link -> $target"
    return 0
  fi

  log_error "Failed to create symlink: $link -> $target"
  return 2
}

ensure_local_config_stub() {
  local target="$FRANKLIN_LOCAL_CONFIG"

  if [ -z "$target" ]; then
    return 0
  fi

  if [ -f "$target" ]; then
    log_debug "Local override file already exists: $target"
    return 0
  fi

  local target_dir
  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir"

  cat <<'EOF' >"$target"
# Franklin local overrides
# Add private aliases, functions, exports, and server shortcuts here.
# This file is sourced automatically at the end of ~/.zshrc.
EOF
  chmod 600 "$target" 2>/dev/null || true
  log_success "Created local overrides file: $target"
}

run_version_audit() {
  local checker="$SCRIPT_DIR/scripts/check_versions.sh"

  if [ ! -x "$checker" ]; then
    log_warning "Version checker script missing; skipping version audit"
    return 1
  fi

  if FRANKLIN_UI_SPINNER_VERBOSE="$VERBOSE" \
      franklin_ui_run_with_spinner \
        "Ensuring dependencies match the latest releases" \
        env FRANKLIN_VERSION_CHECK_VERBOSE="$FRANKLIN_VERSION_CHECK_VERBOSE" \
        "$checker" --apply; then
    return 0
  fi

  log_warning "Version audit encountered issues (continuing)"
  return 1
}

show_help() {
  cat << 'EOF'
Franklin Bootstrap Installation

Usage: bash install.sh [OPTIONS]

Options:
  --verbose           Show debug output
  --quiet             Suppress Franklin UI logging (stderr only)
  --motd-color VALUE  Set Franklin signature color (name or #RRGGBB) for the MOTD banner
  --help              Show this help message

Exit codes:
  0 - Success
  1 - Warning (optional dependency skipped)
  2 - Error (required dependency missing)
  3 - Abort (user cancelled)

Run from your cloned Franklin repository directory.
EOF
}

# ============================================================================
# Installation Flow
# ============================================================================

detect_platform() {
  log_info "Detecting platform..."

  # Source os_detect.sh if available, otherwise detect manually
  if [ -f "$SCRIPT_DIR/lib/os_detect.sh" ]; then
    source "$SCRIPT_DIR/lib/os_detect.sh" >/dev/null 2>&1 || true
  fi

  # Fallback detection if os_detect.sh not available
  if [ -z "$OS_FAMILY" ]; then
    local uname_output
    uname_output=$(uname -s)

    case "$uname_output" in
      Darwin)
        OS_FAMILY="macos"
        ;;
      Linux)
        if [ -f /etc/os-release ]; then
          local distro_id
          distro_id=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
          case "$distro_id" in
            ubuntu|debian)
              OS_FAMILY="debian"
              ;;
            fedora)
              OS_FAMILY="fedora"
              ;;
            *)
              OS_FAMILY="debian"
              ;;
          esac
        else
          OS_FAMILY="debian"
        fi
        ;;
      *)
        log_error "Unsupported platform: $uname_output"
        return 2
        ;;
    esac
  fi

  log_success "Platform detected: $OS_FAMILY"
  export OS_FAMILY
}

check_dependencies() {
  log_info "Checking dependencies..."

  local required_missing=0

  # Required tools
  if ! check_command "git" "Git is required"; then
    required_missing=1
  else
    log_success "git ✓"
  fi

  if ! check_command "curl" "Curl is required for downloads"; then
    required_missing=1
  else
    log_success "curl ✓"
  fi

  # Optional tools (zsh will be installed if missing)
  check_command_optional "zsh" "Zsh not found (will be installed)" || true
  log_success "zsh will be installed if needed"

  if [ $required_missing -eq 1 ]; then
    return 2
  fi

  return 0
}

setup_zshrc() {
  log_info "Setting up .zshrc symlink..."

  local zshrc_target="${FRANKLIN_HOME}/.zshrc"

  if [ ! -f "$zshrc_target" ]; then
    log_error ".zshrc not found in $FRANKLIN_HOME"
    return 2
  fi

  # Backup existing .zshrc
  backup_file "$ZSHRC_PATH"

  # Create symlink
  create_symlink "$zshrc_target" "$ZSHRC_PATH"

  ensure_local_config_stub

  log_success ".zshrc symlink configured"
  return 0
}

install_platform_specific() {
  log_info "Installing platform-specific dependencies..."

  case "$OS_FAMILY" in
    macos)
      if [ -f "$SCRIPT_DIR/lib/install_macos.sh" ]; then
        source "$SCRIPT_DIR/lib/install_macos.sh"
        install_macos_dependencies
      else
        log_warning "macOS-specific installer not found"
      fi
      ;;
    debian)
      if [ -f "$SCRIPT_DIR/lib/install_debian.sh" ]; then
        source "$SCRIPT_DIR/lib/install_debian.sh"
        install_debian_dependencies
      else
        log_warning "Debian-based installer not found"
      fi
      ;;
    fedora)
      if [ -f "$SCRIPT_DIR/lib/install_fedora.sh" ]; then
        source "$SCRIPT_DIR/lib/install_fedora.sh"
        install_fedora_dependencies
      else
        log_warning "Fedora installer not found"
      fi
      ;;
    *)
      log_warning "No platform-specific installer for: $OS_FAMILY"
      ;;
  esac
}

set_default_shell() {
  log_info "Setting zsh as default shell..."

  local zsh_path
  zsh_path=$(command -v zsh)

  if [ -z "$zsh_path" ]; then
    log_error "zsh not found after installation"
    return 2
  fi

  # Check if zsh is already default
  if [ "$SHELL" = "$zsh_path" ]; then
    log_debug "zsh already set as default shell"
    return 0
  fi

  # Try to set default shell
  log_debug "Current shell: $SHELL"
  log_debug "zsh path: $zsh_path"

  # Only on macOS/Linux with chsh available
  if command -v chsh >/dev/null 2>&1; then
    # chsh requires password, skip if not interactive
    if [ -t 0 ]; then
      log_info "Run 'chsh -s $(command -v zsh)' to set zsh as default shell"
    fi
  fi

  log_success "Shell configuration ready"
  return 0
}

show_summary() {
  franklin_ui_blank_line
  franklin_ui_section "Summary"
  log_success "Installation Complete!"
  franklin_ui_blank_line
  franklin_ui_plain "Next steps:"
  franklin_ui_plain "1. Restart your terminal or run: exec zsh"
  franklin_ui_plain "2. Verify installation: zsh"
  franklin_ui_plain "3. To set zsh as default: chsh -s \$(which zsh)"
  franklin_ui_blank_line
  franklin_ui_plain "Configuration:"
  franklin_ui_plain "  - Franklin installed: $FRANKLIN_HOME"
  franklin_ui_plain "  - .zshrc symlink: $ZSHRC_PATH"
  if [ -f "$FRANKLIN_LOCAL_CONFIG" ]; then
    franklin_ui_plain "  - Local overrides: $FRANKLIN_LOCAL_CONFIG"
  fi
  if [ -f "$FRANKLIN_CONFIG_DIR/motd.env" ]; then
    franklin_ui_plain "  - MOTD color config: $FRANKLIN_CONFIG_DIR/motd.env"
  else
    franklin_ui_plain "  - MOTD color: default (run install.sh --motd-color <name|hex> to set)"
  fi
  franklin_ui_blank_line
}

# ============================================================================
# Main Installation Flow
# ============================================================================

main() {
  # Parse arguments
  while [ $# -gt 0 ]; do
    case "$1" in
      --verbose)
        VERBOSE=1
        shift
        ;;
      --quiet)
        FRANKLIN_UI_QUIET=1
        shift
        ;;
      --motd-color)
        if [ -z "${2:-}" ]; then
          log_error "--motd-color requires a value"
          exit 2
        fi
        USER_MOTD_COLOR="$2"
        shift 2
        ;;
      --motd-color=*)
        USER_MOTD_COLOR="${1#*=}"
        shift
        ;;
      --help)
        show_help
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        show_help
        exit 2
        ;;
    esac
  done

  franklin_ui_section "Franklin Installer"
install_log_spacer
log_info "Starting Franklin installation..."
install_log_spacer

  install_log_spacer
  begin_install_phase "Detect platform"
  detect_platform || exit 2

  begin_install_phase "Dependency check"
  check_dependencies || exit 2

  begin_install_phase "Back up shell assets"
  backup_existing_shell_assets || exit 2

  begin_install_phase "Configure zshrc"
  setup_zshrc || exit 2

  begin_install_phase "MOTD colors"
  configure_motd_color || true

  begin_install_phase "Platform packages"
  install_platform_specific || true

  begin_install_phase "Version audit"
  run_version_audit || true

  begin_install_phase "Default shell"
  set_default_shell || true

  show_summary
  exit 0
}

if [ "${FRANKLIN_TEST_MODE:-0}" -ne 1 ]; then
  main "$@"
fi
