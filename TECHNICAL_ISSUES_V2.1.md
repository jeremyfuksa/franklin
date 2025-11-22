# Franklin v2.1 - Technical Issues & Improvements

This document outlines security vulnerabilities, bugs, and under-the-hood improvements identified through code analysis on 2025-11-22.

## Critical Security Issues (P0)

### S1: Unsafe Curl Pipe Bash Pattern (CWE-494)

**Location**: `install.sh` lines 284, 290, 301, 307, 321

**Issue**: Multiple instances of `curl | bash` without cryptographic verification.

```bash
# Current (UNSAFE):
curl -fsSL https://starship.rs/install.sh | sh -s -- --yes

# Lines affected:
# - Sheldon installer (Debian): line 284, 301
# - Starship installer (Debian/Fedora): line 290, 307
# - NVM installer: line 321
```

**Risk**: Man-in-the-middle attacks could inject malicious code during installation.

**Mitigation**:
1. Download scripts to temp files first
2. Verify checksums/signatures before execution
3. Use package managers where available (brew/apt/dnf)
4. Pin exact versions with checksums

**Recommended Fix**:
```bash
# Download and verify before execution
TEMP_SCRIPT=$(mktemp)
trap 'rm -f "$TEMP_SCRIPT"' EXIT

curl -fsSL "https://starship.rs/install.sh" -o "$TEMP_SCRIPT"
EXPECTED_SHA256="..."  # Pin known-good checksum
ACTUAL_SHA256=$(sha256sum "$TEMP_SCRIPT" | cut -d' ' -f1)

if [ "$EXPECTED_SHA256" = "$ACTUAL_SHA256" ]; then
    bash "$TEMP_SCRIPT" --yes
else
    ui_error "Checksum verification failed for starship installer"
fi
```

### S2: Arbitrary Code Execution via /etc/os-release (CWE-94)

**Location**: `install.sh` line 123

**Issue**: Sourcing `/etc/os-release` without validation allows arbitrary code execution if file is compromised.

```bash
# Current (UNSAFE):
. /etc/os-release
case "$ID" in
    debian|ubuntu) ...
```

**Risk**: Compromised `/etc/os-release` could execute malicious code with user privileges.

**Mitigation**: Parse file content instead of sourcing it.

**Recommended Fix**:
```bash
# Parse instead of source
parse_os_release() {
    local key="$1"
    grep "^${key}=" /etc/os-release | cut -d= -f2 | tr -d '"'
}

OS_ID=$(parse_os_release "ID")
case "$OS_ID" in
    debian|ubuntu) ...
```

### S3: Path Injection via --dir Flag (CWE-22)

**Location**: `bootstrap.sh` lines 24-26, 147-148

**Issue**: User-supplied `--dir` parameter is not validated before use in `rm -rf`.

```bash
# Current (UNSAFE):
while [ $# -gt 0 ]; do
    case "$1" in
        --dir)
            INSTALL_DIR="$2"  # No validation!
            shift 2
            ;;
# Later:
rm -rf "$INSTALL_DIR"  # Could delete anything!
```

**Risk**: `--dir /` or `--dir $HOME` could delete critical system files.

**Mitigation**: Validate directory is within safe bounds.

**Recommended Fix**:
```bash
--dir)
    INSTALL_DIR="$2"
    # Validate: must be absolute path, not root, not /usr, not /etc
    case "$INSTALL_DIR" in
        /|/usr|/usr/*|/etc|/etc/*|/bin|/bin/*|/sbin|/sbin/*)
            ui_error "Invalid install directory: $INSTALL_DIR (system directory)"
            ;;
        /*)
            # Valid absolute path
            shift 2
            ;;
        *)
            ui_error "Install directory must be an absolute path"
            ;;
    esac
    ;;
```

### S4: No Integrity Verification of Git Repository (CWE-345)

**Location**: `bootstrap.sh` line 153

**Issue**: Git repository is cloned without verifying commit signatures or checksums.

```bash
# Current (UNSAFE):
git clone --branch "$GIT_REF" --depth 1 "$REPO_URL" "$INSTALL_DIR"
```

**Risk**: Compromised GitHub account or MitM attack could inject malicious code.

**Mitigation**:
1. Verify GPG signatures on tags/commits
2. Pin exact commit hashes for releases
3. Use SSH URLs for authenticated clones (when available)

