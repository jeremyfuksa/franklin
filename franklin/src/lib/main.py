"""
Franklin CLI Entry Point

Implements the command-line interface for Franklin using Typer.
Commands follow the "Campfire" UX standards.
"""

import os
import re
import shutil
import platform
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from typing_extensions import Annotated

import typer
from rich.console import Console
from rich.prompt import Prompt

from .constants import (
    CAMPFIRE_COLORS,
    DEFAULT_CAMPFIRE_COLOR,
    CONFIG_FILE,
    CONFIG_DIR,
    FRANKLIN_ROOT,
)
from .ui import ui
from .motd import render_motd, get_franklin_version


def _resolve_no_color(cli_no_color: bool) -> bool:
    """Determine if color should be disabled based on flag or env."""
    env_no_color = os.environ.get("NO_COLOR") is not None or os.environ.get(
        "FRANKLIN_NO_COLOR"
    )
    return cli_no_color or bool(env_no_color)


app = typer.Typer(
    name="franklin",
    help="A modern Zsh environment manager with cross-platform support.",
    add_completion=False,
)

# Initialize with env-based NO_COLOR; CLI flag can reconfigure later.
console = Console(no_color=_resolve_no_color(False))


def _parse_numeric_selection(
    selection: str, default_idx: int, max_idx: int
) -> Tuple[int, bool]:
    """Parse a numeric menu selection.

    Returns (index, was_valid). was_valid is False only when the user typed
    something that wasn't recognized — empty input (use default) and a valid
    in-range number both count as valid so callers don't print a spurious
    "invalid choice" warning on a legitimate default pick.
    """
    # Strip CSI sequences; '~' terminates bracketed-paste markers (\x1b[200~)
    cleaned = re.sub(r"\x1b\[[0-9;]*[A-Za-z~]", "", selection).strip()
    if not cleaned:
        return default_idx, True
    if not cleaned.isdigit():
        return default_idx, False
    value = int(cleaned)
    if 1 <= value <= max_idx:
        return value, True
    return default_idx, False


def _ensure_first_run_color(ctx: "typer.Context") -> None:
    """Prompt for MOTD color on first run when interactive."""
    # Skip if already configured or not fully interactive (stdin is needed to
    # answer the prompt; stderr to display it)
    if CONFIG_FILE.exists() or not sys.stderr.isatty() or not sys.stdin.isatty():
        return

    # Skip commands where an interactive detour is wrong: config prompts on
    # its own, motd runs at every shell startup, doctor may be feeding a
    # script via --json.
    if ctx.invoked_subcommand in ("config", "motd", "doctor"):
        return

    ui.print_header("Franklin Configuration (first run)")
    ui.print_branch("Select a MOTD color (base + dark preview):")
    console.print()
    choices = list(CAMPFIRE_COLORS.keys())
    for idx, name in enumerate(choices, start=1):
        colors = CAMPFIRE_COLORS[name]
        base_color = colors["base"]
        dark_color = colors["dark"]
        console.print(
            f"  {idx:2d}) [bold {base_color}]████[/bold {base_color}] [bold {dark_color}]████[/bold {dark_color}]  {name:<15} (base {base_color}, dark {dark_color})"
        )

    default_idx = choices.index(DEFAULT_CAMPFIRE_COLOR) + 1
    selection = Prompt.ask(
        f"\nSelect a color number (default {default_idx})",
        default=str(default_idx),
        show_default=True,
    ).strip()

    sel_int, was_valid = _parse_numeric_selection(
        selection, default_idx, len(choices)
    )
    if not was_valid:
        ui.print_warning(
            f"Invalid choice: {selection}, using default {DEFAULT_CAMPFIRE_COLOR}"
        )
        color_choice = DEFAULT_CAMPFIRE_COLOR
    else:
        color_choice = choices[sel_int - 1]

    hex_color = CAMPFIRE_COLORS[color_choice]["base"]
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        f.write(f'MOTD_COLOR_NAME="{color_choice}"\n')
        f.write(f'MOTD_COLOR="{hex_color}"\n')

    ui.print_success(f"MOTD color set to {color_choice} ({hex_color})")


