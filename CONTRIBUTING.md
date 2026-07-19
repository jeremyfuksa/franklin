# Contributing to Franklin

Thank you for your interest in contributing to Franklin! This guide explains how to contribute effectively.

## 🤝 Code of Conduct

We are committed to providing a welcoming and inspiring community for all. Please read and adhere to our Code of Conduct:

- Be respectful and inclusive
- Be patient and helpful with new contributors
- Focus on what is best for the community
- Show empathy towards other community members

## 📋 Before You Start

### Understanding the Project

Before contributing, familiarize yourself with:
- [README.md](README.md) – Install flow, daily usage, and troubleshooting
- [CLAUDE.md](CLAUDE.md) – Project structure, code style, CLI reference, and the definition of done

Franklin ships as a **Python package** (Typer CLI + Rich UI) with shell bootstrap/install wrappers — most contributions touch `franklin/src/lib/` (Python), `franklin/src/*.sh` (installers), or `franklin/templates/zshrc.zsh`.

### Core Principles

These guardrails still matter:

1. **Cross-platform** – macOS, Debian/Ubuntu, and RHEL/Fedora are detected at runtime from a single codebase
2. **Idempotent installs** – Re-running `install.sh` or `franklin update-all` is always safe
3. **Observable operations** – Every step emits Campfire UI feedback; UI goes to stderr so stdout stays clean for machine-readable output (`--json`)
4. **Minimal dependencies** – Stay POSIX-friendly in shell code, and keep the Python dependency list short (Typer, Rich)
5. **Fast recovery** – Installs remain rerunnable thanks to backups at `<install root>/backups/` and idempotent steps

## 🎯 Types of Contributions

### Bug Reports

Found a bug? Help us fix it!

1. **Check existing issues** first: https://github.com/jeremyfuksa/franklin/issues
2. **Reproduce the issue** to confirm it's not environmental
3. **Create a detailed issue** with:
   - Your platform: `uname -a`
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Error output, plus `franklin doctor --json` output if relevant
   - What you've already tried

### Feature Requests

Have an idea for a feature? We'd love to hear it!

1. **Check the roadmap**: Review existing issues and discussions
2. **Create a detailed proposal** with:
   - Clear use case (why you need this)
   - How it aligns with core principles
   - Suggested implementation approach
   - Platform considerations
3. **Discuss before implementing** to avoid duplicate work

### Documentation Improvements

Help improve our docs!

- Fix typos and clarity issues
- Add examples and use cases
- Improve organization and structure
- Add diagrams and visuals

### Code Contributions

Want to implement a feature or fix a bug? Read on.

## 👨‍💻 Development Workflow

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/franklin.git
cd franklin
git remote add upstream https://github.com/jeremyfuksa/franklin.git
```

### 2. Create a Feature Branch

```bash
# Create a branch for your work
git checkout -b feature/your-feature-name
# or for bug fixes:
git checkout -b fix/issue-description

# Branch naming conventions:
# - feature/*  - New features
# - fix/*      - Bug fixes
# - docs/*     - Documentation updates
# - test/*     - Test additions
```

### 3. Set Up Development Environment

```bash
# Create a venv and install Franklin in editable mode
cd franklin
python3 -m venv .venv
source .venv/bin/activate
pip install -e . pytest
cd ..

# Run the CLI during development
PYTHONPATH=franklin/src python -m lib.main doctor
# Or via the installed entrypoint:
franklin doctor

# Run the test suite to verify setup
pytest test/test_cli.py -v
```

To exercise the installers themselves (they modify your dotfiles — prefer a VM or container):

```bash
# Non-interactive install
# Flags: --non-interactive / --color NAME / --with-claude|--no-claude / --no-chsh
bash franklin/src/install.sh --non-interactive --color cello --no-claude

