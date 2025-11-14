# Changelog

All notable changes to this project will be documented in this file.

The format roughly follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project aims to follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `update-all.sh` now accepts `--franklin-only` to run just the Franklin core update step.
- `franklin update` uses the new flag so it only updates Franklin, while `franklin update-all` retains the full workflow entry point.

### Fixed

- `update-all.sh` now updates git-based Franklin installs even when the GitHub API is unreachable, falling back to direct `git pull` before checking release tarballs.
- Release status now falls back to the repo `VERSION` file when the GitHub API is unavailable, eliminating spurious “unable to check latest” warnings.
- `_motd_get_services` no longer assigns to zsh’s read-only `status` parameter, fixing the “read-only variable: status” warning on Debian-based installs.
- Debian updates now revalidate `sudo` credentials before wrapping apt commands in the spinner, preventing hidden password prompts and apparent hangs.
- Version audit skips git-based Antigen upgrades when local modifications are present, logging a warning instead of failing the entire step.
- Debian installers fall back to the official Starship install script if `snap install starship` fails or snapd is unavailable, ensuring the prompt can be installed non-interactively.
- Antigen installs now clone the full upstream repository (respecting `FRANKLIN_ANTIGEN_VERSION`), ensuring `bin/antigen.zsh` exists and preventing “command not found: antigen” errors.
- `_motd_render_services` uses a non-reserved variable name so zsh no longer warns about `status` when printing services.
- Antigen downloads now use the official single-file endpoint (`https://git.io/antigen`), avoiding broken references to non-existent `bin/` scripts.
- `_motd_service_icon` no longer declares the reserved `status` variable, fixing residual “read-only variable: status” warnings on Debian systems.
- Existing Antigen installs referencing the deprecated `/bin/antigen.zsh` shim are automatically backed up and refreshed to the official single-file script, preventing “command not found: antigen” errors while preserving the legacy copy.
- `_motd_service_icon` now lowercases via `tr`, avoiding the “unrecognized modifier” error seen on older Debian zsh builds.
- `_motd_render_services` truncates long cells using portable arithmetic, eliminating “unrecognized modifier” crashes when drawing the services grid.
- `step_nvm` skips deleting active Node versions when pruning old releases, removing spurious “Failed to remove vXX.Y.Z” warnings on Debian hosts.
- Color helpers now auto-detect terminal capabilities, falling back to 256-color or basic ANSI palettes when truecolor isn’t supported so Debian installers render cleanly.
- Truecolor detection now also checks `tput colors` (>= 16777216) so capable Debian terminals get 24-bit badges without needing `COLORTERM=truecolor`.
- UI color bindings now degrade gracefully: if primary Campfire colors aren’t available (basic ANSI mode), badges fall back to secondary/neutral palettes instead of purple/gray blocks.
- Fixed a typo in the version audit so `fzf --version` output redirects to `/dev/null` (not `/divnull`), eliminating the Debian warning.

## [1.4.1] - 2025-11-14

### Fixed

- `update-all.sh` no longer complains about a blank option when run with no arguments (including via `franklin update`); the CLI loop now uses numeric comparison for argument parsing.

## [1.4.0] - 2025-11-14

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
