# Franklin v2.1 - Proposed Features

This document outlines 5 recommended features for Franklin v2.1, identified through codebase analysis on 2025-11-22.

## 1. Backup & Restore Management

### Current State
- Installation creates timestamped backups in `~/.local/share/franklin/backups/<timestamp>/`
- No CLI interface to list, restore, or manage these backups
- Users must manually navigate backup directories to restore files

### Proposed Feature
Add `franklin backup` command with subcommands:

```bash
# List available backups
franklin backup list

# Restore from a specific backup
franklin backup restore <timestamp>

# Create a manual backup before risky changes
franklin backup create [--tag "description"]

# Clean up old backups (keep last N)
franklin backup prune --keep 5

# Show what's in a backup
franklin backup show <timestamp>
```

### Implementation Notes
- Extend `lib/main.py` with new `backup` command group
- Store backup metadata (timestamp, reason, pre/post state) in JSON manifest
- Implement selective restore (e.g., restore only .zshrc, not all files)
- Add safety checks to prevent overwriting current config without confirmation

### Benefits
- Users can safely experiment with Franklin configurations
- Recovery from misconfigurations becomes trivial
- Backup management becomes discoverable through CLI
- Reduces support burden for "how do I undo this?"

---

## 2. Plugin Management Interface

### Current State
- Plugins defined in `franklin/config/plugins.toml`
- Users must manually edit TOML to add/remove plugins
- No validation of plugin sources or syntax until Sheldon runs
- No way to discover popular/recommended plugins

### Proposed Feature
Add `franklin plugin` command with subcommands:

```bash
# List currently installed plugins
franklin plugin list

# Add a new plugin from GitHub
franklin plugin add zsh-users/zsh-completions

# Remove a plugin
franklin plugin remove zsh-completions

# Search/browse popular plugins
franklin plugin search <keyword>

# Show plugin details and documentation
franklin plugin info zsh-autosuggestions

# Update plugins.toml from a curated preset
franklin plugin preset minimal|standard|power-user
```

### Implementation Notes
- Parse and modify `plugins.toml` programmatically using Python `toml` library
- Maintain a curated registry of recommended plugins (JSON/YAML in repo)
- Validate plugin sources before adding (check GitHub URL exists)
- Run `sheldon lock --update` automatically after changes
- Show before/after diffs when modifying plugins

### Benefits
- Lowers barrier to plugin customization
- Prevents TOML syntax errors from manual editing
- Promotes plugin discovery and sharing
- Makes Franklin more approachable for new users

---

## 3. Environment Profiles/Contexts

### Current State
- Single `.zshrc` configuration for all contexts
- Users who want different setups (work/personal/dev) must maintain custom scripts
- No built-in way to switch between configurations
- `~/.franklin.local.zsh` exists but is all-or-nothing

### Proposed Feature
Add profile/context system with `franklin profile` commands:

```bash
# Create a new profile
franklin profile create work

# Switch active profile
franklin profile switch personal

# List available profiles
franklin profile list

# Copy current profile as starting point
franklin profile clone default minimal

# Edit profile-specific settings
franklin profile edit work

# Show current profile
franklin profile current
```

### Implementation Notes
- Store profiles in `~/.config/franklin/profiles/<name>/`
- Each profile has its own:
  - `plugins.toml` (subset of available plugins)
  - `local.zsh` (profile-specific aliases/functions)
  - `config.env` (profile-specific environment variables)
- Symlink active profile files into main config directory
- Switching profiles = update symlinks + reload shell
- Support profile inheritance (e.g., "work" extends "default")

### Benefits
- Clean separation between work/personal configurations
- Easy experimentation without breaking main setup
- Share profiles via dotfiles repos or export/import
- Supports specialized contexts (e.g., "presentation" mode with minimal prompt)

---

## 4. Auto-Repair & Health Monitoring

### Current State
- `franklin doctor` checks for required tools and reports issues
- No automated repair of detected problems
- Users must manually install missing dependencies
- Exit code indicates failure but doesn't suggest fixes

### Proposed Feature
Enhance `franklin doctor` with repair capabilities:

