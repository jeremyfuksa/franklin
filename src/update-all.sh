#!/bin/bash
# Franklin Unified Update System
#
# Updates system packages, shell plugins, Node.js, npm packages, and other tools
# in isolated steps with clear progress reporting.
#
# Usage:
#   bash update-all.sh [--verbose] [--quiet] [--help]
#
# Exit codes:
#   0 - Success
#   1 - Warning (some steps failed but non-critical)
#   2 - Error (critical step failed)

set -e

if command -v sudo >/dev/null 2>&1; then
  trap 'sudo -k >/dev/null 2>&1 || true' EXIT
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE=${VERBOSE:-0}
FRANKLIN_VERSION_CHECK_VERBOSE=${FRANKLIN_VERSION_CHECK_VERBOSE:-$VERBOSE}
FRANKLIN_TEST_MODE=${FRANKLIN_TEST_MODE:-0}
FRANKLIN_UI_QUIET=${FRANKLIN_UI_QUIET:-0}
STEPS_FAILED=0
STEPS_PASSED=0

# Shared resources
# shellcheck source=lib/colors.sh
. "$SCRIPT_DIR/lib/colors.sh"
# shellcheck source=lib/versions.sh
. "$SCRIPT_DIR/lib/versions.sh"
# shellcheck source=lib/ui.sh
. "$SCRIPT_DIR/lib/ui.sh"

# ============================================================================
# Helper Functions
# ============================================================================

run_with_spinner() {
  local desc="$1"
  shift
  local tail_lines="${SPINNER_TAIL_LINES:-40}"
  FRANKLIN_UI_SPINNER_VERBOSE="$VERBOSE" \
    FRANKLIN_UI_SPINNER_TAIL_LINES="$tail_lines" \
    franklin_ui_run_with_spinner "$desc" "$@"
}

UPDATE_BADGE="[UPDATE]"
DEBUG_BADGE="[DEBUG]"

log_info() { franklin_ui_blank_line; franklin_ui_log info "$UPDATE_BADGE" "$@"; }
log_success() { franklin_ui_blank_line; franklin_ui_log success "  OK " "$@"; }
log_warning() { franklin_ui_blank_line; franklin_ui_log warning " WARN " "$@"; }
log_error() { franklin_ui_blank_line; franklin_ui_log error " ERR " "$@"; }
log_debug() {
  if [ "$VERBOSE" -eq 1 ]; then
    franklin_ui_blank_line
    franklin_ui_log debug "$DEBUG_BADGE" "$@"
  fi
}

print_section_header() {
  franklin_ui_blank_line
  franklin_ui_section "$1"
}

print_version_status() {
  local turtle="🐢"
  local version_file="$SCRIPT_DIR/VERSION"
  local current_version="unknown"
  local latest_version="unknown"
  local status="unknown"
  local version_script="$SCRIPT_DIR/scripts/current_franklin_version.sh"

  if [ -x "$version_script" ]; then
    current_version=$("$version_script" 2>/dev/null || echo "unknown")
  elif [ -f "$version_file" ]; then
    current_version=$(cat "$version_file" 2>/dev/null || echo "unknown")
  fi

  if command -v gh >/dev/null 2>&1; then
    latest_version=$(gh release view --json tagName -q '.tagName' 2>/dev/null || echo "unknown")
  else
    latest_version=$(curl -fsSL "https://api.github.com/repos/jeremyfuksa/franklin/releases/latest" 2>/dev/null \
      | grep -m1 '"tag_name"' \
      | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' 2>/dev/null || echo "unknown")
  fi

  if [ "$current_version" != "unknown" ] && [ "$latest_version" != "unknown" ]; then
    if [ "$current_version" = "$latest_version" ]; then
      status="current"
    else
      status="outdated"
    fi
  fi

  case "$status" in
    current)
      franklin_ui_plain "${GREEN}${turtle}${NC} Franklin ${current_version} (latest)"
      ;;
    outdated)
      franklin_ui_plain "${YELLOW}${turtle}${NC} Franklin ${current_version} (latest: ${latest_version})"
      ;;
    *)
      franklin_ui_plain "${turtle} Franklin version: ${current_version} (unable to check latest)"
      ;;
  esac
}