def _save_config_keys(updates: Dict[str, str]) -> None:
    """Update key=value pairs in config.env in place.

    Existing lines are preserved verbatim; the given keys are replaced where
    they appear (including uncommenting a `# KEY=...` placeholder) and
    appended at the end if absent. This keeps hand-edited or future keys
    intact instead of rewriting the whole file.
    """
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)

    lines: List[str] = []
    if CONFIG_FILE.exists():
        try:
            lines = CONFIG_FILE.read_text().splitlines()
        except OSError:
            lines = []
    else:
        lines = ["# Franklin Configuration"]

    remaining = dict(updates)
    out: List[str] = []
    for line in lines:
        stripped = line.strip()
        matched_key = None
        for key in remaining:
            if stripped.startswith(f"{key}=") or stripped.startswith(f"# {key}="):
                matched_key = key
                break
        if matched_key:
            out.append(f'{matched_key}="{remaining.pop(matched_key)}"')
        else:
            out.append(line)

    for key, value in remaining.items():
        out.append(f'{key}="{value}"')

    CONFIG_FILE.write_text("\n".join(out) + "\n")


def _detect_os_family() -> str:
    """Detect OS family for package manager selection.

    Returns:
        'macos', 'debian', 'fedora', or 'unknown'

    Note: Uses 'fedora' for all RHEL-family distros (Fedora, RHEL, CentOS, Rocky, Alma)
    to match install.sh naming convention.
    """
    system = platform.system()
    if system == "Darwin":
        return "macos"
    # Prefer command detection for broader Linux support (backward-compatible)
    if shutil.which("apt-get"):
        return "debian"
    if shutil.which("dnf") or shutil.which("yum"):
        return "fedora"
    if Path("/etc/debian_version").exists():
        return "debian"
    if Path("/etc/redhat-release").exists():
        return "fedora"
    return "unknown"


def _run_logged(
    cmd: List[str],
    dry_run: bool = False,
    timeout: int = 600,
    ok_codes: Tuple[int, ...] = (0,),
) -> Tuple[bool, List[str]]:
    """
    Run a command, streaming stdout to UI branch lines.

    Returns (success, stdout_lines) without raising so callers can collect failures.

    Args:
        cmd: Command to run as list of strings
        dry_run: If True, print command without executing
        timeout: Maximum seconds to wait for command completion (default: 600)
        ok_codes: Exit codes treated as success (e.g. dnf --assumeno exits 1
            when it declines a pending transaction, which is not a failure)
    """
    if dry_run:
        ui.print_branch(f"DRY RUN: {' '.join(cmd)}")
        return True, []
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError:
        ui.print_error(f"{cmd[0]} not found on this system")
        return False, []
    except subprocess.TimeoutExpired:
        ui.print_error(f"{cmd[0]} timed out after {timeout} seconds")
        return False, []

    lines = [line for line in result.stdout.strip().split("\n") if line]
    if result.returncode in ok_codes:
        for line in lines:
            ui.console.print(f"      {line}")
        return True, lines

    stderr = result.stderr.strip() if result.stderr else f"exit code {result.returncode}"
    ui.print_error(stderr)
    return False, lines


def _resync_cli(dry_run: bool = False) -> bool:
    """Reinstall the CLI into the Franklin venv after a core update.

    The editable install picks up code changes automatically, but new
    dependencies declared in pyproject.toml only land via pip. No-op for
    dev layouts without the managed venv.
    """
    pip = FRANKLIN_ROOT / "venv" / "bin" / "pip"
    pkg = FRANKLIN_ROOT / "franklin"
    if not pip.exists() or not (pkg / "pyproject.toml").exists():
        return True
    ui.print_branch("Syncing CLI dependencies...")
    ok, _ = _run_logged(
        [str(pip), "install", "--quiet", "-e", str(pkg)], dry_run=dry_run
    )
    return ok


def _has_bat() -> bool:
    """Check for bat (accept batcat on Debian)."""
    return bool(shutil.which("bat") or shutil.which("batcat"))


