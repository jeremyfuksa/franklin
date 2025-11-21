"""
Franklin CLI Entry Point

Implements the command-line interface for Franklin using Typer.
Commands follow the "Campfire" UX standards.
"""

import os
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


def _detect_os_family() -> str:
    """Detect OS family for package manager selection."""
    system = platform.system()
    if system == "Darwin":
        return "macos"
    if Path("/etc/debian_version").exists():
        return "debian"
    if Path("/etc/redhat-release").exists():
        return "rhel"
    return "unknown"


def _run_logged(cmd: List[str], dry_run: bool = False) -> Tuple[bool, List[str]]:
    """
    Run a command, streaming stdout to UI branch lines.

    Returns (success, stdout_lines) without raising so callers can collect failures.
    """
    if dry_run:
        ui.print_branch(f"DRY RUN: {' '.join(cmd)}")
        return True, []
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
        )
        lines = [line for line in result.stdout.strip().split("\n") if line]
        for line in lines:
            ui.console.print(f"      {line}")
        return True, lines
    except FileNotFoundError:
        ui.print_error(f"{cmd[0]} not found on this system")
        return False, []
    except subprocess.CalledProcessError as e:
        stderr = e.stderr.strip() if e.stderr else str(e)
        ui.print_error(stderr)
        return False, []


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

    if os_family == "rhel":
        ui.print_branch("Using dnf")
        ok_update, _ = _run_logged(["sudo", "dnf", "makecache"], dry_run=dry_run)
        upgrade_cmd = ["sudo", "dnf", "upgrade", "-y"]
        if dry_run:
            upgrade_cmd = ["dnf", "upgrade", "--assumeno"]
        ok_upgrade, _ = _run_logged(upgrade_cmd, dry_run=dry_run)
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
        zsh_version = result.stdout.strip().split()[1]
        checks["Shell"] = f"Zsh {zsh_version}"
    except Exception:
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
        sheldon_version = result.stdout.strip().split()[1]
        checks["Plugin Manager"] = f"Sheldon {sheldon_version}"
    except Exception:
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
        starship_version = result.stdout.strip().split()[1]
        checks["Prompt"] = f"Starship {starship_version}"
    except Exception:
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

    # Check Franklin root
    if FRANKLIN_ROOT.exists():
        checks["Franklin Root"] = str(FRANKLIN_ROOT)
    else:
        checks["Franklin Root"] = "Not found"
        failures.append("franklin_root")

    # Output
    if json_output:
        import json

        print(json.dumps(checks, indent=2))
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
        ui.print_branch("DRY RUN: git -C <franklin_root> pull")
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

    # Run git pull
    ui.print_branch("Pulling latest changes...")
    ok, _ = _run_logged(["git", "-C", str(FRANKLIN_ROOT), "pull"])
    if not ok:
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

    With --system: Updates OS packages, Sheldon plugins, Starship, NVM, and Node.
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
        ok, _ = _run_logged(["git", "-C", str(FRANKLIN_ROOT), "pull"], dry_run=dry_run)
        if ok:
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
):
    """
    Configure Franklin settings interactively or via flags.

    Without flags: Opens an interactive TUI.
    With --color: Sets the MOTD banner color.
    """
    if color:
        # Set color directly
        if color in CAMPFIRE_COLORS:
            color_name = color
            hex_color = CAMPFIRE_COLORS[color]["base"]
        elif color.startswith("#") and len(color) == 7:
            color_name = "custom"
            hex_color = color
        else:
            ui.print_error(f"Invalid color: {color}")
            ui.print_info(f"Valid colors: {', '.join(CAMPFIRE_COLORS.keys())}")
            ui.print_info("Or use hex format: #rrggbb")
            raise typer.Exit(code=1)

        # Save to config (store color name for variants, or hex if custom)
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        with open(CONFIG_FILE, "w") as f:
            f.write(f'MOTD_COLOR_NAME="{color_name}"\n')
            f.write(f'MOTD_COLOR="{hex_color}"\n')

        ui.print_success(f"MOTD color set to {color} ({hex_color})")
        return

    # Interactive mode
    ui.print_header("Franklin Configuration")

    # Show current color
    from .motd import load_motd_color
    current_color_name, current_colors = load_motd_color()
    ui.print_branch(f"Current MOTD color: {current_color_name} ({current_colors['base']})")

    # Color selection with visual swatches
    ui.print_branch("Available Campfire colors:")
    console.print()
    for name, colors in CAMPFIRE_COLORS.items():
        base_color = colors["base"]
        # Display colored block characters as preview
        console.print(f"  [bold {base_color}]████[/bold {base_color}]  {name:<15} ({base_color})")

    color_choice = Prompt.ask(
        "\nSelect a color name or enter a hex code",
        default=DEFAULT_CAMPFIRE_COLOR,
    )

    # Validate and save
    if color_choice in CAMPFIRE_COLORS:
        color_name = color_choice
        hex_color = CAMPFIRE_COLORS[color_choice]["base"]
    elif color_choice.startswith("#") and len(color_choice) == 7:
        color_name = "custom"
        hex_color = color_choice
    else:
        ui.print_error(f"Invalid color: {color_choice}")
        raise typer.Exit(code=1)

    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, "w") as f:
        f.write(f'MOTD_COLOR_NAME="{color_name}"\n')
        f.write(f'MOTD_COLOR="{hex_color}"\n')

    ui.print_success(f"MOTD color set to {color_choice} ({hex_color})")


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
