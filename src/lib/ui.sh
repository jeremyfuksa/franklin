#!/usr/bin/env bash
# Shared Franklin UI helpers so installers, updaters, and MOTD-inspired tools
# render the Campfire-themed badges and section frames.

if [ -n "${FRANKLIN_UI_HELPERS:-}" ]; then
  return 0 2>/dev/null || true
fi

# Ensure color palette is available. Callers should source lib/colors.sh first,
# but fall back to simple ANSI values if they haven't yet.
: "${NC:=\033[0m}"
: "${CAMPFIRE_PRIMARY_700:=\033[38;2;62;79;102m}"
: "${CAMPFIRE_PRIMARY_100_BG:=\033[48;2;235;238;242m}"
: "${CAMPFIRE_PRIMARY_200_BG:=\033[48;2;210;218;227m}"
: "${CAMPFIRE_PRIMARY_600_BG:=\033[48;2;76;98;125m}"
: "${CAMPFIRE_PRIMARY_800_BG:=\033[48;2;54;68;86m}"
: "${CAMPFIRE_NEUTRAL_50:=\033[38;2;247;248;249m}"
: "${CAMPFIRE_NEUTRAL_900:=\033[38;2;43;48;59m}"
: "${CAMPFIRE_SUCCESS_BG:=\033[48;2;90;111;45m}"
: "${CAMPFIRE_SUCCESS_FG:=\033[38;2;245;247;249m}"
: "${CAMPFIRE_WARNING_BG:=\033[48;2;239;153;31m}"
: "${CAMPFIRE_WARNING_FG:=\033[38;2;52;31;25m}"
: "${CAMPFIRE_DANGER_BG:=\033[48;2;190;43;41m}"
: "${CAMPFIRE_DANGER_FG:=\033[38;2;250;246;245m}"
: "${CAMPFIRE_INFO_BG:=\033[48;2;136;153;179m}"
: "${CAMPFIRE_INFO_FG:=\033[38;2;31;37;48m}"

: "${FRANKLIN_UI_WIDTH:=80}"
: "${FRANKLIN_UI_RULE_TOP_CHAR:=▄}"
: "${FRANKLIN_UI_RULE_BOTTOM_CHAR:=▀}"
: "${FRANKLIN_UI_BADGE_WIDTH:=16}"
: "${FRANKLIN_UI_STREAM:=stderr}"

: "${FRANKLIN_UI_COLOR_INFO_BAR:=${CAMPFIRE_PRIMARY_BAR:-$CAMPFIRE_SECONDARY_ACCENT}}"
: "${FRANKLIN_UI_COLOR_INFO_BG:=${CAMPFIRE_PRIMARY_800_BG:-$CAMPFIRE_SECONDARY_800_BG}}"
: "${FRANKLIN_UI_COLOR_INFO_BG_LIGHT:=${CAMPFIRE_PRIMARY_600_BG:-$CAMPFIRE_SECONDARY_700_BG}}"
: "${FRANKLIN_UI_COLOR_INFO_FG:=${CAMPFIRE_PRIMARY_TEXT_LIGHT:-$CAMPFIRE_NEUTRAL_50}}"
: "${FRANKLIN_UI_COLOR_INFO_TEXT:=${CAMPFIRE_PRIMARY_TEXT_LIGHT:-$CAMPFIRE_NEUTRAL_50}}"
: "${FRANKLIN_UI_COLOR_SUCCESS_BG:=$CAMPFIRE_SUCCESS_BG}"
: "${FRANKLIN_UI_COLOR_SUCCESS_FG:=$CAMPFIRE_SUCCESS_FG}"
: "${FRANKLIN_UI_COLOR_WARNING_BG:=$CAMPFIRE_WARNING_BG}"
: "${FRANKLIN_UI_COLOR_WARNING_FG:=$CAMPFIRE_WARNING_FG}"
: "${FRANKLIN_UI_COLOR_ERROR_BG:=$CAMPFIRE_DANGER_BG}"
: "${FRANKLIN_UI_COLOR_ERROR_FG:=$CAMPFIRE_DANGER_FG}"
: "${FRANKLIN_UI_COLOR_DEBUG_BG:=$CAMPFIRE_INFO_BG}"
: "${FRANKLIN_UI_COLOR_DEBUG_FG:=$CAMPFIRE_INFO_FG}"

