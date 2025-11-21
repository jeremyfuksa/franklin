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

set -euo pipefail

# --- Configuration ---
FRANKLIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${HOME}/.local/share/franklin/backups/$(date +%Y-%m-%d_%H%M%S)"
CONFIG_DIR="${HOME}/.config/franklin"
CONFIG_FILE="${CONFIG_DIR}/config.env"
VENV_DIR="${HOME}/.local/share/franklin/venv"

# --- Campfire UI Functions (Bash) ---
# Mirror the Python Campfire UI library for consistent visual hierarchy
# All output goes to stderr to preserve stdout for machine-readable data

# Glyphs
GLYPH_ACTION="⏺"
GLYPH_BRANCH="⎿"
GLYPH_LOGIC="∴"
GLYPH_WAIT="✻"
GLYPH_SUCCESS="✔"
GLYPH_WARNING="⚠"
GLYPH_ERROR="✗"

# Colors (ANSI)
COLOR_ERROR="\033[38;2;191;97;106m"    # #bf616a
COLOR_SUCCESS="\033[38;2;163;190;140m"  # #a3be8c
COLOR_INFO="\033[38;2;136;192;208m"     # #88c0d0
COLOR_WARNING="\033[38;2;235;203;139m"  # #ebcb8b
COLOR_RESET="\033[0m"

# Check if we're in a TTY for color support
if [ -t 2 ]; then
    USE_COLOR=true
else
    USE_COLOR=false
fi

ui_header() {
    # ⏺ text
    echo "${GLYPH_ACTION} $*" >&2
}

ui_branch() {
    # ⎿  text (2-space indent to align under parent glyph)
    echo "${GLYPH_BRANCH}  $*" >&2
}

ui_logic() {
    # ∴ text
    echo "${GLYPH_LOGIC} $*" >&2
}

ui_section_end() {
    # Blank line for breathing room between sections
    echo "" >&2
}

ui_error() {
    # ⎿  ✗ text (in red, then exit)
    if [ "$USE_COLOR" = true ]; then
        echo -e "${GLYPH_BRANCH}  ${COLOR_ERROR}${GLYPH_ERROR} $*${COLOR_RESET}" >&2
    else
        echo "${GLYPH_BRANCH}  ${GLYPH_ERROR} $*" >&2
    fi
    exit 1
}

ui_success() {
    # ⎿  ✔ text (in green)
    if [ "$USE_COLOR" = true ]; then
        echo -e "${GLYPH_BRANCH}  ${COLOR_SUCCESS}${GLYPH_SUCCESS} $*${COLOR_RESET}" >&2
    else
        echo "${GLYPH_BRANCH}  ${GLYPH_SUCCESS} $*" >&2
    fi
}

ui_warning() {
    # ⎿  ⚠ text (in yellow)
    if [ "$USE_COLOR" = true ]; then
        echo -e "${GLYPH_BRANCH}  ${COLOR_WARNING}${GLYPH_WARNING} $*${COLOR_RESET}" >&2
    else
        echo "${GLYPH_BRANCH}  ${GLYPH_WARNING} $*" >&2
    fi
}

ui_final_success() {
    # ✔ text (standalone, no branch, in green)
    if [ "$USE_COLOR" = true ]; then
        echo -e "${COLOR_SUCCESS}${GLYPH_SUCCESS} $*${COLOR_RESET}" >&2
    else
        echo "${GLYPH_SUCCESS} $*" >&2
    fi
}

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
            case "$ID" in
                debian|ubuntu|pop|elementary|linuxmint|neon|kali|raspbian)
                    OS_FAMILY="debian"
                    OS_DISTRO="$ID"
                    ;;
                fedora|rhel|centos|rocky|almalinux|amzn)
                    OS_FAMILY="fedora"
                    OS_DISTRO="$ID"
                    ;;
                *)
                    ui_error "Unsupported Linux distribution: $ID"
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

