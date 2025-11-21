# Franklin UI Design Improvements

## Overview

Enhanced Franklin's Campfire UI system with status symbols, improved visual hierarchy, and better breathing room throughout all install and update scripts.

## Design Philosophy

**"Structured, Connected, Minimal"**

- **Structured**: Clear visual hierarchy shows relationships between actions
- **Connected**: Tree structure connects actions to outcomes
- **Minimal**: Only essential information with space to breathe

## Visual Elements

### Status Symbols

| Symbol | Meaning | Usage | Color |
|--------|---------|-------|-------|
| ⏺ | Section Header | Major operation or step | Default |
| ⎿ | Branch | Sub-action or info item | Default |
| ✔ | Success | Operation completed successfully | Green (#a3be8c) |
| ⚠ | Warning | Non-critical issue or alert | Yellow (#ebcb8b) |
| ✗ | Error | Critical failure (then exit) | Red (#bf616a) |
| ∴ | Logic | Reasoning or decision (rare) | Default |
| ✻ | Wait | Long-running operation (future) | Default |

### Visual Hierarchy

```
⏺ Section Header (Level 0)
  ⎿  Sub-action or info (Level 1)
  ⎿  ✔ Success message (Level 1)
  ⎿  ⚠ Warning message (Level 1)
  ⎿  ✗ Error message (Level 1)
      Command output (Level 2, indented 4+ spaces)
        Nested output (Level 3, indented 6+ spaces)
```

### Spacing Rules

1. **Blank line after each completed section** - Creates breathing room
2. **No blank lines within a section** - Keeps related items together
3. **Final success message gets extra space** - Emphasizes completion
4. **Error messages include remediation steps** - Actionable guidance

## Implementation

### Bash Functions (install.sh, bootstrap.sh)

```bash
ui_header()         # ⏺ Section header
ui_branch()         # ⎿  Regular sub-item
ui_success()        # ⎿  ✔ Success message
ui_warning()        # ⎿  ⚠ Warning message
ui_error()          # ⎿  ✗ Error message (exits)
ui_section_end()    # Blank line between sections
ui_final_success()  # ✔ Final message (no branch glyph)
```

### Python Methods (lib/ui.py)

```python
ui.print_header()        # ⏺ Section header
ui.print_branch()        # ⎿  Regular sub-item
ui.print_success()       # ⎿  ✔ Success message
ui.print_warning()       # ⎿  ⚠ Warning message
ui.print_error()         # ⎿  ✗ Error message (exits)
ui.section_end()         # Blank line between sections
ui.print_final_success() # ✔ Final message (standalone)
```

## Files Modified

### Core UI Libraries

- **franklin/src/install.sh** - Added status symbols and section spacing
- **franklin/src/bootstrap.sh** - Added status symbols and section spacing
- **franklin/src/lib/ui.py** - Added status symbols and new methods
- **franklin/src/lib/constants.py** - Added status symbol constants
- **franklin/src/lib/main.py** - Updated update commands with proper spacing

### Documentation

- **install-design-complete** - Complete design specification with examples
- **ui-design-reference** - Comprehensive reference guide
- **test/ui-demo-output.txt** - Visual demo of all patterns

## Example Output

### Success Flow

```
⏺ Detecting platform
  ⎿  Platform: macos (macos) on arm64
  ⎿  ✔ Platform detected

⏺ Installing dependencies
  ⎿  Found Homebrew at /opt/homebrew/bin
  ⎿  Installing packages via Homebrew...
      ==> Downloading curl-8.17.0...
      ==> Installing curl
  ⎿  ✔ Dependencies installed

✔ Franklin installation complete!
```

### Warning Flow

```
⏺ Creating backup of existing configuration
  ⎿  No existing configuration files found
  ⎿  ⚠ Skipping backup

⏺ Installing dependencies
  ⎿  Found Homebrew at /opt/homebrew/bin
  ⎿  Installing packages via Homebrew...
      Warning: curl 8.17.0 is already installed
  ⎿  ⚠ Some packages were already installed
  ⎿  ✔ Dependencies ready
```

### Error Flow

```
⏺ Detecting platform
  ⎿  ✗ Unsupported operating system: FreeBSD

Installation failed. Franklin supports macOS, Debian, and RHEL-based systems.
Please see https://github.com/youruser/franklin for more information.
```

## Benefits

1. **Immediate Status Recognition** - Symbols communicate outcome at a glance
2. **Better Scannability** - Spacing and hierarchy make output easier to parse
3. **Professional Polish** - Consistent, thoughtful design feels premium
4. **Actionable Errors** - Failures include clear next steps
5. **Calm Experience** - Breathing room prevents overwhelming output

## Testing

Run the demo to see all patterns:

```bash
cat test/ui-demo-output.txt
```

Test in real commands:

```bash
franklin doctor
franklin update --yes
franklin update-all --yes
bash franklin/src/install.sh
```

## Design References

- **install-design** - Original user-provided design mockup
- **install-design-complete** - Extended design with error/warning scenarios
- **ui-design-reference** - Complete specification and guidelines
