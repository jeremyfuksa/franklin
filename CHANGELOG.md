# Changelog

All notable changes to this project will be documented in this file.

The format roughly follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `.zshrc` now sources `~/.franklin.local.zsh` (or `FRANKLIN_LOCAL_CONFIG`) so you can keep private aliases outside the repo; the installer creates the stub automatically.
- MOTD automatically shows a Docker/services grid when containers are present or `MOTD_SERVICES` defines custom daemons to monitor.

### Changed

- Completion caching now refreshes once every 24 hours via `FRANKLIN_ZCOMP_CACHE`, speeding up shell startup while keeping completions fresh.
- Spinner frames now reuse the padded badge formatter so the second column stays aligned with other log lines.

## [1.2.3] - 2025-11-13

## [1.2.3] - 2025-11-13

### Fixed

- Spinner logging now emits ANSI escapes via `%b` so Apple Terminal, Hyper, and other 24-bit terminals render animations correctly instead of printing literal `\033[...]` text.

## [1.2.2] - 2025-11-13

### Added

- Shared `franklin_ui_run_with_spinner` helper provides Campfire-themed animations, stdout-safe logging, and environment overrides for every Bash CLI.

### Changed

- `update-all.sh`, `install.sh`’s version audit, and the release pipeline now consume the centralized spinner helper so long-running steps stay modern without bespoke TTY logic.
- CLI style guide documents the spinner API plus `FRANKLIN_FORCE_SPINNER` / `FRANKLIN_DISABLE_SPINNER` / `FRANKLIN_UI_SPINNER_VERBOSE` for contributors.
- Spinner animation now automatically disables itself when running under CI/dumb terminals/`NO_COLOR`, and `scripts/release.sh` opts out by default so captured logs don’t show raw ANSI control codes.

## [1.2.0] - 2025-11-13

### Added

- Captured the Franklin CLI logging vision in `docs/CLI-UX-Improvement-Plan.md`, keeping the stream separation, badge catalog, and rollout checklist in one place.
- Published a comprehensive UI deep dive plus a CLI style guide so contributors can mirror the Campfire look across every script.

### Changed

- `install.sh`, `update-all.sh`, and all build/release tooling now route diagnostics through `lib/ui.sh`, respect a common `--quiet` flag, and render consistent badges/sections without polluting stdout.
- Release archives now ship the refreshed documentation set (CLI UX plan, UI deep dive, CLI style) so downstream bundles include the latest guidance by default.

## [1.1.5] - 2025-11-13

### Added

- Introduced the Campfire UI palette (Cello/Terracotta/Black Rock + status colors) for installer/update badges, ensuring every non-banner surface shares the same Franklin visual language.
- Franklin signature palettes (Ember/Ash) now power the MOTD banner and installer color picker (use `ember:clay`, `ash:cello`, or any `#hex`).

### Changed

- `.zshrc` reintroduces OS-specific sections (keybindings, `ls` aliases) so Debian/Fedora bundles no longer inherit macOS defaults.
- Section banners in `install.sh` and `update-all.sh` now mirror the Campfire MOTD style exactly: top/bottom glyphs render without background color, and the middle fill uses the lighter Cello shade with base text color for improved contrast.
- `update-all.sh` and `install.sh` now consume the shared Campfire UI helper (`lib/ui.sh`) so badges, section dividers, and colors match the MOTD banner everywhere.
- `scripts/build_release.sh` bundles the new UI helper, skips stray files (e.g., `CHANGELOG.md`), and continues to generate per-OS manifests from a clean staging tree.
- Darkened the Franklin palette via HSL tweaks so prompts and dashboards have better contrast.
- Rebuilt the macOS, Debian, Fedora, and unified release bundles plus manifests to capture the latest assets.
- MOTD banner now uses truecolor sequences when the terminal supports them, falls back to tuned 256-color values otherwise, and expands to the detected terminal width (capped at 80 columns) so headers stay flush edge-to-edge.
- `update-all.sh` and the MOTD now display a 🐢 Franklin release status (current vs. latest) for quick diagnostics.
- MOTD banner regained its Campfire frame and now adds a dedicated "Disk | Memory | Franklin" status row beneath the hostname, with the columns aligned left/center/right as requested.
- Disk usage now derives from the filesystem that backs `$HOME` (configurable via `MOTD_DISK_PATH`) so the numbers match Finder/Disk Utility instead of the tiny system volume slice.
- MOTD version badge falls back to `git describe` when no VERSION file/script exists, so unreleased/dev builds still show a build identifier.
- Status row now uses Nerd Font icons (`` disk, `` memory, turtle for Franklin) and assumes a Nerd Font–patched terminal; document this requirement in README.

### Fixed

