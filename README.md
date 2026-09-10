# Antigravity CLI Statusline

[![Latest release](https://img.shields.io/github/v/release/weby-homelab/antigravity-cli-statusline?display_name=tag&sort=semver)](https://github.com/weby-homelab/antigravity-cli-statusline/releases/latest)
[![Platforms](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-2563eb)](#supported-platforms)

Add an adaptive telemetry statusline to [Antigravity CLI](https://github.com/weby-homelab/antigravity-cli). It shows session, model, Git, context, quota, sandbox, task, host, and power data, then packs available fields across rows as terminal width changes.

![Antigravity CLI Statusline in a wide terminal](screenshots/Antigravity-cli-statusline-ULTRA-2.png)

> [!NOTE]
> The Weby Homelab community fork of Antigravity CLI installs this statusline by default. Follow this README to install it with another Antigravity CLI build, reinstall it, or change its display mode.

## What the statusline shows

The renderer combines data from the Antigravity CLI statusline payload with local Git and host diagnostics:

- **Session**: agent state, active model, CLI version, account tier, email, conversation ID, and Vim editor mode (`NORMAL`, `INSERT`, `VISUAL`, `VISUAL LINE`)
- **Workspace**: shortened working directory, Git branch, and dirty state
- **Usage**: context consumption, session and current-turn tokens, active model quota, and reset countdowns
- **Execution**: sandbox network mode, artifacts, subagents, and background tasks
- **Host**: hostname, Tailscale IPv4 address when available, power source, and battery charge
- **Linux diagnostics**: memory use and one-minute load average when `/proc` exposes them

The statusline reads Antigravity CLI data from standard input. The renderer itself does not send session data over the network.

## Choose a display mode

The default preset uses 256-color ANSI styling and [Nerd Fonts 3](https://www.nerdfonts.com/) glyphs. Its line-packing engine measures each telemetry badge and adds rows when the current terminal width cannot contain the next badge.

| Terminal width | Representative output | Context and quota bars |
| --- | --- | --- |
| 235 columns or wider | Wide layout | 20 and 15 segments |
| Below 235 columns | Packed multiline layout | 10 and 8 segments |

Both the Bash and PowerShell renderers share adaptive bar sizing and line packing. The final row count dynamically depends on the telemetry available in the current session. These screenshots show common Bash results at four widths.

<details>
<summary>View responsive layout examples</summary>

### Wide terminal

![Wide statusline layout](screenshots/Antigravity-cli-statusline-ULTRA-2.png)

### Medium-wide terminal

![Medium-wide statusline layout](screenshots/Antigravity-cli-statusline-2-Rows.png)

### Medium terminal

![Medium statusline layout](screenshots/Antigravity-cli-statusline-MEDIUM-2.png)

### Compact terminal

![Compact statusline layout](screenshots/Antigravity-cli-statusline-SMALL-2.png)

</details>

Use classic mode when your terminal does not have a Nerd Font. It replaces private-use glyphs and 256-color capsules with Unicode labels and 16-color ANSI output.

## Supported platforms

Install the implementation for your operating system:

| Platform | Renderer | Requirements | Optional integrations |
| --- | --- | --- | --- |
| Linux | `statusline.sh` | Bash and `jq` | Git, GNU `timeout`, Tailscale, `/proc`, `/sys/class/power_supply` |
| macOS | `statusline.sh` | Bash and `jq` | Git, Tailscale, `pmset` |
| Windows | `statusline.ps1` | Windows PowerShell 5.1 or newer | Git, Tailscale, Common Information Model (CIM) battery data |

Git is optional. Without it, the statusline omits live branch and dirty-state data.

## Install or upgrade

The installers copy the renderer and uninstaller to `~/.antigravity`, update the `statusLine` object in Antigravity CLI settings, and preserve existing settings in `settings.json.bak`.

> [!WARNING]
> Run the installer as your normal account. Do not use `sudo`: the installer writes to your home directory.

> [!TIP]
> Review [`install.sh`](install.sh) or [`install.ps1`](install.ps1) before executing a remote script.

### Linux and macOS

Install `jq`, then run the installer with either `curl` or `wget`.

```bash
curl -fsSL https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main/install.sh | bash
```

The equivalent `wget` command is:

```bash
wget -qO- https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main/install.sh | bash
```

### Windows PowerShell

Run the installer from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main/install.ps1)"
```

Restart Antigravity CLI after installation. Rerun the same installer to upgrade the statusline.

## Configure the statusline

The installer updates one of these files:

- **Linux and macOS**: `~/.gemini/antigravity-cli/settings.json`
- **Windows**: `%USERPROFILE%\.gemini\antigravity-cli\settings.json`

A Linux configuration has this shape:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/home/your_username/.antigravity/statusline.sh",
    "enabled": true
  }
}
```

On macOS, replace `/home/your_username` with `/Users/your_username`. On Windows, use this command value (quoting the path only if it contains spaces):

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/Users/your_username/.antigravity/statusline.ps1",
    "enabled": true
  }
}
```

### Use classic mode

Append `--classic` (or `-Classic` on Windows) to the configured command:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/home/your_username/.antigravity/statusline.sh --classic",
    "enabled": true
  }
}
```

The Bash and PowerShell renderers also accept `--no-nerdfont` and `--compatibility`.

### Override the layout width

The Bash and PowerShell renderers accept flags that override the width reported by Antigravity CLI:

| Flag | Effective width | Intended result |
| --- | ---: | --- |
| `--compact` / `-Compact` | 89 columns | Compact packed output |
| `--medium` / `-Medium` | 120 columns | Medium packed output |
| `--medium-wide` / `-MediumWide` | 150 columns | Medium-wide packed output |

Append one flag to the `command` value in `settings.json`.

## Verify the installation

Check the installed version and print the live icon legend after installation.

### Linux and macOS

```bash
~/.antigravity/statusline.sh --version
~/.antigravity/statusline.sh --legend
```

The short forms are `-v` and `-l`.

### Windows PowerShell

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.antigravity\statusline.ps1" -Version
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.antigravity\statusline.ps1" -Legend
```

The Windows renderer also accepts `--version`, `-v`, `--legend`, and `-l`.

<details>
<summary>View the graphical telemetry legend</summary>

![Antigravity CLI Statusline telemetry legend](screenshots/Gemini_AGY-CLI-Statusline-LEGEND.png)

</details>

## Understand installed files

The installation keeps its executable files separate from Antigravity CLI settings:

```text
~/.antigravity/
├── statusline.sh
└── uninstall.sh

~/.gemini/antigravity-cli/
├── settings.json
├── statusline_installed_state.json  # State snapshot for safe rollback across upgrades
└── settings.json.bak                # Legacy backup file if present
```

Windows uses the same directory names under `%USERPROFILE%` and installs `statusline.ps1` plus `uninstall.ps1`. The committed production `statusline.ps1` includes a UTF-8 BOM (`\xef\xbb\xbf`) ensuring compatibility with Windows PowerShell 5.1 across all system locales.

## Uninstall

The uninstaller uses the dedicated state snapshot (`statusline_installed_state.json`) to perform a clean, non-destructive rollback:

- If `statusLine` did not exist before installation, the uninstaller removes only the `statusLine` key.
- If `statusLine` existed before installation, the uninstaller restores only its original pre-installation value.
- Any unrelated settings added before or after installation (such as theme or keybindings) remain completely intact.
- Symlinks to dotfiles repositories are preserved without breaking link targets.

Run the Linux or macOS uninstaller:

```bash
~/.antigravity/uninstall.sh
```

Run the Windows uninstaller:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$HOME\.antigravity\uninstall.ps1"
```

## Troubleshoot common problems

Use these checks when the statusline does not render as expected:

- **Icons appear as boxes**: install and select a Nerd Font 3 font, or add `--classic` to the configured command
- **No statusline appears**: confirm that `statusLine.enabled` is `true`, check the command path, and restart Antigravity CLI
- **Linux or macOS renderer exits**: run `jq --version`; the Bash implementation requires `jq`
- **Git data is missing**: install Git and confirm the current working directory belongs to a Git repository
- **Windows Illegal characters in path**: verify your command in `settings.json` does not contain literal escaped quotes around `-File`. The v0.2.4 installer handles spaces automatically using standard path syntax
- **Windows PowerShell 5.1 font or encoding errors**: `statusline.ps1` includes a UTF-8 BOM to prevent mojibake on non-UTF-8 Windows locales. Ensure the BOM is preserved
- **A narrow terminal adds more rows**: increase the terminal width or use a layout override (`--compact`, `--medium`) to test a fixed width
- **Host fields are missing**: the renderer omits diagnostics that the operating system or local tools do not expose

If the issue persists, open a [GitHub issue](https://github.com/weby-homelab/antigravity-cli-statusline/issues) with your operating system, terminal, Antigravity CLI version, statusline version, and a screenshot. Remove account email, hostnames, IP addresses, conversation IDs, and repository details before posting.

## Release history

See [CHANGELOG.md](CHANGELOG.md) for versioned changes and [GitHub Releases](https://github.com/weby-homelab/antigravity-cli-statusline/releases) for downloadable release records.

<p align="center">
  Built in Ukraine under air raid sirens and blackouts ⚡<br>
  &copy; 2026 Weby Homelab
</p>
