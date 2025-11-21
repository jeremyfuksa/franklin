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
        "base": "#607a97",
        "dark": "#4a5f77",
        "light": "#8fa9c3",
    },
    "Terracotta": {
        "base": "#b87b6a",
        "dark": "#8f5d4d",
        "light": "#d9a393",
    },
    "Black Rock": {
        "base": "#747b8a",
        "dark": "#5a606d",
        "light": "#9ca3b0",
    },
    "Sage": {
        "base": "#8fb14b",
        "dark": "#6d8a38",
        "light": "#b3d375",
    },
    "Golden Amber": {
        "base": "#f9c574",
        "dark": "#d9a555",
        "light": "#ffd99d",
    },
    "Flamingo": {
        "base": "#e75351",
        "dark": "#c73e3c",
        "light": "#ff7b79",
    },
    "Blue Calx": {
        "base": "#b8c5d9",
        "dark": "#95a5bd",
        "light": "#d4dfe8",
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
