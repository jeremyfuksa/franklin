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

### Core Principles

Franklin has evolved from its “spec-first” roots, but these guardrails still matter:

1. **OS-aware bundles** – macOS, Debian/Ubuntu, and RHEL/Fedora each get their own trimmed artifacts
2. **Idempotent installs** – Re-running `install.sh` or `update-all.sh` is always safe
3. **Observable operations** – Every long-running step emits logs/spinners, and `--verbose` reveals full output
4. **Minimal dependencies** – Stay POSIX-friendly, prefer shell/packager primitives, and avoid heavyweight tooling
5. **Fast recovery** – Installs should remain rerunnable thanks to backups and idempotent steps

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
   - Error output (use `--verbose` flag)
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
- Translate to other languages
- Add diagrams and visuals

### Code Contributions

Want to implement a feature or fix a bug?

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
# Install Franklin in development mode
bash install.sh --verbose --motd-color mauve

# Run tests to verify setup
bash test/_os_detect_tests.sh
bash test/test_install.sh
bash test/bootstrap-tests.sh
bash test/motd-tests.sh
```

### 4. Make Your Changes

#### For Shell Scripts

```bash
# Follow these patterns:

# 1. Use POSIX shell where possible (sh, not bash-only)
# 2. Use set -e for safety
# 3. Check for command availability before using
# 4. Handle platform differences
# 5. Add comments for non-obvious code
# 6. Use consistent error handling

# Good example:
set -e

check_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    return 1
  fi
}

if check_command "zsh"; then
  log_success "zsh is installed"
else
  log_error "zsh not found"
  exit 2
fi
```

#### For Zsh Configuration

```bash
# Follow these patterns:

# 1. Use Zsh 5+ syntax only
# 2. Avoid bash-isms
# 3. Use functions for reusable code
# 4. Document configuration options
# 5. Test with both Zsh and Bash (where applicable)
```

### 5. Testing

**All contributions must include tests.**

#### Run Existing Tests

```bash
# Unit tests for platform detection
bash test/_os_detect_tests.sh

# Installation script tests
bash test/test_install.sh

# Acceptance/smoke tests
bash test/smoke.zsh
```

#### Write New Tests

Add tests for new features:

```bash
# test/test_your_feature.sh
#!/bin/bash
set -e

# Test setup
setup() {
  # ...initialization...
}

# Test cases
test_something() {
  local result=$(your_function)
  [ "$result" = "expected" ] && echo "PASS" || echo "FAIL"
}

# Run tests
setup
test_something
test_another_thing
```

#### Test on Multiple Platforms

If possible, test on:
- macOS 10.15+ (Intel and Apple Silicon)
- Ubuntu 20.04+
- Debian 11+
- Fedora 36+

Or use GitHub Actions (runs automatically on PR).

### 6. Write Commit Messages

Follow conventional commits:

```
type(scope): description

- Optional detailed explanation
- Multiple points if needed
- Reference issue: fixes #123

Types: feat, fix, docs, test, refactor, perf, ci, chore
Scope: os_detect, install, update, shell, etc.

Examples:
feat(os_detect): add Rocky Linux support
fix(install): handle missing sudo on minimal systems
docs(usage): clarify plugin management
test(platform): add more platform detection cases
```

### 7. Push and Create Pull Request

```bash
# Push your branch
git push origin feature/your-feature-name

# Create PR on GitHub
# - Title: Clear description of changes
# - Description: Explain what, why, and how
# - Tests: Confirm tests pass
# - Screenshots: If UI changes (docs/configuration)
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
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Smoke tests pass
- [ ] Tested on [platform]

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] No breaking changes introduced
- [ ] Tests added for new code
```

### Review Process

1. **Automated checks**:
   - Tests must pass on all platforms
   - No syntax errors

2. **Manual review**:
   - Code quality and style
   - Adherence to principles
   - Performance impact
   - Documentation completeness

3. **Approval**:
   - Maintainer approval required
   - All feedback addressed
   - CI/CD passes

## 🏗️ Architecture Guidelines

When contributing code, follow these architecture patterns:

### 1. Modular Design

```bash
# Create separate modules for different concerns
lib/
├── feature_core.sh       # Main functionality
├── feature_utils.sh      # Helper functions
└── feature_test.sh       # Tests