- MOTD color picker accepts shorthand/custom hex values (`eee`, `abc`, `123456`) with or without a leading `#`, both when using `--motd-color` and during the interactive installer prompt.
- Spinner logging in `update-all` is now TTY-aware, preventing log flooding when stdout is captured.
- MOTD color prompts now restore `$PATH` correctly and stop clobbering Franklin palette environment variables.
- PATH cleanup during installation removes duplicates without stripping required segments.
- `ls` aliases avoid recursive definitions when Antigen reloads them.
- MOTD helper tests can set `FRANKLIN_TEST_MODE=1` to strip ANSI sequences from bar charts, keeping assertions stable in CI.
- Disk usage readings in the MOTD are now derived from raw `df -k` values, so the used/total numbers match macOS Finder exactly (no more 11 GB when you really have 395 GB on disk).

## [1.1.3] - 2025-11-13

### Changed

- `.zshrc` reintroduces OS-specific sections (keybindings, `ls` aliases) so Debian/Fedora bundles no longer inherit macOS defaults.

### Fixed

- MOTD color picker accepts shorthand/custom hex values (`eee`, `abc`, `123456`) with or without a leading `#`, both when using `--motd-color` and during the interactive installer prompt.

## [1.1.1] - 2025-11-13

### Changed

- Section banners in `install.sh` and `update-all.sh` now mirror the Campfire MOTD style exactly: top/bottom glyphs render without background color, and the middle fill uses the lighter Cello shade with base text color for improved contrast.

## [1.1.0] - 2025-11-13

### Added

- New `scripts/release.sh` automates stamping `VERSION`, building `dist/`, committing, tagging, and uploading GitHub releases (with `--dry-run`/`--no-upload` safety switches).

### Changed

- `update-all.sh` and `install.sh` now consume the shared Campfire UI helper (`lib/ui.sh`) so badges, section dividers, and colors match the MOTD banner everywhere.
- `scripts/build_release.sh` bundles the new UI helper, skips stray files (e.g., `CHANGELOG.md`), and continues to generate per-OS manifests from a clean staging tree.

### Fixed

- `scripts/check_versions.sh` no longer aborts when `npm` isn't on the PATH, so `update-all` completes cleanly even if NPM hasn't been initialized yet.

## [1.0.1] - 2025-11-12

### Added

- Show Franklin palette swatches in the installer to make color selection easier.
- Truecolor detection helper (`franklin_use_truecolor`) plus `FRANKLIN_FORCE_TRUECOLOR` / `FRANKLIN_DISABLE_TRUECOLOR` overrides so shells can force or skip 24-bit colors consistently.
- Automatic environment flagging (e.g., `FRANKLIN_FORCE_TRUECOLOR=1`) ensures the MOTD picks up truecolor palettes just like the installer preview.
- `MOTD_DEBUG_COLORS=1` prints the resolved banner hex, ANSI sequences, and text color so you can see exactly what the MOTD is emitting.
- Added VERSION file generation and helper scripts (`scripts/write_version_file.sh`, `scripts/current_franklin_version.sh`) so releases embed and expose the Franklin build identifier.
- Interactive MOTD color picker now uses a numbered menu (plus custom hex option) so invalid text entries can’t accidentally reset the banner color.

- Darkened the Franklin palette via HSL tweaks so prompts and dashboards have better contrast.
- Rebuilt the macOS, Debian, Fedora, and unified release bundles plus manifests to capture the latest assets.
- MOTD banner now uses truecolor sequences when the terminal supports them, falls back to tuned 256-color values otherwise, and expands to the detected terminal width (capped at 80 columns) so headers stay flush edge-to-edge.
- `update-all.sh` and the MOTD now display a 🐢 Franklin release status (current vs. latest) for quick diagnostics.
- MOTD banner regained its Campfire frame and now adds a dedicated "Disk | Memory | Franklin" status row beneath the hostname, with the columns aligned left/center/right as requested.
- Disk usage now derives from the filesystem that backs `$HOME` (configurable via `MOTD_DISK_PATH`) so the numbers match Finder/Disk Utility instead of the tiny system volume slice.
- MOTD version badge falls back to `git describe` when no VERSION file/script exists, so unreleased/dev builds still show a build identifier.
- Status row now uses Nerd Font icons (`` disk, `` memory, turtle for Franklin) and assumes a Nerd Font–patched terminal; document this requirement in README.

### Fixed

- Spinner logging in `update-all` is now TTY-aware, preventing log flooding when stdout is captured.
- MOTD color prompts now restore `$PATH` correctly and stop clobbering Franklin palette environment variables.
- PATH cleanup during installation removes duplicates without stripping required segments.
- `ls` aliases avoid recursive definitions when Antigen reloads them.
- MOTD helper tests can set `FRANKLIN_TEST_MODE=1` to strip ANSI sequences from bar charts, keeping assertions stable in CI.
- Disk usage readings in the MOTD are now derived from raw `df -k` values, so the used/total numbers match macOS Finder exactly (no more 11 GB when you really have 395 GB on disk).

## [1.0.0] - 2025-11-12

### Added

- Initial public release of Franklin with macOS, Debian, and Fedora support, bundling Antigen, Starship, NVM, and a signature Campfire MOTD dashboard.