**Recommended Fix**:
```bash
# For tagged releases, verify GPG signature
git clone --branch "$GIT_REF" --depth 1 "$REPO_URL" "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Verify commit is signed
if ! git verify-commit HEAD 2>/dev/null; then
    ui_warning "Git commit is not signed - proceed at your own risk"
    read -r -p "Continue anyway? [y/N] " response
    if [ "$response" != "y" ]; then
        exit 1
    fi
fi
```

---

## High-Priority Bugs (P1)

### B1: Race Condition in Backup Directory Creation

**Location**: `install.sh` line 19, 152

**Issue**: Backup directory uses timestamp, but multiple installs in same second collide.

```bash
# Current (BUG):
BACKUP_DIR="${HOME}/.local/share/franklin/backups/$(date +%Y-%m-%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"  # Fails if already exists from parallel install
```

**Impact**: Lost backups or installation failures in automation/CI environments.

**Recommended Fix**:
```bash
# Add random suffix to prevent collisions
BACKUP_DIR="${HOME}/.local/share/franklin/backups/$(date +%Y-%m-%d_%H%M%S)-$$"
mkdir -p "$BACKUP_DIR" || ui_error "Failed to create backup directory"
```

### B2: Silent Error Suppression

**Location**: `install.sh` lines 273, 279, 296, 373

**Issue**: Critical operations use `|| true` to suppress errors without logging.

```bash
# Current (BUG):
brew install ... || true
sudo apt-get install ... || true
sheldon lock --update ... || ui_warning "Failed to download some plugins"
```

**Impact**: Installation appears successful even when critical tools fail to install.

**Recommended Fix**:
```bash
# Track failures and exit with appropriate code
FAILED_PACKAGES=""

if ! brew install zsh python3 bat sheldon starship 2>&1 | sed 's/^/  /' >&2; then
    FAILED_PACKAGES="$FAILED_PACKAGES brew"
fi

if [ -n "$FAILED_PACKAGES" ]; then
    ui_error "Failed to install required packages via: $FAILED_PACKAGES"
fi
```

### B3: Missing Symlink Target Validation

**Location**: `install.sh` lines 352-361, 366, 380

**Issue**: Symlinks created without verifying target files exist.

```bash
# Current (BUG):
ln -sf "$ZSHRC_TARGET" "$ZSHRC_LINK"
# What if ZSHRC_TARGET doesn't exist?
```

**Impact**: Broken symlinks leading to shell startup failures.

**Recommended Fix**:
```bash
if [ ! -f "$ZSHRC_TARGET" ]; then
    ui_error "Template not found: $ZSHRC_TARGET"
fi

ln -sf "$ZSHRC_TARGET" "$ZSHRC_LINK"
```

### B4: No Git Clone Timeout

**Location**: `bootstrap.sh` line 153

**Issue**: Git clone has no timeout, can hang indefinitely on slow/stalled networks.

```bash
# Current (BUG):
git clone --branch "$GIT_REF" --depth 1 "$REPO_URL" "$INSTALL_DIR"
```

**Impact**: Installation hangs indefinitely, poor UX in CI/automation.

**Recommended Fix**:
```bash
# Add timeout wrapper
if ! timeout 300 git clone --branch "$GIT_REF" --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>&1 | sed 's/^/  /' >&2; then
    ui_error "Git clone timed out after 5 minutes"
fi
```

### B5: Version Mismatch Between pyproject.toml and VERSION File

**Location**: `pyproject.toml` line 7, `VERSION` file

**Issue**: Version is hardcoded in pyproject.toml but also in VERSION file - can desync.

```toml
# pyproject.toml
version = "2.0.0"  # Hardcoded

# VERSION file
2.0.0
```

**Impact**: Version inconsistencies, confusion about actual installed version.

**Recommended Fix**:
```python
# pyproject.toml - read from VERSION file dynamically
from pathlib import Path
version = Path("VERSION").read_text().strip()

# Or use setuptools_scm for git-based versioning
```

---

## Medium-Priority Improvements (P2)

### I1: Hardcoded Version Pins

**Location**: `install.sh` line 321

**Issue**: NVM version is hardcoded, not centralized with other version pins.

```bash
# Current:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
```

**Improvement**: Move to centralized constants file mentioned in CLAUDE.md.