# Each module has single responsibility
# Modules export functions, not side effects
```

### 2. Error Handling

```bash
# Always use proper error handling
(
  set +e
  operation_that_might_fail
  return $?
) || {
  local exit_code=$?
  if [ $exit_code -eq 1 ]; then
    echo "Optional step skipped"
  else
    echo "ERROR: Critical failure"
    return 2
  fi
}
```

### 3. Platform Abstraction

```bash
# Abstract platform differences
case "$OS_FAMILY" in
  macos)
    install_via_homebrew "$package"
    ;;
  debian)
    install_via_apt "$package"
    ;;
  fedora)
    install_via_dnf "$package"
    ;;
  *)
    return 1  # Unsupported
    ;;
esac
```

### 4. Logging

```bash
# Use consistent logging functions
log_info "Starting operation"
log_success "Operation completed"
log_warning "Optional step skipped"
log_error "Operation failed"
log_debug "Debug information" # Only with --verbose
```

## 🧪 Test Requirements

### Minimum Test Coverage

- All new functions must have tests
- All platform-specific code must be tested on all platforms
- Error cases must be tested
- Exit codes must be validated

### Test Structure

```bash
#!/bin/bash
# test/test_feature.sh
set -e

test_case_1() {
  # Arrange
  local input="value"

  # Act
  local result=$(your_function "$input")

  # Assert
  [ "$result" = "expected" ] && echo "✓ test_case_1" || echo "✗ test_case_1"
}

test_case_2() {
  # Error case testing
  if your_function_that_should_fail 2>/dev/null; then
    echo "✗ test_case_2"
  else
    echo "✓ test_case_2"
  fi
}

# Run all tests
test_case_1
test_case_2
```

## 📖 Documentation

## 🚢 Cutting a Release

Maintainers can publish a new version with the automated helper once all planned changes are merged.

1. Update `CHANGELOG.md`, moving changes from **Unreleased** into a new version heading.
2. Ensure the working tree is clean and that you've run any smoke tests you care about.
3. Preview the release steps:
   ```bash
   src/scripts/release.sh --dry-run v1.1.0
   ```
4. Run the real release (this stamps `VERSION`, commits `release: v1.1.0`, tags, and pushes):
   ```bash
   src/scripts/release.sh v1.1.0
   ```
The script intentionally refuses to run if the working tree is dirty or if the tag already exists, keeping releases reproducible.

All contributions must include documentation:

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
- [README.md](README.md) - Add to feature list and usage examples
- Code comments - Document complex logic inline
- Spec files in `specs/` - Update relevant specifications

### Changelog Entry

Add entry to [CHANGELOG.md](CHANGELOG.md) (if exists):

```markdown
## [Unreleased]

### Added
- New feature description

### Fixed
- Bug fix description

### Changed
- Breaking change description
```

## 🚀 Release Process

Maintainers follow this release process:

1. Ensure `master`/`main` is green (`bash test/test_install.sh`, `bash test/bootstrap-tests.sh`, etc.)
2. Update the changelog/version metadata if needed
3. Preview the release: `bash src/scripts/release.sh --dry-run vX.Y.Z`
4. Execute the release: `bash src/scripts/release.sh vX.Y.Z` (stamps `VERSION`, commits, tags, pushes)
5. Announce changes (release notes, README updates, etc.)

Contributors don't need to worry about releases.

## 💡 Tips for Successful Contributions

### 1. Start Small

- Fix a typo in docs
- Add a missing test
- Improve error message
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

- Test your changes locally
- Test on multiple platforms if possible
- Run full test suite before submitting PR

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