print_version_status() {
  local turtle="🐢"
  local version_file="$SCRIPT_DIR/VERSION"
  local current_version="unknown"
  local latest_version="unknown"
  local status="unknown"

  if [ -f "$version_file" ]; then
    current_version=$(cat "$version_file" 2>/dev/null || echo "unknown")
  fi

  if command -v gh >/dev/null 2>&1; then
    latest_version=$(gh release view --json tagName -q '.\tagName' 2>/dev/null || echo "unknown")
  else
    latest_version=$(curl -fsSL "https://api.github.com/repos/jeremyfuksa/franklin/releases/latest" \
      | grep -m1 '"tag_name"' \
      | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' 2>/dev/null || echo "unknown")
  fi

  if [ "$current_version" != "unknown" ] && [ "$latest_version" != "unknown" ]; then
    if [ "$current_version" = "$latest_version" ]; then
      status="current"
    else
      status="outdated"
    fi
  fi

  case "$status" in
    current)
      franklin_ui_plain "${GREEN}${turtle}${NC} Franklin ${current_version} (latest)"
      ;;
    outdated)
      franklin_ui_plain "${YELLOW}${turtle}${NC} Franklin ${current_version} (latest: ${latest_version})"
      ;;
    *)
      franklin_ui_plain "${turtle} Franklin version: ${current_version} (unable to check latest)"
      ;;
  esac
}

run_step() {
  local step_name="$1"
  local step_fn="$2"

  print_section_header "$step_name"

  # Run in subshell for isolation
  if (
    set +e
    $step_fn
    return $?
  ); then
    franklin_ui_log success " OK " "$step_name"
    ((STEPS_PASSED++))
    return 0
  else
    local exit_code=$?
    if [ $exit_code -eq 1 ]; then
      log_warning "$step_name skipped (optional)"
      ((STEPS_PASSED++))
      return 0
    else
      log_error "$step_name failed"
      ((STEPS_FAILED++))
      return 1
    fi
  fi
}

show_help() {
  cat << 'EOF'
Franklin Unified Update System

Usage: bash update-all.sh [OPTIONS]

Updates all system components in isolated steps:
  - System packages (brew, apt, dnf)
  - Antigen plugins
  - Starship prompt
  - NVM and Node.js
  - npm global packages
  - Version pin audit (compares pinned dependencies to upstream)

Options:
  --verbose     Show debug output
  --quiet       Suppress Franklin UI logging (stderr only)
  --help        Show this help message

Exit codes:
  0 - Success
  1 - Warning (some optional steps failed)
  2 - Error (critical step failed)
EOF
}

# ============================================================================
# Update Steps
# ============================================================================

step_os_packages() {
  source "$SCRIPT_DIR/lib/os_detect.sh" >/dev/null 2>&1

  case "$OS_FAMILY" in
    macos)
      log_info "Updating Homebrew packages..."
      if ! run_with_spinner "Updating Homebrew" brew update; then
        return 2
      fi
      local outdated
      outdated=$(brew outdated --quiet)
      if [ -z "$outdated" ]; then
        log_info "Homebrew formulas already up to date."
      else
        run_with_spinner "Upgrading Homebrew packages" brew upgrade
      fi
      return 0
      ;;
    debian)
      log_info "Updating apt packages..."
      if run_with_spinner "Updating package lists" sudo apt-get update -qq; then
        run_with_spinner "Upgrading packages" sudo apt-get upgrade -y
        return 0
      else
        return 2
      fi
      ;;
    fedora)
      log_info "Updating dnf packages..."
      run_with_spinner "Upgrading dnf packages" sudo dnf upgrade -y
      return 0
      ;;
    *)
      log_warning "OS package update not supported for $OS_FAMILY"
      return 1
      ;;
  esac
}