**Recommended Fix**:
Create `franklin/src/lib/versions.sh`:
```bash
# Centralized version pins
FRANKLIN_NVM_VERSION="v0.39.5"
FRANKLIN_SHELDON_VERSION="0.7.4"
FRANKLIN_STARSHIP_VERSION="v1.17.1"

# Use in install scripts
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${FRANKLIN_NVM_VERSION}/install.sh" | bash
```

### I2: No Installation Audit Log

**Issue**: No record of what was installed/configured during setup.

**Impact**: Debugging failures is difficult without installation history.

**Recommended Fix**:
```bash
# Log all actions to audit file
AUDIT_LOG="${HOME}/.local/share/franklin/install-$(date +%s).log"

log_action() {
    echo "[$(date -Iseconds)] $*" >> "$AUDIT_LOG"
}

# Use throughout installation
log_action "Platform detected: $OS_FAMILY ($OS_DISTRO)"
log_action "Installing dependencies via brew"
```

### I3: Non-Idempotent Installation

**Issue**: Installation script doesn't check if tools are already present before installing.

**Impact**: Wastes time reinstalling already-present tools, may downgrade existing versions.

**Recommended Fix**:
```bash
# Check before install
install_if_missing() {
    local tool="$1"
    local install_cmd="$2"

    if command -v "$tool" >/dev/null 2>&1; then
        ui_branch "$tool already installed ($(command -v "$tool"))"
        return 0
    fi

    ui_branch "Installing $tool..."
    eval "$install_cmd"
}

install_if_missing "sheldon" "brew install sheldon"
```

### I4: No Rollback on Partial Failure

**Issue**: If installation fails partway through, system is left in inconsistent state.

**Impact**: Manual cleanup required, poor UX.

**Recommended Fix**:
```bash
# Track installation state
INSTALL_STATE_FILE="${HOME}/.local/share/franklin/.install-state"

record_step() {
    echo "$1" >> "$INSTALL_STATE_FILE"
}

rollback() {
    ui_warning "Installation failed, rolling back..."

    # Read state file and undo actions
    if [ -f "$INSTALL_STATE_FILE" ]; then
        while read -r step; do
            case "$step" in
                "symlink:$HOME/.zshrc")
                    rm -f "$HOME/.zshrc"
                    restore_from_backup "$HOME/.zshrc"
                    ;;
            esac
        done < "$INSTALL_STATE_FILE"
    fi
}

trap rollback EXIT
```

### I5: Unpinned Python Dependencies

**Location**: `requirements.txt` lines 1-4

**Issue**: Dependencies use `>=` which can pull breaking changes.

```
# Current:
typer>=0.9.0  # Could pull 1.0.0 with breaking changes
```

**Improvement**: Pin exact versions or use compatible release specifiers.

**Recommended Fix**:
```
# requirements.txt
typer==0.9.0
rich==13.0.0
psutil==5.9.0
typing-extensions==4.0.0

# Or use compatible release
typer~=0.9.0  # Allows 0.9.x but not 0.10.0
```

### I6: No Verification of Package Manager Updates

**Location**: `lib/main.py` lines 166-189

**Issue**: System package updates via sudo have no dry-run preview or confirmation of changes.

```python
# Current:
ok_upgrade, _ = _run_logged(upgrade_cmd, dry_run=dry_run)
```

**Improvement**: Show what will be updated before running `sudo`.

**Recommended Fix**:
```python
# First show what would be updated
if os_family == "debian":
    # Show pending updates
    preview_cmd = ["apt", "list", "--upgradable"]
    ui.print_branch("Pending updates:")
    _run_logged(preview_cmd, dry_run=False)

    # Confirm with user
    if not yes and sys.stderr.isatty():
        confirm = Prompt.ask("Proceed with upgrade?", choices=["y", "n"], default="n")
        if confirm != "y":
            return False
```

### I7: Missing Input Validation in Color Selection

**Location**: `lib/main.py` lines 89-93, `install.sh` lines 207-230

**Issue**: Color input could contain ANSI escape sequences from pasted text.

**Mitigation**: Already partially addressed with `_parse_numeric_selection()` regex stripping, but bash version lacks this.

**Recommended Fix**:
```bash
# install.sh - sanitize input
read -r -p "Enter choice [1-8, default: 1]: " color_choice

# Strip ANSI escapes and non-numeric characters
color_choice=$(echo "$color_choice" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | tr -cd '0-9')
```