def _update_system_packages(os_family: str, dry_run: bool) -> bool:
    """Update system packages for the detected OS family."""
    if os_family == "macos":
        ui.print_branch("Using Homebrew")
        ok_update, _ = _run_logged(["brew", "update"], dry_run=dry_run)
        upgrade_cmd = ["brew", "upgrade"]
        if dry_run:
            upgrade_cmd.append("--dry-run")
        ok_upgrade, _ = _run_logged(upgrade_cmd, dry_run=dry_run)
        return ok_update and ok_upgrade

    if os_family == "debian":
        ui.print_branch("Using apt-get")
        ok_update, _ = _run_logged(["sudo", "apt-get", "update"], dry_run=dry_run)
        upgrade_cmd = ["sudo", "apt-get", "upgrade", "-y"]
        if dry_run:
            upgrade_cmd = ["apt-get", "upgrade", "-s"]
        ok_upgrade, _ = _run_logged(upgrade_cmd, dry_run=dry_run)
        return ok_update and ok_upgrade

    if os_family == "fedora":
        ui.print_branch("Using dnf")
        ok_update, _ = _run_logged(["sudo", "dnf", "makecache"], dry_run=dry_run)
        upgrade_cmd = ["sudo", "dnf", "upgrade", "-y"]
        upgrade_ok_codes: Tuple[int, ...] = (0,)
        if dry_run:
            # --assumeno answers "no" to the transaction prompt and exits 1
            # when updates were available; both 0 and 1 mean the dry run worked.
            upgrade_cmd = ["dnf", "upgrade", "--assumeno"]
            upgrade_ok_codes = (0, 1)
        ok_upgrade, _ = _run_logged(upgrade_cmd, dry_run=dry_run, ok_codes=upgrade_ok_codes)
        return ok_update and ok_upgrade

    ui.print_error("Unsupported OS family for system package updates")
    return False


def version_callback(value: bool):
    """Callback for --version flag."""
    if value:
        version = get_franklin_version()
        console.print(f"Franklin v{version}")
        raise typer.Exit()


@app.callback()
def main_callback(
    ctx: typer.Context,
    version: Annotated[
        bool,
        typer.Option(
            "--version",
            "-v",
            help="Show Franklin version and exit.",
            callback=version_callback,
            is_eager=True,
        ),
    ] = False,
    no_color: Annotated[
        bool,
        typer.Option(
            "--no-color",
            help="Disable color output (also respected via NO_COLOR or FRANKLIN_NO_COLOR).",
            envvar="FRANKLIN_NO_COLOR",
        ),
    ] = False,
):
    """
    Franklin: A modern Zsh environment manager.
    """
    effective_no_color = _resolve_no_color(no_color)
    global console
    ui.set_color(not effective_no_color)
    console = Console(no_color=effective_no_color)
    _ensure_first_run_color(ctx)


@app.command()
def doctor(
    json_output: Annotated[
        bool,
        typer.Option("--json", help="Output in JSON format"),
    ] = False,
):
    """
    Run diagnostic checks on the Franklin environment.

    Checks for:
    - Zsh installation and version
    - Sheldon plugin manager
    - Starship prompt
    - Python version
    - Franklin core files
    """
    ui.print_logic("Checking Environment...")

    checks: Dict[str, str] = {}
    failures = []

    # Check Zsh
    try:
        result = subprocess.run(
            ["zsh", "--version"],
            capture_output=True,
            text=True,
            check=True,
        )
        version_parts = result.stdout.strip().split()
        zsh_version = version_parts[1] if len(version_parts) > 1 else "unknown"
        checks["Shell"] = f"Zsh {zsh_version}"
    except (FileNotFoundError, subprocess.CalledProcessError, IndexError):
        checks["Shell"] = "Zsh not found"
        failures.append("zsh")

    # Check Sheldon
    try:
        result = subprocess.run(
            ["sheldon", "--version"],
            capture_output=True,
            text=True,
            check=True,
        )
        version_parts = result.stdout.strip().split()
        sheldon_version = version_parts[1] if len(version_parts) > 1 else "unknown"
        checks["Plugin Manager"] = f"Sheldon {sheldon_version}"
    except (FileNotFoundError, subprocess.CalledProcessError, IndexError):
        checks["Plugin Manager"] = "Sheldon not found"
        failures.append("sheldon")

    # Check Starship
    try:
        result = subprocess.run(
            ["starship", "--version"],
            capture_output=True,
            text=True,
            check=True,
        )
        # Starship outputs multi-line version info, extract version from first line
        first_line = result.stdout.strip().split("\n")[0]
        version_parts = first_line.split()
        starship_version = version_parts[1] if len(version_parts) > 1 else "unknown"
        checks["Prompt"] = f"Starship {starship_version}"
    except (FileNotFoundError, subprocess.CalledProcessError, IndexError):
        checks["Prompt"] = "Starship not found"
        failures.append("starship")

    # Check Python
    python_version = (
        f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    )
    checks["Python"] = python_version

    # Check bat (core)
    if _has_bat():
        checks["bat"] = "present"
    else:
        checks["bat"] = "not found"
        failures.append("bat")

    # Check git (required by `franklin update`)
    if shutil.which("git"):
        checks["git"] = "present"
    else:
        checks["git"] = "not found"
        failures.append("git")

    # Check mise (runtime manager set up by install.sh)
    if shutil.which("mise"):
        checks["mise"] = "present"
    else:
        checks["mise"] = "not found"
        failures.append("mise")

    # Check eza (optional: ls aliases fall back to plain ls without it)
    checks["eza"] = "present" if shutil.which("eza") else "not found (optional)"

    # Check Franklin root
    if FRANKLIN_ROOT.exists():
        checks["Franklin Root"] = str(FRANKLIN_ROOT)
    else:
        checks["Franklin Root"] = "Not found"
        failures.append("franklin_root")

    # Check that ~/.zshrc is the Franklin-managed symlink
    zshrc = Path.home() / ".zshrc"
    template = FRANKLIN_ROOT / "franklin" / "templates" / "zshrc.zsh"
    if zshrc.is_symlink() and zshrc.resolve() == template.resolve():
        checks["~/.zshrc"] = "Franklin-managed symlink"
    else:
        checks["~/.zshrc"] = "not linked to Franklin template"
        failures.append("zshrc")

    # Output
    if json_output:
        import json

        payload: Dict[str, str] = dict(checks)
        payload["status"] = "fail" if failures else "ok"
        print(json.dumps(payload, indent=2))
    else:
        ui.print_columnar(checks)

    if failures:
        raise typer.Exit(code=1)


