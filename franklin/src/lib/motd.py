"""
MOTD (Message of the Day) Generator

Implements the Campfire-style MOTD banner with:
- Rich color palette (dark/base/light variants)
- Horizontal rule dividers
- System stats with ASCII progress bars
- Docker containers status (grid layout)
- System services status (grid layout)
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
from rich.text import Text

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
    except (socket.error, OSError):
        return "unknown"


def get_ip_address() -> str:
    """Get the primary IP address."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except (socket.error, OSError, TimeoutError):
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
                timeout=2,
            )
            return f"macOS {result.stdout.strip()}"
        except (
            FileNotFoundError,
            subprocess.CalledProcessError,
            subprocess.TimeoutExpired,
        ):
            return "macOS"
    elif system == "Linux":
        try:
            with open("/etc/os-release") as f:
                os_release = {}
                for line in f:
                    if "=" in line:
                        key, value = line.strip().split("=", 1)
                        # Handle quoted values with potential escaped quotes
                        if value.startswith('"') and value.endswith('"'):
                            value = value[1:-1].replace('\\"', '"')
                        elif value.startswith("'") and value.endswith("'"):
                            value = value[1:-1].replace("\\'", "'")
                        os_release[key] = value

                distro = os_release.get("NAME", "Linux")
                version = os_release.get("VERSION_ID", "")
                return f"{distro} {version}" if version else distro
        except (FileNotFoundError, IOError, OSError):
            return "Linux"
    else:
        return system


def create_progress_bar(percent: float, width: int = 10) -> str:
    """Create an ASCII progress bar."""
    filled = int((percent / 100) * width)
    empty = width - filled
    return f"|{'█' * filled}{'░' * empty}|"


def get_disk_stats() -> Tuple[str, float, str, str]:
    """Get disk usage statistics."""
    try:
        disk = shutil.disk_usage("/")
        total_gb = disk.total / (1024**3)
        used_gb = disk.used / (1024**3)
        percent = (disk.used / disk.total) * 100

        bar = create_progress_bar(percent)
        return bar, percent, f"{used_gb:.0f}G", f"{total_gb:.0f}G"
    except Exception:
        return "|??????????|", 0, "??", "??"


def get_memory_stats() -> Tuple[str, str]:
    """Get memory usage statistics."""
    try:
        mem = psutil.virtual_memory()
        used_gb = mem.used / (1024**3)
        total_gb = mem.total / (1024**3)
        return f"{used_gb:.0f}G", f"{total_gb:.0f}G"
    except Exception:
        return "??", "??"


def get_docker_containers() -> List[str]:
    """Get list of running Docker containers (with mock data if none)."""
    try:
        result = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}"],
            capture_output=True,
            text=True,
            check=True,
            timeout=2,
        )
        containers = [
            name.strip() for name in result.stdout.strip().split("\n") if name.strip()
        ]
        return containers
    except (
        FileNotFoundError,
        subprocess.CalledProcessError,
        subprocess.TimeoutExpired,
    ):
        # Return empty list if Docker isn't available
        return []


def get_monitored_services_list() -> List[str]:
    """
    Get list of services to monitor from config file.

    Users can define services in ~/.config/franklin/config.env:
        MONITORED_SERVICES="service1,service2,service3"
    """
    monitored = []

    try:
        if CONFIG_FILE.exists():
            with open(CONFIG_FILE) as f:
                for line in f:
                    if line.startswith("MONITORED_SERVICES="):
                        services_str = line.split("=", 1)[1].strip().strip('"')
                        monitored = [
                            s.strip() for s in services_str.split(",") if s.strip()
                        ]
                        break
    except (FileNotFoundError, IOError, OSError):
        pass

    return monitored


def get_system_services() -> List[str]:
    """Get list of running system services configured by user."""
    monitored_services = get_monitored_services_list()

    if not monitored_services:
        return []

    running_services = []
    system = platform.system()

    try:
        if system == "Darwin":
            # macOS: Check for specific services via launchctl
            result = subprocess.run(
                ["launchctl", "list"],
                capture_output=True,
                text=True,
                check=True,
                timeout=2,
            )
            # Check which monitored services are running using word boundary matching
            for service in monitored_services:
                import re

                for line in result.stdout.split("\n"):
                    if re.search(
                        r"\b" + re.escape(service) + r"\b", line, re.IGNORECASE
                    ):
                        running_services.append(service)
                        break

        elif system == "Linux":
            # Linux: Use systemctl to check each monitored service
            for service in monitored_services:
                try:
                    result = subprocess.run(
                        ["systemctl", "is-active", service],
                        capture_output=True,
                        text=True,
                        timeout=1,
                    )
                    if result.stdout.strip() == "active":
                        running_services.append(service)
                except Exception:
                    continue

    except Exception:
        pass

    return running_services


