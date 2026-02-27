#!/usr/bin/env bash
# Franklin Installer (Stage 2)
#
# Purpose: Configure the Franklin environment after bootstrap
#
# This script:
# 1. Detects the platform (macOS/Debian/RHEL) and architecture
# 2. Backs up existing Zsh configuration files
# 3. Prompts for Campfire color selection (interactive mode)
# 4. Installs dependencies via the appropriate package manager
# 5. Sets up Sheldon, Starship, and NVM
# 6. Symlinks ~/.zshrc to the Franklin template
# 7. Installs the Franklin CLI via Python
#
# Flags:
#   --non-interactive   Skip interactive prompts (use defaults)
#   --color NAME        Pre-select MOTD color (e.g., Cello, Terracotta)

set -euo pipefail

# --- Configuration ---
FRANKLIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
BACKUP_DIR="${HOME}/.local/share/franklin/backups/$(date +%Y-%m-%d_%H%M%S)"
CONFIG_DIR="${HOME}/.config/franklin"
CONFIG_FILE="${CONFIG_DIR}/config.env"
VENV_DIR="${HOME}/.local/share/franklin/venv"

# --- Parse Arguments ---
NON_INTERACTIVE=false
PRESET_COLOR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --non-interactive|-y)
            NON_INTERACTIVE=true
            shift
            ;;
        --color)
            if [ $# -lt 2 ]; then
                echo "ERROR: --color requires an argument" >&2
                exit 1
            fi
            PRESET_COLOR="$2"
            shift 2
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            echo "Usage: install.sh [--non-interactive] [--color NAME]" >&2
            exit 1
            ;;
    esac
done

# --- Source shared UI library ---
source "${FRANKLIN_ROOT}/src/lib/ui.sh"

# --- Platform Detection ---
ui_header "Detecting platform"

OS_FAMILY=""
OS_DISTRO=""
OS_ARCH="$(uname -m)"

case "$(uname -s)" in
    Darwin)
        OS_FAMILY="macos"
        OS_DISTRO="macos"
        ;;
    Linux)
        # Parse /etc/os-release
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "${ID:-}" in
                debian|ubuntu|pop|elementary|linuxmint|neon|kali|raspbian)
                    OS_FAMILY="debian"
                    OS_DISTRO="$ID"
                    ;;
                fedora|rhel|centos|rocky|almalinux|amzn)
                    OS_FAMILY="fedora"
                    OS_DISTRO="$ID"
                    ;;
                *)
                    ui_error "Unsupported Linux distribution: ${ID:-unknown}"
                    ;;
            esac
        else
            ui_error "Cannot determine Linux distribution (/etc/os-release not found)"
        fi
        ;;
    *)
        ui_error "Unsupported operating system: $(uname -s)"
        ;;
esac

ui_success "Platform: $OS_FAMILY ($OS_DISTRO) on $OS_ARCH"
ui_section_end

# --- Backup Existing Configuration ---
ui_header "Creating backup of existing configuration"

mkdir -p "$BACKUP_DIR"

for file in .zshrc .zprofile .zshenv; do
    filepath="${HOME}/${file}"
    if [ -f "$filepath" ] && [ ! -L "$filepath" ]; then
        ui_branch "Found $file, backing up to $BACKUP_DIR"
        mv "$filepath" "$BACKUP_DIR/"
    fi
done

ui_success "Backup complete"
ui_section_end

# --- Campfire Color Selection ---
ui_header "Configuring MOTD color"

# Default color
MOTD_COLOR="#607a97"  # Cello
MOTD_COLOR_NAME="Cello"

# Color lookup table (assign separately to avoid unbound variable with set -u)
declare -A COLOR_MAP
COLOR_MAP["Cello"]="#607a97"
COLOR_MAP["Terracotta"]="#b87b6a"
COLOR_MAP["Black Rock"]="#747b8a"
COLOR_MAP["Sage"]="#8fb14b"
COLOR_MAP["Golden Amber"]="#f9c574"
COLOR_MAP["Flamingo"]="#e75351"
COLOR_MAP["Blue Calx"]="#b8c5d9"

