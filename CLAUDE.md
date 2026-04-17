# CLAUDE.md

This file provides guidance to AI coding assistants (Claude, Codex, Warp, etc.) when working with this repository.

## Project Overview

Franklin is a Zsh shell configuration system that provides a consistent, themed shell environment across macOS, Debian/Ubuntu, and RHEL/Fedora. It ships as a **Python package** (Typer CLI + Rich UI) with shell bootstrap/install wrappers.

## Project Structure

```
franklin/
├── bin/franklin          # POSIX sh shim that invokes the Python CLI
├── config/
│   ├── mise.toml         # mise-managed Node/Python versions
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
# Accepts: --non-interactive / --color NAME / --with-claude / --no-claude
# Color NAME is case- and separator-insensitive: "ember", "Ember", "mauve-earth", "Mauve Earth" all resolve.
bash franklin/src/install.sh --non-interactive --color cello --no-claude

# Test bootstrap
bash franklin/src/bootstrap.sh --dir /tmp/franklin-test --ref main
```

### Runtime managers bundled by install.sh

- **mise** — manages Node and Python versions via `franklin/config/mise.toml` (symlinked to `~/.config/mise/config.toml`). Installed by `install.sh` if absent.
- **eza** — modern `ls` replacement; installed via the platform package manager where available (macOS brew / apt 24.04+ / dnf 38+), best-effort with a graceful fallback to plain `ls` on older distros.
- **Claude Code** — optional via `install.sh --with-claude`; uses Anthropic's native installer, no Node dependency.

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
- **Colors**: Error (Flamingo), Success (Sage), Warning (Golden Amber), Info (Cello) — all pulled from Campfire semantic-500 values. Source of truth: `constants.py` (`UI_*_COLOR`) and `lib/ui.sh` (`COLOR_*`).
- **MOTD palette**: `CAMPFIRE_COLORS` mirrors the Campfire signature palette — 14 names (Cello, Terracotta, Sage, Golden Amber, Flamingo, Blue Calx, Clay, Ember, Hay, Moss, Pine, Dusk, Mauve Earth, Stone) plus `Black Rock` as a legacy alias for Stone. Variants (`base`/`dark`/`light`) come from the upstream 11-step scales; only Blue Calx uses scale-100 for `light` because the info scale is compressed.
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

When the user asks to cut a release — any phrasing ("cut a release", "ship v2.1.3", "tag and publish") — the assistant runs the full playbook below. The user's only manual steps are to merge the PR and (until the git-proxy blocker is lifted) push the tag and click Publish. The assistant never hands off changelog curation, version math, or SHA lookup.

### Step 1 — Agent: open the release PR

1. Decide the version.
   - **Patch** (`X.Y.Z+1`): only fixes, tiny UX refinements, docs.
   - **Minor** (`X.Y+1.0`): new user-visible features, CLI subcommands/flags, install dependencies.
   - **Major** (`X+1.0.0`): breaking changes to flags, config formats, CLI contracts, or install layout.
   - Ask the user when `[Unreleased]` is ambiguous; default to patch otherwise.
2. Branch from tip of `main`: `claude/release-vX.Y.Z`.
3. Update:
   - `VERSION` → `X.Y.Z`
   - `franklin/pyproject.toml` → `version = "X.Y.Z"`
   - `CHANGELOG.md` → promote `[Unreleased]` to `[X.Y.Z] - <today>` and leave a fresh empty `[Unreleased]` block above it.
4. Commit with `release: vX.Y.Z` and a body summarising the changes since the prior tag (grouped by PR).
5. Push and open the PR (title: `release: vX.Y.Z`).

### Step 2 — User: merge the release PR

Standard "merge commit" method (matches every prior Franklin release).

### Step 3 — Agent: tag and prepare the publish kit

After the merge webhook fires, the assistant:

1. `git checkout main && git pull origin main` to fast-forward locally.
2. `git tag -a vX.Y.Z <merge-sha> -m "Franklin vX.Y.Z"` on the merge commit.
3. Attempts `git push origin vX.Y.Z`. **This currently 403s** because the localhost git proxy filters `refs/tags/*` pushes (see "Known blocker" below).

**Regardless of whether the tag push succeeded**, the assistant posts a single "publish kit" message with:

- The merge SHA.
- A ready-to-run snippet for the user's local machine:
  ```bash
  git fetch origin
  git tag -a vX.Y.Z <merge-sha> -m "Franklin vX.Y.Z"
  git push origin vX.Y.Z
  ```
- The direct-click URL: `https://github.com/jeremyfuksa/franklin/releases/new?tag=vX.Y.Z`
- The release **title**: `Franklin vX.Y.Z`.
- The release **body**: ready-to-paste Markdown pulled from the new CHANGELOG section, reorganised into a short "Highlights" summary at the top with a link back to the CHANGELOG for the full detail block.

### Step 4 — User: push the tag and publish

1. Run the three-line `git` snippet from the publish kit.
2. Open the URL from the publish kit.
3. Paste title (if not already pre-filled) and body.
4. Click **Publish release**.

### Known blocker: tag push 403

The localhost git proxy at `http://local_proxy@127.0.0.1:<port>/…` currently allows branch pushes but rejects `refs/tags/*` with HTTP 403. Once its ref-allowlist is relaxed to include tags, Step 3's push will succeed and the agent can (a) push the tag directly, (b) call `mcp__github__create_release` (once that tool is exposed by the MCP server's `repos` toolset), and skip the user's tag-push+click loop entirely.

### Cross-project note

This playbook lives in this repo's `CLAUDE.md`, so it applies to Franklin only. To get the same behaviour in another project, mirror this section into that project's `CLAUDE.md` (or add it to `~/.claude/CLAUDE.md` for every session, repo-agnostic).

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
