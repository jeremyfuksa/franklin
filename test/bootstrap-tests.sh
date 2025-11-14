#!/usr/bin/env bash
# Smoke test for bootstrap installer using local release artifacts.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

bash "$ROOT_DIR/src/scripts/build_release.sh" >/dev/null

case "$(uname -s)" in
  Darwin)
    OS_FAMILY="macos"
    ;;
  Linux)
    if [ -f /etc/os-release ]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      case "${ID:-}" in
        ubuntu|debian|pop|elementary|linuxmint|neon)
          OS_FAMILY="debian"
          ;;
        fedora)
          OS_FAMILY="fedora"
          ;;
        *)
          echo "Skipping bootstrap smoke test: unsupported Linux distro ($ID)."
          exit 0
          ;;
      esac
    else
      echo "Skipping bootstrap smoke test: unable to detect Linux distro."
      exit 0
    fi
    ;;
  *)
    echo "Skipping bootstrap smoke test: unsupported platform $(uname -s)."
    exit 0
    ;;
 esac

ARCHIVE_PATH="$ROOT_DIR/dist/franklin-$OS_FAMILY.tar.gz"
if [ ! -f "$ARCHIVE_PATH" ]; then
  echo "Archive $ARCHIVE_PATH not found; build_release may have failed."
  exit 1
fi

INSTALL_DIR="$TMP_ROOT/franklin"
FRANKLIN_TEST_MODE=1 FRANKLIN_BOOTSTRAP_ARCHIVE="file://$ARCHIVE_PATH" bash "$ROOT_DIR/bootstrap.sh" --install-root "$INSTALL_DIR" >/dev/null

echo "Franklin bootstrap smoke test for $OS_FAMILY completed successfully."
