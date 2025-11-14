#!/bin/bash
# macOS-Specific Installation Module
#
# Installs Franklin dependencies on macOS using Homebrew
# Sourced by install.sh

_franklin_install_lib="${FRANKLIN_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=lib/install_helpers.sh
. "$_franklin_install_lib/install_helpers.sh"
unset _franklin_install_lib

install_macos_dependencies() {
  log_info "Installing macOS dependencies (Homebrew)..."

  # Check if Homebrew is installed
  if ! command -v brew >/dev/null 2>&1; then
    log_warning "Homebrew not installed. Please install from https://brew.sh"
    log_info "After installing Homebrew, you can re-run this script"
    return 1
  fi

  log_success "Homebrew found"

  # Update Homebrew
  log_info "Updating Homebrew..."
  brew update

  # Install core dependencies
  local packages=(
    "zsh"           # Shell (if not installed)
    "antigen"       # Plugin manager
    "fzf"           # Fuzzy finder
    "starship"      # Prompt
    "bat"           # Cat with syntax highlighting
  )

  local failed=0
  for pkg in "${packages[@]}"; do
    if brew list "$pkg" >/dev/null 2>&1; then
      log_debug "$pkg already installed"
    else
      log_info "Installing $pkg..."
      if brew install "$pkg"; then
        log_success "$pkg installed ✓"
      else
        log_warning "Failed to install $pkg"
        failed=1
      fi
    fi
  done

  if [ $failed -eq 1 ]; then
    return 1
  fi

  ensure_nvm_installed || log_warning "NVM installation skipped (macOS)"

  log_success "macOS dependencies installed"
  return 0
}