def format_grid(
    items: List[str], width: int, color: str, max_item_width: int = 22
) -> List[Text]:
    """Format items in a grid layout with color."""
    if not items:
        return []

    items_per_line = max(1, (width - 1) // max_item_width)

    lines = []
    for i in range(0, len(items), items_per_line):
        chunk = items[i : i + items_per_line]
        line = Text()
        for item in chunk:
            line.append(f" {GLYPH_ACTION} ", style=color)
            line.append(f"{item:<{max_item_width - 4}} ", style=color)
        lines.append(line)

    return lines


def load_motd_color() -> Tuple[str, Dict[str, str]]:
    """
    Load the user's MOTD color preference from config.

    Returns:
        Tuple of (color_name, color_dict) with dark/base/light variants
    """
    color_name = DEFAULT_CAMPFIRE_COLOR

    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE) as f:
                for line in f:
                    if line.startswith("MOTD_COLOR_NAME="):
                        color_name = line.split("=", 1)[1].strip().strip('"')
                        break
        except (FileNotFoundError, IOError, OSError):
            pass

    # If custom color or unknown, use default
    if color_name not in CAMPFIRE_COLORS:
        color_name = DEFAULT_CAMPFIRE_COLOR

    return color_name, CAMPFIRE_COLORS[color_name]


def render_motd(width: Optional[int] = None) -> None:
    """
    Render the Campfire MOTD banner.

    Displays:
    - Hostname and IP address
    - System stats (disk, RAM, OS version)
    - Running Docker containers (if Docker is available)
    - Monitored services (configured in ~/.config/franklin/config.env)

    To monitor custom services, add to your config file:
        MONITORED_SERVICES="service1,service2,service3"
    """
    console = Console()

    # Determine terminal width
    if width is None:
        width = console.width

    # Constrain to MOTD min/max
    width = max(MOTD_MIN_WIDTH, min(width, MOTD_MAX_WIDTH))

    # Load user's color preference (get name and variants)
    color_name, colors = load_motd_color()
    dark = colors["dark"]
    base = colors["base"]
    light = colors["light"]

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

    # Top border (dark)
    console.print(hr, style=dark)

    # Header line: white ">" then light color for hostname/IP
    header_line = Text()
    header_line.append(" > ", style="white")
    header_line.append(f"{hostname} ({ip})", style=light)

    # Right-align version in base color
    version_text = f"🐢 {version}"
    current_len = len(f" > {hostname} ({ip})")
    padding = width - current_len - len(version_text) - 1  # -1 for emoji width
    header_line.append(" " * padding)
    header_line.append(version_text, style=base)

    console.print(header_line)

    # Middle border (dark)
    console.print(hr, style=dark)

    # Stats line with varied colors
    stats_line = Text()
    stats_line.append("  ", style=base)
    stats_line.append(disk_bar, style=light)
    stats_line.append(f" {disk_pct:.0f}% {disk_used}/{disk_total}", style=base)
    stats_line.append("               ", style=base)
    stats_line.append("RAM ", style=light)
    stats_line.append(f"{mem_used}/{mem_total}", style=base)

    # Right-align OS version
    stats_text = f"  {disk_bar} {disk_pct:.0f}% {disk_used}/{disk_total}               RAM {mem_used}/{mem_total}"
    os_padding = width - len(stats_text) - len(os_version)
    stats_line.append(" " * os_padding)
    stats_line.append(os_version, style=light)

    console.print(stats_line)

    # Bottom border (dark)
    console.print(" " + hr, style=dark)

    # Docker containers section (if any)
    if containers:
        console.print()
        console.print(" Docker Containers:", style=base)
        for line in format_grid(containers, width, light):
            console.print(line)

    # Services section (if any)
    if services:
        console.print()
        console.print(" Services:", style=base)
        for line in format_grid(services, width, light):
            console.print(line)

    # Final spacing
    if containers or services:
        console.print()


if __name__ == "__main__":
    render_motd()