---

## Low-Priority Code Quality (P3)

### Q1: Inconsistent Error Exit Codes

**Issue**: Some errors exit with 1, others with 2, no documented convention.

**Recommendation**: Follow standard convention:
- 0: Success
- 1: General errors
- 2: Misuse of shell command (invalid args)
- 3-125: Custom error codes
- 126: Command cannot execute
- 127: Command not found
- 128+N: Fatal error signal N

### Q2: Mixed echo vs printf in Shell Scripts

**Issue**: Some functions use `echo -e`, others use `printf`.

**Recommendation**: Standardize on `printf` for portability (POSIX).

### Q3: No Test Coverage for Installation Scripts

**Issue**: Installation scripts lack unit tests.

**Recommendation**: Add bash unit tests:
```bash
# test/install-unit-tests.sh
test_parse_os_release() {
    echo 'ID="ubuntu"' > /tmp/test-os-release
    result=$(parse_os_release "ID" < /tmp/test-os-release)
    assert_equals "ubuntu" "$result"
}
```

### Q4: Duplicate Code Between bash and Python UI

**Issue**: UI functions duplicated in `install.sh` and `lib/ui.py`.

**Recommendation**: Generate bash UI from Python source of truth, or extract to shared file.

### Q5: No Telemetry or Anonymous Usage Stats

**Issue**: No visibility into installation failures, platform distribution, common errors.

**Recommendation**: Add opt-in anonymous telemetry:
```bash
# Only with user consent
if [ "$FRANKLIN_TELEMETRY" = "1" ]; then
    curl -fsSL https://telemetry.franklin.sh/install \
        -d "os=$OS_FAMILY" \
        -d "version=$VERSION" \
        -d "status=success" \
        --max-time 2 \
        || true  # Never fail on telemetry
fi
```

---

## Security Hardening Checklist

- [ ] Replace all `curl | bash` with download-verify-execute pattern
- [ ] Parse `/etc/os-release` instead of sourcing
- [ ] Validate `--dir` flag input
- [ ] Implement GPG verification for git tags
- [ ] Add checksums for downloaded scripts
- [ ] Use HTTPS for all network requests (already done ✓)
- [ ] Validate symlink targets exist before creation
- [ ] Sanitize user input in color selection
- [ ] Add timeout to network operations
- [ ] Implement installation rollback
- [ ] Create audit log of all installation actions
- [ ] Pin dependency versions
- [ ] Add rate limiting for update operations
- [ ] Implement backup integrity checks

---

## Testing Requirements for Fixes

All security fixes and bug fixes should include:

1. **Unit tests**: Test individual functions in isolation
2. **Integration tests**: Test full installation flow
3. **Security tests**: Attempt to exploit vulnerabilities
4. **Cross-platform tests**: Verify on macOS, Debian, Fedora
5. **Failure mode tests**: Ensure graceful degradation

Example test structure:
```bash
# test/security-tests.sh
test_path_injection_prevented() {
    # Attempt to set dangerous directory
    if ./bootstrap.sh --dir / 2>&1 | grep -q "Invalid install directory"; then
        echo "PASS: Path injection prevented"
    else
        echo "FAIL: Path injection not prevented"
        return 1
    fi
}
```

---

## Remediation Priority

### Immediate (v2.1.0)
1. S1: Replace curl pipe bash with verified downloads
2. S2: Parse /etc/os-release instead of sourcing
3. S3: Validate --dir flag
4. B2: Fix silent error suppression
5. B3: Validate symlink targets

### Short-term (v2.1.1)
1. S4: Add git verification
2. B1: Fix backup race condition
3. B4: Add git clone timeout
4. I5: Pin Python dependencies
5. I3: Make installation idempotent

### Medium-term (v2.2.0)
1. I2: Add installation audit logging
2. I4: Implement rollback mechanism
3. I6: Add package manager preview
4. Q3: Add test coverage

### Long-term (v3.0.0)
1. I1: Centralize version management
2. Q4: Consolidate UI implementations
3. Q5: Optional telemetry system

---

**Document Status**: Technical analysis for implementation
**Author**: Claude (AI Assistant)
**Date**: 2025-11-22
**Severity Ratings**: P0 (Critical), P1 (High), P2 (Medium), P3 (Low)
**Next Steps**: Review with maintainers, prioritize fixes, create GitHub issues
