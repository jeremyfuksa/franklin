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
# These are the signature colors users can select for their MOTD banner.
# Each color has base/dark/light variants for visual hierarchy.
#
# Colors with a Campfire semantic scale (primary/secondary/neutral/success/
# warning/danger/info) use `base`=scale-500, `dark`=scale-700, `light`=scale-300.
# (Blue Calx / info uses `light`=scale-100 because the info scale is unusually
# compressed at the 300-500 end — scale-300 would be indistinguishable from
# base.) The 8 signature-only accent colors use Campfire's dark-mode swatch as
# base, its light-mode swatch as light, and a -18% HSL L shift for dark.
CAMPFIRE_COLORS = {
    "Cello": {
        "base":  "#607a97",  # primary-500
        "dark":  "#3e4f66",  # primary-700
        "light": "#acbbcc",  # primary-300
    },
    "Terracotta": {
        "base":  "#b87b6a",  # secondary-500
        "dark":  "#8d5443",  # secondary-700
        "light": "#dbbdb3",  # secondary-300
    },
    "Black Rock": {
        "base":  "#747b8a",  # neutral-500
        "dark":  "#4d515c",  # neutral-700
        "light": "#b8bcc5",  # neutral-300
    },
    "Sage": {
        "base":  "#8fb14b",  # success-500
        "dark":  "#5a6f2d",  # success-700
        "light": "#b1d27e",  # success-300
    },
    "Golden Amber": {
        "base":  "#f9c574",  # warning-500
        "dark":  "#d97706",  # warning-700
        "light": "#fddfa0",  # warning-300
    },
    "Flamingo": {
        "base":  "#e75351",  # danger-500
        "dark":  "#be2b29",  # danger-700
        "light": "#f8a5a4",  # danger-300
    },
    "Blue Calx": {
        "base":  "#b8c5d9",  # info-500
        "dark":  "#8899b3",  # info-700
        "light": "#e8eef6",  # info-100 (info scale is compressed; 300 ≈ base)
    },
    # --- Signature accent colors (from Campfire's signature palette) ---
    # base  = Campfire dark-mode swatch (saturated, reads well on terminal bg)
    # light = Campfire light-mode swatch (pastel)
    # dark  = base darkened ~18% in HSL L (matches spread of entries above)
    "Clay": {
        "base":  "#c89c8d",
        "dark":  "#a86751",
        "light": "#e5beb0",
    },
    "Ember": {
        "base":  "#d97706",
        "dark":  "#804604",
        "light": "#f5a855",
    },
    "Hay": {
        "base":  "#d4b86a",
        "dark":  "#b08f33",
        "light": "#f2d88f",
    },
    "Moss": {
        "base":  "#5a6f2d",
        "dark":  "#252e13",
        "light": "#88a055",
    },
    "Pine": {
        "base":  "#4a7c7e",
        "dark":  "#284344",
        "light": "#75acaf",
    },
    "Dusk": {
        "base":  "#8b7a9f",
        "dark":  "#5d4f6e",
        "light": "#b8a0cc",
    },
    "Mauve Earth": {
        "base":  "#9b6b7f",
        "dark":  "#664552",
        "light": "#c898ad",
    },
    # Stone is Campfire's signature name for the same neutral gray-blue Franklin
    # historically called "Black Rock". Both entries exist so legacy configs
    # keep working; Stone is the canonical Campfire name going forward.
    "Stone": {
        "base":  "#747b8a",
        "dark":  "#4a4f58",
        "light": "#a0a8b5",
    },
}

# Default color
DEFAULT_CAMPFIRE_COLOR = "Cello"

# --- UI Chrome Colors (for CLI output, not MOTD) ---
# These are used for the UI helpers in ui.py. Aligned with Campfire's semantic
# scales so install/update chrome shares the MOTD banner's visual language.
UI_ERROR_COLOR = "#e75351"    # danger-500 (Flamingo family)
UI_SUCCESS_COLOR = "#8fb14b"  # success-500 (Sage family)
UI_INFO_COLOR = "#607a97"     # primary-500 (Cello family) — info-500 is too pale for chrome
UI_WARNING_COLOR = "#f9c574"  # warning-500 (Golden Amber family)

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
