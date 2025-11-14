#!/bin/zsh
# franklin Configuration File
#
# Main shell configuration that sources all franklin libraries

# ============================================================================
# Core Setup
# ============================================================================

# Detect Franklin location from where this .zshrc actually lives
if [[ -L ~/.zshrc ]]; then
  # Follow symlink to find the repo location
  export FRANKLIN_CONFIG_DIR="$(cd "$(dirname "$(readlink ~/.zshrc)")" && pwd)"
else
  # Fallback if not a symlink (user copied file instead)
  export FRANKLIN_CONFIG_DIR="${FRANKLIN_CONFIG_DIR:-$HOME/.config/franklin}"
fi
export ZSH_CONFIG_DIR="$FRANKLIN_CONFIG_DIR"
export FRANKLIN_PLUGINS_DIR="${FRANKLIN_PLUGINS_DIR:-$FRANKLIN_CONFIG_DIR/lib}"

# User configuration (e.g., MOTD color)
if [ -f "$FRANKLIN_CONFIG_DIR/motd.env" ]; then
  source "$FRANKLIN_CONFIG_DIR/motd.env"
fi

: "${FRANKLIN_LOCAL_CONFIG:=${HOME}/.franklin.local.zsh}"
if [ -f "$FRANKLIN_LOCAL_CONFIG" ]; then
  source "$FRANKLIN_LOCAL_CONFIG"
fi

# Early platform detection
if [ -f "$FRANKLIN_PLUGINS_DIR/os_detect.zsh" ]; then
  source "$FRANKLIN_PLUGINS_DIR/os_detect.zsh"
fi

# ============================================================================
# Antigen Plugin Manager
# ============================================================================

# Initialize antigen if available
antigen_loaded=0
antigen_candidates=()

if command -v brew >/dev/null 2>&1; then
  brew_antigen_path="$(brew --prefix antigen 2>/dev/null)/share/antigen/antigen.zsh"
  if [ -f "$brew_antigen_path" ]; then
    antigen_candidates+=("$brew_antigen_path")
  fi
fi

antigen_candidates+=("$HOME/.antigen/antigen.zsh" "/usr/share/zsh-antigen/antigen.zsh")

for antigen_path in "${antigen_candidates[@]}"; do
  if [ -f "$antigen_path" ]; then
    source "$antigen_path"
    antigen_loaded=1
    break
  fi
done

unset antigen_candidates
unset brew_antigen_path antigen_path

if [ "$antigen_loaded" -eq 1 ] 2>/dev/null; then
  # Load plugins
  antigen bundle zsh-users/zsh-syntax-highlighting
  antigen bundle zsh-users/zsh-autosuggestions
  antigen bundle zsh-users/zsh-completions
  antigen bundle git
  antigen bundle history-substring-search
  antigen bundle colored-man-pages
  antigen bundle command-not-found

  # Apply antigen changes
  antigen apply
else
  echo "franklin: Antigen not found; skipping plugin initialization" >&2
fi

# ============================================================================
# Completion System
# ============================================================================

_franklin_init_completion() {
  autoload -Uz compinit 2>/dev/null || return
  : "${FRANKLIN_ZCOMP_CACHE:=$FRANKLIN_CONFIG_DIR/.zcompdump}"
  local cache_file="$FRANKLIN_ZCOMP_CACHE"
  local cache_dir="${cache_file:h}"
  if [ -n "$cache_dir" ] && [ ! -d "$cache_dir" ]; then
    mkdir -p "$cache_dir" 2>/dev/null || true
  fi

  local refresh_cache=1
  if [ -f "$cache_file" ]; then
    refresh_cache=0
    if zmodload zsh/stat 2>/dev/null; then
      local -a _fr_comp_stat
      if zstat -A _fr_comp_stat +mtime -- "$cache_file" 2>/dev/null; then
        if [[ -z "${EPOCHSECONDS+x}" ]]; then
          zmodload zsh/datetime 2>/dev/null || true
        fi
        local now=${EPOCHSECONDS:-$(date +%s)}
        local age=$(( now - ${_fr_comp_stat[1]} ))
        if (( age > 86400 )); then
          refresh_cache=1
        fi
      else
        refresh_cache=1
      fi
    else
      refresh_cache=1
    fi
  fi

  if [ "$refresh_cache" -eq 0 ]; then
    compinit -C -d "$cache_file" >/dev/null 2>&1 || compinit -i -d "$cache_file"
  else
    compinit -i -d "$cache_file"
  fi
}
_franklin_init_completion
unset -f _franklin_init_completion

