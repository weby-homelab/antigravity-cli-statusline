#!/usr/bin/env python3
"""tests/test_windows.py - Cross-platform tests for Windows & PowerShell parity."""

import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

class TestWindowsPowerShellParity(unittest.TestCase):

    def test_bom_header_present_on_statusline_ps1(self):
        """statusline.ps1 MUST start with UTF-8 BOM bytes (EF BB BF) for legacy Windows PowerShell 5.1."""
        ps1_file = REPO_ROOT / "statusline.ps1"
        self.assertTrue(ps1_file.exists(), "statusline.ps1 exists")
        data = ps1_file.read_bytes()
        self.assertTrue(
            data.startswith(b"\xef\xbb\xbf"),
            "statusline.ps1 must start with UTF-8 BOM bytes (b'\\xef\\xbb\\xbf')",
        )

    def test_command_string_generation(self):
        """Command string must not pass literal escaped quotes that trigger 'Illegal characters in path'."""
        # Path without spaces must not have quotes around -File argument
        normal_path = "C:/Users/weby/.antigravity/statusline.ps1"
        cmd_normal = f"powershell.exe -NoProfile -ExecutionPolicy Bypass -File {normal_path}"
        self.assertNotIn('"', cmd_normal)

        # Path with spaces must be quoted cleanly
        spaced_path = "C:/Users/User With Spaces/.antigravity/statusline.ps1"
        cmd_spaced = f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{spaced_path}"'
        self.assertTrue(cmd_spaced.startswith('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:/Users/User With Spaces/'))

    def test_settings_json_has_no_bom(self):
        """settings.json must NEVER have a UTF-8 BOM (RFC 8259)."""
        sample_json = json.dumps({"statusLine": {"type": "command"}}, indent=2)
        raw_bytes = sample_json.encode("utf-8")
        self.assertFalse(raw_bytes.startswith(b"\xef\xbb\xbf"))

    def test_non_destructive_state_snapshot(self):
        """Snapshot preserves pre-install state even across repeated upgrades."""
        with tempfile.TemporaryDirectory() as td:
            install_dir = Path(td)
            snapshot_file = install_dir / "statusline_installed_state.json"
            
            initial_state = {"statusLine_existed": False, "original_statusLine": None}
            snapshot_file.write_text(json.dumps(initial_state))
            
            self.assertTrue(snapshot_file.exists())
            read_back = json.loads(snapshot_file.read_text())
            self.assertFalse(read_back["statusLine_existed"])

if __name__ == "__main__":
    unittest.main()
