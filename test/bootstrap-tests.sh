#!/usr/bin/env bash
# Smoke test for bootstrap installer using a locally generated archive.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

ARCHIVE_PATH="$TMP_ROOT/franklin-bootstrap.tar.gz"
git -C "$ROOT_DIR" archive --format=tar.gz --prefix="franklin-v0.0.0/src/" HEAD src >"$ARCHIVE_PATH"

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

if [ ! -s "$ARCHIVE_PATH" ]; then
  echo "Archive $ARCHIVE_PATH not created."
  exit 1
fi

INSTALL_DIR="$TMP_ROOT/franklin"
FRANKLIN_TEST_MODE=1 FRANKLIN_BOOTSTRAP_ARCHIVE="file://$ARCHIVE_PATH" bash "$ROOT_DIR/bootstrap.sh" --install-root "$INSTALL_DIR" >/dev/null

echo "Franklin bootstrap smoke test for $OS_FAMILY completed successfully."