# ============================================================================
# Shell Options
# ============================================================================

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=200000
SAVEHIST=200000

# History options
setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY

# Other options
setopt AUTO_CD
setopt CORRECT
setopt PROMPT_SUBST
setopt INTERACTIVE_COMMENTS

# ============================================================================
# Key Bindings
# ============================================================================

# Platform-specific keybindings
# macOS / Darwin terminals
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down



# ============================================================================
# Aliases
# ============================================================================

# macOS uses -G for color (requires CLICOLOR)
export CLICOLOR=1
export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd
alias ls='command ls -G'
alias ll='command ls -laG'
alias la='command ls -aG'
alias lh='command ls -lhG'


alias ..='cd ..'
alias ...='cd ../..'
alias ~='cd ~'

# Grep with colors
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# bat (cat with syntax highlighting)
if command -v bat >/dev/null 2>&1; then
  # macOS/Fedora: bat command available
  alias cat='bat --paging=never'
  alias bcat='bat'  # Original bat with paging
elif command -v batcat >/dev/null 2>&1; then
  # Debian/Ubuntu: batcat command (naming conflict)
  alias cat='batcat --paging=never'
  alias bat='batcat'
  alias bcat='batcat'
fi

# ============================================================================
# Starship Prompt
# ============================================================================

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# ============================================================================
# Notifications
# ============================================================================

if [ -f "$FRANKLIN_PLUGINS_DIR/notify.zsh" ]; then
  source "$FRANKLIN_PLUGINS_DIR/notify.zsh"
fi

# ============================================================================
# NVM (Node Version Manager)
# ============================================================================

if [ -f "$FRANKLIN_PLUGINS_DIR/nvm.zsh" ]; then
  source "$FRANKLIN_PLUGINS_DIR/nvm.zsh"
elif [ -s "$HOME/.nvm/nvm.sh" ]; then
  source "$HOME/.nvm/nvm.sh"
  [ -s "$HOME/.nvm/bash_completion" ] && source "$HOME/.nvm/bash_completion"
fi

# ============================================================================
# System Message of the Day (motd) Display
# ============================================================================

FRANKLIN_ENABLE_MOTD="${FRANKLIN_ENABLE_MOTD:-1}"
FRANKLIN_SHOW_MOTD_ON_LOGIN="${FRANKLIN_SHOW_MOTD_ON_LOGIN:-1}"
export FRANKLIN_ENABLE_MOTD FRANKLIN_SHOW_MOTD_ON_LOGIN

if [ "$FRANKLIN_ENABLE_MOTD" -eq 1 ]; then
  if [ -f "$FRANKLIN_PLUGINS_DIR/motd-helpers.zsh" ]; then
    source "$FRANKLIN_PLUGINS_DIR/motd-helpers.zsh"
  fi

  if [ -f "$FRANKLIN_PLUGINS_DIR/motd.zsh" ]; then
    source "$FRANKLIN_PLUGINS_DIR/motd.zsh"
    if [ "$FRANKLIN_SHOW_MOTD_ON_LOGIN" -eq 1 ] && command -v motd >/dev/null 2>&1; then
      motd
    fi
  fi
fi

# ============================================================================
# Functions
# ============================================================================

# cleanup-path: Remove duplicates and invalid entries from PATH
cleanup-path() {
  typeset -U path
  path=(${path:#*/.antigen/bundles/*})
  export PATH=${(j/:/)path}
}

# reload: Reload shell configuration
reload() {
  echo "Reloading shell configuration..."
  if command -v zsh >/dev/null 2>&1; then
    exec zsh
  else
    echo "Error: zsh not found in PATH" >&2
    return 1
  fi
}

# update-all: Update all components
update-all() {
  if [ -f "$ZSH_CONFIG_DIR/update-all.sh" ]; then
    bash "$ZSH_CONFIG_DIR/update-all.sh" "$@"
  else
    echo "update-all.sh not found"
    return 1
  fi
}

# ============================================================================
# PATH Cleanup
# ============================================================================

# Clean up PATH on shell startup (remove duplicates and invalid entries)
cleanup-path