@app.command()
def update(
    yes: Annotated[
        bool,
        typer.Option("--yes", "-y", help="Skip confirmation prompts"),
    ] = False,
    dry_run: Annotated[
        bool,
        typer.Option(
            "--dry-run",
            "-n",
            help="Show what would run without making changes",
        ),
    ] = False,
):
    """
    Update Franklin core files from the repository.
    """
    ui.print_header("Updating Franklin Core")
    ui.print_branch(f"Franklin root: {FRANKLIN_ROOT}")

    # Check if we're in a git repository
    if not (FRANKLIN_ROOT / ".git").exists():
        ui.print_error("Franklin root is not a git repository")
        raise typer.Exit(code=1)

    if dry_run:
        ui.print_branch("DRY RUN: git -C <franklin_root> pull --ff-only")
        ui.print_branch("DRY RUN: venv pip install -e <franklin_root>/franklin")
        ui.print_success("Dry run complete (no changes made).")
        ui.section_end()
        return

    # Confirm if not --yes
    if not yes and sys.stderr.isatty():
        confirm = Prompt.ask(
            "This will pull the latest changes from the repository. Continue?",
            choices=["y", "n"],
            default="n",
        )
        if confirm != "y":
            ui.print_info("Update cancelled")
            raise typer.Exit()

    # Run git pull. --ff-only refuses to create a merge commit, which means a
    # tampered remote or rewritten upstream history surfaces as an error
    # instead of silently merging unfamiliar content into the install tree.
    ui.print_branch("Pulling latest changes...")
    ok, _ = _run_logged(["git", "-C", str(FRANKLIN_ROOT), "pull", "--ff-only"])
    if not ok:
        raise typer.Exit(code=1)

    if not _resync_cli():
        raise typer.Exit(code=1)

    ui.section_end()


