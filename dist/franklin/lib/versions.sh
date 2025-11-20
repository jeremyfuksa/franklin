#!/bin/bash
# Centralized version pins for external dependencies.
#
# IMPORTANT: Check for updates before each Franklin release:
# - NVM: https://github.com/nvm-sh/nvm/releases
# - Antigen: https://github.com/zsh-users/antigen/releases
# - Update SHA256 checksum when updating NVM version

if [ -n "${FRANKLIN_VERSIONS_LOADED:-}" ]; then
  return 0 2>/dev/null || true
fi

# NVM (Node Version Manager) - v0.40.3 released 2025-04-23
FRANKLIN_NVM_VERSION="${FRANKLIN_NVM_VERSION:-v0.40.3}"
FRANKLIN_NVM_INSTALL_SHA256="${FRANKLIN_NVM_INSTALL_SHA256:-2d8359a64a3cb07c02389ad88ceecd43f2fa469c06104f92f98df5b6f315275f}"

# Antigen (Zsh plugin manager) - will be replaced by sheldon in 2.0
FRANKLIN_ANTIGEN_VERSION="${FRANKLIN_ANTIGEN_VERSION:-v2.2.3}"
FRANKLIN_ANTIGEN_URL="${FRANKLIN_ANTIGEN_URL:-https://git.io/antigen}"

FRANKLIN_VERSIONS_LOADED=1

export FRANKLIN_NVM_VERSION FRANKLIN_NVM_INSTALL_SHA256 FRANKLIN_ANTIGEN_VERSION FRANKLIN_ANTIGEN_URL FRANKLIN_VERSIONS_LOADED
