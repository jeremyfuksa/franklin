#!/bin/bash
# Package a production-ready copy of franklin without development-only assets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SRC_DIR/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
PROJECT_SLUG="${PROJECT_SLUG:-franklin}"
OUTPUT_DIR="${1:-$DIST_DIR/$PROJECT_SLUG}"
FRANKLIN_UI_QUIET=${FRANKLIN_UI_QUIET:-0}

# shellcheck source=../lib/colors.sh
. "$SRC_DIR/lib/colors.sh"
# shellcheck source=../lib/ui.sh
. "$SRC_DIR/lib/ui.sh"

log_info() { franklin_ui_log info "[BUILD]" "$@"; }
log_success() { franklin_ui_log success " DONE " "$@"; }
log_warning() { franklin_ui_log warning " WARN " "$@"; }
log_error() { franklin_ui_log error " ERR " "$@"; }

mkdir -p "$DIST_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

log_info "Copying Franklin source files to $OUTPUT_DIR..."
rsync -a "$SRC_DIR/" "$OUTPUT_DIR/"

# Copy VERSION file from root
cp "$ROOT_DIR/VERSION" "$OUTPUT_DIR/VERSION"

ARCHIVE_PATH="$DIST_DIR/$PROJECT_SLUG.tar.gz"
rm -f "$ARCHIVE_PATH"

log_info "Creating release tarball..."
tar -czf "$ARCHIVE_PATH" -C "$OUTPUT_DIR" .

log_success "Release directory: $OUTPUT_DIR"
log_success "Release archive:   $ARCHIVE_PATH"
