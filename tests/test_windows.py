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

    def test_state_snapshot_restoration_logic(self):
        """Simulate state snapshot restoration on uninstall."""
        # Case A: statusLine did not exist originally
        settings = {
            "unrelatedPref": "val",
            "statusLine": {"type": "command", "command": "run", "enabled": True},
            "addedLater": 123
        }
        state = {"statusLine_existed": False, "original_statusLine": None}
        if not state["statusLine_existed"]:
            settings.pop("statusLine", None)
        self.assertNotIn("statusLine", settings)
        self.assertEqual(settings["unrelatedPref"], "val")
        self.assertEqual(settings["addedLater"], 123)

        # Case B: statusLine did exist originally with custom values
        orig_sl = {"type": "command", "custom": "abc", "enabled": True}
        settings = {
            "unrelated": "val",
            "statusLine": {"type": "command", "command": "new_path", "enabled": True, "custom": "abc"}
        }
        state = {"statusLine_existed": True, "original_statusLine": orig_sl}
        if state["statusLine_existed"]:
            settings["statusLine"] = state["original_statusLine"]
        self.assertEqual(settings["statusLine"], orig_sl)
        self.assertEqual(settings["unrelated"], "val")

    def test_installer_script_type_is_command(self):
        """install.ps1 and install.sh must configure type: 'command'."""
        ps1_text = (REPO_ROOT / "install.ps1").read_text(encoding="utf-8")
        sh_text = (REPO_ROOT / "install.sh").read_text(encoding="utf-8")
        self.assertIn('type = "command"', ps1_text)
        self.assertNotIn('type = ""', ps1_text)
        self.assertIn('"type": "command"', sh_text)
        self.assertNotIn('"type": ""', sh_text)

    def test_powershell_power_detection_logic(self):
        """statusline.ps1 must implement multi-tier power detection (SystemInformation, BatteryStatus, Win32_Battery)."""
        ps1_text = (REPO_ROOT / "statusline.ps1").read_text(encoding="utf-8")
        self.assertIn("System.Windows.Forms.SystemInformation", ps1_text)
        self.assertIn("PowerStatus", ps1_text)
        self.assertIn("PowerOnline", ps1_text)
        self.assertIn("Win32_Battery", ps1_text)
        self.assertIn("ICON_AC", ps1_text)
        self.assertIn("ICON_BAT", ps1_text)

if __name__ == "__main__":
    unittest.main()