@app.command()
def update_all(
    yes: Annotated[
        bool,
        typer.Option("--yes", "-y", help="Skip confirmation prompts"),
    ] = False,
    system: Annotated[
        bool,
        typer.Option("--system", help="Also update system packages (requires sudo)"),
    ] = False,
    dry_run: Annotated[
        bool,
        typer.Option(
            "--dry-run",
            "-n",
            help="Show what would run without making changes",
        ),
    ] = False,
):
    """
    Update Franklin core, plugins, and optionally system packages.

    With --system: Updates OS packages, Sheldon plugins, Starship, mise runtimes, and Node.
    Without --system: Updates only Franklin core and Sheldon plugins.
    """
    ui.print_header("Franklin Update")

    failed = False

    # Step 1: Update Franklin core
    ui.print_header("Updating Franklin core")
    ui.print_branch(f"Franklin root: {FRANKLIN_ROOT}")

    if not (FRANKLIN_ROOT / ".git").exists():
        ui.print_warning("Franklin root is not a git repository, skipping core update")
    else:
        ok, _ = _run_logged(
            ["git", "-C", str(FRANKLIN_ROOT), "pull", "--ff-only"],
            dry_run=dry_run,
        )
        if ok and _resync_cli(dry_run=dry_run):
            ui.print_success("Franklin core updated")
        else:
            failed = True

    ui.section_end()

    # Step 2: Update Sheldon plugins
    ui.print_header("Updating Sheldon plugins")
    ok, _ = _run_logged(["sheldon", "lock", "--update"], dry_run=dry_run)
    if ok:
        ui.print_success("Sheldon plugins updated")
    else:
        ui.print_error("Failed to update Sheldon plugins (Sheldon is required)")
        failed = True

    ui.section_end()

    # Step 2b: Validate core tools
    ui.print_header("Validating core tools")
    if _has_bat():
        ui.print_success("bat present")
    else:
        ui.print_error("bat/batcat not found (bat is required)")
        failed = True

    ui.section_end()

    # Step 3: System packages (if --system)
    if system:
        if not yes and sys.stderr.isatty():
            confirm = Prompt.ask(
                "System package updates may require sudo. Continue?",
                choices=["y", "n"],
                default="n",
            )
            if confirm != "y":
                ui.print_info("Update cancelled")
                raise typer.Exit()

        ui.print_header("Updating system packages")
        os_family = _detect_os_family()
        if os_family == "unknown":
            ui.print_error("Could not detect supported OS for system updates")
            failed = True
        else:
            ok = _update_system_packages(os_family, dry_run=dry_run)
            if not ok:
                failed = True

        ui.section_end()

    if failed:
        raise typer.Exit(code=1)

    ui.print_final_success("Update complete!")


@app.command()
def config(
    color: Annotated[
        Optional[str],
        typer.Option("--color", help="Set MOTD color (hex code or color name)"),
    ] = None,
    services: Annotated[
        Optional[str],
        typer.Option(
            "--services",
            help='Comma-separated services to show in the MOTD (e.g. "nginx,redis"); pass "" to clear',
        ),
    ] = None,
):
    """
    Configure Franklin settings interactively or via flags.

    Without flags: Opens an interactive TUI.
    With --color: Sets the MOTD banner color.
    With --services: Sets the MOTD monitored services list.
    """

    def save_color(color_name: str, hex_color: str) -> None:
        _save_config_keys(
            {"MOTD_COLOR_NAME": color_name, "MOTD_COLOR": hex_color}
        )
        ui.print_success(f"MOTD color set to {color_name} ({hex_color})")

    # Flag-driven (non-interactive) path
    if services is not None:
        cleaned = ",".join(s.strip() for s in services.split(",") if s.strip())
        _save_config_keys({"MONITORED_SERVICES": cleaned})
        if cleaned:
            ui.print_success(f"Monitored services set to: {cleaned}")
        else:
            ui.print_success("Monitored services cleared")
        if not color:
            return

    if color:
        # Accept canonical title-case ("Mauve Earth"), lowercase ("mauve earth"),
        # and kebab-case ("mauve-earth") for any CAMPFIRE_COLORS key.
        def _norm(name: str) -> str:
            return name.lower().replace("-", " ").replace("_", " ").strip()

        lookup = {_norm(k): k for k in CAMPFIRE_COLORS}
        normalized = _norm(color)
        if normalized in lookup:
            canonical = lookup[normalized]
            save_color(canonical, CAMPFIRE_COLORS[canonical]["base"])
            return
        if (
            color.startswith("#")
            and len(color) == 7
            and re.match(r"^#[0-9a-fA-F]{6}$", color)
        ):
            save_color("custom", color)
            return
        ui.print_error(f"Invalid color: {color}")
        ui.print_info(f"Valid colors: {', '.join(CAMPFIRE_COLORS.keys())}")
        ui.print_info("Or use hex format: #rrggbb")
        raise typer.Exit(code=1)

    # Interactive mode
    ui.print_header("Franklin Configuration")

    # Show current color
    from .motd import load_motd_color

    current_color_name, current_colors = load_motd_color()
    ui.print_branch(
        f"Current MOTD color: {current_color_name} ({current_colors['base']})"
    )

    # Color selection with base + dark swatches
    ui.print_branch("Available Campfire colors:")
    console.print()
    choices = list(CAMPFIRE_COLORS.keys())
    for idx, name in enumerate(choices, start=1):
        colors = CAMPFIRE_COLORS[name]
        base_color = colors["base"]
        dark_color = colors["dark"]
        console.print(
            f"  {idx:2d}) [bold {base_color}]████[/bold {base_color}] [bold {dark_color}]████[/bold {dark_color}]  {name:<15} (base {base_color}, dark {dark_color})"
        )

    default_idx = choices.index(DEFAULT_CAMPFIRE_COLOR) + 1
    selection = Prompt.ask(
        "\nSelect a color number or enter a hex code",
        default=str(default_idx),
    ).strip()

    # Allow hex entry directly
    if (
        selection.startswith("#")
        and len(selection) == 7
        and re.match(r"^#[0-9a-fA-F]{6}$", selection)
    ):
        save_color("custom", selection)
        return

    sel_int, was_valid = _parse_numeric_selection(
        selection, default_idx, len(choices)
    )
    if was_valid:
        color_choice = choices[sel_int - 1]
        save_color(color_choice, CAMPFIRE_COLORS[color_choice]["base"])
        return

    ui.print_error(f"Invalid selection: {selection}")
    raise typer.Exit(code=1)


