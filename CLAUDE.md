# CLAUDE.md

This file provides guidance to AI coding assistants (Claude, Codex, Warp, etc.) when working with this repository.

## Project Overview

Franklin is a Zsh shell configuration system that provides a consistent, themed shell environment across macOS, Debian/Ubuntu, and RHEL/Fedora. It ships as a **Python package** (Typer CLI + Rich UI) with shell bootstrap/install wrappers.

## Project Structure

```
franklin/
├── bin/franklin          # POSIX sh shim that invokes the Python CLI
├── config/
│   ├── plugins.toml      # Sheldon plugin configuration
│   └── starship.toml     # Starship prompt configuration
├── src/
│   ├── bootstrap.sh      # Network installer (Stage 1)
│   ├── install.sh        # Environment setup (Stage 2)
│   └── lib/
│       ├── __init__.py
│       ├── constants.py  # Paths, colors, glyphs
│       ├── main.py       # Typer CLI entrypoint
│       ├── motd.py       # MOTD banner rendering
│       └── ui.py         # Campfire UI helpers (Rich)
│       └── ui.sh         # Campfire UI helpers (Bash)
├── templates/
│   └── zshrc.zsh         # Zsh template installed to ~/.zshrc
├── pyproject.toml        # Python package definition
└── requirements.txt      # Python dependencies
test/
├── test_cli.py           # Pytest CLI smoke tests
├── ui-demo.sh            # UI visual demo
└── sheldon-diagnostic.sh # Plugin manager diagnostic
VERSION                   # Current version (read by CLI)
```

## CLI Commands

The `franklin` CLI provides these commands:

| Command | Description |
|---------|-------------|
| `franklin doctor [--json]` | Run diagnostic checks on the environment |
| `franklin update [--dry-run] [--yes]` | Update Franklin core from git |
| `franklin update-all [--dry-run] [--system]` | Update core, plugins, and optionally system packages |
| `franklin config [--color NAME]` | Configure MOTD color interactively or via flag |
| `franklin motd` | Display the Message of the Day banner |
| `franklin --version` | Show version |

## Development Workflow

### Setup

```bash
# Create and activate venv
cd franklin
python3 -m venv .venv
source .venv/bin/activate
pip install -e .

# Run CLI during development
PYTHONPATH=franklin/src python -m lib.main doctor
# Or via installed entrypoint:
franklin doctor
```

### Testing

```bash
# Run pytest tests
pytest test/test_cli.py -v

# Test installer (non-interactive)
bash franklin/src/install.sh --non-interactive --color Cello

# Test bootstrap
bash franklin/src/bootstrap.sh --dir /tmp/franklin-test --ref main
```

## Code Style

### Python
- Use Typer for commands; keep docstrings short
- Route all UI through `CampfireUI` (from `lib.ui`) so stdout stays clean for `--json`
- Reuse glyph/color constants from `lib.constants`
- Config persists as key/value in `~/.config/franklin/config.env`

### Shell (Bash)
- Use `set -euo pipefail` at the top
- Quote all variable expansions (`"$var"`)
- Source shared UI from `lib/ui.sh` (install.sh) or use minimal inline (bootstrap.sh)
- Keep FRANKLIN_ROOT/CONFIG paths consistent with `constants.py`

### UI Conventions (Campfire)
- **Hierarchy**: Headers (`⏺`) → Branches (`⎿`) → Logic (`∴`)
- **Colors**: Error (red), Success (green), Warning (yellow), Info (blue)
- **Stream separation**: UI to stderr, machine-readable data to stdout
- **TTY-aware**: Respect `NO_COLOR` and `FRANKLIN_NO_COLOR` env vars

## Commit Conventions

Follow conventional commits:
- `feat(scope)`: New features
- `fix(scope)`: Bug fixes  
- `docs(scope)`: Documentation
- `test(scope)`: Tests
- `refactor(scope)`: Code refactoring
- `chore(scope)`: Maintenance

Scopes: `cli`, `install`, `update`, `ui`, `motd`, `config`

## Release Workflow

1. Update `CHANGELOG.md` under `[Unreleased]`
2. Sync version in `VERSION` and `franklin/pyproject.toml`
3. Commit: `release: vX.Y.Z`
4. Tag: `git tag vX.Y.Z && git push origin main --tags`
5. Create GitHub release from tag

## Key Principles

1. **Idempotent installs** - Re-running `install.sh` is always safe
2. **Observable operations** - UI feedback via Campfire glyphs
3. **Cross-platform** - Single codebase detects macOS/Debian/Fedora at runtime
4. **Fast recovery** - Backups at `~/.local/share/franklin/backups/<timestamp>`
5. **Clean stdout** - Machine-readable output (JSON) on stdout; UI on stderr

## Important Paths

| Path | Purpose |
|------|--------|
| `~/.local/share/franklin` | Install root |
| `~/.config/franklin/config.env` | User configuration (MOTD color, etc.) |
| `~/.franklin.local.zsh` | User's private overrides (sourced by zshrc) |
| `~/.local/share/franklin/backups/` | Pre-install backup snapshots |

## Platform Detection

Platform detection in `main.py:_detect_os_family()` returns:
- `macos` - Darwin systems
- `debian` - Ubuntu, Debian, Pop!_OS, Mint, etc.
- `fedora` - Fedora, RHEL, Rocky, Alma, CentOS
- `unknown` - Unsupported

The shell installer (`install.sh`) uses equivalent logic inline.

## Agent Personas

Detailed persona briefs for AI agents live in `.codex/agents/`:
- `cli-architect.md` - CLI UX and flag design
- `unix-polyglot.md` - Cross-platform portability
- `docs-architect.md` - Information architecture
- `franklin-architect.md` - Franklin-specific domain knowledge
