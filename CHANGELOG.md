# Changelog

All notable changes to this project will be documented in this file.

The format roughly follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `franklin_ui_stream_filtered` and `franklin_ui_stream_filtered_with_timeout` provide filtered, real-time output with hang detection and signal-safe cleanup.
- `src/lib/streaming_filters.sh` centralizes Homebrew/apt/dnf/npm/tool filter presets plus package-count helpers.
- `--mode=auto|quiet|verbose` flag (and `FRANKLIN_UPDATE_MODE`/`~/.config/franklin/update.env`) to control streaming verbosity in `update-all.sh`.
- `test/streaming_filters_test.sh` and `test/streaming_integration_test.sh` cover filter accuracy and exit-code propagation.
- Sheldon plugin management replaces Antigen, including automatic migration of legacy bundles to `plugins.toml` and new sheldon update step in `update-all.sh`.

### Changed

- `update-all.sh` now streams package manager output by default, replacing spinner-wrapped commands across Franklin core, OS packages, Antigen, Starship, Python, uv, NVM, and npm steps.
- Added hang detection/timeout messaging plus SSH-aware defaults (`FRANKLIN_UPDATE_TIMEOUT`) for long-running updates.
- README/CLAUDE documentation updated to describe streaming UI behavior and configuration.
- Install workflow now generates `~/.config/franklin/sheldon/plugins.toml`, initializes Sheldon in `.zshrc`, and removes all Antigen dependencies.
- Bootstrap now downloads GitHub tag archives directly and strips to the `src/` payload (no prebuilt dist/ tarball).

### Removed

- Removed `src/scripts/build_release.sh` and committed `dist/` artifacts; releases now rely on GitHub tag archives and a tag/commit-only workflow.

### Documentation

- Added `UPGRADING_TO_V2.md` outlining the v2 streaming behavior changes and compatibility notes.

## [1.6.0] - 2025-01-20

### Added

- **UV (Python package installer)** now installed on all platforms (macOS via Homebrew, Linux via official installer)
- **Brewfile-based package management** on macOS for declarative dependency installation
- **TTY detection** for color output - respects `NO_COLOR` environment variable and disables ANSI codes when output is redirected
- **Signal handling** (Ctrl+C) in install/update scripts - properly cleans up temp files and restores terminal state
- **Comprehensive cleanup traps** in spinner UI - prevents corrupted terminal on interrupts
- `FRANKLIN_FORCE_COLORS` and `FRANKLIN_DISABLE_COLORS` environment variables for color override
- Python virtual environment support (`python3-venv`) on Debian/Ubuntu
- Better error messages when installations are interrupted by user

### Changed

- **Core dependencies now required** (not optional) - Antigen, Starship, NVM, and UV must be installed successfully
- **macOS**: Uses `brew bundle` with Brewfile instead of individual package installs
- **Debian/Ubuntu**: Added bat to core packages (was optional), improved Starship fallback installer
- **Fedora/RHEL**: Added bat to core packages, improved Starship fallback installer
- **Exit codes**: Improved consistency - missing files/commands now use exit code 2 (user error) instead of 1
- **Stream handling**: Status messages in `franklin reload` now output to stderr instead of stdout
- Enhanced documentation in `versions.sh` with update instructions and release dates

### Fixed

- **Color codes no longer pollute pipes and redirects** - fixes CI/CD integration and scriptability
- **Terminal state properly restored on Ctrl+C** - no more hidden cursor or corrupted display
- **Temp files cleaned up on interrupt** - prevents orphaned files in `/tmp`
- `franklin reload` now starts a login shell (`exec zsh -l`), preserving login shell status so `logout` command works correctly
- `franklin reload` zsh not found error now uses exit code 2 instead of 1 (correct for user error)

### Documentation

- Added `INSTALL_WORKFLOW_DESIGN.md` - architectural design for v2.0 migration to Sheldon plugin manager
- Added `src/Brewfile` - declarative macOS dependency specification
- Updated `versions.sh` with inline update instructions and version comments

### Technical

This release completes **Phase 0 critical fixes** identified in architectural review, preparing Franklin for v2.0 development:

