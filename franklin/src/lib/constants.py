"""
Franklin Constants - Paths and Color Definitions
"""

from pathlib import Path
import os

# --- Paths ---
HOME = Path.home()
FRANKLIN_ROOT = Path(os.environ.get("FRANKLIN_ROOT", HOME / ".local" / "share" / "franklin"))
CONFIG_DIR = HOME / ".config" / "franklin"
CONFIG_FILE = CONFIG_DIR / "config.env"
BACKUP_DIR = FRANKLIN_ROOT / "backups"

# --- Campfire Color Palette (for MOTD) ---
# These are the signature colors users can select for their MOTD banner
# Each color has dark and light variants for visual hierarchy
CAMPFIRE_COLORS = {
    "Cello": {
        "base": "#607a97",   # H: 210° (blue-gray)
        "dark": "#4a5f77",   # H: 213° (shifts cooler/bluer)
        "light": "#8fa9bd",  # H: 207° (shifts warmer/toward cyan)
    },
    "Terracotta": {
        "base": "#b87b6a",   # H: 12° (warm terracotta)
        "dark": "#8f5d4f",   # H: 8° (shifts toward brick red)
        "light": "#d9a090",  # H: 16° (shifts toward peachy-pink)
    },
    "Black Rock": {
        "base": "#747b8a",   # H: 220° (cool gray-blue)
        "dark": "#5a5f6d",   # H: 225° (shifts cooler/bluer)
        "light": "#9ca3ad",  # H: 215° (shifts warmer/toward steel)
    },
    "Sage": {
        "base": "#8fb14b",   # H: 75° (yellow-green)
        "dark": "#6d8a3a",   # H: 72° (shifts toward olive)
        "light": "#b3d378",  # H: 78° (shifts toward lime)
    },
    "Golden Amber": {
        "base": "#f9c574",   # H: 40° (golden yellow)
        "dark": "#d9a558",   # H: 35° (shifts toward amber-orange)
        "light": "#ffd99f",  # H: 45° (shifts toward cream)
    },
    "Flamingo": {
        "base": "#e75351",   # H: 1° (coral-red)
        "dark": "#c73e3e",   # H: 0° (shifts toward deep burgundy)
        "light": "#ff7b7d",  # H: 359° (shifts toward pink-coral)
    },
    "Blue Calx": {
        "base": "#b8c5d9",   # H: 212° (powder blue)
        "dark": "#95a3bd",   # H: 218° (shifts toward periwinkle)
        "light": "#d4e0e8",  # H: 206° (shifts toward cyan-blue)
    },
}

# Default color
DEFAULT_CAMPFIRE_COLOR = "Cello"

# --- UI Chrome Colors (for CLI output, not MOTD) ---
# These are used for the UI helpers in ui.py
UI_ERROR_COLOR = "#bf616a"  # Red for errors
UI_SUCCESS_COLOR = "#a3be8c"  # Green for success
UI_INFO_COLOR = "#88c0d0"  # Blue for info
UI_WARNING_COLOR = "#ebcb8b"  # Yellow for warnings

# --- Glyph Dictionary ---
GLYPH_ACTION = "⏺"
GLYPH_BRANCH = "⎿"
GLYPH_LOGIC = "∴"
GLYPH_WAIT = "✻"
GLYPH_SUCCESS = "✔"
GLYPH_WARNING = "⚠"
GLYPH_ERROR = "✗"

# --- MOTD Layout Constants ---
MOTD_MAX_WIDTH = 80
MOTD_MIN_WIDTH = 40
MOTD_BORDER_CHAR = "─"
