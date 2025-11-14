#!/bin/zsh
# Notifications and Progress Feedback Library
#
# Provides notify() and run_with_spinner() functions for user feedback

# notify(level, title, message)
# Levels: success, warning, error, info
notify() {
  local level="$1"
  local title="$2"
  local message="$3"

  case "$level" in
    success)
      echo "✓ $title: $message" >&2
      ;;
    warning)
      echo "⚠ $title: $message" >&2
      ;;
    error)
      echo "✗ $title: $message" >&2
      ;;
    info)
      echo "ℹ $title: $message" >&2
      ;;
    *)
      echo "$title: $message" >&2
      ;;
  esac
}

# run_with_spinner(description, command ...)
# Runs command with animated spinner
run_with_spinner() {
  if [ $# -eq 0 ]; then
    notify error "Spinner" "No command provided"
    return 1
  fi

  local desc="$1"
  shift
  local cmd=("$@")

  if [ ${#cmd[@]} -eq 0 ]; then
    cmd=("$desc")
    desc="Running"
  fi

  local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0

  # Run command in background
  "${cmd[@]}" >/dev/null 2>&1 &
  local pid=$!
  sleep 0.1

  # Show spinner
  while kill -0 "$pid" 2>/dev/null; do
    echo -ne "\r${spinner[$i]} $desc"
    i=$((($i + 1) % ${#spinner[@]}))
    sleep 0.1
  done

  # Wait for command to complete
  wait "$pid"
  local exit_code=$?

  # Clear spinner line
  echo -ne "\r"

  if [ $exit_code -eq 0 ]; then
    notify success "$desc" "completed"
  else
    notify error "$desc" "failed (exit code $exit_code)"
  fi

  return $exit_code
}
