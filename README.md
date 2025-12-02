# Franklin 🐢

[![Release](https://img.shields.io/github/v/release/jeremyfuksa/franklin?color=89b4fa&label=release)](https://github.com/jeremyfuksa/franklin/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-94e2d5)](LICENSE)
[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-blue)](#franklin-starter-pack)
[![Buy Me a Coffee](https://img.shields.io/badge/support-buy%20me%20a%20coffee-fab387)](https://buymeacoffee.com/jeremyfuksa)

Franklin is a cozy Zsh shell setup inspired by the cartoon turtle you probably read about as a kid. He keeps your shell lightweight, consistent, and portable. macOS and Linux installs auto-detect the right package manager (brew/apt/dnf) so each flavor gets the correct fit.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/jeremyfuksa/franklin/main/franklin/src/bootstrap.sh | bash
```

Pin a specific version and install path:

```bash
curl -fsSL https://raw.githubusercontent.com/jeremyfuksa/franklin/main/franklin/src/bootstrap.sh \
  | bash -s -- --dir "${HOME}/.local/share/franklin" --ref v2.0.0-beta-1
```

That's it—Franklin downloads his shell and gently asks about your preferred color palette along the way. Need automation? Use the flags below.

| Layer | Flag | Description |
| --- | --- | --- |
| bootstrap | `--ref <branch\|tag>` | Install from a specific ref (default: `main`) |
| bootstrap | `--dir <path>` | Install location (default: `~/.local/share/franklin`) |

Franklin signature color names ([Campfire](https://github.com/jeremyfuksa/campfire) palettes): `clay`, `flamingo`, `terracotta`, `ember`, `golden-amber`, `hay`, `sage`, `moss`, `pine`, `cello`, `blue-calx`, `dusk`, `mauve-earth`, `stone`. You can pin `ember:clay`, `ash:cello`, or any `#rrggbb`.

Prefer cloning?

```bash
git clone https://github.com/jeremyfuksa/franklin ~/.config/franklin
cd ~/.config/franklin
bash install.sh
```

## Franklin Starter Pack

| Component | Notes |
| --- | --- |
| Zsh + Sheldon | Franklin keeps a tidy `.zshrc` and installs anything missing. |
| Starship prompt | Configured via `starship.toml`; auto-enabled for a snappy shell. |
| bat / batcat | Syntax-highlighted `cat` replacement; Franklin aliases `cat` ⇒ `bat`. |
| fzf, ripgrep | Included on Linux for quick fuzzy search and grepping. |
| NVM + Node LTS | Installed/pinned via `install.sh` & `update-all.sh`. |
| MOTD dashboard | Franklin Campfire banner with host/OS/disk/memory details. Toggle with `FRANKLIN_ENABLE_MOTD` / `FRANKLIN_SHOW_MOTD_ON_LOGIN`. |
| Fonts | MOTD status icons (``, ``, turtle) require a Nerd Font (e.g., Dank Mono Nerd Font). |
| Campfire UI palette | Non-banner UI chrome (install/update logs, badges) uses the Campfire palette (Cello/Terracotta/Black Rock) for consistent Franklin branding. |

Everything lives under your install dir (default `~/.local/share/franklin`) with configs in `~/.config/franklin`. The installer detects your OS (macOS, Debian/Ubuntu, Fedora, or any Linux with apt/dnf) and runs the appropriate setup. Before touching your existing setup, it backs up `.zshrc`, `.zshenv`, `.zprofile`, your sheldon config, and `~/.config/starship.toml` to `~/.local/share/franklin/backups/<timestamp>`.

## Daily Moves

| Command | Purpose |
| --- | --- |
| `update-all.sh` | Streams real-time progress while updating Franklin core files, OS packages (brew/apt/dnf), Sheldon plugins, Starship, Python, uv, NVM, Node, npm globals, and version pins. Detects your OS, filters noisy output in `auto` mode, and accepts `--mode=quiet|auto|verbose`. |
| `franklin` | Helper CLI wrapper; use `franklin update` for Franklin core only (via `update-franklin.sh`), `franklin update-all` for everything else, plus `franklin check`/`-v`. |
| `motd` | Renders the Franklin dashboard on demand; auto-runs at login unless disabled. |
| `reload` | Re-sources `.zshrc` after edits—Franklin's equivalent of poking his head out and checking his surroundings. |

## Customization

- **Banner color**: on first interactive run you’ll be prompted; change anytime via `franklin config --color <name|#hex>` or edit `~/.config/franklin/config.env`. Signature names: `clay`, `flamingo`, `terracotta`, `ember`, `golden-amber`, `hay`, `sage`, `moss`, `pine`, `cello`, `blue-calx`, `dusk`, `mauve-earth`, `stone`.
- **Prompt/plugins**: edit `starship.toml` or drop additional scripts in `~/.config/franklin/` and source them from `.zshrc`.
- **Local overrides**: customize Franklin without touching the managed `.zshrc` by editing `~/.franklin.local.zsh`. The installer auto-creates this file with commented examples for common options (MOTD flags, update defaults, backup directory, NVM/Node `PATH`, and custom aliases); uncomment and tweak the lines you need. Set `FRANKLIN_LOCAL_CONFIG` to point at a different file if you want to relocate your overrides.
- **MOTD services**: Docker containers are detected automatically; add `MONITORED_SERVICES="nginx,postgresql,redis"` (comma-separated) to `~/.config/franklin/config.env` to track additional systemd/launchd services in the dashboard.
- **Backups**: set `FRANKLIN_BACKUP_DIR=/path/to/dir` before installing if you want backups elsewhere.
- **Streaming defaults**: create `~/.config/franklin/update.env` with `FRANKLIN_UPDATE_MODE=quiet` (or `auto`/`verbose`) and `FRANKLIN_UPDATE_TIMEOUT=600` to set your preferred `update-all.sh` mode globally.

## Troubleshooting

| Issue | Fix |
| --- | --- |
| `update-all.sh` complains about missing package manager | Install Homebrew/apt/dnf, then rerun. |
| MOTD doesn’t show | Ensure `FRANKLIN_ENABLE_MOTD=1` and `FRANKLIN_SHOW_MOTD_ON_LOGIN=1`, then run `motd` to verify. |
| Wrong color | Prefer `franklin config --color <name|#hex>`; or edit `~/.config/franklin/config.env`. |
| Need to reinstall | Remove `~/.config/franklin` and `~/.local/share/franklin`, then rerun the bootstrapper. |
| Mixed stdout/stderr | UI logs go to stderr by design; pipe `franklin ... --json` output from stdout. |

## Development

Working on Franklin itself (not just using it)?

```bash
# Bootstrap smoke test (uses a GitHub-style archive from HEAD)
bash test/bootstrap-tests.sh

# Legacy installer tests (macOS-oriented)
bash test/test_install.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for coding style, release expectations, and PR guidelines.

## Release Workflow

For v2.x, releases are tagged and published on GitHub:

1. Ensure `CHANGELOG.md` has the new entry.
2. Update `VERSION` and `pyproject.toml`.
3. Tag (`vX.Y.Z`) and push; draft the GitHub release from the tag with summary notes.

## License & Credits

MIT License. Check out the source at [github.com/jeremyfuksa/franklin](https://github.com/jeremyfuksa/franklin).

Franklin stands on the shoulders of:
- [Sheldon](https://github.com/rossmacarthur/sheldon) for plugin management
- [Starship](https://github.com/starship/starship) for the prompt
- [NVM](https://github.com/nvm-sh/nvm) for Node versioning
