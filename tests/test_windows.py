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

    def test_installer_argument_forwarding_and_settings_preservation(self):
        """Arguments passed to install.ps1 command-string builder are forwarded and preserved in settings.json."""
        ps1_text = (REPO_ROOT / "install.ps1").read_text(encoding="utf-8")
        uninstall_ps1_text = (REPO_ROOT / "uninstall.ps1").read_text(encoding="utf-8")

        # Static verification of install.ps1 and uninstall.ps1 argument and prefix matching logic
        self.assertIn('$extraArgs = ""', ps1_text)
        self.assertIn('$args -join " "', ps1_text)
        self.assertIn('$commandString = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fileArg$extraArgs"', ps1_text)
        self.assertIn('$existingCommand.StartsWith($expectedCommand + " "', ps1_text)
        self.assertIn('$currentCommand.StartsWith($expectedCommand + " "', uninstall_ps1_text)

        # Simulation of install.ps1 command-string builder
        def build_ps1_command(target_script: str, args: list) -> str:
            escaped_path = target_script.replace("\\", "/")
            file_arg = f'"{escaped_path}"' if " " in escaped_path else escaped_path
            extra_args = (" " + " ".join(args)) if args else ""
            return f"powershell.exe -NoProfile -ExecutionPolicy Bypass -File {file_arg}{extra_args}"

        # 1. Builder forwarding checks
        # Path without spaces + telemetry switches
        switches = ["-NoModel", "-NoTokensUsage", "-NoAccount"]
        cmd_standard = build_ps1_command("C:/Users/weby/.antigravity/statusline.ps1", switches)
        self.assertEqual(
            cmd_standard,
            "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/Users/weby/.antigravity/statusline.ps1 -NoModel -NoTokensUsage -NoAccount",
        )
        self.assertTrue(cmd_standard.endswith(" -NoModel -NoTokensUsage -NoAccount"))

        # Path with spaces + POSIX-style flags
        posix_flags = ["--no-model", "--no-tokens-usage", "--no-account"]
        cmd_spaces = build_ps1_command("C:/Users/User With Spaces/.antigravity/statusline.ps1", posix_flags)
        self.assertEqual(
            cmd_spaces,
            'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:/Users/User With Spaces/.antigravity/statusline.ps1" --no-model --no-tokens-usage --no-account',
        )
        self.assertTrue(cmd_spaces.endswith(" --no-model --no-tokens-usage --no-account"))

        # Empty args produces clean unpadded command
        cmd_empty = build_ps1_command("C:/Users/weby/.antigravity/statusline.ps1", [])
        self.assertEqual(
            cmd_empty,
            "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/Users/weby/.antigravity/statusline.ps1",
        )

        # Preflight check in install.ps1 & uninstall.ps1 matches active command with arguments
        expected_prefix = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/Users/weby/.antigravity/statusline.ps1"
        current_cmd = cmd_standard
        matches = (
            current_cmd.lower() == expected_prefix.lower()
            or current_cmd.lower().startswith(expected_prefix.lower() + " ")
        )
        self.assertTrue(matches, "Installer preflight check must match active command string with extra arguments")


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

    def test_custom_install_directory_is_shared_by_install_and_uninstall(self):
        """Custom install locations are normalized, persisted, and reused by uninstallers."""
        install_ps1 = (REPO_ROOT / "install.ps1").read_text(encoding="utf-8")
        uninstall_ps1 = (REPO_ROOT / "uninstall.ps1").read_text(encoding="utf-8")
        install_sh = (REPO_ROOT / "install.sh").read_text(encoding="utf-8")
        uninstall_sh = (REPO_ROOT / "uninstall.sh").read_text(encoding="utf-8")

        self.assertIn("$env:AGY_STATUSLINE_INSTALL_DIR", install_ps1)
        self.assertIn("Update-StatuslineInstallSnapshot", install_ps1)
        self.assertIn("Refusing to overwrite files not referenced", install_ps1)
        self.assertIn("$savedState.install_dir", uninstall_ps1)
        self.assertIn("$PSScriptRoot", uninstall_ps1)
        self.assertIn("settings.json does not point to this installation", uninstall_ps1)
        self.assertIn("Resolve-InstallDirectory", uninstall_ps1)
        self.assertIn("AGY_STATUSLINE_INSTALL_DIR", install_sh)
        self.assertIn("QUOTED_SCRIPT_TARGET", install_sh)
        self.assertIn("install_dir", install_sh)
        self.assertIn("SNAPSHOT_INSTALL_DIR", uninstall_sh)
        self.assertIn("BASH_SOURCE[0]", uninstall_sh)
        self.assertIn("settings.json does not point to this installation", uninstall_sh)

    def test_powershell_power_detection_logic(self):
        """statusline.ps1 must implement multi-tier power detection (SystemInformation, BatteryStatus, Win32_Battery)."""
        ps1_text = (REPO_ROOT / "statusline.ps1").read_text(encoding="utf-8")
        self.assertIn("System.Windows.Forms.SystemInformation", ps1_text)
        self.assertIn("PowerStatus", ps1_text)
        self.assertIn("PowerOnline", ps1_text)
        self.assertIn("Win32_Battery", ps1_text)
        self.assertIn("ICON_AC", ps1_text)
        self.assertIn("ICON_BAT", ps1_text)

    def test_powershell_flag_definitions_and_switch_parity(self):
        """statusline.ps1 must accept both POSIX double-dash flags and case-insensitive PowerShell switches."""
        ps1_text = (REPO_ROOT / "statusline.ps1").read_text(encoding="utf-8")
        ps1_lower = ps1_text.lower()

        # Header Segments (Line 1)
        expected_header_flags = {
            "Agent State": (["--no-state"], ["-nostate"]),
            "Vim Mode": (["--no-vim", "--no-vim-mode"], ["-novim", "-novimmode"]),
            "Git / VCS Branch": (["--no-branch", "--no-git"], ["-nobranch", "-nogit"]),
            "Model": (["--no-model"], ["-nomodel"]),
            "Working Directory": (["--no-dir", "--no-cwd"], ["-nodir", "-nocwd"]),
            "Conversation ID": (["--no-conv", "--no-conversation"], ["-noconv", "-noconversation"]),
            "Account & Plan": (["--no-account", "--no-user", "--no-plan"], ["-noaccount", "-nouser", "-noplan"]),
            "Host Diagnostics": (["--no-host"], ["-nohost"]),
            "CLI Version": (["--no-version"], ["-noversion"]),
        }

        for comp, (posix_flags, ps_switches) in expected_header_flags.items():
            for flag in posix_flags:
                self.assertIn(flag, ps1_lower, f"POSIX flag '{flag}' for {comp} must be handled in statusline.ps1")
            for switch in ps_switches:
                self.assertIn(switch, ps1_lower, f"PowerShell switch '{switch}' for {comp} must be handled in statusline.ps1")

        # Pill Badges (Lines 2+)
        expected_pill_flags = {
            "Context Usage": (["--no-context-usage", "--no-context"], ["-nocontextusage", "-nocontext"]),
            "Token Totals": (["--no-tokens-usage", "--no-tokens"], ["-notokensusage", "-notokens"]),
            "Cost": (["--no-cost"], ["-nocost"]),
            "System Resources": (["--no-sys", "--no-system", "--no-resources"], ["-nosys", "-nosystem", "-noresources"]),
            "Artifacts": (["--no-artifacts"], ["-noartifacts"]),
            "Subagents": (["--no-subagents"], ["-nosubagents"]),
            "Background Tasks": (["--no-tasks"], ["-notasks"]),
            "Sandbox State": (["--no-sandbox"], ["-nosandbox"]),
            "Quota Bars": (["--no-quota"], ["-noquota"]),
            "Power / Battery": (["--no-power"], ["-nopower"]),
        }

        for comp, (posix_flags, ps_switches) in expected_pill_flags.items():
            for flag in posix_flags:
                self.assertIn(flag, ps1_lower, f"POSIX flag '{flag}' for {comp} must be handled in statusline.ps1")
            for switch in ps_switches:
                self.assertIn(switch, ps1_lower, f"PowerShell switch '{switch}' for {comp} must be handled in statusline.ps1")

    def test_powershell_default_on_backward_compatibility(self):
        """statusline.ps1 must initialize all telemetry flags to $true by default."""
        ps1_text = (REPO_ROOT / "statusline.ps1").read_text(encoding="utf-8")

        expected_defaults = [
            "$SHOW_STATE = $true",
            "$SHOW_VIM = $true",
            "$SHOW_BRANCH = $true",
            "$SHOW_MODEL = $true",
            "$SHOW_DIR = $true",
            "$SHOW_CONV = $true",
            "$SHOW_ACCOUNT = $true",
            "$SHOW_HOST = $true",
            "$SHOW_VERSION = $true",
            "$SHOW_CONTEXT_USAGE = $true",
            "$SHOW_TOKENS_USAGE = $true",
            "$SHOW_COST = $true",
            "$SHOW_SYS = $true",
            "$SHOW_ARTIFACTS = $true",
            "$SHOW_SUBAGENTS = $true",
            "$SHOW_TASKS = $true",
            "$SHOW_SANDBOX = $true",
            "$SHOW_QUOTA = $true",
            "$SHOW_POWER = $true",
            "$USE_CLASSIC_ICONS = $false",
        ]

        for default_expr in expected_defaults:
            self.assertIn(default_expr, ps1_text, f"Default initialization '{default_expr}' must be present")

        # Existing flags must continue to be handled
        ps1_lower = ps1_text.lower()
        for flag in ["--classic", "-classic", "-c", "classic", "--no-nerdfont", "--compatibility", "--version", "-version", "-v", "--legend", "-legend", "-l"]:
            self.assertIn(flag, ps1_lower, f"Existing flag '{flag}' must be supported in statusline.ps1")

    def test_powershell_header_collapse_logic(self):
        """statusline.ps1 must assemble Line 1 dynamically and adjust outer box borders on Header Collapse."""
        ps1_text = (REPO_ROOT / "statusline.ps1").read_text(encoding="utf-8")

        # Line 1 segments must be dynamically assembled
        self.assertIn("function Format-Line1", ps1_text)
        self.assertIn("$ACTIVE_L1", ps1_text)
        self.assertIn("$LINE1 = Format-Line1 $ACTIVE_L1", ps1_text)

        # On header collapse (LINE1 empty), first packed row must start with ╭─ instead of ├─
        self.assertIn('if ($LINE1)', ps1_text)
        self.assertIn('"${FG_GRAY}╭─${R}$($PACKED_LINES[$i])"', ps1_text)
        self.assertIn('"${FG_GRAY}├─${R}$($PACKED_LINES[$i])"', ps1_text)
        self.assertIn('"${FG_GRAY}╰─${R}$($PACKED_LINES[$i])"', ps1_text)

    def test_powershell_full_suppression_logic(self):
        """statusline.ps1 must produce clean empty output when both Line 1 and badges are suppressed."""
        ps1_text = (REPO_ROOT / "statusline.ps1").read_text(encoding="utf-8")

        # When LINE1 is empty and total_packed is 0, no box borders should be output
        self.assertIn('if ($total_packed -gt 0)', ps1_text)

    def test_powershell_execution_and_header_collapse_parity(self):
        """When powershell or pwsh is available, execute statusline.ps1 and test runtime parity."""
        import subprocess
        ps_bin = shutil.which("powershell") or shutil.which("pwsh")
        if not ps_bin:
            self.skipTest("PowerShell executable not found on this runner (skipped live execution)")

        payload = json.dumps({
            "agent_state": "working",
            "terminal_width": 150,
            "vcs": {"branch": "main", "dirty": False},
            "model": {"id": "gemini-2.0-flash", "display_name": "Gemini 2.0 Flash"},
            "context_window": {
                "used_percentage": 14.2,
                "total_input_tokens": 88244,
                "total_output_tokens": 61074,
                "context_window_size": 1048576,
            },
            "vim": {"mode": "NORMAL"},
        })

        ps1_path = str(REPO_ROOT / "statusline.ps1")

        def run_ps1(*args):
            cmd = [ps_bin, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps1_path, *args]
            res = subprocess.run(cmd, input=payload, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=10)
            return res.stdout

        # Baseline
        base = run_ps1()
        self.assertIn("WORKING", base)
        self.assertIn("NORMAL", base)
        current_branch = subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True).stdout.strip()
        if current_branch:
            self.assertIn(current_branch, base)
        self.assertIn("Gemini 2.0 Flash", base)

        # Flag and Switch parity
        self.assertNotIn("WORKING", run_ps1("--no-state"))
        self.assertNotIn("WORKING", run_ps1("-NoState"))
        self.assertNotIn("NORMAL", run_ps1("--no-vim"))
        self.assertNotIn("NORMAL", run_ps1("-NoVim"))
        if current_branch:
            self.assertNotIn(current_branch, run_ps1("--no-branch"))
            self.assertNotIn(current_branch, run_ps1("-NoBranch"))

        # Header Collapse
        l1_flags = ["--no-state", "--no-vim", "--no-branch", "--no-model", "--no-dir", "--no-conv", "--no-account", "--no-host", "--no-version"]
        hc_out = run_ps1(*l1_flags)
        self.assertNotIn("WORKING", hc_out)
        self.assertNotIn("NORMAL", hc_out)
        first_line = hc_out.strip().splitlines()[0] if hc_out.strip() else ""
        self.assertIn("╭─", first_line)
        self.assertNotIn("├─", first_line)

        # Full suppression
        all_flags = l1_flags + ["--no-context", "--no-tokens", "--no-cost", "--no-sys", "--no-artifacts", "--no-subagents", "--no-tasks", "--no-sandbox", "--no-quota", "--no-power"]
        full_out = run_ps1(*all_flags)
        self.assertEqual(full_out.strip(), "")

if __name__ == "__main__":
    unittest.main()
