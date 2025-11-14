#!/bin/zsh
# NVM (Node Version Manager) Integration
#
# Loads NVM to ensure npm global packages are available

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [ -s "$NVM_DIR/nvm.sh" ]; then
  # Load NVM
  source "$NVM_DIR/nvm.sh"
  
  # Load bash completion if available
  if [ -s "$NVM_DIR/bash_completion" ]; then
    source "$NVM_DIR/bash_completion"
  fi
fi
