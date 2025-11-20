#!/usr/bin/env bash
# Automate Franklin release creation end-to-end:
#   1. Stamp VERSION with the supplied tag
#   2. Commit and tag the release
#   3. Push commit + tag

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SRC_DIR/.." && pwd)"

: "${FRANKLIN_UI_QUIET:=0}"
: "${FRANKLIN_DISABLE_SPINNER:=1}"
# shellcheck source=../lib/colors.sh
. "$SRC_DIR/lib/colors.sh"
# shellcheck source=../lib/ui.sh
. "$SRC_DIR/lib/ui.sh"

DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: scripts/release.sh [options] vX.Y.Z

Options:
  --dry-run      Print the steps without mutating git
  --quiet        Suppress Franklin UI logging (stderr only)
  --help         Show this help message

Examples:
  scripts/release.sh v1.1.0
  scripts/release.sh --dry-run v1.1.0
EOF
}

log_info() { franklin_ui_log info "[RELEASE]" "$@"; }
log_success() { franklin_ui_log success " DONE " "$@"; }
log_warning() { franklin_ui_log warning " WARN " "$@"; }
log_error() { franklin_ui_log error " ERR " "$@"; }

release_step() {
  local desc="$1"
  shift
  if [ "$DRY_RUN" -eq 1 ]; then
    log_info "(dry-run) $desc: $*"
    return 0
  fi
  FRANKLIN_UI_SPINNER_TAIL_LINES="${FRANKLIN_UI_SPINNER_TAIL_LINES:-80}" \
    franklin_ui_run_with_spinner "$desc" "$@"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --quiet)
      FRANKLIN_UI_QUIET=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    v*.*.*)
      ARGS+=("$1")
      shift
      ;;
    *)
      log_error "Unsupported argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

if [ "${#ARGS[@]}" -ne 1 ]; then
  log_error "Please supply exactly one semantic version starting with 'v' (e.g., v1.1.0)"
  exit 2
fi

VERSION="${ARGS[0]}"
if ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9._-]+)?$ ]]; then
  log_error "'$VERSION' is not a valid version (expected vMAJOR.MINOR.PATCH[-extra])"
  exit 2
fi

if [ "$DRY_RUN" -eq 0 ]; then
  if [ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]; then
    log_error "Working tree is dirty. Commit or stash changes first."
    exit 2
  fi

  if git -C "$ROOT_DIR" rev-parse "$VERSION" >/dev/null 2>&1; then
    log_error "Tag $VERSION already exists."
    exit 2
  fi
fi

log_info "Releasing Franklin $VERSION (dry-run=$DRY_RUN)"

release_step "Stamping VERSION file" env FRANKLIN_VERSION="$VERSION" "$SCRIPT_DIR/write_version_file.sh"

release_step "Staging VERSION" git -C "$ROOT_DIR" add VERSION
release_step "Committing release" git -C "$ROOT_DIR" commit -m "release: $VERSION"
release_step "Tagging release" git -C "$ROOT_DIR" tag -a "$VERSION" -m "Franklin $VERSION"
release_step "Pushing main branch" git -C "$ROOT_DIR" push
release_step "Pushing release tag" git -C "$ROOT_DIR" push origin "$VERSION"

log_success "Release $VERSION complete."