step_antigen() {
  # Check if antigen is installed (Homebrew or manual)
  local antigen_found=0
  local antigen_path=""

  # Check for Homebrew installation
  if command -v brew >/dev/null 2>&1; then
    local brew_antigen="$(brew --prefix antigen 2>/dev/null)/share/antigen/antigen.zsh"
    if [ -f "$brew_antigen" ]; then
      antigen_found=1
      antigen_path="$brew_antigen"
    fi
  fi

  # Check for manual installation
  if [ -f "$HOME/.antigen/antigen.zsh" ]; then
    antigen_found=1
    antigen_path="$HOME/.antigen/antigen.zsh"
  fi

  if [ $antigen_found -eq 0 ]; then
    log_warning "Antigen not installed, skipping"
    return 1
  fi

  # Update Antigen using the proper method
  if command -v brew >/dev/null 2>&1 && brew list antigen >/dev/null 2>&1; then
    log_info "Updating Antigen via Homebrew..."
    if [ -z "$(brew outdated --quiet antigen)" ]; then
      log_info "Antigen already up to date."
    else
      run_with_spinner "Upgrading Antigen" brew upgrade antigen >/dev/null 2>&1
    fi
  elif [ -d "$HOME/.antigen/.git" ]; then
    log_info "Updating Antigen and plugins..."
    # Use antigen's built-in selfupdate command
    if run_with_spinner "Updating Antigen and plugins" zsh -c "source '$antigen_path' && antigen selfupdate && antigen update" 2>/dev/null; then
      log_debug "Antigen and plugins updated successfully"
    else
      log_warning "Antigen update failed, trying git pull..."
      run_with_spinner "Pulling Antigen updates" bash -c "cd '$HOME/.antigen' && git pull --quiet" || log_warning "Git pull failed"
    fi
  else
    log_info "Re-downloading Antigen..."
    # For single-file installations, re-download
    if run_with_spinner "Downloading Antigen" curl -fsSL git.io/antigen -o "$antigen_path.tmp" 2>/dev/null; then
      mv "$antigen_path.tmp" "$antigen_path"
      log_debug "Antigen updated successfully"
    else
      log_warning "Failed to download Antigen update"
      rm -f "$antigen_path.tmp"
    fi
  fi

  return 0
}

step_starship() {
  if ! command -v starship >/dev/null 2>&1; then
    log_warning "Starship not installed, skipping"
    return 1
  fi

  source "$SCRIPT_DIR/lib/os_detect.sh" >/dev/null 2>&1

  # Try package manager first, then fall back to official installer
  case "$OS_FAMILY" in
    macos)
      if command -v brew >/dev/null 2>&1 && brew list starship >/dev/null 2>&1; then
        log_info "Updating Starship via Homebrew..."
        if [ -z "$(brew outdated --quiet starship)" ]; then
          log_info "Starship already up to date."
        else
          run_with_spinner "Upgrading Starship" brew upgrade starship >/dev/null 2>&1
        fi
        return 0
      fi
      ;;
    debian)
      if command -v snap >/dev/null 2>&1 && snap list starship >/dev/null 2>&1; then
        log_info "Updating Starship via snap..."
        if snap refresh --list 2>/dev/null | grep -q '^starship'; then
          run_with_spinner "Refreshing Starship" sudo snap refresh starship >/dev/null 2>&1
        else
          log_info "Starship already up to date."
        fi
        return 0
      fi
      ;;
    fedora)
      if rpm -q starship >/dev/null 2>&1; then
        log_info "Updating Starship via dnf..."
        sudo dnf check-update starship >/dev/null 2>&1
        local dnf_status=$?
        if [ $dnf_status -eq 100 ]; then
          run_with_spinner "Upgrading Starship" sudo dnf upgrade -y starship >/dev/null 2>&1
        elif [ $dnf_status -eq 0 ]; then
          log_info "Starship already up to date."
        else
          log_warning "Unable to check Starship updates (dnf status $dnf_status)"
        fi
        return 0
      fi
      ;;
  esac

  # Fall back to official installer (works for all platforms)
  log_info "Updating Starship via official installer..."
  if run_with_spinner "Installing Starship" bash -c "curl -fsSL https://starship.rs/install.sh | sh -s -- --yes" >/dev/null 2>&1; then
    log_debug "Starship updated successfully"
    return 0
  else
    log_warning "Starship update failed"
    return 1
  fi
}