: "${FRANKLIN_UI_SPINNER_COLOR:=${FRANKLIN_UI_COLOR_INFO_BG}${FRANKLIN_UI_COLOR_INFO_FG}}"
: "${FRANKLIN_UI_SPINNER_INTERVAL:=0.1}"
: "${FRANKLIN_UI_SPINNER_FRAMES:=⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏}"

_franklin_ui_emit() {
  local text="$1"
  local newline="${2:-1}"
  local quiet="${FRANKLIN_UI_QUIET:-0}"
  local stream="${FRANKLIN_UI_STREAM:-stderr}"

  if [ "$quiet" -eq 1 ]; then
    return
  fi

  if [ "$newline" -eq 1 ]; then
    if [ "$stream" = "stdout" ]; then
      printf '%b\n' "$text"
    else
      printf '%b\n' "$text" >&2
    fi
  else
    if [ "$stream" = "stdout" ]; then
      printf '%b' "$text"
    else
      printf '%b' "$text" >&2
    fi
  fi
}

franklin_ui_plain() {
  _franklin_ui_emit "$*"
}

franklin_ui_blank_line() {
  _franklin_ui_emit ""
}

franklin_ui_visible_length() {
  local text="$1"
  local i=0
  local visible=0
  local length=${#text}

  while [ $i -lt $length ]; do
    local char=${text:i:1}
    if [ "$char" = $'\033' ]; then
      i=$((i + 1))
      if [ $i -ge $length ]; then
        break
      fi
      char=${text:i:1}
      if [ "$char" = "[" ]; then
        while [ $i -lt $length ]; do
          char=${text:i:1}
          case "$char" in
            [@-~])
              i=$((i + 1))
              break
              ;;
          esac
          i=$((i + 1))
        done
        continue
      fi
    fi
    visible=$((visible + 1))
    i=$((i + 1))
  done

  printf '%d' "$visible"
}

franklin_ui_pad_badge() {
  local text="$1"
  local width="${2:-$FRANKLIN_UI_BADGE_WIDTH}"
  local visible padding needed

  visible=$(franklin_ui_visible_length "$text")
  needed=$(( width - visible ))

  if [ "$needed" -gt 0 ]; then
    printf -v padding '%*s' "$needed" ''
    printf '%b' "${text}${padding}"
  else
    printf '%b' "$text"
  fi
}

franklin_ui_repeat_char() {
  local char="$1"
  local count="${2:-$FRANKLIN_UI_WIDTH}"
  printf -v __fr_line '%*s' "$count" ''
  __fr_line=${__fr_line// /$char}
  printf '%s' "$__fr_line"
}

franklin_ui_section() {
  local title="$1"
  local width="${2:-$FRANKLIN_UI_WIDTH}"
  local inner_width=$(( width - 2 ))
  local top bottom middle
  top=$(franklin_ui_repeat_char "$FRANKLIN_UI_RULE_TOP_CHAR" "$width")
  bottom=$(franklin_ui_repeat_char "$FRANKLIN_UI_RULE_BOTTOM_CHAR" "$width")
  printf -v middle ' %s ' "$title"
  printf -v middle '%-*s' "$FRANKLIN_UI_WIDTH" "$middle"
  # Convert INFO_BAR foreground color to background to match half-block colors
  local middle_bg="${FRANKLIN_UI_COLOR_INFO_BAR/38;/48;}"
  _franklin_ui_emit "${FRANKLIN_UI_COLOR_INFO_BAR}${top}${NC}"
  _franklin_ui_emit "${middle_bg}${FRANKLIN_UI_COLOR_INFO_TEXT}${middle}${NC}"
  _franklin_ui_emit "${FRANKLIN_UI_COLOR_INFO_BAR}${bottom}${NC}"
}

franklin_ui_badge() {
  local level="$1"
  local label="$2"
  local bg fg icon=""
  label=${label:-${level^^}}

  case "$level" in
    success)
      bg="$FRANKLIN_UI_COLOR_SUCCESS_BG"
      fg="$FRANKLIN_UI_COLOR_SUCCESS_FG"
      icon='✓'
      ;;
    warning)
      bg="$FRANKLIN_UI_COLOR_WARNING_BG"
      fg="$FRANKLIN_UI_COLOR_WARNING_FG"
      icon='⚠'
      ;;
    error)
      bg="$FRANKLIN_UI_COLOR_ERROR_BG"
      fg="$FRANKLIN_UI_COLOR_ERROR_FG"
      icon='✗'
      ;;
    debug)
      bg="$FRANKLIN_UI_COLOR_DEBUG_BG"
      fg="$FRANKLIN_UI_COLOR_DEBUG_FG"
      icon=''
      ;;
    run|info)
      bg="$FRANKLIN_UI_COLOR_INFO_BG"
      fg="$FRANKLIN_UI_COLOR_INFO_FG"
      icon='↺'
      ;;
    *)
      bg="$FRANKLIN_UI_COLOR_INFO_BG"
      fg="$FRANKLIN_UI_COLOR_INFO_FG"
      ;;
  esac

  local content="$label"
  if [ -n "$icon" ]; then
    content="$icon $label"
  fi
  local raw="${bg}${fg} ${content} ${NC}"
  franklin_ui_pad_badge "$raw"
}

