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
# 5. Sets up Sheldon, Starship, and mise
# 6. Symlinks ~/.zshrc to the Franklin template
# 7. Installs the Franklin CLI via Python
#
# Flags:
#   --non-interactive   Skip interactive prompts (install everything by default,
#                       use the default MOTD color). Opt out of specific steps
#                       with the --no-* flags below.
#   --color NAME        Pre-select MOTD color (e.g., Cello, Terracotta)
#   --with-claude       Install Claude Code even in interactive mode (no prompt)
#   --no-claude         Skip Claude Code installation
#   --no-chsh           Don't change the user's default login shell to zsh

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
CLAUDE_CHOICE=""  # "", "yes", or "no"
CHSH_ENABLED=true

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
        --with-claude)
            CLAUDE_CHOICE="yes"
            shift
            ;;
        --no-claude)
            CLAUDE_CHOICE="no"
            shift
            ;;
        --no-chsh)
            CHSH_ENABLED=false
            shift
            ;;
        *)
            echo "ERROR: Unknown argument: $1" >&2
            echo "Usage: install.sh [--non-interactive] [--color NAME] [--with-claude|--no-claude] [--no-chsh]" >&2
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
# Tracks whether the user actively chose the color (via --color or the
# interactive picker) vs. silently got the default in non-interactive mode.
# The post-install summary uses this to nudge non-interactive users toward
# `franklin config --color <name>` so they don't miss that they're on default.
COLOR_WAS_DEFAULTED=false

