#!/bin/bash
# Fedora Installation Module (dnf-based)
#
# Installs Franklin dependencies on RHEL/Fedora using dnf
# Sourced by install.sh

_franklin_install_lib="${FRANKLIN_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=lib/install_helpers.sh
. "$_franklin_install_lib/install_helpers.sh"
unset _franklin_install_lib

install_fedora_dependencies() {
  log_info "Installing Fedora dependencies (dnf)..."

  # Check if dnf is available
  if ! command -v dnf >/dev/null 2>&1; then
    log_error "dnf not found on this system"
    return 2
  fi

  log_success "dnf found"

  # Update package cache
  log_info "Updating package cache..."
  local dnf_status=0
  if ! sudo dnf check-update -q >/dev/null 2>&1; then
    dnf_status=$?
  fi

  if [ $dnf_status -ne 0 ]; then
    if [ $dnf_status -eq 100 ]; then
      log_debug "dnf reports available updates; continuing installation"
    else
      log_error "Failed to update package cache (dnf exited with $dnf_status)"
      return 2
    fi
  fi

  # Install core dependencies
  local packages=(
    "zsh"           # Shell
    "git"           # Version control
    "curl"          # Downloads
    "gcc"           # C compiler
    "make"          # Build tool
    "python3"       # Python 3
    "python3-pip"   # pip package manager
    "bat"           # Cat with syntax highlighting
  )

  local failed=0
  for pkg in "${packages[@]}"; do
    log_info "Checking $pkg..."
    if rpm -q "$pkg" >/dev/null 2>&1; then
      log_debug "$pkg already installed"
    else
      log_info "Installing $pkg..."
      if sudo dnf install -y "$pkg" >/dev/null 2>&1; then
        log_success "$pkg installed ✓"
      else
        log_warning "Failed to install $pkg"
        failed=1
      fi
    fi
  done

  # Install uv (Python package manager) - not in dnf, install via official installer
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

  # Starship (required - install via dnf or fallback to official installer)
  if ! command -v starship >/dev/null 2>&1; then
    log_info "Installing Starship prompt..."
    if sudo dnf install -y starship >/dev/null 2>&1; then
      log_success "Starship installed ✓"
    else
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

  log_success "Fedora dependencies installation complete"
  return 0
}
