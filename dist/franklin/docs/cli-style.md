# Franklin CLI Style Guide

This document captures the logging and UX conventions introduced in `UI-DeepDive.md` and implemented by `lib/ui.sh`.

## Streams & Quiet Mode
- Diagnostic output (badges, sections, summaries) **always** goes to `stderr` via the helpers in `lib/ui.sh`.
- Machine-readable/stdout output is reserved for commands that are piped or scripted.
- Pass `--quiet` (or set `FRANKLIN_UI_QUIET=1`) to suppress all Franklin UI logging. Commands still return correct exit codes so automation can detect failures.

## Badge System
- Badges combine semantic color, icon, and bracketed label. The palette lives in `lib/ui.sh` and uses Campfire colors.
- `FRANKLIN_UI_BADGE_WIDTH` enforces fixed-width padding so two-column layouts stay aligned even with ANSI color codes.
- Available levels: `run/info`, `success`, `warning`, `error`, `debug`. Each level has an icon (↺, ✓, ⚠, ✗,  respectively).
- Use `franklin_ui_log <level> <label> <message>` instead of manual `printf`s.

## Sections & Spacing
- Use `franklin_ui_section "Heading"` to start a block; it renders an 80-char rule with inverted colors.
- `franklin_ui_blank_line` adds intentional whitespace that also respects quiet mode.
- Never `echo` blank lines for diagnostics—use the helpers so they inherit the user's stream/quiet preferences.

## Task / Step Patterns
- For spinner-like work, call `franklin_ui_run_with_spinner "Description" cmd args...`. It routes progress to `stderr`, captures output for verbose mode, and emits aligned badges automatically.
- For higher-level phases (`run_step`/`begin_install_phase`), rely on `franklin_ui_section` + `franklin_ui_log` so summaries share the same look and alignment.
- `FRANKLIN_FORCE_SPINNER=1` or `FRANKLIN_DISABLE_SPINNER=1` let CI/users override detection, and `FRANKLIN_UI_SPINNER_VERBOSE=1` replays captured output after success.
- Spinners automatically stay off in `CI`/`GITHUB_ACTIONS`, `TERM=dumb`, or when `NO_COLOR`/`CLICOLOR=0` is set so captured logs don't show raw ANSI escape codes—set `FRANKLIN_FORCE_SPINNER=1` to opt back in.

## Consumer Scripts
- `install.sh` and `update-all.sh` both accept `--quiet`, `--verbose`, and reuse the shared helpers (no direct ANSI/printf logic).
- Additional scripts should source `lib/ui.sh` and, whenever possible, avoid bespoke formatting.

## Adding New Scripts
1. `source lib/ui.sh` (after `lib/colors.sh` if you need palette access).
2. Emit work summaries with `franklin_ui_log` and sections with `franklin_ui_section`.
3. Keep stdout reserved for machine output or prompts; diagnostics go to stderr via the helpers.
4. Expose `--quiet` (or honor `FRANKLIN_UI_QUIET`) for automation contexts.