# Handle preset color from --color flag. Accepts Title Case ("Mauve Earth"),
# lowercase ("mauve earth"), and kebab-case ("mauve-earth") forms for any
# Campfire color name. Hex codes (#rrggbb) pass through as custom.
if [ -n "$PRESET_COLOR" ]; then
    # Normalize: lowercase, turn -/_ into spaces, collapse whitespace.
    # Note: put '-' at the end of the tr set so it isn't parsed as a flag.
    PRESET_COLOR_NORM="$(printf '%s' "$PRESET_COLOR" | tr '[:upper:]' '[:lower:]' | tr '_-' '  ' | xargs)"
    PRESET_MATCHED=true
    case "$PRESET_COLOR_NORM" in
        cello)         MOTD_COLOR="#607a97"; MOTD_COLOR_NAME="Cello" ;;
        terracotta)    MOTD_COLOR="#b87b6a"; MOTD_COLOR_NAME="Terracotta" ;;
        "black rock")  MOTD_COLOR="#747b8a"; MOTD_COLOR_NAME="Black Rock" ;;
        sage)          MOTD_COLOR="#8fb14b"; MOTD_COLOR_NAME="Sage" ;;
        "golden amber") MOTD_COLOR="#f9c574"; MOTD_COLOR_NAME="Golden Amber" ;;
        flamingo)      MOTD_COLOR="#e75351"; MOTD_COLOR_NAME="Flamingo" ;;
        "blue calx")   MOTD_COLOR="#b8c5d9"; MOTD_COLOR_NAME="Blue Calx" ;;
        clay)          MOTD_COLOR="#c89c8d"; MOTD_COLOR_NAME="Clay" ;;
        ember)         MOTD_COLOR="#d97706"; MOTD_COLOR_NAME="Ember" ;;
        hay)           MOTD_COLOR="#d4b86a"; MOTD_COLOR_NAME="Hay" ;;
        moss)          MOTD_COLOR="#5a6f2d"; MOTD_COLOR_NAME="Moss" ;;
        pine)          MOTD_COLOR="#4a7c7e"; MOTD_COLOR_NAME="Pine" ;;
        dusk)          MOTD_COLOR="#8b7a9f"; MOTD_COLOR_NAME="Dusk" ;;
        "mauve earth") MOTD_COLOR="#9b6b7f"; MOTD_COLOR_NAME="Mauve Earth" ;;
        stone)         MOTD_COLOR="#747b8a"; MOTD_COLOR_NAME="Stone" ;;
        *)
            PRESET_MATCHED=false
            if [[ "$PRESET_COLOR" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
                MOTD_COLOR="$PRESET_COLOR"
                MOTD_COLOR_NAME="custom"
                ui_success "Using custom color: $MOTD_COLOR"
            else
                ui_warning "Invalid color '$PRESET_COLOR', using default (Cello)"
            fi
            ;;
    esac
    if [ "$PRESET_MATCHED" = true ]; then
        ui_success "Using preset color: $MOTD_COLOR_NAME ($MOTD_COLOR)"
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
    COLOR_WAS_DEFAULTED=true
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
        if ! brew install curl git zsh python3 bat eza sheldon starship 2>&1 | sed 's/^/      /' >&2; then
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

        # Install eza (best-effort; only in apt on Ubuntu 24.04+ / Debian 13+)
        if ! command -v eza >/dev/null 2>&1; then
            ui_branch "Installing eza..."
            if sudo apt-get install -y -qq eza 2>&1 | sed 's/^/      /' >&2; then
                :
            else
                ui_warning "eza not available via apt on this release; ls aliases will fall back to plain ls (install manually from https://github.com/eza-community/eza to enable)"
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

        # Install eza (best-effort; in dnf on Fedora 38+, may be absent on older RHEL-likes)
        if ! command -v eza >/dev/null 2>&1; then
            ui_branch "Installing eza..."
            if sudo dnf install -y -q eza 2>&1 | sed 's/^/      /' >&2; then
                :
            else
                ui_warning "eza not available via dnf on this release; ls aliases will fall back to plain ls (install manually from https://github.com/eza-community/eza to enable)"
            fi
        fi
        ;;
esac

if [ "$INSTALL_FAILED" = true ]; then
    ui_warning "Some dependencies failed to install. Continuing with available tools..."
fi

ui_success "Dependencies installed"
ui_section_end

# --- Install mise ---
ui_header "Setting up mise"

# https://mise.run installs the binary at ~/.local/bin/mise by default.
# Ensure ~/.local/bin is on PATH for the remainder of this installer so
# subsequent `mise` invocations resolve even on shells that didn't already
# include it (common on macOS).
case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) export PATH="${HOME}/.local/bin:${PATH}" ;;
esac

if ! command -v mise >/dev/null 2>&1; then
    ui_branch "Installing mise..."
    if ! curl -fsSL https://mise.run | sh 2>&1 | sed 's/^/  /' >&2; then
        ui_error_noexit "mise installer failed"
        INSTALL_FAILED=true
    fi
else
    ui_branch "mise already installed"
fi

# Resolve mise binary path (works even if PATH cache is stale)
MISE_BIN=""
if command -v mise >/dev/null 2>&1; then
    MISE_BIN="$(command -v mise)"
elif [ -x "${HOME}/.local/bin/mise" ]; then
    MISE_BIN="${HOME}/.local/bin/mise"
fi

# Link mise config
MISE_CONFIG_SRC="${FRANKLIN_ROOT}/config/mise.toml"
MISE_CONFIG_LINK="${HOME}/.config/mise/config.toml"
mkdir -p "$(dirname "$MISE_CONFIG_LINK")"
if [ -f "$MISE_CONFIG_SRC" ]; then
    ln -sf "$MISE_CONFIG_SRC" "$MISE_CONFIG_LINK"
    ui_branch "Linked mise config"
fi

# Install managed runtimes (Node LTS + Python latest)
if [ -n "$MISE_BIN" ]; then
    ui_branch "Installing runtimes via mise (Node LTS, Python latest)..."
    if ! "$MISE_BIN" install 2>&1 | sed 's/^/  /' >&2; then
        ui_error_noexit "mise failed to install one or more runtimes (see output above)"
        INSTALL_FAILED=true
    fi
else
    ui_error_noexit "mise binary not found after install; skipping runtime setup"
    INSTALL_FAILED=true
fi

ui_success "mise ready"
ui_section_end

# --- Install Claude Code ---
ui_header "Claude Code"

# Decision order:
#   1. Already installed -> skip.
#   2. --no-claude -> skip.
#   3. --with-claude -> install without prompting.
#   4. Interactive TTY -> prompt (default: yes).
#   5. Non-interactive (no flag) -> install by default. Non-interactive means
#      "install everything"; use --no-claude to opt out.
if command -v claude >/dev/null 2>&1; then
    ui_branch "Claude Code already installed, skipping"
    CLAUDE_INSTALL=false
elif [ "$CLAUDE_CHOICE" = "no" ]; then
    ui_branch "Skipping Claude Code install (--no-claude)"
    CLAUDE_INSTALL=false
elif [ "$CLAUDE_CHOICE" = "yes" ]; then
    CLAUDE_INSTALL=true
elif [ -t 0 ] && [ "$NON_INTERACTIVE" = false ]; then
    echo "" >&2
    echo "Claude Code is Anthropic's official CLI for Claude." >&2
    echo "It installs to ~/.local/bin/claude and is kept up to date automatically." >&2
    echo "" >&2
    read -r -p "Install Claude Code now? [Y/n]: " claude_reply
    case "${claude_reply:-Y}" in
        n|N|no|NO) CLAUDE_INSTALL=false ;;
        *)         CLAUDE_INSTALL=true ;;
    esac
else
    ui_branch "Non-interactive mode: installing Claude Code by default (use --no-claude to skip)"
    CLAUDE_INSTALL=true
