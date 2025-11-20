#!/usr/bin/env bash

# Wrapper to ensure we run the repo's current update-all with a local archive,
# so we don't fall back to the latest tagged release (v1.6.0) on GitHub.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${FRANKLIN_BOOTSTRAP_ARCHIVE:-}" ]; then
  tmp_archive="$(mktemp "/tmp/franklin-head.XXXXXX.tar.gz")"
  tar -czf "$tmp_archive" -C "$SCRIPT_DIR/src" .
  export FRANKLIN_BOOTSTRAP_ARCHIVE="file://$tmp_archive"
fi

if [ -z "${FRANKLIN_VERSION:-}" ] && [ -f "$SCRIPT_DIR/VERSION" ]; then
  export FRANKLIN_VERSION
  FRANKLIN_VERSION="$(cat "$SCRIPT_DIR/VERSION" 2>/dev/null || true)"
fi

exec bash "$SCRIPT_DIR/src/update-all.sh" "$@"
