#!/bin/bash
# Debian-based Installation Module (apt-based)
#
# Installs Franklin dependencies on Debian-based systems (Debian, Ubuntu, etc.) using apt
# Sourced by install.sh

_franklin_install_lib="${FRANKLIN_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=lib/install_helpers.sh
. "$_franklin_install_lib/install_helpers.sh"
unset _franklin_install_lib

install_debian_dependencies() {
  log_info "Installing Debian-based dependencies (apt)..."

  # Check if apt is available
  if ! command -v apt-get >/dev/null 2>&1; then
    log_error "apt-get not found on this system"
    return 2
  fi

  log_success "apt-get found"

  # Update package lists
  log_info "Updating package lists..."
  if ! sudo apt-get update -qq; then
    log_warning "Failed to update package lists"
    return 1
  fi

  # Install core dependencies
  local packages=(
    "zsh"           # Shell
    "git"           # Version control (should already be installed)
    "curl"          # Downloads (should already be installed)
    "build-essential"  # For compiling
  )

  local failed=0
  for pkg in "${packages[@]}"; do
    log_info "Checking $pkg..."
    if dpkg -l | grep -q "^ii.*$pkg"; then
      log_debug "$pkg already installed"
    else
      log_info "Installing $pkg..."
      if sudo apt-get install -y "$pkg" >/dev/null 2>&1; then
        log_success "$pkg installed ✓"
      else
        log_warning "Failed to install $pkg"
        failed=1
      fi
    fi
  done

  # Install optional packages
  log_info "Installing optional packages..."

  local optional_packages=(
    "fzf"           # Fuzzy finder
    "ripgrep"       # Fast grep alternative
    "bat"           # Cat with syntax highlighting (command: batcat on Debian)
  )

  for pkg in "${optional_packages[@]}"; do
    if dpkg -l | grep -q "^ii.*$pkg"; then
      log_debug "$pkg already installed"
    else
      log_info "Installing $pkg (optional)..."
      if sudo apt-get install -y "$pkg" >/dev/null 2>&1; then
        log_success "$pkg installed ✓"
      else
        log_debug "Skipping $pkg (not critical)"
      fi
    fi
  done

  # Starship (need to use snap or build)
  if ! command -v starship >/dev/null 2>&1; then
    log_info "Installing Starship prompt..."
    if command -v snap >/dev/null 2>&1; then
      if sudo snap install starship >/dev/null 2>&1; then
        log_success "Starship installed via snap"
      else
        log_warning "Starship snap installation failed"
      fi
    else
      log_warning "Starship not installed (requires snap or manual installation)"
    fi
  else
    log_debug "Starship already installed"
  fi

  ensure_antigen_installed || log_warning "Antigen installation skipped (manual install required)"
  ensure_nvm_installed || log_warning "NVM installation skipped (manual install required)"

  log_success "Debian-based dependencies installation complete"
  return 0
}