# Bootstrap into a throwaway location
bash franklin/src/bootstrap.sh --dir /tmp/franklin-test --ref main
```

### 4. Make Your Changes

Follow the code style in [CLAUDE.md](CLAUDE.md). In brief:

**Python** (`franklin/src/lib/`):
- Use Typer for commands; keep docstrings short
- Route all UI through `CampfireUI` (from `lib.ui`) so stdout stays clean for `--json`
- Reuse glyph/color constants from `lib.constants`

**Shell** (`franklin/src/*.sh`):
- Use `set -euo pipefail` at the top
- Quote all variable expansions (`"$var"`)
- Source shared UI from `lib/ui.sh` (install.sh) or use minimal inline (bootstrap.sh)
- Keep FRANKLIN_ROOT/CONFIG paths consistent with `constants.py`

**Zsh template** (`franklin/templates/zshrc.zsh`):
- Respect the load-order contract: sheldon loads before `compinit`, and the `compdef` queue-and-replay stub must stay between them (see CLAUDE.md)
- Verify template changes in a live zsh — start a fresh shell and watch for startup errors

### 5. Testing

The test suite is `test/test_cli.py` — pytest smoke tests that run each CLI command as a subprocess and assert on exit codes and output.

```bash
# Run the suite (with your venv activated so `python3` resolves Typer/Rich)
pytest test/test_cli.py -v
```

Manual/diagnostic helpers also live in `test/`:

```bash
bash test/ui-demo.sh            # Visual demo of the Campfire UI helpers
bash test/sheldon-diagnostic.sh # Plugin manager diagnostic
```

Add pytest cases to `test/test_cli.py` for new CLI behavior — new commands, flags, and error cases (exit codes included).

#### Continuous Integration

`.github/workflows/ci.yml` runs CLI smokes on macOS and Ubuntu for every PR (with sheldon/starship/bat/zsh/mise stubbed). **CI does not run the pytest suite** — run `pytest test/test_cli.py` locally before pushing; it's part of the definition of done.

#### Test on Multiple Platforms

If possible, test on:
- macOS (Intel and Apple Silicon)
- Ubuntu 20.04+ / Debian 11+
- Fedora 36+

### 6. Write Commit Messages

Follow conventional commits:

```
type(scope): description

- Optional detailed explanation
- Multiple points if needed
- Reference issue: fixes #123

Types: feat, fix, docs, test, refactor, perf, ci, chore
Scopes: cli, install, update, ui, motd, config

Examples:
feat(cli): add Rocky Linux support to doctor
fix(install): handle missing sudo on minimal systems
docs(readme): clarify plugin management
test(cli): cover doctor --json failure paths
```

### 7. Push and Create Pull Request

```bash
# Push your branch
git push origin feature/your-feature-name

# Create PR on GitHub
# - Title: Clear description of changes
# - Description: Explain what, why, and how
# - Tests: Confirm pytest passes locally and CI smokes are green
# - Screenshots: If UI changes (MOTD, doctor output, etc.)
```

## 📝 Pull Request Guidelines

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Other (describe)

## Related Issue
Fixes #123 (if applicable)

## How Has This Been Tested?
- [ ] `pytest test/test_cli.py` passes locally
- [ ] CI smokes pass (macOS + Ubuntu)
- [ ] Tested on [platform]

## Checklist
- [ ] Code follows style guidelines (CLAUDE.md)
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated (README.md / CLAUDE.md / CHANGELOG.md)
- [ ] No breaking changes introduced
- [ ] Tests added for new code
```

### Review Process

1. **Automated checks**:
   - CI smokes must pass on macOS and Ubuntu

2. **Manual review**:
   - Code quality and style
   - Adherence to principles
   - Performance impact
   - Documentation completeness

3. **Approval**:
   - Maintainer approval required
   - All feedback addressed
   - CI passes

## 📖 Documentation

All contributions should keep the docs honest:

### Code Comments

```bash
# For complex logic, explain the "why"
# Good:
# We use a subshell to isolate the installation step
# so that failures don't affect other steps
(
  install_package
) || handle_error

# Bad:
# Install package
install_package
```

### Documentation Updates

If you add a feature, update:
- [README.md](README.md) – Add to feature list and usage examples
- [CLAUDE.md](CLAUDE.md) – Update the CLI table, paths, or structure if they changed
- Code comments – Document complex logic inline

### Changelog Entry

Add an entry to [CHANGELOG.md](CHANGELOG.md) under `[Unreleased]`:

```markdown
## [Unreleased]

### Added
- New feature description

### Fixed
- Bug fix description

### Changed
- Breaking change description
```

## 🚢 Release Process

Releases are automated by `.github/workflows/release.yml` — there is no release script to run. Maintainers:

1. Open a release PR that bumps `VERSION` and `franklin/pyproject.toml`, and promotes `[Unreleased]` in `CHANGELOG.md` to `[X.Y.Z] - <date>`
2. Merge the PR — the workflow detects the `VERSION` change on `main`, validates it, tags `vX.Y.Z`, and publishes the GitHub Release with the CHANGELOG section as the body

The full playbook lives in [CLAUDE.md](CLAUDE.md) under "Release Workflow". Contributors don't need to worry about releases.

## 💡 Tips for Successful Contributions

### 1. Start Small

- Fix a typo in docs
- Add a missing test
- Improve an error message
- Before tackling large features

### 2. Discuss First

- Create an issue to discuss your idea
- Get feedback before implementing
- Saves time if idea isn't aligned with project

### 3. Read the Code

- Understand existing patterns
- Follow established conventions
- Ask questions if unclear

### 4. Test Thoroughly

- Run `pytest test/test_cli.py` locally — CI won't do it for you
- Test on multiple platforms if possible
- Verify zshrc template changes in a live shell

### 5. Keep it Simple

- Simpler code is easier to maintain
- Avoid over-engineering
- One change per PR is better than many

### 6. Write Clear Messages

- Commit messages explain intent
- PR description explains design
- Comments explain complex logic

## 🆘 Getting Help

### Questions?

- Open an issue for discussion
- Check existing issues for answers
- Review documentation and code examples

### Stuck?

- Ask in GitHub Discussions
- Request help in your PR
- Reach out to maintainers

## 📜 License

By contributing to Franklin, you agree that your contributions will be licensed under the MIT License.

## 🎉 Thank You

Your contributions, whether code, documentation, bug reports, or ideas, help make Franklin better!

---

**Additional Resources:**
- [GitHub Help: Collaborating with pull requests](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Shell Script Best Practices](https://mywiki.wooledge.org/BashGuide)
