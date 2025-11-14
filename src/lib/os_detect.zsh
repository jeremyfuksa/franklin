#!/bin/sh
# Platform Detection & OS Abstraction (Zsh/Bash Wrapper)
#
# Detects the operating system family (macOS, Debian-based, Fedora) and
# Homebrew availability. This wrapper sources lib/os_detect.sh for compatibility
# with both zsh and bash.
#
# Usage:
#   source lib/os_detect.zsh [--verbose]
#
# Exported variables:
#   OS_FAMILY    - String: macos | debian | fedora
#   HAS_HOMEBREW - String: true | false
#
# Exit codes:
#   0 - Success (platform detected)
#   1 - Warning (fallback used, unknown platform defaulted to debian)
#   2 - Error (system error like permission denied)

# Get the directory where this script is located
# Compatible with both bash and zsh when sourced
if [ -n "$ZSH_VERSION" ]; then
  # Zsh syntax
  _script_dir="${0:a:h}"
elif [ -n "$BASH_VERSION" ]; then
  # Bash syntax
  _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  # Fallback for POSIX sh (when sourced, $0 might not work reliably)
  # Try to find ourselves relative to a known location
  _script_dir="$(dirname "$0")"
fi

# Source the POSIX implementation with arguments
# Eval the output to execute exports without printing them
eval "$("${_script_dir}/os_detect.sh" "$@")"
_exit_code=$?

# Export variables for the calling shell (already set by eval above)
export OS_FAMILY
export HAS_HOMEBREW

# Clean up temporary variable
unset _script_dir

return $_exit_code
