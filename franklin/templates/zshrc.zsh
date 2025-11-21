# Franklin .zshrc Template
# ========================
# A modern, cross-platform Zsh configuration

# --- Environment Setup ---
export FRANKLIN_ROOT="${HOME}/.local/share/franklin"
export FRANKLIN_CONFIG="${HOME}/.config/franklin"

# --- PATH Management ---
# Clean and deduplicate PATH, ensuring all required directories are present

# Function to deduplicate PATH
_franklin_dedupe_path() {
    local path_array=("${(s/:/)PATH}")
    local -A seen
    local new_path=""
    
    for dir in $path_array; do
        if [[ -z "${seen[$dir]}" && -d "$dir" ]]; then
            seen[$dir]=1
            if [[ -z "$new_path" ]]; then
                new_path="$dir"
            else
                new_path="$new_path:$dir"
            fi
        fi
    done
    
    echo "$new_path"
}

# Build clean PATH with required directories
_franklin_setup_path() {
    local new_path=""
    
    # Priority directories (checked in order)
    local priority_dirs=(
        "${FRANKLIN_ROOT}/venv/bin"
        "${HOME}/.local/bin"
    )
    
    # Platform-specific directories
    case "$(uname -s)" in
        Darwin)
            # macOS - add Homebrew paths
            if [ -d "/opt/homebrew/bin" ]; then
                priority_dirs+=("/opt/homebrew/bin" "/opt/homebrew/sbin")
            elif [ -d "/usr/local/bin" ]; then
                priority_dirs+=("/usr/local/bin" "/usr/local/sbin")
            fi
            ;;
    esac
    
    # Add priority directories first
    for dir in "${priority_dirs[@]}"; do
        if [ -d "$dir" ]; then
            if [[ -z "$new_path" ]]; then
                new_path="$dir"
            else
                new_path="$new_path:$dir"
            fi
        fi
    done
    
    # Append existing PATH
    if [[ -n "$PATH" ]]; then
        new_path="$new_path:$PATH"
    fi
    
    # Deduplicate and export
    export PATH="$(_franklin_dedupe_path)"
}

# Initialize PATH
_franklin_setup_path

# --- Platform Normalization ---
# Detect OS and set platform-specific variables
case "$(uname -s)" in
    Darwin)
        # macOS (BSD-based)
        export CLICOLOR=1
        export LSCOLORS="ExGxBxDxCxEgEdxbxgxcxd"
        alias ls="ls -G"
        alias grep="grep --color=auto"
        alias bat="bat"
        ;;
    Linux)
        # Linux (GNU-based)
        export LS_COLORS="di=1;34:ln=1;36:so=1;31:pi=1;33:ex=1;32:bd=1;34;46:cd=1;34;43:su=0;41:sg=0;46:tw=0;42:ow=0;43"
        alias ls="ls --color=auto"
        alias grep="grep --color=auto"

        # Debian/Ubuntu uses 'batcat' instead of 'bat'
        if command -v batcat >/dev/null 2>&1; then
            alias bat="batcat"
        fi
        ;;
esac

# --- Standard Aliases ---
alias ll="ls -lAh"
alias la="ls -A"
alias lh="ls -lh"
alias l="ls -CF"

# Navigation shortcuts
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias ~="cd ~"

# --- History Configuration ---
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=200000
SAVEHIST=200000

# History options
setopt APPEND_HISTORY          # Append to history file
setopt SHARE_HISTORY           # Share history across sessions
setopt HIST_IGNORE_DUPS        # Don't record duplicate commands
setopt HIST_IGNORE_SPACE       # Don't record commands starting with space
setopt HIST_REDUCE_BLANKS      # Remove superfluous blanks
setopt EXTENDED_HISTORY        # Record timestamp in history

# --- Completion System ---
autoload -Uz compinit
compinit

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Colored completion (different colors for dirs/files/etc)
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# --- Keybindings ---
# Use Emacs-style keybindings
bindkey -e

# Bind Up/Down to history substring search (if plugin loaded)
# This will be enhanced by the history-substring-search plugin
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search

# Home/End keys
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# Ctrl+Left/Right: Jump by word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Delete key
bindkey '^[[3~' delete-char

# --- Plugin Loading (Sheldon) ---
# Sheldon is a fast, modern plugin manager
if command -v sheldon >/dev/null 2>&1; then
    eval "$(sheldon source)"
fi

# --- Prompt (Starship) ---
# Starship is a cross-shell prompt
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# --- NVM Lazy Loading ---
# NVM is expensive to load on every shell startup, so we lazy-load it
# The first time you run 'nvm', 'node', 'npm', or 'npx', it will load NVM

export NVM_DIR="${HOME}/.nvm"

# Lazy-load function
_lazy_load_nvm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}

nvm() {
    _lazy_load_nvm
    nvm "$@"
}

node() {
    _lazy_load_nvm
    node "$@"
}

npm() {
    _lazy_load_nvm
    npm "$@"
}

npx() {
    _lazy_load_nvm
    npx "$@"
}

# --- UV (Python Package Manager) Lazy Loading ---
# Similar to NVM, lazy-load uv
if [ -f "${HOME}/.local/bin/uv" ]; then
    export PATH="${HOME}/.local/bin:${PATH}"
fi

# --- Local Overrides ---
# Load user's local customizations (if present)
[ -f "${HOME}/.franklin.local.zsh" ] && source "${HOME}/.franklin.local.zsh"

# --- MOTD (Message of the Day) ---
# Display the Campfire banner on new shells (interactive only)
if [[ -o interactive ]] && command -v franklin >/dev/null 2>&1; then
    franklin motd
fi