@app.command()
def uninstall(
    yes: Annotated[
        bool,
        typer.Option("--yes", "-y", help="Skip confirmation prompt"),
    ] = False,
):
    """
    Restore your pre-Franklin shell configuration.

    Removes the Franklin-managed symlinks (~/.zshrc, sheldon, starship, mise
    configs) and restores the most recent pre-install backup of your Zsh
    dotfiles. The install directory, venv, and backups are left on disk;
    their paths are printed so you can remove them manually.
    """
    ui.print_header("Uninstalling Franklin")

    if not yes and sys.stderr.isatty():
        confirm = Prompt.ask(
            "This will unlink Franklin's shell configuration and restore your backed-up dotfiles. Continue?",
            choices=["y", "n"],
            default="n",
        )
        if confirm != "y":
            ui.print_info("Uninstall cancelled")
            raise typer.Exit()

    franklin_root = FRANKLIN_ROOT.resolve()

    def _points_into_franklin(link: Path) -> bool:
        try:
            return str(link.resolve()).startswith(str(franklin_root) + os.sep)
        except OSError:
            return False

    # 1. Remove Franklin-managed symlinks (only if they point into the install)
    managed_links = [
        Path.home() / ".zshrc",
        Path.home() / ".config" / "sheldon" / "plugins.toml",
        Path.home() / ".config" / "starship.toml",
        Path.home() / ".config" / "mise" / "config.toml",
        Path.home() / ".local" / "bin" / "franklin",
    ]
    for link in managed_links:
        if link.is_symlink() and _points_into_franklin(link):
            link.unlink()
            ui.print_branch(f"Removed symlink {link}")

    # 2. Restore the most recent backup of the Zsh dotfiles
    backups_root = FRANKLIN_ROOT / "backups"
    snapshots = (
        sorted(p for p in backups_root.iterdir() if p.is_dir())
        if backups_root.is_dir()
        else []
    )
    if snapshots:
        latest = snapshots[-1]
        restored = False
        for name in (".zshrc", ".zprofile", ".zshenv"):
            src = latest / name
            dest = Path.home() / name
            if src.is_file() and not dest.exists():
                shutil.copy2(src, dest)
                ui.print_branch(f"Restored {name} from {latest.name}")
                restored = True
        if not restored:
            ui.print_branch(f"Nothing to restore from backup {latest.name}")
    else:
        ui.print_branch("No backups found; nothing to restore")

    ui.section_end()
    ui.print_final_success("Franklin unlinked.")
    ui.print_info("Left on disk (remove manually if desired):")
    ui.print_branch(f"Install root: {FRANKLIN_ROOT}")
    ui.print_branch(f"Config:       {CONFIG_DIR}")
    ui.print_branch(f"Overrides:    {Path.home() / '.franklin.local.zsh'}")
    ui.print_info(
        "If zsh was set as your login shell and you want it back: chsh -s /bin/bash (or your preferred shell)"
    )


@app.command()
def motd():
    """
    Display the Message of the Day (MOTD) banner.
    """
    render_motd()


def main():
    """Entry point for setuptools console_scripts."""
    app()


if __name__ == "__main__":
    main()