```bash
# Run diagnostics and auto-fix issues (interactive)
franklin doctor --fix

# Auto-repair without prompts (CI/automation)
franklin doctor --fix --yes

# Watch mode: continuously monitor and alert
franklin doctor --watch

# Export health report
franklin doctor --json > health-report.json

# Check specific subsystem
franklin doctor --check plugins
franklin doctor --check shell
franklin doctor --check dependencies
```

### Implementation Notes
- Extend existing `doctor()` function in `lib/main.py`
- For each check failure, add corresponding repair action:
  - Missing Sheldon → Install via package manager or cargo
  - Missing Starship → Install via package manager or official script
  - Missing bat → Install via package manager
  - Corrupt plugins.toml → Restore from backup or regenerate from defaults
- Add repair strategy registry (check → repair function mapping)
- Implement repair dry-run mode to preview actions
- Log all repair actions to `~/.config/franklin/doctor.log`

### Benefits
- Reduces friction when tools become outdated or misconfigured
- Self-healing system reduces support burden
- Useful for onboarding on new machines (doctor --fix after install)
- CI/automation-friendly with `--json` output for monitoring

---

## 5. Uninstall & Restoration

### Current State
- No official uninstall procedure documented
- Users must manually remove:
  - `~/.local/share/franklin/`
  - `~/.config/franklin/`
  - Symlinked `.zshrc`
  - Franklin CLI from PATH
- No way to restore pre-Franklin shell configuration

### Proposed Feature
Add `franklin uninstall` command:

```bash
# Interactive uninstall with confirmation
franklin uninstall

# Uninstall and restore original configs
franklin uninstall --restore

# Keep configs but remove Franklin CLI
franklin uninstall --keep-config

# Complete purge (configs + backups + cache)
franklin uninstall --purge

# Dry-run to preview what would be removed
franklin uninstall --dry-run
```

### Implementation Notes
- Create new `uninstall()` command in `lib/main.py`
- Steps:
  1. Confirm action with user (unless `--yes`)
  2. Find most recent backup (if `--restore`)
  3. Remove Franklin-managed symlinks
  4. Restore original files from backup (if available)
  5. Remove Franklin directories:
     - `~/.local/share/franklin/`
     - `~/.config/franklin/`
     - Virtual environment
  6. Remove Franklin CLI from PATH (if installed via bootstrap)
  7. Print summary of removed items and next steps
- Add `--keep-plugins` option to preserve Sheldon plugins
- Generate uninstall report (what was removed, what was restored)

### Benefits
- Clean, reversible installation experience
- Reduces commitment anxiety for new users ("I can always uninstall")
- Professional polish expected of modern CLI tools
- Makes Franklin suitable for trial/evaluation on shared systems

---

## Implementation Priority

Recommended order for v2.1 development:

1. **Uninstall & Restoration** (P0) - Foundational UX, builds trust
2. **Auto-Repair & Health Monitoring** (P0) - Reduces support burden significantly
3. **Backup & Restore Management** (P1) - Natural companion to uninstall
4. **Plugin Management Interface** (P1) - High user value, moderate complexity
5. **Environment Profiles** (P2) - Advanced feature, appeals to power users

## Testing Considerations

Each feature should include:
- Unit tests for core logic (Python `pytest`)
- Integration tests on all supported platforms (macOS, Debian, Fedora)
- Smoke tests in CI (GitHub Actions)
- Documentation updates (README, CONTRIBUTING, inline help)
- Changelog entries

## Breaking Changes

None of these features introduce breaking changes. All are additive enhancements to the existing CLI.

## Estimated Effort

- Feature 1 (Backup): ~2-3 days
- Feature 2 (Plugins): ~3-4 days
- Feature 3 (Profiles): ~4-5 days
- Feature 4 (Doctor): ~2 days
- Feature 5 (Uninstall): ~1-2 days

Total: ~12-16 days of focused development

## Related Issues

Before implementing, check GitHub issues for:
- User requests for these features
- Alternative proposals or design ideas
- Platform-specific constraints or requirements

---

**Document Status**: Draft proposal for discussion
**Author**: Claude (AI Assistant)
**Date**: 2025-11-22
**Version**: Franklin 2.0.0 → 2.1.0
