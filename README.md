# Antigravity CLI Statusline

[![Latest release](https://img.shields.io/github/v/release/weby-homelab/antigravity-cli-statusline?display_name=tag&sort=semver)](https://github.com/weby-homelab/antigravity-cli-statusline/releases/latest)
[![Platforms](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-2563eb)](#supported-platforms)

Add an adaptive statusline to [Antigravity CLI](https://github.com/weby-homelab/antigravity-cli). The Bash renderer supports Linux and macOS; the PowerShell renderer supports Windows. Both read the CLI’s JSON payload from standard input and combine it with local Git and host data.

![Antigravity CLI Statusline in a medium terminal](screenshots/Antigravity-cli-statusline-MEDIUM-2.png)

> [!NOTE]
> The Weby Homelab community fork configures this statusline during installation. These installers target `~/.gemini/antigravity-cli/settings.json`. On Windows, they use `%USERPROFILE%\.gemini\antigravity-cli\settings.json`. If your CLI build reads settings elsewhere, add the `statusLine` block to its settings file manually. See the [official status line customization guide](https://antigravity.google/docs/cli/statusline/) for the payload schema.

## What the statusline shows

The renderers combine Antigravity CLI state with local Git and operating-system checks. Available fields include:

- **Agent and Vim state**: `idle`, `thinking`, `working`, and `tool_use` map to `READY`, `THINKING`, `WORKING`, and `TOOL`. Other agent states appear in uppercase. Vim mode appears when the payload contains `vim.mode`.
- **Model and session**: model ID or display name, CLI version, and the first eight characters of the conversation ID. The conversation ID appears at 80 columns or wider.
- **Account**: plan tier and account identifier from `plan_tier` and `email`. These appear at 130 columns or wider.
- **Workspace**: shortened working directory and Git branch. When Git is available, the renderer marks a dirty working tree, including untracked files. Without Git, it can still use VCS values from the CLI payload.
- **Context and tokens**: context usage bar, percentage, used-token count, and context limit when present. The renderer uses a positive `context_window.total_tokens` value; otherwise, it sums `total_input_tokens` and `total_output_tokens`. It can also show total input/output and current-turn token counts.
- **Quota**: model-aware selection between Gemini and third-party quota buckets, remaining-use bars, and reset countdowns when the payload includes them. The renderer uses available buckets as a fallback when the preferred bucket is missing.
- **Execution**: sandbox network state, artifact count for the conversation, subagent count, and running background-task count.
- **Host**: hostname, Tailscale IPv4 address when detectable, and power or battery state when the operating system exposes it. Linux also reports one-minute load average and RAM usage from `/proc`.

The renderers set a one-second deadline for reading standard input. Empty or stalled input falls back to an idle payload instead of waiting indefinitely. They do not upload the CLI JSON payload to a remote service.

## Choose a display mode

The default mode uses 256-color ANSI styling and [Nerd Fonts 3](https://www.nerdfonts.com/) glyphs. The renderer packs badges into box-drawn rows. Bar lengths and optional first-row fields change with the terminal width reported by Antigravity CLI.

| Terminal width | Context bar | Quota bar | Behavior |
| :--- | :---: | :---: | :--- |
| **235 columns or wider** | 20 segments | 15 segments | Widest labels and optional account, host, and token fields. |
| **180–234 columns** | 10 segments | 8 segments | More room for model, branch, account, and host fields. |
| **130–179 columns** | 10 segments | 8 segments | Account fields can appear when the payload includes them. |
| **100–129 columns** | 10 segments | 8 segments | Shorter first-row labels; host and version fields may fit. |
| **60–99 columns** | 10 segments | 8 segments | Shorter labels and more packed rows. |

Both implementations use the same bar-length thresholds and greedy badge-packing approach, but their fields and options differ. Row count depends on the payload. Packing counts characters after removing ANSI codes, so terminals can wrap wide glyphs differently.

<details open>
<summary><b>📸 Visual Screenshot Gallery Across All Terminal Widths</b></summary>
<br>

### 1. Ultra-wide example: single row at 235 columns or wider

*This example uses a 20-segment context bar and a 15-segment quota bar.*

![Ultra-Wide single-row statusline](screenshots/Antigravity-cli-statusline-ULTRA-2.png)

### 2. Ultra-wide example: multiple packed rows

*This example shows Linux host metrics, power state, subagent count, and token deltas.*

![Ultra-Wide multi-row statusline dashboard](screenshots/Antigravity-cli-statusline-ULTRA.png)

### 3. Wide example at 180–234 columns

*This example shows account details, a dirty Git branch, and session token totals.*

![Maximized wide terminal statusline](screenshots/Antigravity-cli-statusline-max.png)

### 4. Medium-wide example packed into two rows

*This screenshot shows one payload that fits in two boxed rows; other payloads can use more rows.*

![Medium-wide 2-row statusline layout](screenshots/Antigravity-cli-statusline-2-Rows.png)

### 5. Medium-width examples at 100–129 columns

*The screenshots show two badge groupings at medium widths.*

![Medium statusline layout standard](screenshots/Antigravity-cli-statusline-MEDIUM-2.png)

![Medium statusline layout alternative grouping](screenshots/Antigravity-cli-statusline-midle.png)

### 6. Narrow examples at 60–99 columns

*These examples use shortened labels and additional rows. Row count depends on the payload.*

![Compact statusline layout](screenshots/Antigravity-cli-statusline-SMALL-2.png)

![High-density minimal statusline layout](screenshots/Antigravity-cli-statusline-min.png)

</details>

Use Classic mode if your terminal lacks Nerd Font glyphs. It uses text labels, Unicode block characters, and 16-color ANSI output; it is not ASCII-only.

## Supported platforms

Install the implementation for your operating system:

| Platform | Renderer | Requirements | Optional integrations |
| --- | --- | --- | --- |
| Linux | `statusline.sh` | Bash and `jq` | Git; `/proc` load and memory data; `/sys/class/power_supply`; `ip` with `tailscale0` |
| macOS | `statusline.sh` | Bash and `jq` | Git; `pmset` power data |
| Windows | `statusline.ps1` | Windows PowerShell 5.1 or newer | Git; Tailscale CLI; Windows power status APIs |

GNU `timeout` is optional; the Bash renderer includes a bounded fallback. The Bash renderer checks Linux Tailscale addresses through `ip` and `tailscale0`; PowerShell runs `tailscale ip -4` when the CLI is available.

Git is optional. Without it, the renderer cannot query branch or working-tree state locally, but it can show VCS values from the Antigravity CLI payload.

## Install or upgrade

The installers copy the renderer and uninstaller to `~/.antigravity` or `%USERPROFILE%\.antigravity` by default, then configure `statusLine.type = "command"` in Antigravity CLI settings. They stage managed scripts through temporary files and save the original `statusLine` value in `statusline_installed_state.json` beside the settings file. Windows also stores a snapshot copy beside the installed scripts.

Set `AGY_STATUSLINE_INSTALL_DIR` to use another directory. The installers normalize and record that path so uninstallers can verify it. They refuse filesystem roots and Git working trees. They also refuse symlinked renderer or uninstaller files and existing targets not referenced by the active statusline setting.

> [!WARNING]
> Run the installer as your normal account. Do not use `sudo`: the installer writes to your home directory.

> [!TIP]
> Review [`install.sh`](install.sh) or [`install.ps1`](install.ps1) before executing a remote script.

### Linux and macOS

Install `jq`, then run the installer with either `curl` or `wget`.

To choose a custom install directory, set the environment variable before running either command. Relative paths are resolved from the current directory; `~` and `~/...` are expanded under your home directory.

```bash
export AGY_STATUSLINE_INSTALL_DIR="$HOME/.local/share/antigravity-statusline"
installer_url="https://raw.githubusercontent.com/"\
"weby-homelab/antigravity-cli-statusline/main/install.sh"
curl -fsSL "$installer_url" | bash
```

The equivalent `wget` command is:

```bash
installer_url="https://raw.githubusercontent.com/"\
"weby-homelab/antigravity-cli-statusline/main/install.sh"
wget -qO- "$installer_url" | bash
```

### Windows PowerShell

Run the installer from PowerShell:

```powershell
$env:AGY_STATUSLINE_INSTALL_DIR = Join-Path $HOME "Apps\Antigravity Statusline"
$base = "https://raw.githubusercontent.com/"
$installerPath = "weby-homelab/antigravity-cli-statusline/main/install.ps1"
Invoke-Expression (Invoke-RestMethod "$base$installerPath")
```

Restart Antigravity CLI after installation. Rerun the same installer to upgrade the statusline. Run the uninstaller from the selected install directory. It checks that its own location matches both the saved install path and the active `settings.json` command before removing files; if `AGY_STATUSLINE_INSTALL_DIR` is set, it must resolve to that same directory.

## Configure the statusline

The installers write the `statusLine` command to one of these files:

- **Linux and macOS**: `~/.gemini/antigravity-cli/settings.json`
- **Windows**: `%USERPROFILE%\.gemini\antigravity-cli\settings.json`

If your CLI build uses another settings path, add the same `statusLine` block to that file manually.

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

On macOS, replace `/home/your_username` with `/Users/your_username`. The Windows installer writes a command like `powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:/u/.antigravity/statusline.ps1`. Replace this example path with the installed script path. If you edit the setting manually, quote the `-File` path when it contains spaces and escape those quotes in JSON.

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

These width overrides are available in Bash only. The PowerShell renderer uses `terminal_width` from the Antigravity CLI payload.

| Bash flag | Effective width | Result |
| --- | ---: | --- |
| `--compact` | 89 columns | Compact output |
| `--medium` | 120 columns | Medium output |
| `--medium-wide` | 150 columns | Medium-wide output |

Append one Bash flag to the `command` value in `settings.json` to test a fixed width.

## Verify the installation

Check the installed version and print the icon legend. Replace the default path if you chose a custom install directory.

### Linux and macOS

```bash
~/.antigravity/statusline.sh --version
~/.antigravity/statusline.sh --legend
```

The short forms are `-v` and `-l`.

### Windows PowerShell

```powershell
$script = "$HOME\.antigravity\statusline.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File $script -Version
powershell -NoProfile -ExecutionPolicy Bypass -File $script -Legend
```

The Windows renderer also accepts `--version`, `-v`, `--legend`, and `-l`.

<details>
<summary>View the graphical telemetry legend</summary>

![Antigravity CLI Statusline telemetry legend](screenshots/Gemini_AGY-CLI-Statusline-LEGEND.png)

</details>

## Run automated tests

Run the master suite on Linux or macOS:

```bash
bash tests/run_all.sh
```

It runs renderer, stdin-timeout, subagent-state, installer, and Python compatibility checks. The Python checks run when Python 3 is available.

Run the PowerShell renderer and Python checks on Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tests\test_powershell_renderer.ps1
python tests\test_windows.py
```

CI runs the Bash suites on Ubuntu and macOS, and the PowerShell suite on Windows PowerShell 5.1 and PowerShell Core.

## Understand installed files

The installers keep renderer scripts separate from Antigravity CLI settings. The default files are:

```text
~/.antigravity/
├── statusline.sh
└── uninstall.sh

~/.gemini/antigravity-cli/
├── settings.json
├── statusline_installed_state.json  # Original value and install path
└── settings.json.bak                # Created if needed
```

On Windows, the renderer and uninstaller are under `%USERPROFILE%\.antigravity`. The state snapshot also has a copy beside those scripts. Settings and the primary snapshot are under `%USERPROFILE%\.gemini\antigravity-cli`.

The PowerShell renderer starts with a UTF-8 byte-order mark (BOM). Keep it if you edit the file; Windows PowerShell 5.1 uses it to read the non-ASCII source correctly.

## Uninstall

The uninstaller checks its location against the recorded install path and active settings command before removing scripts. It restores the original `statusLine` value or removes that key if none existed before installation. Other settings remain in place.

> [!WARNING]
> The current uninstaller removes `settings.json.bak` during cleanup. If that file existed before installation, save a copy elsewhere before uninstalling.

Run the Linux or macOS uninstaller:

```bash
~/.antigravity/uninstall.sh
```

Run the Windows uninstaller:

```powershell
$uninstaller = "$HOME\.antigravity\uninstall.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $uninstaller
```

## Troubleshoot common problems

Use these checks when the statusline does not render as expected:

- **Icons appear as boxes**: select a Nerd Font, or add `--classic` to the Bash command or `-Classic` to the PowerShell command.
- **No statusline appears**: confirm that `statusLine.enabled` is `true`, check the command path, and restart Antigravity CLI.
- **The Bash renderer exits**: run `jq --version`; Bash requires `jq`.
- **Live Git data is missing**: install Git and run Antigravity CLI inside a Git working tree. The renderer can still use VCS values from the payload.
- **Windows reports an illegal path**: when editing `settings.json` manually, quote the `-File` path only when it contains spaces. The installer adds these quotes when needed.
- **PowerShell 5.1 shows garbled characters**: preserve the UTF-8 BOM at the start of `statusline.ps1`. Use Classic mode if your terminal font lacks Nerd Font glyphs.
- **Context or quota percentages are wrong in Windows PowerShell 5.1**: a comma-decimal locale issue is tracked in [issue #75](https://github.com/weby-homelab/antigravity-cli-statusline/issues/75).
- **A narrow terminal adds rows**: this is expected when the available badges do not fit. Bash width overrides are documented above; PowerShell uses the width from the CLI payload.
- **Host fields are missing**: the renderer omits diagnostics that the operating system or local tools do not expose.

## Release history

See [CHANGELOG.md](CHANGELOG.md) for versioned changes and [GitHub Releases](https://github.com/weby-homelab/antigravity-cli-statusline/releases) for downloadable release records.

<p align="center">
  Built in Ukraine under air raid sirens and blackouts ⚡<br>
  &copy; 2026 Weby Homelab
</p>
