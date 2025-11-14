# Franklin 🐢

[![Release](https://img.shields.io/github/v/release/jeremyfuksa/franklin?color=89b4fa&label=release)](https://github.com/jeremyfuksa/franklin/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-94e2d5)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Debian%20%7C%20RHEL-blue)](#franklin-starter-pack)
[![Buy Me a Coffee](https://img.shields.io/badge/support-buy%20me%20a%20coffee-fab387)](https://buymeacoffee.com/jeremyfuksa)

Franklin is a cozy Zsh shell setup inspired by the cartoon turtle you probably read about as a kid. He takes great care of his shell, keeps it lightweight, and never carries more than he needs. macOS, Debian/Ubuntu, and RHEL/Fedora each get their own streamlined bundle, so your machine only wears the shell it deserves.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/jeremyfuksa/franklin/main/bootstrap.sh | bash
```

That's it—Franklin downloads his shell and gently asks about your palette along the way. Need automation? Use the flags below.

| Layer | Flag | Description |
| --- | --- | --- |
| bootstrap | `--release <tag>` | Install a specific GitHub release (default: latest) |
| bootstrap | `--install-root <dir>` | Where to unpack Franklin (default: `~/.local/share/franklin`) |
| bootstrap | `--owner <name>` / `--repo <name>` | Point at a fork or alternate repo |
| bootstrap | `--archive <url>` | Use a custom tarball URL (skips release lookup) |
| install | `--motd-color <name\|palette:name\|#hex>` | Skip the interactive prompt and pin a Franklin signature color (Ember/Ash palettes) |
| install | `--verbose` | Show debug output during install |

Franklin signature color names (Ember/Ash palettes): `clay`, `flamingo`, `terracotta`, `ember`, `golden-amber`, `hay`, `sage`, `moss`, `pine`, `cello`, `blue-calx`, `dusk`, `mauve-earth`, `stone`. You can pin `ember:clay`, `ash:cello`, or any `#RRGGBB`.

Prefer cloning?

```bash
git clone https://github.com/jeremyfuksa/franklin ~/.config/franklin
cd ~/.config/franklin
bash install.sh
```

## Franklin Starter Pack

| Component | Notes |
| --- | --- |
| Zsh + Antigen | Franklin keeps a tidy `.zshrc` and installs anything missing. |
| Starship prompt | Configured via `starship.toml`; auto-enabled for a snappy shell. |
| bat / batcat | Syntax-highlighted `cat` replacement; Franklin aliases `cat` ⇒ `bat`. |
| fzf, ripgrep | Included on Linux for quick fuzzy search and grepping. |
| NVM + Node LTS | Installed/pinned via `install.sh` & `update-all.sh`. |
| MOTD dashboard | Franklin Campfire banner with host/OS/disk/memory details. Toggle with `FRANKLIN_ENABLE_MOTD` / `FRANKLIN_SHOW_MOTD_ON_LOGIN`. |
| Fonts | MOTD status icons (``, ``, turtle) require a Nerd Font (e.g., Dank Mono Nerd Font). |
| Campfire UI palette | Non-banner UI chrome (install/update logs, badges) uses the Campfire palette (Cello/Terracotta/Black Rock) for consistent Franklin branding. |

Everything lives under `~/.config/franklin` (or your `--install-root`). The installer detects your OS (macOS, Debian/Ubuntu, or Fedora) and runs the appropriate setup. Before touching your existing setup, it backs up `.zshrc`, `.zshenv`, `.zprofile`, Antigen, and `~/.config/starship.toml` to `~/.local/share/franklin/backups/<timestamp>`.

## Daily Moves

| Command | Purpose |
| --- | --- |
| `update-all.sh` | Updates Franklin core files plus OS packages (brew/apt/dnf), Antigen, Starship, Python, uv, NVM, Node, npm globals, and version pins. Detects your OS and runs the appropriate update logic. |
| `franklin` | Helper CLI wrapper; use `franklin update` for Franklin core only (via `update-franklin.sh`), `franklin update-all` for everything else, plus `franklin check`/`-v`. |
| `motd` | Renders the Franklin dashboard on demand; auto-runs at login unless disabled. |
| `reload` | Re-sources `.zshrc` after edits—Franklin's equivalent of poking his head out and checking his surroundings. |

## Customization

- **Banner color**: rerun `install.sh --motd-color <name|palette:name|#hex>` or edit `~/.config/franklin/motd.env`. See the Quick Start table for Franklin signature names.
- **Prompt/plugins**: edit `starship.toml` or drop additional scripts in `~/.config/franklin/` and source them from `.zshrc`.
- **Local overrides**: add private aliases/functions to `~/.franklin.local.zsh` (auto-created, sourced after Franklin loads). Set `FRANKLIN_LOCAL_CONFIG` before install to change the path.
- **MOTD services**: Docker containers are detected automatically; set `MOTD_SERVICES=(nginx postgresql redis)` (array or space-separated string) to track additional systemd/launchd services in the dashboard.
- **Backups**: set `FRANKLIN_BACKUP_DIR=/path/to/dir` before installing if you want backups elsewhere.

## Troubleshooting

| Issue | Fix |
| --- | --- |
| `update-all.sh` complains about missing package manager | Install Homebrew/apt/dnf, then rerun. |
| MOTD doesn’t show | Ensure `FRANKLIN_ENABLE_MOTD=1` and `FRANKLIN_SHOW_MOTD_ON_LOGIN=1`, then run `motd` to verify. |
| Wrong color | Edit `~/.config/franklin/motd.env` or rerun installer with `--motd-color`. |
| Need to reinstall | Remove `~/.config/franklin` and `~/.local/share/franklin`, then rerun the bootstrapper. |

## Development

Working on Franklin itself (not just using it)?

```bash
# Build release artifacts
bash src/scripts/build_release.sh

# Ensure bootstrap flow works on your OS
bash test/bootstrap-tests.sh

# Legacy installer tests (macOS-oriented)
bash test/test_install.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for coding style, release expectations, and PR guidelines.

## Release Workflow

Franklin now ships with an automated release helper:

```bash
# Dry run to see what would happen
src/scripts/release.sh --dry-run v1.1.0

# Real release (stamps VERSION, builds dist/, commits, tags, uploads via gh)
src/scripts/release.sh v1.1.0
```

Before running the script:

1. Make sure `CHANGELOG.md` has an entry for the new version.
2. Commit all work (the release script requires a clean tree).
3. Ensure you are authenticated with GitHub CLI (`gh auth status`).

The script creates the commit (`release: vX.Y.Z`), tags it, pushes to `origin`, and uploads `dist/franklin.tar.gz` to a brand-new GitHub release. Use `--no-upload` if you only want the git/tag portion.

## License & Credits

MIT License. Check out the source at [github.com/jeremyfuksa/franklin](https://github.com/jeremyfuksa/franklin).

Franklin stands on the shoulders of:
- [Antigen](https://github.com/zsh-users/antigen) for plugin management
- [Starship](https://github.com/starship/starship) for the prompt
- [NVM](https://github.com/nvm-sh/nvm) for Node versioning
