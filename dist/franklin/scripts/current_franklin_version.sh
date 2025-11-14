#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SRC_DIR/.." && pwd)"

if [ -n "${FRANKLIN_VERSION:-}" ]; then
  echo "$FRANKLIN_VERSION"
elif [ -f "$ROOT_DIR/VERSION" ]; then
  cat "$ROOT_DIR/VERSION"
else
  echo "unknown"
fi
