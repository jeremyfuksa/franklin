# Shell Libraries

This directory contains reusable shell libraries for franklin.

## os_detect.sh / os_detect.zsh

Platform detection library that identifies the operating system family (macOS, Debian-based, Fedora) and Homebrew availability.

### Usage

**Source in .zshrc (runtime)**:
```bash
source "$HOME/.config/franklin/lib/os_detect.zsh"
echo "Platform: $OS_FAMILY"
echo "Homebrew: $HAS_HOMEBREW"
```

**Source in install.sh (bootstrap)**:
```bash
source "lib/os_detect.sh"
if [ $? -ne 0 ]; then
  echo "Failed to detect platform" >&2
  exit 1
fi

case "$OS_FAMILY" in
  macos)
    brew install zsh
    ;;
  debian)
    apt-get update && apt-get install -y zsh
    ;;
  fedora)
    dnf install -y zsh
    ;;
esac
```

**Standalone execution (for testing/debugging)**:
```bash
$ lib/os_detect.sh --json
{"OS_FAMILY":"macos","HAS_HOMEBREW":true,"detection_ms":42,"fallback":false}

$ lib/os_detect.sh --verbose
[os_detect] Detecting platform...
[os_detect] uname: Darwin (macOS)
[os_detect] Checking Homebrew...
[os_detect] Homebrew found
[os_detect] Detection complete (15ms)
```

### Exported Variables

| Variable | Type | Description |
|----------|------|-------------|
| `OS_FAMILY` | string | Platform identifier: `macos`, `debian`, `fedora` |
| `HAS_HOMEBREW` | string | Homebrew availability: `true` or `false` |

### Exit Codes

| Code | Meaning | Usage |
|------|---------|-------|
| 0 | Success | Platform detected correctly |
| 1 | Warning | Fallback used (unknown platform defaulted to debian) |
| 2 | Error | System error (e.g., permission denied) |

### Flags

| Flag | Description | Output |
|------|-------------|--------|
| `--verbose` | Debug output to stderr | `[os_detect] Detecting platform...` |
| `--json` | Machine-readable JSON output | `{"OS_FAMILY":"macos",...}` |

### Detection Logic

Platform detection follows this state machine:

```
[START]
  ↓
[Check uname]
  ├→ Darwin → OS_FAMILY=macos → [Check Homebrew]
  └→ Linux → [Check /etc/os-release]
      ├→ ID=ubuntu|debian → OS_FAMILY=debian
      ├→ ID=fedora → OS_FAMILY=fedora
      └→ unknown/missing → OS_FAMILY=debian (fallback)

[Check Homebrew]
  ├→ `command -v brew` → HAS_HOMEBREW=true
  └→ not found → HAS_HOMEBREW=false

[EXPORT & END]
```

### Platform Support

| OS | Version | Detection Method | Status |
|----|---------|------------------|--------|
| macOS | 10.15+ | `uname -s` (Darwin) | ✓ Supported |
| Ubuntu | 20.04+ | `/etc/os-release` (ID=ubuntu → debian) | ✓ Supported |
| Debian | 11+ | `/etc/os-release` (ID=debian) | ✓ Supported |
| Fedora | 36+ | `/etc/os-release` (ID=fedora) | ✓ Supported |
| Other Linux | Any | Fallback to debian | ✓ Graceful |

### Environment Variable Override

Users can override the detected OS:

```bash
export OS_FAMILY=debian
source lib/os_detect.zsh
echo $OS_FAMILY  # debian (from env, not detected)
```

### Performance

- **Target**: <100ms detection time
- **Typical**: 15-50ms on modern systems
- **Measured via**: `--json` flag includes `detection_ms` field

### Design Principles

1. **POSIX Compatible**: Works in POSIX sh, Bash 4+, and Zsh
2. **Zero External Dependencies**: Uses only shell builtins and standard tools
3. **Idempotent**: Safe to source multiple times
4. **Silent by Default**: No output unless --verbose or --json
5. **Graceful Fallback**: Unknown platforms default to debian
6. **Observable**: Optional --verbose mode for debugging

### Integration Points

- **bootstrap-installation**: Uses OS_FAMILY to select package manager
- **update-all-system**: Platform-specific update commands
- **antigen-plugins-config**: Conditional keybindings (macOS vs Linux)
- **nvm-node-integration**: Platform detection in nvm.zsh
- **starship-prompt-config**: Optional platform-specific configuration

### Testing

Unit tests: `test/_os_detect_tests.sh`
Acceptance tests: `test/smoke.zsh`
Mock fixtures: `test/fixtures/os-release.d/`

See `test/fixtures/README.md` for test fixture documentation.

