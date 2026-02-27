#!/usr/bin/env bash
# UI Design Demo Script
# Demonstrates all Campfire UI patterns

set -e

# Source UI library (shared with install.sh)
FRANKLIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "${FRANKLIN_ROOT}/franklin/src/lib/ui.sh"

echo "════════════════════════════════════════════════════════════════════════════════"
echo "FRANKLIN CAMPFIRE UI DEMO"
echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

# Demo 1: Normal flow with successes
ui_header "Detecting platform"
ui_branch "Platform: macos (macos) on arm64"
ui_success "Platform detected"
ui_section_end

# Demo 2: Flow with command output
ui_header "Installing dependencies"
ui_branch "Found Homebrew at /opt/homebrew/bin"
ui_branch "Installing packages via Homebrew..."
echo "      ==> Downloading curl-8.17.0..." >&2
echo "      ==> Installing curl" >&2
ui_success "Dependencies installed"
ui_section_end

# Demo 3: Flow with warning
ui_header "Checking existing configuration"
ui_branch "Found existing .zshrc"
ui_branch "Found existing .zshenv"
ui_warning "Existing configuration will be backed up"
ui_success "Backup created at ~/.local/share/franklin/backups/2025-11-20_231045"
ui_section_end

# Demo 4: Flow with multiple successes
ui_header "Linking configuration files"
ui_success ".zshrc linked to Franklin template"
ui_success "Sheldon config linked"
ui_success "Starship config linked"
ui_section_end

# Demo 5: Final success message
ui_final_success "Franklin installation complete!"
echo "" >&2
echo "Next steps:" >&2
echo "  1. Restart your shell or run: exec zsh" >&2
echo "  2. Verify installation with: franklin doctor" >&2
echo "" >&2

echo "════════════════════════════════════════════════════════════════════════════════"
echo ""

# Demo 6: Error scenario (commented out since it exits)
echo "ERROR SCENARIO (not executed):" >&2
echo "⏺ Detecting platform" >&2
echo "  ⎿  ✗ Unsupported operating system: FreeBSD" >&2
echo "" >&2
echo "Installation failed. Franklin supports macOS, Debian, and RHEL-based systems." >&2
