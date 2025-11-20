# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Franklin is a Zsh shell configuration system that provides a consistent, themed shell environment across macOS, Debian/Ubuntu, and RHEL/Fedora. It manages plugin installation, shell configuration, and system updates through a unified interface.

## Build and Release Commands

```bash
# Test bootstrap installer (creates temporary install)
bash test/bootstrap-tests.sh

# Run platform detection tests
bash test/_os_detect_tests.sh

# Run installation tests (macOS-oriented)
bash test/test_install.sh

# Run MOTD tests
bash test/motd-tests.sh

# Create a new release (dry-run first recommended)
bash src/scripts/release.sh --dry-run v1.2.3
bash src/scripts/release.sh v1.2.3

# Update all tools and packages (for testing update flow)
bash src/update-all.sh --verbose
```

## Architecture

### Core Components

**Source Structure (`src/`)**
- `install.sh` - Main installation script with platform detection and backup creation
- `update-all.sh` - Unified update system for Franklin core, OS packages, and development tools
- `update-franklin.sh` - Updates only Franklin core files from GitHub
- `bootstrap.sh` - Network installer that downloads and executes install.sh
- `franklin` - CLI wrapper for common operations (update, check versions, etc.)
- `.zshrc` - Main Zsh configuration template that users get installed

**Library Modules (`src/lib/`)**
- `os_detect.sh` - Platform detection (macOS/Debian/Fedora), exports `OS_FAMILY` and `HAS_HOMEBREW`
- `install_helpers.sh` - Shared installation functions (Sheldon, Starship, NVM setup)
- `install_macos.sh` - macOS-specific package installation via Homebrew
- `install_debian.sh` - Debian/Ubuntu package installation via apt
- `install_fedora.sh` - Fedora/RHEL package installation via dnf
- `ui.sh` - Campfire-themed UI system with badges, streaming output helpers, and section headers
- `colors.sh` - Color palette definitions (Ember/Ash palettes + Campfire UI chrome)
- `versions.sh` - Pinned version constants for Starship, NVM
- `motd.zsh` - Message-of-the-day dashboard with system stats
- `motd-helpers.zsh` - Helper functions for MOTD rendering

**Build and Release (`src/scripts/`)**
- `release.sh` - Automated release workflow: stamps VERSION, commits, tags, pushes
- `check_versions.sh` - Version checking utility for Franklin and dependencies
- `current_franklin_version.sh` - Reads current Franklin version from VERSION file
- `write_version_file.sh` - Writes version to VERSION file during release

### Platform Abstraction

Platform-specific logic is isolated in `lib/install_*.sh` modules. The main installer (`install.sh`) sources `lib/os_detect.sh` to set `OS_FAMILY`, then delegates to the appropriate platform installer.

All platform installers follow the same contract:
- Idempotent (safe to re-run)
- Use package manager for system tools (brew/apt/dnf)
- Install or update Sheldon, Starship, NVM, Node LTS
- Log via `lib/ui.sh` helpers (`log_info`, `log_success`, `log_warning`, `log_error`)

### UI System

Franklin uses a consistent Campfire-themed UI across all scripts:
- **Badges**: Fixed-width colored labels (`[UPDATE]`, `[BUILD]`, etc.) via `franklin_ui_log`
- **Streaming**: `franklin_ui_stream_filtered` streams package manager output in `auto` (filtered), `quiet`, or `verbose` modes with hang detection
- **Section headers**: Divider lines via `franklin_ui_section`
- **Color palette**: Campfire theme (Cello/Terracotta/Black Rock) for non-banner UI chrome
- **MOTD palette**: User-selectable Ember/Ash palette for the dashboard banner

All UI functions respect `FRANKLIN_UI_QUIET=1` for suppressed output and `VERBOSE=1` for debug logs.

### Update System

