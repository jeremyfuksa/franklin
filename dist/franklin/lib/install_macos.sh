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

  # Install dependencies from Brewfile
  local brewfile="$FRANKLIN_LIB_DIR/../Brewfile"
  if [ ! -f "$brewfile" ]; then
    log_error "Brewfile not found at $brewfile"
    return 2
  fi

  log_info "Installing packages from Brewfile..."
  if brew bundle install --file="$brewfile" --no-lock; then
    log_success "Homebrew packages installed ✓"
  else
    log_warning "Some Homebrew packages failed to install"
    return 1
  fi

  # NVM is required (not optional)
  if ! ensure_nvm_installed; then
    log_error "NVM installation failed - this is required for Franklin"
    return 2
  fi

  log_success "macOS dependencies installed"
  return 0
}