# Handle preset color from --color flag
if [ -n "$PRESET_COLOR" ]; then
    if [ -n "${COLOR_MAP[$PRESET_COLOR]:-}" ]; then
        MOTD_COLOR="${COLOR_MAP[$PRESET_COLOR]}"
        MOTD_COLOR_NAME="$PRESET_COLOR"
        ui_success "Using preset color: $MOTD_COLOR_NAME ($MOTD_COLOR)"
    elif [[ "$PRESET_COLOR" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
        MOTD_COLOR="$PRESET_COLOR"
        MOTD_COLOR_NAME="custom"
        ui_success "Using custom color: $MOTD_COLOR"
    else
        ui_warning "Invalid color '$PRESET_COLOR', using default (Cello)"
    fi
# Interactive mode if TTY and not --non-interactive
elif [ -t 0 ] && [ "$NON_INTERACTIVE" = false ]; then
    echo "" >&2
    echo "Select your Campfire color for the MOTD banner:" >&2
    echo "" >&2
    show_color "1) Cello" "#607a97"
    show_color "2) Terracotta" "#b87b6a"
    show_color "3) Black Rock" "#747b8a"
    show_color "4) Sage" "#8fb14b"
    show_color "5) Golden Amber" "#f9c574"
    show_color "6) Flamingo" "#e75351"
    show_color "7) Blue Calx" "#b8c5d9"
    echo "  8) Custom (enter hex code)" >&2
    echo "" >&2

    read -r -p "Enter choice [1-8, default: 1]: " color_choice

    case "${color_choice:-1}" in
        1) MOTD_COLOR="#607a97"; MOTD_COLOR_NAME="Cello" ;;
        2) MOTD_COLOR="#b87b6a"; MOTD_COLOR_NAME="Terracotta" ;;
        3) MOTD_COLOR="#747b8a"; MOTD_COLOR_NAME="Black Rock" ;;
        4) MOTD_COLOR="#8fb14b"; MOTD_COLOR_NAME="Sage" ;;
        5) MOTD_COLOR="#f9c574"; MOTD_COLOR_NAME="Golden Amber" ;;
        6) MOTD_COLOR="#e75351"; MOTD_COLOR_NAME="Flamingo" ;;
        7) MOTD_COLOR="#b8c5d9"; MOTD_COLOR_NAME="Blue Calx" ;;
        8)
            read -r -p "Enter hex code (#rrggbb): " custom_color
            # Basic validation
            if [[ "$custom_color" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
                MOTD_COLOR="$custom_color"
                MOTD_COLOR_NAME="custom"
            else
                ui_warning "Invalid hex code, using default (Cello)"
            fi
            ;;
        *)
            ui_warning "Invalid choice, using default (Cello)"
            ;;
    esac
else
    ui_branch "Non-interactive mode, using default color (Cello)"
fi

# Save color to config
mkdir -p "$CONFIG_DIR"
{
    echo "# Franklin Configuration"
    echo "# Generated: $(date)"
    echo ""
    echo "# MOTD Color (Campfire palette)"
    echo "MOTD_COLOR_NAME=\"${MOTD_COLOR_NAME}\""
    echo "MOTD_COLOR=\"${MOTD_COLOR}\""
    echo ""
    echo "# Monitored Services (comma-separated list)"
    echo "# Example: MONITORED_SERVICES=\"nginx,postgresql,redis\""
    echo "# MONITORED_SERVICES=\"\""
} > "$CONFIG_FILE"
ui_success "MOTD color set to $MOTD_COLOR_NAME ($MOTD_COLOR)"
ui_section_end

# --- Install Dependencies ---
ui_header "Installing dependencies"

INSTALL_FAILED=false

case "$OS_FAMILY" in
    macos)
        # Check for Homebrew and add to PATH if needed
        if ! command -v brew >/dev/null 2>&1; then
            # Check common Homebrew locations
            if [ -x "/opt/homebrew/bin/brew" ]; then
                # Apple Silicon
                export PATH="/opt/homebrew/bin:$PATH"
                ui_branch "Found Homebrew at /opt/homebrew/bin"
            elif [ -x "/usr/local/bin/brew" ]; then
                # Intel Mac
                export PATH="/usr/local/bin:$PATH"
                ui_branch "Found Homebrew at /usr/local/bin"
            else
                ui_error "Homebrew is required on macOS but not found. Please install it first: https://brew.sh"
            fi
        fi

        # Install dependencies
        ui_branch "Installing packages via Homebrew..."
        if ! brew install curl git zsh python3 bat sheldon starship 2>&1 | sed 's/^/      /' >&2; then
            ui_error_noexit "Some Homebrew packages failed to install"
            INSTALL_FAILED=true
        fi
        ;;

    debian)
        ui_branch "Installing packages via apt..."
        if ! sudo apt-get update -qq 2>&1 | sed 's/^/      /' >&2; then
            ui_error_noexit "apt-get update failed"
            INSTALL_FAILED=true
        fi
        if ! sudo apt-get install -y -qq curl git zsh python3 python3-venv python3-pip bat 2>&1 | sed 's/^/      /' >&2; then
            ui_error_noexit "Some apt packages failed to install"
            INSTALL_FAILED=true
        fi

        # Install Sheldon (not in apt)
        if ! command -v sheldon >/dev/null 2>&1; then
            ui_branch "Installing Sheldon..."
            if ! curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh | bash -s -- --repo rossmacarthur/sheldon --to ~/.local/bin 2>&1 | sed 's/^/      /' >&2; then
                ui_error_noexit "Sheldon installation failed"
                INSTALL_FAILED=true
            fi
        fi

        # Install Starship (not in apt)
        if ! command -v starship >/dev/null 2>&1; then
            ui_branch "Installing Starship..."
            if ! curl -fsSL https://starship.rs/install.sh | sh -s -- --yes 2>&1 | sed 's/^/      /' >&2; then
                ui_error_noexit "Starship installation failed"
                INSTALL_FAILED=true
            fi
        fi
        ;;

    fedora)
        ui_branch "Installing packages via dnf..."
        if ! sudo dnf install -y curl git zsh python3 python3-pip bat 2>&1 | sed 's/^/      /' >&2; then
            ui_error_noexit "Some dnf packages failed to install"
            INSTALL_FAILED=true
        fi

        # Install Sheldon (not in dnf)
        if ! command -v sheldon >/dev/null 2>&1; then
            ui_branch "Installing Sheldon..."
            if ! curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh | bash -s -- --repo rossmacarthur/sheldon --to ~/.local/bin 2>&1 | sed 's/^/      /' >&2; then
                ui_error_noexit "Sheldon installation failed"
                INSTALL_FAILED=true
            fi
        fi

        # Install Starship (not in dnf)
        if ! command -v starship >/dev/null 2>&1; then
            ui_branch "Installing Starship..."
            if ! curl -fsSL https://starship.rs/install.sh | sh -s -- --yes 2>&1 | sed 's/^/      /' >&2; then
                ui_error_noexit "Starship installation failed"
                INSTALL_FAILED=true
            fi
        fi
        ;;
