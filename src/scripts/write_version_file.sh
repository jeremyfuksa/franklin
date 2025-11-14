#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SRC_DIR/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"

if [ -n "${FRANKLIN_VERSION:-}" ]; then
  version="$FRANKLIN_VERSION"
elif git -C "$ROOT_DIR" describe --tags --dirty --always >/dev/null 2>&1; then
  version=$(git -C "$ROOT_DIR" describe --tags --dirty --always)
else
  version="unknown"
fi

echo "$version" >"$VERSION_FILE"