- CLI now follows Unix Philosophy (stdout for data, stderr for logs)
- Respects [no-color.org](https://no-color.org/) standard for accessibility
- Proper signal handling prevents resource leaks
- Exit codes follow standard conventions
- Scriptability improved: `franklin version | grep "1.5"` now works correctly

## [1.5.7] - 2025-01-15

### Changed

- MOTD banner now uses dual-color design (middle row background uses main background color, creating visual contrast with half-block borders)

## [1.5.6] - 2025-01-15

### Fixed

- UI section banners (install/update) now use consistent color (middle row background matches half-block character color)

## [1.5.5] - 2025-01-15

### Added

- `install` wrapper function for unified package installation across platforms (automatically uses brew/apt/dnf based on OS)
- `franklin reload` command to reload shell configuration (replaces standalone `reload()` function)
- `update-all.sh` now accepts `--franklin-only` to run just the Franklin core update step.
- `franklin update` uses the new flag so it only updates Franklin, while `franklin update-all` retains the full workflow entry point.

### Changed

- Moved `reload` functionality from standalone function to `franklin reload` subcommand, avoiding namespace conflicts with plugin aliases
- MOTD service status indicators now use colored ANSI dots (●) instead of emoji circles for better terminal compatibility

### Fixed

- MOTD service icons now include trailing space for better visual separation from service names
- MOTD memory calculation now uses floating-point arithmetic instead of integer division, fixing "0M" display when RAM usage is less than 1GB
- MOTD services grid now uses correct 1-indexed array access for zsh (was accessing empty cells[0] instead of cells[1])
- MOTD services grid now renders correctly by calculating visible length instead of including ANSI escape codes in length calculations
- MOTD service status icons now render properly (was outputting literal escape sequences instead of colored dots)
- MOTD now displays memory and disk usage in MB when values are less than 1GB (e.g., "512M/3G" instead of "0G/3G")

## [1.4.20] - 2025-01-15

### Fixed

- `.zshrc` now unaliases `reload` before defining the function, preventing "defining function based on alias" parse errors when Antigen plugins define a `reload` alias.
- `update-all.sh` now updates git-based Franklin installs even when the GitHub API is unreachable, falling back to direct `git pull` before checking release tarballs.
- Release status now falls back to the repo `VERSION` file when the GitHub API is unavailable, eliminating spurious "unable to check latest" warnings.
- `_motd_get_services` no longer assigns to zsh's read-only `status` parameter, fixing the "read-only variable: status" warning on Debian-based installs.
- Debian updates now revalidate `sudo` credentials before wrapping apt commands in the spinner, preventing hidden password prompts and apparent hangs.
- Version audit skips git-based Antigen upgrades when local modifications are present, logging a warning instead of failing the entire step.
- Debian installers fall back to the official Starship install script if `snap install starship` fails or snapd is unavailable, ensuring the prompt can be installed non-interactively.
- Antigen installs now clone the full upstream repository (respecting `FRANKLIN_ANTIGEN_VERSION`), ensuring `bin/antigen.zsh` exists and preventing "command not found: antigen" errors.
- `_motd_render_services` uses a non-reserved variable name so zsh no longer warns about `status` when printing services.
- Antigen downloads now use the official single-file endpoint (`https://git.io/antigen`), avoiding broken references to non-existent `bin/` scripts.
- `_motd_service_icon` no longer declares the reserved `status` variable, fixing residual "read-only variable: status" warnings on Debian systems.
- Existing Antigen installs referencing the deprecated `/bin/antigen.zsh` shim are automatically backed up and refreshed to the official single-file script, preventing "command not found: antigen" errors while preserving the legacy copy.
- `_motd_service_icon` now lowercases via `tr`, avoiding the "unrecognized modifier" error seen on older Debian zsh builds.
- `_motd_render_services` truncates long cells using portable arithmetic, eliminating "unrecognized modifier" crashes when drawing the services grid.
- `step_nvm` skips deleting active Node versions when pruning old releases, removing spurious "Failed to remove vXX.Y.Z" warnings on Debian hosts.
- Color helpers now auto-detect terminal capabilities, falling back to 256-color or basic ANSI palettes when truecolor isn't supported so Debian installers render cleanly.
- Truecolor detection now also checks `tput colors` (>= 16777216) so capable Debian terminals get 24-bit badges without needing `COLORTERM=truecolor`.
- UI color bindings now degrade gracefully: if primary Campfire colors aren't available (basic ANSI mode), badges fall back to secondary/neutral palettes instead of purple/gray blocks.
- Fixed a typo in the version audit so `fzf --version` output redirects to `/dev/null` (not `/divnull`), eliminating the Debian warning.
- Version audit now detects uv installs from `~/.local/bin/uv`, so Debian installs see uv as "system" once the official installer runs.
- System packages managed by apt/snap are now labeled as "lagging" instead of "update_available", acknowledging that Debian repos often trail upstream releases.

## [1.4.1] - 2024-11-14

### Fixed

- `update-all.sh` no longer complains about a blank option when run with no arguments (including via `franklin update`); the CLI loop now uses numeric comparison for argument parsing.

## [1.4.0] - 2024-11-14

### Added

- Introduced the `franklin` helper CLI so `franklin -v`, `franklin update`, and `franklin check` work from any shell without spelunking through the install directory.
- `update-all.sh` now self-updates Franklin (git pull or release tarball) so the core files stay in sync before other maintenance steps run.
- Added Python runtime and uv maintenance steps to `update-all.sh` so Homebrew/apt/dnf installs stay current alongside Node/npm.
- `.zshrc` now sources `~/.franklin.local.zsh` (or `FRANKLIN_LOCAL_CONFIG`) so you can keep private aliases outside the repo; the installer creates the stub automatically.
- MOTD automatically shows a Docker/services grid when containers are present or `MOTD_SERVICES` defines custom daemons to monitor.

### Changed

- **Simplified distribution architecture**: Franklin now ships as a single universal tarball instead of three OS-specific bundles, reducing build complexity while keeping runtime OS detection. The 18KB size difference is negligible compared to eliminated maintenance overhead.
- **Improved project structure**: Source files moved to `src/` directory for cleaner separation between code, tests, documentation, and project metadata. Follows standard conventions for modern projects.
- Completion caching now refreshes once every 24 hours via `FRANKLIN_ZCOMP_CACHE`, speeding up shell startup while keeping completions fresh.
- Spinner frames now reuse the padded badge formatter so the second column stays aligned with other log lines.

### Removed

- OS-specific build bundles (`franklin-macos.tar.gz`, `franklin-debian.tar.gz`, `franklin-fedora.tar.gz`) in favor of single `franklin.tar.gz` containing all platform scripts.
- `scripts/render_os_specific.py` and manifest generation logic—runtime detection handles OS differences cleanly.

## [1.2.3] - 2024-11-13

### Fixed

- Spinner logging now emits ANSI escapes via `%b` so Apple Terminal, Hyper, and other 24-bit terminals render animations correctly instead of printing literal `\033[...]` text.

## [1.2.2] - 2024-11-13

### Added

- Shared `franklin_ui_run_with_spinner` helper provides Campfire-themed animations, stdout-safe logging, and environment overrides for every Bash CLI.

### Changed

- `update-all.sh`, `install.sh`’s version audit, and the release pipeline now consume the centralized spinner helper so long-running steps stay modern without bespoke TTY logic.
- CLI style guide documents the spinner API plus `FRANKLIN_FORCE_SPINNER` / `FRANKLIN_DISABLE_SPINNER` / `FRANKLIN_UI_SPINNER_VERBOSE` for contributors.
- Spinner animation now automatically disables itself when running under CI/dumb terminals/`NO_COLOR`, and `scripts/release.sh` opts out by default so captured logs don’t show raw ANSI control codes.

## [1.2.0] - 2024-11-13

### Added

- Captured the Franklin CLI logging vision in `docs/CLI-UX-Improvement-Plan.md`, keeping the stream separation, badge catalog, and rollout checklist in one place.
- Published a comprehensive UI deep dive plus a CLI style guide so contributors can mirror the Campfire look across every script.

### Changed

- `install.sh`, `update-all.sh`, and all build/release tooling now route diagnostics through `lib/ui.sh`, respect a common `--quiet` flag, and render consistent badges/sections without polluting stdout.
- Release archives now ship the refreshed documentation set (CLI UX plan, UI deep dive, CLI style) so downstream bundles include the latest guidance by default.

## [1.1.5] - 2024-11-13

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

## [1.1.3] - 2024-11-13

### Changed

- `.zshrc` reintroduces OS-specific sections (keybindings, `ls` aliases) so Debian/Fedora bundles no longer inherit macOS defaults.

### Fixed

- MOTD color picker accepts shorthand/custom hex values (`eee`, `abc`, `123456`) with or without a leading `#`, both when using `--motd-color` and during the interactive installer prompt.

## [1.1.1] - 2024-11-13

### Changed

- Section banners in `install.sh` and `update-all.sh` now mirror the Campfire MOTD style exactly: top/bottom glyphs render without background color, and the middle fill uses the lighter Cello shade with base text color for improved contrast.

## [1.1.0] - 2024-11-13

### Added

- New `scripts/release.sh` automates stamping `VERSION`, building `dist/`, committing, tagging, and uploading GitHub releases (with `--dry-run`/`--no-upload` safety switches).

### Changed

- `update-all.sh` and `install.sh` now consume the shared Campfire UI helper (`lib/ui.sh`) so badges, section dividers, and colors match the MOTD banner everywhere.
- `scripts/build_release.sh` bundles the new UI helper, skips stray files (e.g., `CHANGELOG.md`), and continues to generate per-OS manifests from a clean staging tree.

### Fixed

- `scripts/check_versions.sh` no longer aborts when `npm` isn't on the PATH, so `update-all` completes cleanly even if NPM hasn't been initialized yet.

## [1.0.1] - 2024-11-12

### Added

- Show Franklin palette swatches in the installer to make color selection easier.
- Truecolor detection helper (`franklin_use_truecolor`) plus `FRANKLIN_FORCE_TRUECOLOR` / `FRANKLIN_DISABLE_TRUECOLOR` overrides so shells can force or skip 24-bit colors consistently.
- Automatic environment flagging (e.g., `FRANKLIN_FORCE_TRUECOLOR=1`) ensures the MOTD picks up truecolor palettes just like the installer preview.
- `MOTD_DEBUG_COLORS=1` prints the resolved banner hex, ANSI sequences, and text color so you can see exactly what the MOTD is emitting.
- Added VERSION file generation and helper scripts (`scripts/write_version_file.sh`, `scripts/current_franklin_version.sh`) so releases embed and expose the Franklin build identifier.
- Interactive MOTD color picker now uses a numbered menu (plus custom hex option) so invalid text entries can't accidentally reset the banner color.

### Changed

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

## [1.0.0] - 2024-11-12

### Added

- Initial public release of Franklin with macOS, Debian, and Fedora support, bundling Antigen, Starship, NVM, and a signature Campfire MOTD dashboard.
