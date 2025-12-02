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
        "base": "#607a97",   # H: 210° L: 48% (blue-gray)
        "dark": "#3d4f63",   # H: 213° L: 32% (shifts cooler/bluer, Δ-16%)
        "light": "#a3bdd4",  # H: 207° L: 73% (shifts warmer/cyan, Δ+25%)
    },
    "Terracotta": {
        "base": "#b87b6a",   # H: 12° L: 57% (warm terracotta)
        "dark": "#7a4a3e",   # H: 8° L: 38% (shifts toward brick red, Δ-19%)
        "light": "#e8b5a5",  # H: 16° L: 77% (shifts peachy-pink, Δ+20%)
    },
    "Black Rock": {
        "base": "#747b8a",   # H: 220° L: 51% (cool gray-blue)
        "dark": "#494f5c",   # H: 225° L: 33% (shifts cooler/bluer, Δ-18%)
        "light": "#a8b0be",  # H: 215° L: 71% (shifts warmer/steel, Δ+20%)
    },
    "Sage": {
        "base": "#8fb14b",   # H: 75° L: 50% (yellow-green)
        "dark": "#5a6e2f",   # H: 72° L: 32% (shifts toward olive, Δ-18%)
        "light": "#c5e088",  # H: 78° L: 73% (shifts toward lime, Δ+23%)
    },
    "Golden Amber": {
        "base": "#f9c574",   # H: 40° L: 72% (golden yellow)
        "dark": "#b8873e",   # H: 35° L: 52% (shifts amber-orange, Δ-20%)
        "light": "#ffe0b0",  # H: 45° L: 90% (shifts toward cream, Δ+18%)
    },
    "Flamingo": {
        "base": "#e75351",   # H: 1° L: 60% (coral-red)
        "dark": "#a12f2d",   # H: 0° L: 41% (shifts deep burgundy, Δ-19%)
        "light": "#ff9d9b",  # H: 359° L: 80% (shifts pink-coral, Δ+20%)
    },
    "Blue Calx": {
        "base": "#b8c5d9",   # H: 212° L: 78% (powder blue)
        "dark": "#7b8da8",   # H: 218° L: 58% (shifts periwinkle, Δ-20%)
        "light": "#e5edf5",  # H: 206° L: 93% (shifts cyan-blue, Δ+15%)
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
