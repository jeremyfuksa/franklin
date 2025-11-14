#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRANKLIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -n "${FRANKLIN_VERSION:-}" ]; then
  echo "$FRANKLIN_VERSION"
elif [ -f "$FRANKLIN_ROOT/VERSION" ]; then
  cat "$FRANKLIN_ROOT/VERSION"
else
  echo "unknown"
fi