step_nvm() {
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"

  if [ ! -d "$nvm_dir" ]; then
    log_warning "NVM not installed, skipping"
    return 1
  fi

  if [ ! -d "$nvm_dir/.git" ]; then
    log_warning "NVM directory missing git metadata, skipping update"
    return 1
  fi

  log_info "Updating NVM..."
  (
    cd "$nvm_dir"
    if [ -n "$(git status --porcelain)" ]; then
      log_warning "NVM has local modifications, skipping update"
      return 1
    fi
    git fetch --quiet --tags origin || return 1
    local latest_tag
    latest_tag=$(git describe --tags "$(git rev-list --tags --max-count=1)")
    if [ -z "$latest_tag" ]; then
      log_warning "Unable to determine latest NVM tag"
      return 1
    fi
    log_debug "Checking out NVM $latest_tag"
    git checkout -q "$latest_tag"
  ) || return 1

  if ! source "$nvm_dir/nvm.sh" 2>/dev/null; then
    log_warning "Unable to source NVM from $nvm_dir"
    return 1
  fi

  local current_lts desired_lts
  current_lts=$(nvm version lts/* 2>/dev/null || echo "")
  [ "$current_lts" = "N/A" ] && current_lts=""
  desired_lts=$(nvm version-remote --lts 2>/dev/null || echo "")
  if [ -n "$desired_lts" ]; then
    log_debug "Latest LTS: $desired_lts"
  fi

  if [ -n "$current_lts" ] && [ -n "$desired_lts" ] && [ "$current_lts" = "$desired_lts" ]; then
    log_info "Node LTS already at $current_lts."
  else
    log_info "Installing Node LTS..."
    if ! run_with_spinner "Installing Node LTS" nvm install --lts; then
      log_warning "Failed to install Node LTS via NVM"
      return 1
    fi
  fi

  if ! nvm alias default lts/* >/dev/null 2>&1; then
    log_warning "Failed to set default Node alias"
  fi

  # Clean up old node versions (keep only LTS)
  log_info "Cleaning up old Node versions..."
  local lts_version
  lts_version=$(nvm version lts/* 2>/dev/null)
  
  if [ -n "$lts_version" ]; then
    local version
    for version in "$nvm_dir"/versions/node/v*; do
      [ -d "$version" ] || continue
      local ver_name
      ver_name=$(basename "$version")
      
      # Skip the LTS version
      if [ "$ver_name" = "$lts_version" ]; then
        log_debug "Keeping LTS version: $ver_name"
        continue
      fi
      
      # Uninstall old versions
      log_debug "Removing old version: $ver_name"
      nvm uninstall "$ver_name" >/dev/null 2>&1 || log_warning "Failed to remove $ver_name"
    done
  fi

  return 0
}

step_npm_global() {
  # Source NVM first to ensure npm is in PATH (in case it was just installed)
  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"
  if [ -f "$nvm_dir/nvm.sh" ]; then
    source "$nvm_dir/nvm.sh" 2>/dev/null
  fi

  if ! command -v npm >/dev/null 2>&1; then
    log_warning "npm not installed, skipping"
    return 1
  fi

  local npm_version
  npm_version=$(npm --version 2>/dev/null)
  if [ -n "$npm_version" ]; then
    log_debug "npm version: $npm_version"
  fi

  local outdated_json
  outdated_json=$(npm outdated -g --depth=0 --json 2>/dev/null || true)
  if [ -z "$outdated_json" ] || [ "$outdated_json" = "{}" ]; then
    log_info "Global npm packages already up to date."
    return 0
  fi

  log_info "Updating global npm packages..."
  run_with_spinner "Updating npm packages" npm update -g || return 0
  return 0
}

step_version_pins() {
  local checker="$SCRIPT_DIR/scripts/check_versions.sh"
  if [ ! -x "$checker" ]; then
    log_warning "Version checker script missing, skipping"
    return 1
  fi

  log_info "Checking pinned dependency versions..."
  log_debug "Running: $checker --apply"
  if FRANKLIN_VERSION_CHECK_VERBOSE="$VERBOSE" "$checker" --apply; then
    log_debug "All pinned versions are current"
    return 0
  fi

  log_warning "Some pinned versions need attention (see above)"
  return 1
}

# ============================================================================
# Main Update Flow
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

  log_info "Franklin release status:"
  print_version_status
  echo ""

  log_info "Starting unified system update..."
  echo ""

  # Run update steps (isolated)
  run_step "OS packages" step_os_packages || true
  run_step "Antigen plugins" step_antigen || true
  run_step "Starship prompt" step_starship || true
  run_step "NVM and Node.js" step_nvm || true
  run_step "npm global packages" step_npm_global || true
  run_step "Pinned version audit" step_version_pins || true

  print_section_header "Summary"
  if [ $STEPS_FAILED -eq 0 ]; then
    log_success "All steps passed (${STEPS_PASSED})"
    exit 0
  else
    log_warning "Passed: $STEPS_PASSED  Failed: $STEPS_FAILED"
    exit 1
  fi
}

if [ "${FRANKLIN_TEST_MODE:-0}" -ne 1 ]; then
  main "$@"
fi
