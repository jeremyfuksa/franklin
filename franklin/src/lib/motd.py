"""
MOTD (Message of the Day) Generator

Implements the Campfire-style MOTD banner with:
- Horizontal rule dividers
- System stats with ASCII progress bars
- Docker containers status (grid layout)
- System services status (grid layout)
- User-selected Campfire color palette
"""

import os
import platform
import socket
import subprocess
import shutil
from pathlib import Path
from typing import Optional, List, Dict, Tuple

import psutil
from rich.console import Console

from .constants import (
    CAMPFIRE_COLORS,
    DEFAULT_CAMPFIRE_COLOR,
    MOTD_MAX_WIDTH,
    MOTD_MIN_WIDTH,
    CONFIG_FILE,
    GLYPH_ACTION,
)


def get_franklin_version() -> str:
    """Read Franklin version from VERSION file."""
    version_file = Path(__file__).parent.parent.parent.parent / "VERSION"
    if version_file.exists():
        return version_file.read_text().strip()
    return "unknown"


def get_hostname() -> str:
    """Get the system hostname."""
    try:
        return socket.gethostname()
    except Exception:
        return "unknown"


def get_ip_address() -> str:
    """Get the primary IP address."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "0.0.0.0"


def get_os_version() -> str:
    """Get OS version string."""
    system = platform.system()

    if system == "Darwin":
        try:
            result = subprocess.run(
                ["sw_vers", "-productVersion"],
                capture_output=True,
                text=True,
                check=True,
            )
            return f"macOS {result.stdout.strip()}"
        except Exception:
            return "macOS"
    elif system == "Linux":
        try:
            with open("/etc/os-release") as f:
                os_release = {}
                for line in f:
                    if "=" in line:
                        key, value = line.strip().split("=", 1)
                        os_release[key] = value.strip('"')

                distro = os_release.get("NAME", "Linux")
                version = os_release.get("VERSION_ID", "")
                return f"{distro} {version}" if version else distro
        except Exception:
            return "Linux"
    else:
        return system


def create_progress_bar(percent: float, width: int = 10) -> str:
    """
    Create an ASCII progress bar.

    Args:
        percent: Percentage (0-100)
        width: Width of the bar in characters

    Returns:
        String like |███████░░░|
    """
    filled = int((percent / 100) * width)
    empty = width - filled
    return f"|{'█' * filled}{'░' * empty}|"


def get_disk_stats() -> Tuple[str, float, str, str]:
    """
    Get disk usage statistics.

    Returns:
        Tuple of (progress_bar, percent, used, total)
    """
    try:
        disk = shutil.disk_usage("/")
        total_gb = disk.total / (1024 ** 3)
        used_gb = disk.used / (1024 ** 3)
        percent = (disk.used / disk.total) * 100

        bar = create_progress_bar(percent)
        return bar, percent, f"{used_gb:.0f}G", f"{total_gb:.0f}G"
    except Exception:
        return "|??????????|", 0, "??", "??"


def get_memory_stats() -> Tuple[str, str]:
    """
    Get memory usage statistics.

    Returns:
        Tuple of (used, total)
    """
    try:
        mem = psutil.virtual_memory()
        used_gb = mem.used / (1024 ** 3)
        total_gb = mem.total / (1024 ** 3)
        return f"{used_gb:.0f}G", f"{total_gb:.0f}G"
    except Exception:
        return "??", "??"


def get_docker_containers() -> List[str]:
    """
    Get list of running Docker containers.

    Returns:
        List of container names
    """
    try:
        result = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}"],
            capture_output=True,
            text=True,
            check=True,
        )
        containers = [name.strip() for name in result.stdout.strip().split("\n") if name.strip()]
        return containers
    except Exception:
        return []


def get_system_services() -> List[str]:
    """
    Get list of running system services.

    Returns:
        List of service names
    """
    services = []
    system = platform.system()

    if system == "Darwin":
        # macOS: Check for specific services via launchctl
        try:
            result = subprocess.run(
                ["launchctl", "list"],
                capture_output=True,
                text=True,
                check=True,
            )
            # Parse output and filter for common services
            # This is a simplified approach - could be enhanced
            for line in result.stdout.split("\n"):
                # Look for common service patterns
                for svc in ["meshtasticd", "spyserver"]:
                    if svc in line.lower():
                        services.append(svc)
        except Exception:
            pass
    elif system == "Linux":
        # Linux: Use systemctl
        try:
            result = subprocess.run(
                ["systemctl", "--type=service", "--state=running", "--no-pager", "--no-legend"],
                capture_output=True,
                text=True,
                check=True,
            )
            for line in result.stdout.split("\n"):
                if line.strip():
                    # Extract service name (first column)
                    parts = line.split()
                    if parts:
                        service_name = parts[0].replace(".service", "")
                        services.append(service_name)
        except Exception:
            pass

    return services


def format_grid(items: List[str], width: int, max_item_width: int = 22) -> List[str]:
    """
    Format items in a grid layout.

    Args:
        items: List of item names
        width: Terminal width
        max_item_width: Maximum width for each item including glyph and padding

    Returns:
        List of formatted lines
    """
    if not items:
        return []

    # Calculate how many items fit per line
    items_per_line = max(1, (width - 1) // max_item_width)

    lines = []
    for i in range(0, len(items), items_per_line):
        chunk = items[i:i + items_per_line]
        formatted = [f" {GLYPH_ACTION} {item:<{max_item_width - 4}}" for item in chunk]
        lines.append("".join(formatted))

    return lines


def load_motd_color() -> str:
    """
    Load the user's MOTD color preference from config.

    Returns:
        Hex color string (e.g., "#607a97")
    """
    if not CONFIG_FILE.exists():
        return CAMPFIRE_COLORS[DEFAULT_CAMPFIRE_COLOR]

    try:
        with open(CONFIG_FILE) as f:
            for line in f:
                if line.startswith("MOTD_COLOR="):
                    color = line.split("=", 1)[1].strip().strip('"')
                    return color
    except Exception:
        pass

    return CAMPFIRE_COLORS[DEFAULT_CAMPFIRE_COLOR]


def render_motd(width: Optional[int] = None) -> None:
    """
    Render the Campfire MOTD banner.

    Args:
        width: Terminal width (auto-detected if None)
    """
    console = Console()

    # Determine terminal width
    if width is None:
        width = console.width

    # Constrain to MOTD min/max
    width = max(MOTD_MIN_WIDTH, min(width, MOTD_MAX_WIDTH))

    # Load user's color preference
    color = load_motd_color()

    # Gather all stats
    hostname = get_hostname()
    ip = get_ip_address()
    version = get_franklin_version()
    os_version = get_os_version()

    disk_bar, disk_pct, disk_used, disk_total = get_disk_stats()
    mem_used, mem_total = get_memory_stats()

    containers = get_docker_containers()
    services = get_system_services()

    # Build output
    hr = "─" * width

    # Header line
    header = f" > {hostname} ({ip})"
    version_text = f"🐢 {version}"
    padding = width - len(header) - len(version_text)
    header_line = f"{header}{' ' * padding}{version_text}"

    # Stats line
    stats_line = f"  {disk_bar} {disk_pct:.0f}% {disk_used}/{disk_total}"
    stats_line += f"{'':15}RAM {mem_used}/{mem_total}"
    stats_line += f"{' ' * (width - len(stats_line) - len(os_version))}{os_version}"

    # Print with color
    console.print(hr, style=color)
    console.print(header_line, style=color)
    console.print(hr, style=color)
    console.print(stats_line, style=color)
    console.print(" " + hr, style=color)

    # Docker containers
    if containers:
        console.print(" Docker Containers:", style=color)
        for line in format_grid(containers, width):
            console.print(line, style=color)
        console.print()

    # Services
    if services:
        console.print(" Services:", style=color)
        for line in format_grid(services, width):
            console.print(line, style=color)
        console.print()


if __name__ == "__main__":
    render_motd()