franklin_ui_log() {
  local level="$1"
  local label="$2"
  shift 2
  local message="$*"
  local badge
  badge="$(franklin_ui_badge "$level" "$label")"
  _franklin_ui_emit "$(printf '%b %s' "$badge" "$message")"
}

franklin_ui_spinner_should_run() {
  if [ "${FRANKLIN_UI_QUIET:-0}" -eq 1 ]; then
    return 1
  fi
  if [ "${FRANKLIN_DISABLE_SPINNER:-0}" -eq 1 ]; then
    return 1
  fi
  if [ "${FRANKLIN_FORCE_SPINNER:-0}" -eq 1 ]; then
    return 0
  fi
  case "${CI:-}" in
    1|true|TRUE)
      return 1
      ;;
  esac
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    return 1
  fi
  if [ -n "${NO_COLOR:-}" ] || [ "${CLICOLOR:-1}" = "0" ]; then
    return 1
  fi
  case "${TERM:-}" in
    ""|dumb)
      return 1
      ;;
  esac
  if [ ! -t 2 ]; then
    return 1
  fi
  return 0
}

franklin_ui_spinner_wait() {
  local pid="$1"
  shift
  local desc="$*"

  if ! franklin_ui_spinner_should_run; then
    wait "$pid"
    return $?
  fi

  local frames i=0 frame_count spinner_raw="$FRANKLIN_UI_SPINNER_FRAMES"
  local IFS=' '
  read -r -a frames <<<"$spinner_raw"
  if [ "${#frames[@]}" -eq 0 ]; then
    frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  fi
  frame_count=${#frames[@]}

  printf '\n' >&2
  while kill -0 "$pid" 2>/dev/null; do
    local frame="${frames[$i]}"
    local spinner_badge
    spinner_badge="$(franklin_ui_pad_badge "${FRANKLIN_UI_SPINNER_COLOR} [${frame}] ${NC}")"
    printf '\r\033[K%b %s' "$spinner_badge" "$desc" >&2
    i=$(( (i + 1) % frame_count ))
    sleep "$FRANKLIN_UI_SPINNER_INTERVAL"
  done

  wait "$pid"
  local exit_code=$?
  printf '\r\033[K' >&2
  return $exit_code
}

franklin_ui_run_with_spinner() {
  local desc="$1"
  shift
  local tail_lines="${FRANKLIN_UI_SPINNER_TAIL_LINES:-40}"
  local verbose="${FRANKLIN_UI_SPINNER_VERBOSE:-0}"

  if [ "${FRANKLIN_UI_QUIET:-0}" -eq 1 ]; then
    "$@" >/dev/null 2>&1
    return $?
  fi

  local tmpfile
  tmpfile=$(mktemp)
  local exit_code

  if franklin_ui_spinner_should_run; then
    "$@" >"$tmpfile" 2>&1 &
    local pid=$!
    franklin_ui_spinner_wait "$pid" "$desc"
    exit_code=$?
  else
    franklin_ui_blank_line
    franklin_ui_log run " RUN " "$desc"
    "$@" >"$tmpfile" 2>&1
    exit_code=$?
  fi

  franklin_ui_blank_line
  if [ $exit_code -eq 0 ]; then
    franklin_ui_log success " OK " "$desc"
    if [ "$verbose" -eq 1 ]; then
      cat "$tmpfile" >&2
    fi
  else
    franklin_ui_log error "FAIL" "$desc"
    franklin_ui_log error " INFO" "$desc failed. Last ${tail_lines} log lines:"
    tail -n "$tail_lines" "$tmpfile" | sed 's/^/    /' >&2
  fi

  rm -f "$tmpfile"
  return $exit_code
}

FRANKLIN_UI_HELPERS=1