`update-all.sh` implements a step-based update system with clear isolation:
1. Franklin core (pulls latest from GitHub)
2. OS packages (brew upgrade / apt upgrade / dnf upgrade)
3. Sheldon plugins (sheldon lock --update)
4. Starship (self-update)
5. Python + uv (package manager)
6. NVM + Node LTS (version manager)
7. npm global packages (npm update -g)

Each step:
- Runs in isolation with `set -e` error handling
- Streams filtered package manager output (default `auto` mode; `--mode=quiet|verbose` supported)
- Tracks success/failure counts
- Continues on non-critical failures (exits 1 for warnings, 2 for errors)

## Development Workflow

### Code Style

- **Shell scripts**: Use Bash with `set -euo pipefail`, indent with 2 spaces, quote all variable expansions (`"$var"`)
- **Functions/files**: snake_case naming (`step_franklin_core`, `install_debian_dependencies`)
- **Logging**: Use `franklin_ui_log` helpers from `lib/ui.sh`, not ad-hoc `echo`
- **Configuration**: ASCII only, avoid Unicode except for existing MOTD glyphs

### Testing Strategy

- **Unit tests**: `test/<feature>.sh` for platform detection, version checks, etc.
- **Smoke tests**: `test/smoke.zsh` for acceptance testing
- **Test mode**: Set `FRANKLIN_TEST_MODE=1` to suppress colorized output for assertions
- **Cross-platform**: Test on macOS + Debian/Fedora, or mock via `OS_FAMILY` overrides

### Commit Conventions

Follow conventional commits:
- `feat(scope)`: New features
- `fix(scope)`: Bug fixes
- `docs(scope)`: Documentation
- `test(scope)`: Tests
- `refactor(scope)`: Code refactoring
- `chore(scope)`: Maintenance

Scopes: `os_detect`, `install`, `update`, `ui`, `motd`, `release`

### Release Workflow

1. Update `CHANGELOG.md` under `[Unreleased]`
2. Ensure working tree is clean
3. Preview: `bash src/scripts/release.sh --dry-run vX.Y.Z`
4. Execute: `bash src/scripts/release.sh vX.Y.Z`

The release script:
- Writes version to `VERSION` file
- Commits with message `release: vX.Y.Z`
- Creates git tag
- Pushes commit + tag to origin

## Key Principles

1. **OS-aware bundles** - Single universal tarball with runtime OS detection
2. **Idempotent installs** - Re-running `install.sh` or `update-all.sh` is always safe
3. **Observable operations** - Long-running steps emit UI spinners; `--verbose` shows full output
4. **Minimal dependencies** - Stay POSIX-friendly, prefer shell/packager primitives
5. **Fast recovery** - Backups created before install (`~/.local/share/franklin/backups/<timestamp>`)

## Important Paths

- **Install root**: `~/.local/share/franklin` (default, configurable via `--install-root`)
- **User config**: `~/.config/franklin` (symlinked to install root)
- **Local overrides**: `~/.franklin.local.zsh` (user's private aliases/functions)
- **MOTD config**: `~/.config/franklin/motd.env` (stores user's color choice)
- **Backups**: `~/.local/share/franklin/backups/<timestamp>` (pre-install snapshots)

## Platform Detection

Platform detection happens in `lib/os_detect.sh` and exports:
- `OS_FAMILY`: `macos` | `debian` | `fedora`
- `HAS_HOMEBREW`: `true` | `false`

Detection order:
1. macOS: `uname -s` == "Darwin"
2. Linux: Parse `/etc/os-release` for `ID` field
   - Debian family: ubuntu, debian, pop, elementary, linuxmint, neon
   - Fedora family: fedora, rhel, rocky, alma

## Version Management

Version pins are in `src/lib/versions.sh`:
- `FRANKLIN_ANTIGEN_VERSION` / `FRANKLIN_ANTIGEN_URL`
- `FRANKLIN_STARSHIP_VERSION`
- `FRANKLIN_NVM_VERSION`
- `FRANKLIN_NODE_VERSION`

Update these constants when bumping dependency versions. The release script reads the root `VERSION` file for Franklin's version.
