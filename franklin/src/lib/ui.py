"""
Campfire UI Library - Rich-based TUI for Franklin CLI

Implements the "Campfire" UX Standards:
- Visual Philosophy: "Structured, Connected, Minimal"
- Hierarchy via strict indentation
- Data in aligned columns
- TTY detection for colors/animations
- Stream separation (stderr for UI, stdout for data)
"""

import os
import sys
from typing import Optional
from rich.console import Console
from rich.style import Style

from .constants import (
    GLYPH_ACTION,
    GLYPH_BRANCH,
    GLYPH_LOGIC,
    GLYPH_WAIT,
    GLYPH_SUCCESS,
    GLYPH_WARNING,
    GLYPH_ERROR,
    UI_ERROR_COLOR,
    UI_SUCCESS_COLOR,
    UI_INFO_COLOR,
    UI_WARNING_COLOR,
)


class CampfireUI:
    """
    Campfire-themed UI helper using Rich.

    All output goes to stderr to preserve stdout for machine-readable data.
    Colors and animations are automatically disabled when not in a TTY.
    """

    def __init__(self, no_color: Optional[bool] = None):
        """Initialize the Campfire UI with stderr console."""
        env_no_color = (
            os.environ.get("NO_COLOR") is not None
            or os.environ.get("FRANKLIN_NO_COLOR") is not None
        )
        # allow explicit override for tests or CLI flag
        self.no_color = env_no_color if no_color is None else no_color
        self._init_console()

        # Define styles
        self.style_error = Style(color=UI_ERROR_COLOR)
        self.style_success = Style(color=UI_SUCCESS_COLOR)
        self.style_info = Style(color=UI_INFO_COLOR)
        self.style_warning = Style(color=UI_WARNING_COLOR)

    def _init_console(self) -> None:
        """(Re)initialize the console based on current color settings."""
        self.console = Console(
            file=sys.stderr,
            force_terminal=None,
            no_color=self.no_color,
        )
        # Rich already handles TTY detection; also respect explicit no_color
        self.is_tty = self.console.is_terminal and not self.no_color

    def set_color(self, enable: bool) -> None:
        """Toggle colored output at runtime (e.g., from CLI flag)."""
        self.no_color = not enable
        self._init_console()

    def print_header(self, text: str, style: Optional[str] = None) -> None:
        """
        Print an action header (Level 0).

        Format: ⏺ text

        Args:
            text: The header text
            style: Optional Rich style/color
        """
        output = f"{GLYPH_ACTION} {text}"
        if style and self.is_tty:
            self.console.print(output, style=style)
        else:
            self.console.print(output)

    def print_branch(self, text: str, style: Optional[str | Style] = None) -> None:
        """
        Print a branch/output line (Level 1).

        Format: ⎿  text (3-space indent to align under parent glyph)

        Args:
            text: The branch text
            style: Optional Rich style/color (string or Style object)
        """
        output = f"{GLYPH_BRANCH}  {text}"
        if style and self.is_tty:
            self.console.print(output, style=style)
        else:
            self.console.print(output)

    def print_logic(self, text: str) -> None:
        """
        Print a logic/thought indicator.

        Format: ∴ text

        Args:
            text: The logic text
        """
        output = f"{GLYPH_LOGIC} {text}"
        self.console.print(output)

    def section_end(self) -> None:
        """
        Print a blank line for breathing room between sections.
        """
        self.console.print()

    def print_error(self, text: str) -> None:
        """
        Print an error message with red styling.

        Format: ⎿  ✗ text (in red)

        Args:
            text: The error message
        """
        output = f"{GLYPH_BRANCH}  {GLYPH_ERROR} {text}"
        if self.is_tty:
            self.console.print(output, style=self.style_error)
        else:
            self.console.print(output)

    def print_success(self, text: str) -> None:
        """
        Print a success message with green styling.

        Format: ⎿  ✔ text (in green)

        Args:
            text: The success message
        """
        output = f"{GLYPH_BRANCH}  {GLYPH_SUCCESS} {text}"
        if self.is_tty:
            self.console.print(output, style=self.style_success)
        else:
            self.console.print(output)

    def print_info(self, text: str) -> None:
        """
        Print an info message with blue styling.

        Format: ⎿  text (in blue)

        Args:
            text: The info message
        """
        self.print_branch(text, style=self.style_info if self.is_tty else None)

    def print_warning(self, text: str) -> None:
        """
        Print a warning message with yellow styling.

        Format: ⎿  ⚠ text (in yellow)

        Args:
            text: The warning message
        """
        output = f"{GLYPH_BRANCH}  {GLYPH_WARNING} {text}"
        if self.is_tty:
            self.console.print(output, style=self.style_warning)
        else:
            self.console.print(output)

    def print_final_success(self, text: str) -> None:
        """
        Print a final success message without branch glyph.

        Format: ✔ text (standalone, in green)

        Args:
            text: The success message
        """
        output = f"{GLYPH_SUCCESS} {text}"
        if self.is_tty:
            self.console.print(output, style=self.style_success)
        else:
            self.console.print(output)

    def print_columnar(self, data: dict[str, str], indent: int = 3) -> None:
        """
        Print key-value pairs in aligned columns.

        Format:
        ⎿  Key1       :: Value1
           Key2       :: Value2
           LongerKey  :: Value3

        Args:
            data: Dictionary of key-value pairs
            indent: Number of spaces to indent (default 3 for branch alignment)
        """
        if not data:
            return

        # Calculate max key length for alignment
        max_key_length = max((len(key) for key in data.keys()), default=0)

        for i, (key, value) in enumerate(data.items()):
            # First line gets the branch glyph, rest get spaces
            if i == 0:
                prefix = f"{GLYPH_BRANCH}  "
            else:
                prefix = " " * indent

            # Right-pad the key to align all values
            padded_key = key.ljust(max_key_length)
            output = f"{prefix}{padded_key} :: {value}"
            self.console.print(output)

    def truncate_output(
        self, lines: list[str], max_lines: int = 10, log_path: Optional[str] = None
    ) -> None:
        """
        Print output with truncation if it exceeds max_lines.

        Args:
            lines: List of output lines
            max_lines: Maximum lines to show before truncating
            log_path: Optional path to full log file
        """
        if len(lines) <= max_lines:
            for line in lines:
                self.print_branch(line)
        else:
            for line in lines[:max_lines]:
                self.print_branch(line)

            hidden_count = len(lines) - max_lines
            log_msg = f"... +{hidden_count} lines hidden"
            if log_path:
                log_msg += f" (full log at {log_path})"
            self.print_branch(log_msg)


# Global UI instance
ui = CampfireUI()