esac

if [ "$INSTALL_FAILED" = true ]; then
    ui_warning "Some dependencies failed to install. Continuing with available tools..."
fi

ui_success "Dependencies installed"
ui_section_end

# --- Install NVM ---
ui_header "Setting up NVM"

NVM_DIR="${HOME}/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    ui_branch "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash 2>&1 | sed 's/^/  /' >&2
else
    ui_branch "NVM already installed"
fi

ui_success "NVM ready"
ui_section_end

# --- Set up Python Virtual Environment ---
ui_header "Setting up Python virtual environment"

if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    ui_success "Virtual environment created at $VENV_DIR"
else
    ui_branch "Virtual environment already exists"
fi

# --- Install Franklin CLI ---
ui_header "Installing Franklin CLI"

"$VENV_DIR/bin/pip" install --quiet -e "$FRANKLIN_ROOT" 2>&1 | sed 's/^/  /' >&2 || \
    ui_warning "Failed to install Franklin CLI (non-fatal)"

ui_success "Franklin CLI installed"
ui_section_end

# --- Symlink Configuration Files ---
ui_header "Linking configuration files"

# Link .zshrc
ZSHRC_TARGET="${FRANKLIN_ROOT}/templates/zshrc.zsh"
ZSHRC_LINK="${HOME}/.zshrc"

