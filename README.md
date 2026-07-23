# 🚀 Antigravity CLI Statusline (v0.2.2)

[![Release](https://img.shields.io/badge/release-v0.2.2-brightgreen.svg)](https://github.com/weby-homelab/antigravity-cli-statusline/releases/tag/v0.2.2)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-blue.svg)](#-platform--cross-platform-compatibility)
[![License](https://img.shields.io/badge/license-GPL--3.0-orange.svg)](LICENSE)

An advanced, responsive, zero-line-wrapping statusline extension for the **[Antigravity CLI (Community Fork)](https://github.com/weby-homelab/antigravity-cli)** (`agy`). It features a high-density telemetry dashboard, real-time Git status, turn-by-turn token tracking, model quota reset countdowns, sandbox networking badges, user subscription tier indicators, and cross-platform hardware diagnostics.

---

## 🎨 Layout Showcase

### 👑 Ultra / Wide Layout (Terminal width $\ge$ 180 chars)
The ultimate high-information layout displaying all telemetry fields: system metrics, Git status, active subagents, background tasks, model quotas, and power/battery state in a single aligned row.
![Ultra Layout](screenshots/Antigravity-cli-statusline-ULTRA-2.png)

### ⚡ Medium-Wide / Two-Line Layout (Terminal width 140 to 179 chars)
Encloses the statusline powerline segments and all telemetry badges into a space-efficient, beautifully boxed 2-line layout.
![Medium-Wide Layout](screenshots/Antigravity-cli-statusline-2-Rows.png)

### 📱 Medium Layout (Terminal width 100 to 139 chars)
Stacks status segments and telemetry badges into a clean 3-line layout to prevent command output wrapping on standard terminals.
![Medium Layout](screenshots/Antigravity-cli-statusline-MEDIUM-2.png)

### 📟 Small / Compact Layout (Terminal width < 100 chars)
Ensures all metrics (READY, model, CWD, tokens, resources, and power) fit perfectly in a stacked 4-line layout on narrower terminals.
![Compact Layout](screenshots/Antigravity-cli-statusline-SMALL-2.png)

---

## 🔍 How to Check Installed Version & Preset

Users can inspect their installed version and current telemetry mapping directly from the terminal at any time:

### 1. Check Installed Version
* **Linux / macOS:**
  ```bash
  ~/.antigravity/statusline.sh --version   # (or -v)
  # Output: Antigravity CLI Statusline v0.2.2
  ```
* **Windows (PowerShell):**
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\.antigravity\statusline.ps1 -Version
  ```

### 2. View Telemetry Legend & Active Graphic Preset
* **Linux / macOS:**
  ```bash
  ~/.antigravity/statusline.sh --legend   # (or -l / legend)
  ```
* **Windows (PowerShell):**
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\.antigravity\statusline.ps1 -Legend
  ```

---

## 🎨 Graphic Presets & Options

The statusline supports two main graphical presets to suit any terminal environment:

### 1. Modern Powerline & Pill Preset (Default)
Requires a [Nerd Font (V3.0+)](https://www.nerdfonts.com/) active in your terminal emulator (e.g. *JetBrainsMono*, *Hack*, *FiraCode*, *Inter*).
* **Header (LINE1):** Left-aligned metadata components rendered as connected Powerline blocks using classic `` (U+E0B0) dividers and custom 256-color palettes.
* **Telemetry Badges (LINE2+):** Telemetry items styled as rounded capsules enclosed in `` (U+E0B6) and `` (U+E0B4) dark-gray pills (`#303030`).

### 2. Classic Compatibility Preset (`--classic`)
Replaces Nerd Font glyphs with standard Unicode symbols (`●`, `◆`, `⚙`, `🔧`, `ctx`, `sys`) and 16-color ANSI output. Recommended for legacy TTYs, ChromeOS Terminal, Emacs, or SSH sessions without Nerd Fonts.
* **Enable in `settings.json`:** Append `--classic` (or `--no-nerdfont` / `--compatibility`) to the statusline command.

### 📐 Manual Layout Override Flags
Override automatic terminal width detection by passing one of the following CLI flags in `settings.json`:
* `--compact`: Force compact stacked layout (< 100 cols).
* `--medium`: Force medium 3-line layout (100–139 cols).
* `--medium-wide`: Force 2-line boxed layout (140–179 cols).

---

## 🧠 Smart Dynamic Line-Packing Engine (v0.2.2)

Unlike legacy statuslines that hardcode static rows and cause ugly text wrapping on small screens, **v0.2.2** introduces a greedy, adaptive **Line-Packing Engine**:
1. Calculates exact printed Unicode character lengths for every active badge (stripping ANSI color sequences).
2. Dynamically packs badges into cleanly framed boxed rows (`╭─`, `├─`, `╰─`) within `terminal_width - 4`.
3. **Guarantees ZERO line wrapping and 100% telemetry visibility** on any terminal width from 60 to 250+ columns.

---

## 📖 Complete Telemetry Legend (14 Components)

![Telemetry Legend Showcase](screenshots/Gemini_AGY-CLI-Statusline-LEGEND.png)

| Component | Nerd Font Icon | Classic Icon | Description |
| :--- | :---: | :---: | :--- |
| **State: READY** | `` READY | `●` READY | Agent is idle, waiting for commands. |
| **State: THINKING** | `󰟷` THINKING | `◆` THINKING | Agent is currently thinking/processing request. |
| **State: WORKING** | `` WORKING | `⚙` WORKING | Agent is performing background operations. |
| **State: TOOL** | `` TOOL | `🔧` TOOL | Agent is executing a tool call. |
| **VCS Branch** | `` branch | `╱` branch | Active Git branch name (Red + `*` if dirty). |
| **Active Model** | `` model | `model` | Active LLM model name or ID (e.g. Gemini 3.6 Flash). |
| **User Account & Tier** | `👤` Plan (email) | `Plan (email)` | User subscription tier (e.g. Pro) and account email. |
| **Sandbox (Network)** | `󰒙` ON (net) | `ON (net)` | Sandbox enabled with full network access. |
| **Sandbox (Restricted)** | `󰴴` ON (no-net) | `ON (no-net)` | Sandbox enabled with disabled network. |
| **Sandbox (Off)** | `󰦜` OFF | `sandbox off` | Sandbox disabled (commands execute on host). |
| **Context Window Bar** | `󱍏` █░░... | `ctx` █··... | Visual context usage bar (10 or 20 segments) + %. |
| **Token Metrics** | `` total / turn | `total / turn` | Session total input/output tokens + turn delta (`+IN/OUT`). |
| **System Diagnostics** | `` RAM/ld | `sys` RAM/ld | Real-time host CPU 1-min load average & RAM utilization. |
| **Artifacts Counter** | `` count | `artifacts` count | Active workspace output artifacts. |
| **Subagents Counter** | `󱙺` count | `subagents` count | Spawned active subagent processes. |
| **Background Tasks** | `` count | `tasks` count | Running background asynchronous tasks. |
| **Current Directory** | `` path | `╱` path | Shortened current working directory path. |
| **Conversation ID** | `󰍪` id | `╱` id | 8-character prefix of current session ID. |
| **Host & Tailscale IP** | `󰒋` Host (IP) | `Host (IP)` | Hostname and active Tailscale connection IP address. |
| **Quota Reset** | `⌛️` time | `⌛` time | Remaining time until model API quota limits reset. |
| **Power (Mains/AC)** | `󰚥` AC | `AC` | Connected to external AC power. |
| **Power (Battery)** | `🔋` charge% | `BAT:`charge% | Running on battery/UPS (shows charge percentage). |

---

## 📥 Installation & Upgrade

> [!WARNING]
> Do **NOT** run installation commands with `sudo`. The statusline installs locally in your home directory (`~/.antigravity` and `~/.gemini/`).

### 🐧 macOS / Linux
**One-command install / upgrade (curl):**
```bash
curl -fsSL https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main/install.sh | bash
```

**One-command install / upgrade (wget):**
```bash
wget -qO- https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main/install.sh | bash
```

---

### 🪟 Windows (PowerShell)
**One-command install / upgrade (PowerShell WebRequest):**
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main/install.ps1)"
```

---

## ⚙️ Configuration (`settings.json`)

The statusline is registered in `~/.gemini/antigravity-cli/settings.json` (macOS/Linux) or `%USERPROFILE%\.gemini\antigravity-cli\settings.json` (Windows):

### 🐧 macOS / Linux Configuration
```json
{
  "statusLine": {
    "type": "",
    "command": "/home/user/.antigravity/statusline.sh",
    "enabled": true
  }
}
```

### Enabling Classic Mode in `settings.json`:
```json
{
  "statusLine": {
    "type": "",
    "command": "/home/user/.antigravity/statusline.sh --classic",
    "enabled": true
  }
}
```

---

## 🗑️ Uninstallation

To remove the statusline and restore backup configuration:
* **Linux / macOS:** `~/.antigravity/uninstall.sh`
* **Windows (PowerShell):** `powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\.antigravity\uninstall.ps1`

---

## 📝 Changelog

For a detailed list of changes, fixes, and release history, please see the **[CHANGELOG.md](CHANGELOG.md)**.

---

<p align="center">
  Built in Ukraine under air raid sirens &amp; blackouts ⚡<br>
  &copy; 2026 Weby Homelab
</p>
