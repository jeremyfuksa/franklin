"""
Franklin CLI Entry Point

Implements the command-line interface for Franklin using Typer.
Commands follow the "Campfire" UX standards.
"""

import os
import subprocess
import sys
from pathlib import Path
from typing import Optional
from typing_extensions import Annotated

import typer
from rich.console import Console
from rich.prompt import Prompt
from rich.table import Table

from .constants import (
    CAMPFIRE_COLORS,
    DEFAULT_CAMPFIRE_COLOR,
    CONFIG_FILE,
    CONFIG_DIR,
    FRANKLIN_ROOT,
)
from .ui import ui
from .motd import render_motd, get_franklin_version


app = typer.Typer(
    name="franklin",
    help="A modern Zsh environment manager with cross-platform support.",
    add_completion=False,
)

console = Console()


def version_callback(value: bool):
    """Callback for --version flag."""
    if value:
        version = get_franklin_version()
        console.print(f"Franklin v{version}")
        raise typer.Exit()


@app.callback()
def main(
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
):
    """
    Franklin: A modern Zsh environment manager.
    """
    pass


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

    checks = {}

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

    # Check Python
    python_version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    checks["Python"] = python_version

    # Check Franklin root
    if FRANKLIN_ROOT.exists():
        checks["Franklin Root"] = str(FRANKLIN_ROOT)
    else:
        checks["Franklin Root"] = "Not found"

    # Output
    if json_output:
        import json
        print(json.dumps(checks, indent=2))
    else:
        ui.print_columnar(checks)


@app.command()
def update(
    yes: Annotated[
        bool,
        typer.Option("--yes", "-y", help="Skip confirmation prompts"),
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
    try:
        result = subprocess.run(
            ["git", "-C", str(FRANKLIN_ROOT), "pull"],
            capture_output=True,
            text=True,
            check=True,
        )
        if result.stdout:
            for line in result.stdout.strip().split("\n"):
                if line:  # Skip empty lines
                    ui.console.print(f"      {line}")
        ui.print_success("Franklin core updated")
    except subprocess.CalledProcessError as e:
        ui.print_error(f"Failed to update: {e.stderr}")
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
):
    """
    Update Franklin core, plugins, and optionally system packages.

    With --system: Updates OS packages, Sheldon plugins, Starship, NVM, and Node.
    Without --system: Updates only Franklin core and Sheldon plugins.
    """
    ui.print_header("Franklin Update")
    
    # Step 1: Update Franklin core
    ui.print_header("Updating Franklin core")
    ui.print_branch(f"Franklin root: {FRANKLIN_ROOT}")
    
    if not (FRANKLIN_ROOT / ".git").exists():
        ui.print_warning("Franklin root is not a git repository, skipping core update")
    else:
        ui.print_branch("Pulling latest changes...")
        try:
            result = subprocess.run(
                ["git", "-C", str(FRANKLIN_ROOT), "pull"],
                capture_output=True,
                text=True,
                check=True,
            )
            if result.stdout:
                for line in result.stdout.strip().split("\n"):
                    if line:
                        ui.console.print(f"      {line}")
            ui.print_success("Franklin core updated")
        except subprocess.CalledProcessError as e:
            ui.print_error(f"Failed to update Franklin core: {e.stderr}")
    
    ui.section_end()

    # Step 2: Update Sheldon plugins
    ui.print_header("Updating Sheldon plugins")
    try:
        result = subprocess.run(
            ["sheldon", "lock", "--update"],
            capture_output=True,
            text=True,
            check=True,
        )
        if result.stdout:
            for line in result.stdout.strip().split("\n"):
                if line and not line.startswith("Warning"):
                    ui.console.print(f"      {line}")
        ui.print_success("Sheldon plugins updated")
    except subprocess.CalledProcessError as e:
        ui.print_warning(f"Failed to update Sheldon plugins: {e.stderr}")
    except FileNotFoundError:
        ui.print_warning("Sheldon not found, skipping plugin update")
    
    ui.section_end()

    # Step 3: System packages (if --system)
    if system:
        ui.print_header("Updating system packages")
        # Detect OS and run appropriate package manager
        # This is a placeholder - full implementation would detect OS
        # and run brew/apt/dnf accordingly
        ui.print_info("System package update not yet implemented")
        ui.section_end()

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


if __name__ == "__main__":
    app()
