#!/bin/sh
# Platform Detection & OS Abstraction
#
# Detects the operating system family (macOS, Ubuntu, Debian, Fedora) and
# Homebrew availability. Exports OS_FAMILY and HAS_HOMEBREW variables.
#
# Usage:
#   source lib/os_detect.sh [--verbose] [--json]
#   lib/os_detect.sh --json
#
# Exported variables:
#   OS_FAMILY    - String: macos | debian | fedora
#   HAS_HOMEBREW - String: true | false
#
# Exit codes:
#   0 - Success (platform detected)
#   1 - Warning (reserved for recoverable issues)
#   2 - Error (system error like permission denied)

set -e

# Configuration
_OS_DETECT_VERBOSE=${_OS_DETECT_VERBOSE:-0}
_OS_DETECT_JSON=${_OS_DETECT_JSON:-0}

_os_detect_now_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' 2>/dev/null
import time
print(int(time.time() * 1000))
PY
    return
  fi

  if command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes -e 'printf("%d\n", Time::HiRes::time() * 1000)' 2>/dev/null
    return
  fi

  local seconds
  seconds=$(date +%s 2>/dev/null || echo 0)
  echo $((seconds * 1000))
}

_OS_DETECT_START_TIME=$(_os_detect_now_ms)

# Parse command-line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --verbose)
      _OS_DETECT_VERBOSE=1
      shift
      ;;
    --json)
      _OS_DETECT_JSON=1
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# ============================================================================
# Helper Functions
# ============================================================================

_os_detect_log() {
  if [ "$_OS_DETECT_VERBOSE" -eq 1 ]; then
    echo "[os_detect] $*" >&2
  fi
}

_os_detect_error() {
  echo "[os_detect] ERROR: $*" >&2
}

_os_detect_get_elapsed_ms() {
  local end_time
  end_time=$(_os_detect_now_ms)
  if [ "${_OS_DETECT_START_TIME:-0}" -eq 0 ] || [ -z "$end_time" ]; then
    echo "0"
  else
    echo $((end_time - _OS_DETECT_START_TIME))
  fi
}

# ============================================================================
# Detection Logic
# ============================================================================

_os_detect_get_family() {
  _os_detect_log "Detecting platform..."

  local uname_output
  uname_output=$(uname -s 2>/dev/null)

  # Check for macOS
  if [ "$uname_output" = "Darwin" ]; then
    _os_detect_log "uname: $uname_output (macOS)"
    OS_FAMILY="macos"
    return 0
  fi

  # Check for Linux distro via /etc/os-release
  if [ -f /etc/os-release ]; then
    _os_detect_log "Found /etc/os-release"
    local distro_id
    # Extract ID field from /etc/os-release
    # Use grep and sed for POSIX compatibility
    distro_id=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")

    if [ -n "$distro_id" ]; then
      _os_detect_log "Detected distro: $distro_id"
      case "$distro_id" in
        ubuntu|debian)
          OS_FAMILY="debian"
          return 0
          ;;
        fedora)
          OS_FAMILY="fedora"
          return 0
          ;;
        *)
          _os_detect_log "Unknown distro '$distro_id', defaulting to debian"
          OS_FAMILY="debian"
          return 0
          ;;
      esac
    fi
  fi

  # Fallback: assume debian
  _os_detect_log "No /etc/os-release found, defaulting to debian"
  OS_FAMILY="debian"
  return 0
}

_os_detect_check_homebrew() {
  _os_detect_log "Checking Homebrew..."

  if command -v brew >/dev/null 2>&1; then
    _os_detect_log "Homebrew found"
    HAS_HOMEBREW="true"
  else
    _os_detect_log "Homebrew not found"
    HAS_HOMEBREW="false"
  fi
}

# ============================================================================
# Main Detection
# ============================================================================

main() {
  local exit_code=0

  # Allow environment variable override
  if [ -n "$OS_FAMILY" ]; then
    _os_detect_log "OS_FAMILY already set via environment: $OS_FAMILY"
  else
    _os_detect_get_family
    exit_code=$?
  fi

  # Check Homebrew (regardless of OS)
  _os_detect_check_homebrew

  # Export variables
  export OS_FAMILY
  export HAS_HOMEBREW

  local elapsed_ms
  elapsed_ms=$(_os_detect_get_elapsed_ms)

  # Output mode
  if [ "$_OS_DETECT_JSON" -eq 1 ]; then
    # Machine-readable JSON output
    printf '{"OS_FAMILY":"%s","HAS_HOMEBREW":%s,"detection_ms":%s,"fallback":%s}\n' \
      "$OS_FAMILY" \
      "$HAS_HOMEBREW" \
      "$elapsed_ms" \
      "$([ "$exit_code" -eq 1 ] && echo 'true' || echo 'false')" >&1
  else
    # Default: export statements (for sourcing)
    printf 'export OS_FAMILY="%s"\n' "$OS_FAMILY"
    printf 'export HAS_HOMEBREW="%s"\n' "$HAS_HOMEBREW"
  fi

  _os_detect_log "Detection complete (${elapsed_ms}ms)"

  return $exit_code
}

# Run main function
main