fi

if [ "${CLAUDE_INSTALL:-false}" = true ]; then
    ui_branch "Installing Claude Code via native installer..."
    if ! curl -fsSL https://claude.ai/install.sh | bash 2>&1 | sed 's/^/  /' >&2; then
        ui_error_noexit "Claude Code installer failed (non-fatal, rerun install.sh later)"
    else
        ui_success "Claude Code installed"
    fi
fi

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
# mise manages Node and Python versions globally via ~/.config/mise/config.toml.
# To pin a project-local version, create a .mise.toml in the project directory.

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

# --- Set zsh as the default login shell ---
# Without this, SSH sessions and new terminals will still land in whatever
# shell was the default (bash on most Linux distros), meaning the Franklin
# .zshrc never gets sourced. Opt out with --no-chsh.
ui_header "Setting zsh as the default login shell"

CHSH_CHANGED=false
CHSH_SKIPPED_REASON=""

_install_ensure_zsh_in_shells() {
    local zsh_path="$1"
    # /etc/shells exists on every supported OS; if the path is already there
    # we don't need sudo.
    if [ -f /etc/shells ] && grep -Fxq "$zsh_path" /etc/shells; then
        return 0
    fi
    ui_branch "Registering $zsh_path in /etc/shells..."
    if echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

if [ "$CHSH_ENABLED" != true ]; then
    CHSH_SKIPPED_REASON="--no-chsh flag was passed"
elif ! command -v zsh >/dev/null 2>&1; then
    CHSH_SKIPPED_REASON="zsh is not on PATH (dependency install may have failed)"
elif ! command -v chsh >/dev/null 2>&1; then
    CHSH_SKIPPED_REASON="chsh is not available on this system"
else
    ZSH_PATH="$(command -v zsh)"
    CURRENT_SHELL="${SHELL:-}"

    if [ "$CURRENT_SHELL" = "$ZSH_PATH" ]; then
        ui_branch "zsh is already the default shell ($ZSH_PATH)"
    else
        if _install_ensure_zsh_in_shells "$ZSH_PATH"; then
            # chsh prompts for the user's password via PAM. When install.sh
            # is launched through `curl | bash`, stdin is the pipe so the
            # prompt can't read; redirecting from /dev/tty works around that
            # in interactive SSH / terminal sessions. If /dev/tty isn't
            # available (cron, systemd unit, etc.), skip.
            if [ ! -c /dev/tty ]; then
                CHSH_SKIPPED_REASON="no controlling TTY for chsh password prompt"
            else
                ui_branch "Changing default shell to $ZSH_PATH..."
                if chsh -s "$ZSH_PATH" </dev/tty 2>&1 | sed 's/^/      /' >&2; then
                    CHSH_CHANGED=true
                else
                    ui_warning "chsh failed. You can finish the change manually: chsh -s $ZSH_PATH"
                    CHSH_SKIPPED_REASON="chsh invocation failed"
                fi
            fi
        else
            ui_warning "Could not register $ZSH_PATH in /etc/shells (sudo prompt may have been declined)"
            CHSH_SKIPPED_REASON="zsh is not in /etc/shells"
        fi
    fi
fi

if [ "$CHSH_CHANGED" = true ]; then
    ui_success "Default shell set to zsh (log out and back in for it to take effect)"
elif [ -n "$CHSH_SKIPPED_REASON" ]; then
    ui_warning "Did not change default shell: $CHSH_SKIPPED_REASON"
fi
ui_section_end

# --- Post-Install Instructions ---
ui_final_success "Franklin installation complete!"
echo "" >&2
echo "Next steps:" >&2
if [ "$CHSH_CHANGED" = true ]; then
    echo "  1. Log out and back in (or open a new terminal) so zsh becomes your login shell." >&2
    echo "     For this session, run: exec zsh" >&2
else
    echo "  1. Restart your shell or run: exec zsh" >&2
    echo "     To also make zsh your default shell: chsh -s \"$(command -v zsh 2>/dev/null || echo /usr/bin/zsh)\"" >&2
fi
echo "" >&2
echo "  2. Verify installation with: franklin doctor" >&2
echo "" >&2

# MOTD color nudge: if the non-interactive path silently defaulted to Cello,
# tell the user loudly so they don't miss that they can personalize it.
if [ "$COLOR_WAS_DEFAULTED" = true ]; then
    echo "  3. Your MOTD banner color is set to the default (Cello). Pick your own:" >&2
    echo "     franklin config --color <name>   # clay, ember, sage, flamingo, mauve-earth, ..." >&2
    echo "     (14 Campfire colors available; see README or run 'franklin config' for the picker)" >&2
    echo "" >&2
fi