# --- Color Display Helper ---
# Convert hex color to ANSI 24-bit color code and display a colored swatch
show_color() {
    local name="$1"
    local hex="$2"

    # Strip # from hex
    hex="${hex#\#}"

    # Convert hex to RGB
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    # ANSI 24-bit color: \033[38;2;R;G;Bm for foreground
    # Use echo -e to ensure escape sequences are interpreted
    # Display colored block characters as preview
    echo -e "  \033[38;2;${r};${g};${b}m████\033[0m  $(printf '%-15s' "$name") (#${hex})" >&2
}

# --- Campfire Color Selection ---
ui_header "Configuring MOTD color"

# Default color
MOTD_COLOR="#607a97"  # Cello
MOTD_COLOR_NAME="Cello"

# Interactive mode if TTY
if [ -t 0 ]; then
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
fi

# Save color to config
mkdir -p "$CONFIG_DIR"
{
    echo "MOTD_COLOR_NAME=\"${MOTD_COLOR_NAME}\""
    echo "MOTD_COLOR=\"${MOTD_COLOR}\""
} > "$CONFIG_FILE"
ui_success "MOTD color set to $MOTD_COLOR_NAME ($MOTD_COLOR)"
ui_section_end

# --- Install Dependencies ---
ui_header "Installing dependencies"

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
        brew install curl git zsh python3 bat sheldon starship 2>&1 | sed 's/^/  /' >&2 || true
        ;;

    debian)
        ui_branch "Installing packages via apt..."
        sudo apt-get update -qq 2>&1 | sed 's/^/  /' >&2
        sudo apt-get install -y -qq curl git zsh python3 python3-venv python3-pip batcat 2>&1 | sed 's/^/  /' >&2 || true

        # Install Sheldon (not in apt)
        if ! command -v sheldon >/dev/null 2>&1; then
            ui_branch "Installing Sheldon..."
            curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh | bash -s -- --repo rossmacarthur/sheldon --to ~/.local/bin 2>&1 | sed 's/^/  /' >&2
        fi

        # Install Starship (not in apt)
        if ! command -v starship >/dev/null 2>&1; then
            ui_branch "Installing Starship..."
            curl -fsSL https://starship.rs/install.sh | sh -s -- --yes 2>&1 | sed 's/^/  /' >&2
        fi
        ;;

    fedora)
        ui_branch "Installing packages via dnf..."
        sudo dnf install -y curl git zsh python3 python3-pip bat 2>&1 | sed 's/^/  /' >&2 || true

        # Install Sheldon (not in dnf)
        if ! command -v sheldon >/dev/null 2>&1; then
            ui_branch "Installing Sheldon..."
            curl --proto '=https' -fLsS https://rossmacarthur.github.io/install/crate.sh | bash -s -- --repo rossmacarthur/sheldon --to ~/.local/bin 2>&1 | sed 's/^/  /' >&2
        fi

        # Install Starship (not in dnf)
        if ! command -v starship >/dev/null 2>&1; then
            ui_branch "Installing Starship..."
            curl -fsSL https://starship.rs/install.sh | sh -s -- --yes 2>&1 | sed 's/^/  /' >&2
        fi
        ;;
esac

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

# Link Sheldon config
SHELDON_CONFIG_DIR="${HOME}/.config/sheldon"
mkdir -p "$SHELDON_CONFIG_DIR"
ln -sf "${FRANKLIN_ROOT}/config/plugins.toml" "${SHELDON_CONFIG_DIR}/plugins.toml"
ui_success "Sheldon config linked"

# Link Starship config
STARSHIP_CONFIG="${HOME}/.config/starship.toml"
ln -sf "${FRANKLIN_ROOT}/config/starship.toml" "$STARSHIP_CONFIG"
ui_success "Starship config linked"
ui_section_end

# --- Post-Install Instructions ---
ui_final_success "Franklin installation complete!"
echo "" >&2
echo "Next steps:" >&2
echo "  1. Add Franklin to your PATH by adding this to your .zshrc:" >&2
echo "     export PATH=\"${VENV_DIR}/bin:\$PATH\"" >&2
echo "" >&2
echo "  2. Restart your shell or run: exec zsh" >&2
echo "" >&2
echo "  3. Verify installation with: franklin doctor" >&2
echo "" >&2