if [ -L "$ZSHRC_LINK" ]; then
    ui_branch "Removing existing .zshrc symlink"
    rm "$ZSHRC_LINK"
fi

ln -sf "$ZSHRC_TARGET" "$ZSHRC_LINK"
ui_success ".zshrc linked to Franklin template"

# Create local overrides stub if it does not exist
LOCAL_CONFIG_PATH="${FRANKLIN_LOCAL_CONFIG:-${HOME}/.franklin.local.zsh}"
if [ ! -f "$LOCAL_CONFIG_PATH" ]; then
    ui_branch "Creating local overrides config at $LOCAL_CONFIG_PATH"
    cat > "$LOCAL_CONFIG_PATH" <<'EOF'
# Franklin local overrides
# ------------------------
# This file is sourced at the end of Franklin's .zshrc to let you customize
# your shell without touching the managed template.

# PATH / Node / npm
# -----------------
# Example: pin a specific NVM-managed Node version on PATH at login.
# Uncomment and adjust the version to match your system:
# export PATH="$HOME/.nvm/versions/node/v18.18.0/bin:$PATH"

# MOTD (Message of the Day)
# -------------------------
# Enable/disable the Franklin MOTD banner on login:
# export FRANKLIN_SHOW_MOTD=1   # Set to 0 to disable

# To track services in the MOTD (e.g., nginx, postgresql, meshtasticd):
# Services MUST be added to ~/.config/franklin/config.env, NOT here.
# Edit ~/.config/franklin/config.env and add (comma-separated):
#   MONITORED_SERVICES="nginx,postgresql,meshtasticd"
# Services will only appear if they are running (systemctl is-active)

# Updates
# -------
# Control the default mode and timeout for update-all.sh:
# export FRANKLIN_UPDATE_MODE="auto"   # quiet | auto | verbose
# export FRANKLIN_UPDATE_TIMEOUT=600   # seconds

# Backups
# -------
# Override where Franklin stores configuration backups:
# export FRANKLIN_BACKUP_DIR="$HOME/.local/share/franklin/backups"

# Custom aliases and functions
# ----------------------------
# Put any aliases or functions you want to keep private below.
# Example:
# alias gs="git status -sb"
EOF
else
    ui_branch "Local overrides config already exists at $LOCAL_CONFIG_PATH"
fi

# Link Sheldon config
SHELDON_CONFIG_DIR="${HOME}/.config/sheldon"
mkdir -p "$SHELDON_CONFIG_DIR"
ln -sf "${FRANKLIN_ROOT}/config/plugins.toml" "${SHELDON_CONFIG_DIR}/plugins.toml"
ui_success "Sheldon config linked"

# Download Sheldon plugins
if command -v sheldon >/dev/null 2>&1; then
    ui_branch "Downloading Sheldon plugins..."
    sheldon lock --update 2>&1 | sed 's/^/      /' >&2 || ui_warning "Failed to download some plugins"
    ui_success "Sheldon plugins downloaded"
else
    ui_warning "Sheldon not found, skipping plugin download"
fi

# Link Starship config
STARSHIP_CONFIG="${HOME}/.config/starship.toml"
ln -sf "${FRANKLIN_ROOT}/config/starship.toml" "$STARSHIP_CONFIG"
ui_success "Starship config linked"
ui_section_end

# --- Post-Install Instructions ---
ui_final_success "Franklin installation complete!"
echo "" >&2
echo "Next steps:" >&2
echo "  1. Add Franklin to your PATH by adding this to your .zshrc (optional if you're using the Franklin .zshrc template):" >&2
echo "     export PATH=\"${VENV_DIR}/bin:\$PATH\"" >&2
echo "" >&2
echo "  2. Restart your shell or run: exec zsh" >&2
echo "" >&2
echo "  3. Verify installation with: franklin doctor" >&2
echo "" >&2
