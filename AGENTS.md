# Repository Guidelines

## Project Structure & Module Organization
- Core source lives under `src/`, including the primary shell scripts (`update-all.sh`, `install.sh`, `bootstrap.sh`), helper libraries in `src/lib/`, and user-facing config templates such as `src/.zshrc`.
- Install assets are pulled directly from GitHub tag archives; run-time installs mirror the `src/` layout under `~/.local/share/franklin`.
- Supporting assets: documentation (`README.md`, `CHANGELOG.md`), release tooling (`src/scripts/`), and tests under `test/` for shell helpers.

## Build, Test, and Development Commands
- `./src/scripts/release.sh vX.Y.Z`: Stamps `VERSION`, commits, tags, and pushes.
- `bash src/update-all.sh --help`: Quick sanity check to confirm argument parsing and step registration.
- Tests (when present): `bash test/<name>.sh`.

## Coding Style & Naming Conventions
- Shell scripts use Bash with `set -euo pipefail`; indent with two spaces and quote all variable expansions (`"$var"`).
- Functions and files are snake_case (`step_franklin_core`, `install_debian_dependencies`).
- Logging flows through `lib/ui.sh`; prefer `franklin_ui_log` helpers over ad-hoc `echo`.
- Configuration files remain ASCII; avoid Unicode unless already used (e.g., MOTD glyphs).

## Testing Guidelines
- Unit-style shell tests reside in `test/`; name scripts `test_<feature>.sh` and keep them idempotent.
- Validate interactive scripts by exercising their `--help` or dry-run modes; set `FRANKLIN_TEST_MODE=1` to suppress colorized output in assertions.
- When adding cross-platform logic, test on macOS plus at least one Debian/Fedora target or mock via `OS_FAMILY` overrides.

## Commit & Pull Request Guidelines
- Follow conventional, action-oriented messages (`fix: improve Franklin self-update`, `feat: add Franklin helper CLI`). Include `@codex` in commit bodies when collaborator access is needed.
- When authoring commits yourself, append a `Co-authored-by: Codex <noreply@openai.com>` trailer (per GitHub’s multi-author convention) so collaborator tracking is preserved automatically.
- Describe PRs with a concise summary, testing notes, and screenshots for UI-facing changes (e.g., MOTD adjustments).
- Reference related issues/tickets using “Fixes #123” syntax when applicable; ensure `CHANGELOG.md` receives an entry under `[Unreleased]`.
- **Slash command workflow**: when the user types a plain `release` request (optionally followed by a short description), interpret it as “stage all changes, craft the next semantic commit message (with `@codex` + `Co-authored-by: @codex`), rebuild, and run `./src/scripts/release.sh` with the next logical semver (patch/minor/major). Mention the chosen version in your response if the user didn’t specify one explicitly.
