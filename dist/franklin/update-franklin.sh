#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRANKLIN_ROOT="$SCRIPT_DIR"
UPDATE_SCRIPT="$FRANKLIN_ROOT/update-all.sh"

if [ ! -f "$UPDATE_SCRIPT" ]; then
  echo "franklin: update script missing at $UPDATE_SCRIPT" >&2
  exit 2
fi

exec bash "$UPDATE_SCRIPT" --franklin-only "$@"
