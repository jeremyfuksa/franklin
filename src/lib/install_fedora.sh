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

  # Install optional packages
  log_info "Installing optional packages..."

  local optional_packages=(
    "fzf"           # Fuzzy finder
    "ripgrep"       # Fast grep alternative
    "bat"           # Cat with syntax highlighting
  )

  for pkg in "${optional_packages[@]}"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      log_debug "$pkg already installed"
    else
      log_info "Installing $pkg (optional)..."
      if sudo dnf install -y "$pkg" >/dev/null 2>&1; then
        log_success "$pkg installed ✓"
      else
        log_debug "Skipping $pkg (not critical)"
      fi
    fi
  done

  # Starship (install via cargo or dnf)
  if ! command -v starship >/dev/null 2>&1; then
    log_info "Installing Starship prompt..."
    if sudo dnf install -y starship >/dev/null 2>&1; then
      log_success "Starship installed ✓"
    else
      log_warning "Starship installation failed (optional)"
    fi
  else
    log_debug "Starship already installed"
  fi

  ensure_antigen_installed || log_warning "Antigen installation skipped (manual install required)"
  ensure_nvm_installed || log_warning "NVM installation skipped (manual install required)"

  log_success "Fedora dependencies installation complete"
  return 0
}
