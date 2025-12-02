"""
Franklin CLI Tests

Basic smoke tests for the Franklin CLI commands.
Run with: pytest test/test_cli.py -v
"""

import subprocess
import sys
from pathlib import Path

import pytest

# Ensure we can import from the Franklin source
FRANKLIN_ROOT = Path(__file__).parent.parent / "franklin"
sys.path.insert(0, str(FRANKLIN_ROOT / "src"))


class TestCLISmoke:
    """Smoke tests that verify CLI commands execute without crashing."""

    def test_version_flag(self):
        """Test that --version returns version string."""
        result = subprocess.run(
            ["python3", "-m", "lib.main", "--version"],
            cwd=FRANKLIN_ROOT / "src",
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "Franklin" in result.stdout or "franklin" in result.stdout.lower()

    def test_help_flag(self):
        """Test that --help shows usage information."""
        result = subprocess.run(
            ["python3", "-m", "lib.main", "--help"],
            cwd=FRANKLIN_ROOT / "src",
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "Usage" in result.stdout or "usage" in result.stdout.lower()

    def test_doctor_command(self):
        """Test that doctor command runs (may fail checks but shouldn't crash)."""
        result = subprocess.run(
            ["python3", "-m", "lib.main", "doctor"],
            cwd=FRANKLIN_ROOT / "src",
            capture_output=True,
            text=True,
        )
        # Doctor may return non-zero if deps are missing, but shouldn't crash
        assert result.returncode in (0, 1)
        # Should output something (either checks passed or failed)
        assert result.stderr or result.stdout

    def test_doctor_json_output(self):
        """Test that doctor --json returns valid JSON."""
        import json
        
        result = subprocess.run(
            ["python3", "-m", "lib.main", "doctor", "--json"],
            cwd=FRANKLIN_ROOT / "src",
            capture_output=True,
            text=True,
        )
        # Should be parseable as JSON
        try:
            data = json.loads(result.stdout)
            assert isinstance(data, dict)
        except json.JSONDecodeError:
            pytest.fail(f"doctor --json did not return valid JSON: {result.stdout}")

    def test_motd_command(self):
        """Test that motd command runs without crashing."""
        result = subprocess.run(
            ["python3", "-m", "lib.main", "motd"],
            cwd=FRANKLIN_ROOT / "src",
            capture_output=True,
            text=True,
        )
        # MOTD should always succeed
        assert result.returncode == 0

    def test_config_help(self):
        """Test that config --help shows options."""
        result = subprocess.run(
            ["python3", "-m", "lib.main", "config", "--help"],
            cwd=FRANKLIN_ROOT / "src",
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "--color" in result.stdout

    def test_update_dry_run(self):
        """Test that update --dry-run doesn't make changes."""
        result = subprocess.run(
            ["python3", "-m", "lib.main", "update", "--dry-run"],
            cwd=FRANKLIN_ROOT / "src",
            capture_output=True,
            text=True,
        )
        # Dry run should succeed or warn about not being in git repo
        assert result.returncode in (0, 1)
        assert "DRY RUN" in result.stderr or "not a git repository" in result.stderr.lower()

    def test_update_all_dry_run(self):
        """Test that update-all --dry-run doesn't make changes."""
        result = subprocess.run(
            ["python3", "-m", "lib.main", "update-all", "--dry-run"],
            cwd=FRANKLIN_ROOT / "src",
            capture_output=True,
            text=True,
        )
        # Should show dry run output
        assert "DRY RUN" in result.stderr or result.returncode in (0, 1)


class TestOSDetection:
    """Tests for OS family detection logic."""

    def test_detect_os_family_returns_valid_value(self):
        """Test that _detect_os_family returns a known value."""
        from lib.main import _detect_os_family
        
        result = _detect_os_family()
        assert result in ("macos", "debian", "fedora", "unknown")

    def test_detect_os_family_macos_on_darwin(self, monkeypatch):
        """Test macOS detection."""
        import platform
        monkeypatch.setattr(platform, "system", lambda: "Darwin")
        
        from lib.main import _detect_os_family
        assert _detect_os_family() == "macos"


class TestUIModule:
    """Tests for the UI module."""

    def test_campfire_ui_instantiates(self):
        """Test that CampfireUI can be instantiated."""
        from lib.ui import CampfireUI
        
        ui = CampfireUI(no_color=True)
        assert ui is not None
        assert ui.no_color is True

    def test_ui_set_color(self):
        """Test that set_color toggles color mode."""
        from lib.ui import CampfireUI
        
        ui = CampfireUI(no_color=True)
        assert ui.no_color is True
        
        ui.set_color(True)
        assert ui.no_color is False


class TestConstants:
    """Tests for constants module."""

    def test_campfire_colors_has_expected_colors(self):
        """Test that CAMPFIRE_COLORS contains expected entries."""
        from lib.constants import CAMPFIRE_COLORS, DEFAULT_CAMPFIRE_COLOR
        
        assert "Cello" in CAMPFIRE_COLORS
        assert "Terracotta" in CAMPFIRE_COLORS
        assert DEFAULT_CAMPFIRE_COLOR in CAMPFIRE_COLORS

    def test_campfire_colors_have_variants(self):
        """Test that each color has base/dark/light variants."""
        from lib.constants import CAMPFIRE_COLORS
        
        for name, colors in CAMPFIRE_COLORS.items():
            assert "base" in colors, f"{name} missing 'base'"
            assert "dark" in colors, f"{name} missing 'dark'"
            assert "light" in colors, f"{name} missing 'light'"

    def test_glyphs_are_defined(self):
        """Test that all glyphs are defined."""
        from lib.constants import (
            GLYPH_ACTION,
            GLYPH_BRANCH,
            GLYPH_SUCCESS,
            GLYPH_ERROR,
            GLYPH_WARNING,
        )
        
        assert GLYPH_ACTION
        assert GLYPH_BRANCH
        assert GLYPH_SUCCESS
        assert GLYPH_ERROR
        assert GLYPH_WARNING


class TestMOTD:
    """Tests for MOTD module."""

    def test_get_franklin_version(self):
        """Test that version is readable."""
        from lib.motd import get_franklin_version
        
        version = get_franklin_version()
        # Should be a version string like "2.0.0" or "unknown"
        assert version
        assert isinstance(version, str)

    def test_get_hostname(self):
        """Test that hostname is retrievable."""
        from lib.motd import get_hostname
        
        hostname = get_hostname()
        assert hostname
        assert isinstance(hostname, str)

    def test_get_disk_stats_returns_tuple(self):
        """Test that disk stats returns expected format."""
        from lib.motd import get_disk_stats
        
        bar, percent, used, total = get_disk_stats()
        assert isinstance(bar, str)
        assert isinstance(percent, (int, float))
        assert isinstance(used, str)
        assert isinstance(total, str)

    def test_create_progress_bar(self):
        """Test progress bar generation."""
        from lib.motd import create_progress_bar
        
        bar = create_progress_bar(50, width=10)
        assert "|" in bar
        assert "█" in bar or "░" in bar

    def test_load_motd_color_returns_defaults(self):
        """Test that load_motd_color returns valid defaults."""
        from lib.motd import load_motd_color
        from lib.constants import CAMPFIRE_COLORS
        
        name, colors = load_motd_color()
        assert name in CAMPFIRE_COLORS or name == "custom"
        assert "base" in colors
        assert "dark" in colors
        assert "light" in colors


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
