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

  # Install core dependencies (all required)
  local packages=(
    "zsh"           # Shell
    "git"           # Version control (should already be installed)
    "curl"          # Downloads (should already be installed)
    "build-essential"  # For compiling
    "python3"       # Python 3
    "python3-pip"   # pip package manager
    "python3-venv"  # Python virtual environments
    "bat"           # Cat with syntax highlighting (command: batcat on Debian)
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

  # Install uv (Python package manager) - not in apt, install via official installer
  if ! command -v uv >/dev/null 2>&1; then
    log_info "Installing uv (Python package manager)..."
    if curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1; then
      log_success "uv installed ✓"
    else
      log_error "uv installation failed - this is required for Franklin"
      failed=1
    fi
  else
    log_debug "uv already installed"
  fi

  # Starship (required - prefer snap; fall back to official script)
  if ! command -v starship >/dev/null 2>&1; then
    log_info "Installing Starship prompt..."
    local installed=0
    if command -v snap >/dev/null 2>&1; then
      if sudo snap install starship >/dev/null 2>&1; then
        log_success "Starship installed via snap"
        installed=1
      else
        log_warning "Starship snap installation failed"
      fi
    fi
    if [ "$installed" -eq 0 ]; then
      log_info "Falling back to official Starship installer..."
      if curl -fsSL https://starship.rs/install.sh | sh -s -- --yes >/dev/null 2>&1; then
        log_success "Starship installed via official installer"
      else
        log_error "Starship installation failed - this is required for Franklin"
        return 2
      fi
    fi
  else
    log_debug "Starship already installed"
  fi

  # Antigen is required (not optional)
  if ! ensure_antigen_installed; then
    log_error "Antigen installation failed - this is required for Franklin"
    return 2
  fi

  # NVM is required (not optional)
  if ! ensure_nvm_installed; then
    log_error "NVM installation failed - this is required for Franklin"
    return 2
  fi

  if [ $failed -eq 1 ]; then
    return 2
  fi

  log_success "Debian-based dependencies installation complete"
  return 0
}
