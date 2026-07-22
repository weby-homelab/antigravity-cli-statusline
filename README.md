# 🚀 Antigravity CLI Statusline (Max Edition)

An advanced, responsive, and high-information statusline plugin for the **[Antigravity CLI (Community Fork)](https://github.com/weby-homelab/antigravity-cli)** (`agy`). It features multi-layout adapting to your terminal width, real-time Git status tracking, token counting, active model quotas, and sandbox badges.

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

## 📖 Telemetry Legend

You can inspect the legend of all components and icons directly from your terminal by running:
* **Linux/macOS:** `~/.antigravity/statusline.sh --legend` (or `-l` / `legend`)
* **Windows (PowerShell):** `powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\.antigravity\statusline.ps1 -Legend` (or `--legend`)

![Telemetry Legend Showcase](screenshots/Gemini_AGY-CLI-Statusline-LEGEND.png)

> [!IMPORTANT]
> **Nerd Font Glyphs Rendering:** The icons in the "Nerd Font Icon" column utilize characters from Nerd Fonts (V3+). If they appear as boxes, squares, or question marks in your web browser or on GitHub, this is expected since web browsers do not load Nerd Fonts by default. In your terminal, they will render correctly if you have a Nerd Font installed and active. The Unicode codepoints (e.g. `U+F192`) are provided for reference.

| Component | Nerd Font Icon (Codepoint) | Classic Icon | Description |
| :--- | :---: | :---: | :--- |
| **State: READY** | ` (U+F192)` READY | `●` READY | Agent is idle, waiting for commands. |
| **State: THINKING** | `󰟷 (U+F07F7)` THINKING | `◆` THINKING | Agent is currently thinking/processing request. |
| **State: WORKING** | ` (U+F423)` WORKING | `⚙` WORKING | Agent is performing background tasks. |
| **State: TOOL** | ` (U+F425)` TOOL | `🔧` TOOL | Agent is currently executing a tool. |
| **State: UNKNOWN** | ` (U+F252)` STATE | `⏳` STATE | Agent state is unknown or initializing. |
| **VCS Branch** | ` (U+F418)` branch | `╱` branch | Active Git branch (renders Red + `*` if dirty). |
| **Active Model** | ` (U+F400)` model | `model` | Active LLM model name or ID. |
| **Sandbox (Network)** | `󰒙 (U+F0499)` ON (net) | `ON (net)` | Execution sandbox active with full network access. |
| **Sandbox (Restricted)** | `󰴴 (U+F0D34)` ON (no-net) | `ON (no-net)` | Execution sandbox active with disabled network. |
| **Sandbox (Off)** | `󰦜 (U+F099C)` OFF | `sandbox off` | Sandbox is disabled, commands run on host. |
| **Context Window Bar** | `󱍏 (U+F134F)` █░░... | `ctx` █··... | 20-segment visual representation of context usage. |
| **Artifacts Counter** | ` (U+F0F6)` count | `artifacts` count | Number of currently active workspace artifacts. |
| **Subagents Counter** | `󱙺 (U+F167A)` count | `subagents` count | Number of spawned active subagent processes. |
| **Background Tasks** | ` (U+F0AE)` count | `tasks` count | Number of running background asynchronous tasks. |
| **System Diagnostics** | ` (U+F04BC)` RAM/ld | `sys` RAM/ld | Real-time host CPU 1-min load average and RAM utilization. |
| **Current Directory** | ` (U+EA83)` path | `╱` path | Shortened current working directory path. |
| **Conversation ID** | `󰍪 (U+F036A)` id | `╱` id | 8-character prefix of the current session ID. |
| **Host Info** | `󰒋 (U+F048B)` Host (IP) | `Host (IP)` | Hostname and active Tailscale connection IP. |
| **Token Sum** | ` (U+E26B)` tokens | `tokens` | Total input + output tokens processed in session. |
| **Quota Reset** | `⌛️ (U+231B)` time | `⌛` time | Remaining time until model API quota limits reset. |
| **Power (Mains/AC)** | `󰚥 (U+F06A5)` AC | `AC` | Connected to AC power. |
| **Power (Battery)** | `🔋 (U+1F50B)` charge% | `BAT:`charge% | Running on battery or UPS (shows charge percentage). |
| **Segment Divider** | ` (U+E0B0)` | ` ` | Powerline transition symbol for active segments. |
| **Pill Capsule Caps** | ` (U+E0B6)` / ` (U+E0B4)` | ` ` | Left and right caps enclosing telemetry badges. |

---

## 💎 Telemetry & Icon Styling

The statusline features a modern, high-density telemetry layout built with two key design elements:

1. **Powerline Segments (LINE1):** Left-aligned metadata components (e.g. State, Git Branch, Active Model, Current Directory, Conversation ID, Host Info, Version) are styled as connected blocks using classic `` (U+E0B0) powerline dividers. Each segment features premium 256-color palette styling mapped specifically to its contents.
2. **Rounded Pill Badges (LINE2/3/4):** Right-aligned/stacked telemetry items (e.g. Host CPU/RAM diagnostics, Artifacts, Subagents, Background Tasks, Sandbox networking, Context Usage bar, Quota metrics, Power state) are rendered as isolated capsules enclosed in rounded caps `` (U+E0B6) and `` (U+E0B4) with a clean, dark-gray background (`#303030`).
3. **Dynamic Warnings:** Icons inside badges dynamically change colors to signal bottleneck conditions (e.g. CPU/RAM load, critical quota limits, battery power under blackouts).


### 📐 Layout Size Options

You can force a specific layout width regardless of your terminal size by passing one of the following flags:
* `--compact` (or `< 100` width): Force 4-line stacked compact layout.
* `--medium` (100–139 width): Force 3-line medium layout.
* `--medium-wide` (140–179 width): Force 2-line boxed layout.

### 🛠️ Configuration and Font Setup

To configure the statusline icons correctly and prevent rendering issues (e.g., icons showing up as boxes or question marks):

* **Install a Nerd Font (V3.0+):** The statusline relies on Nerd Font glyphs. Make sure you install and configure a compatible font (such as *Inter*, *Hack Nerd Font*, *JetBrainsMono Nerd Font*, or *FiraCode Nerd Font*) in your terminal's settings.
* **Integrate with `settings.json`:** The statusline command is declared inside the `settings.json` configuration file of the Antigravity CLI, located in `~/.gemini/antigravity-cli/settings.json` (macOS/Linux) or `%USERPROFILE%\.gemini\antigravity-cli\settings.json` (Windows).
* **Enable Classic Fallback:** If you're running in a terminal environment that lacks Nerd Font support (e.g. legacy TTY, ChromeOS Terminal, Emacs), append `--classic` to the statusline command inside your `settings.json`. This tells the script to use standard Unicode fallback characters and prevents raw 256-color ANSI escapes from leaking into the output.

---

## 🎨 Compatibility Mode (Classic Icons)

If your terminal does not support Nerd Fonts (e.g., ChromeOS Terminal, Emacs, or standard TTYs), you can run the statusline in **Classic Icon Mode**. This mode replaces advanced glyphs with standard Unicode symbols (`●`, `◆`, `⚙`, `🔧`, etc.) and plain text labels to ensure clean rendering.

To enable it, simply append `--classic` (or `--no-nerdfont` / `--compatibility`) to the command parameter in your `settings.json`:

### 🐧 macOS / Linux (`~/.gemini/antigravity-cli/settings.json`)
```json
{
  "statusLine": {
    "type": "",
    "command": "/home/user/.antigravity/statusline.sh --classic",
    "enabled": true
  }
}
```

### 🪟 Windows (`%USERPROFILE%\.gemini\antigravity-cli\settings.json`)
```json
{
  "statusLine": {
    "type": "",
    "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:/Users/user/.antigravity/statusline.ps1\" --classic",
    "enabled": true
  }
}
```

---

## ✨ Features

- **Responsive Design:** Automatically switches layouts (Wide, Medium, Small) depending on terminal width (`terminal_width`) to avoid messy line wrapping.
- **Smart Git Tracking:** Queries the Git binary (`git -C`) directly with a 1-second timeout safeguard to get real-time branch status and dirty states, bypassing cached session details and preventing hangs on slow/unreachable network mounts.
- **Dynamic Quota Swapping:** Automatically detects the current LLM model (Gemini vs. 3rd-party models) and switches to display the correct active quotas (`gemini-5h` & `gemini-weekly` or `3p-5h` & `3p-weekly`) along with countdowns to quota reset.
- **Context & Token Metres:** Displays a visual 20-segment context window bar with percentage, and displays total input/output tokens in a human-readable (`K`, `M`) format.
- **Current Turn Token Usage:** Tracks the input/output tokens processed during the last turn (e.g. `turn: +40.5K/318`).
- **Sandbox Network Badges:** Displays whether the execution sandbox is `ON (net)`, `ON (no-net)`, or `OFF`.
- **Background Actions Tracker:** Live metrics showing active subagents count (`󱙺`) and running background tasks (``).
- **CLI & Session Metadata:** Displays the current `agy` CLI version, subscription tier (e.g. `Google AI Pro`), and logged-in account email.
- **Resilient Power & Host Tracking:** Live display of the host machine's name, Tailscale connection IP, and mains/battery status via dynamic hardware supply scanning (supporting any AC/BAT device combination) to track blackout states.

---

## 📥 Installation

> [!NOTE]
> This statusline is already configured and enabled by default when you install the community-hardened **[Antigravity CLI](https://github.com/weby-homelab/antigravity-cli)**. Use this manual installation only if you are using the upstream CLI version or want to reinstall it separately.

> [!WARNING]
> Do **NOT** run the installation commands with `sudo`. The statusline installs locally in your home directory (`~/.antigravity` and `~/.gemini/`). Running with `sudo` will cause file permission issues for your user account.

Choose the installation command for your operating system:

### 🐧 macOS / Linux

**One-liner (curl):**
```bash
curl -fsSL https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main/install.sh | bash
```

**One-liner (wget):**
```bash
wget -qO- https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main/install.sh | bash
```

**Manual Installation:**
1. Clone this repository:
   ```bash
   git clone https://github.com/weby-homelab/antigravity-cli-statusline.git
   ```
2. Navigate to the directory, make the installer executable, and run it:
   ```bash
   cd antigravity-cli-statusline
   chmod +x install.sh
   ./install.sh
   ```

---

### 🪟 Windows (PowerShell)

**One-liner (PowerShell WebRequest):**
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main/install.ps1)"
```

**One-liner (curl on Windows):**
If you have curl.exe installed on Windows, you can download and run the installer in one line:
```powershell
curl -fsSL https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main/install.ps1 | powershell -NoProfile -ExecutionPolicy Bypass -Command -
```

**Manual Installation:**
1. Clone this repository:
   ```powershell
   git clone https://github.com/weby-homelab/antigravity-cli-statusline.git
   ```
2. Navigate to the directory and execute:
   ```powershell
   cd antigravity-cli-statusline
   Powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
   ```

---

## 🗑️ Uninstallation

The installation script places a dedicated uninstaller script in your permanent `~/.antigravity` folder. You can run it directly from anywhere without needing the original git clone directory.

### 🐧 macOS / Linux
```bash
~/.antigravity/uninstall.sh
```

### 🪟 Windows (PowerShell)
```powershell
Powershell -NoProfile -ExecutionPolicy Bypass -File $HOME\.antigravity\uninstall.ps1
```

---

## ⚙️ Configuration & File Structure

Here is the file structure installed by the automated setup scripts on each platform, along with their related configuration paths.

### 🐧 macOS / Linux File Structure
```text
~ (User Home)
├── .antigravity/                   # Installation folder
│   ├── statusline.sh               # Statusline logic script
│   └── uninstall.sh                # Uninstallation helper script
└── .gemini/
    └── antigravity-cli/
        └── settings.json           # Antigravity CLI configuration
```

Your `~/.gemini/antigravity-cli/settings.json` will be configured as follows:
```json
{
  "statusLine": {
    "type": "",
    "command": "/home/user/.antigravity/statusline.sh",
    "enabled": true
  }
}
```

### 🪟 Windows File Structure
```text
C:\Users\<username> (User Profile)
├── .antigravity\                   # Installation folder
│   ├── statusline.ps1              # Statusline PowerShell script
│   └── uninstall.ps1               # Uninstallation helper script
└── .gemini\
    └── antigravity-cli\
        └── settings.json           # Antigravity CLI configuration
```

Your `%USERPROFILE%\.gemini\antigravity-cli\settings.json` will be configured as follows:
```json
{
  "statusLine": {
    "type": "",
    "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:/Users/user/.antigravity/statusline.ps1\"",
    "enabled": true
  }
}
```

---

## 📝 Important Notes & Release History

### 🚀 Release v0.1.6 (July 9, 2026)
- **Subprocess-Free Load Average**: Replaced `bc` shell calls in `statusline.sh` with pure Bash decimal stripping to improve rendering performance and remove external package dependency.
- **Windows Git Timeout Resilience**: Ported the Git timeout safeguard to `statusline.ps1` using a .NET-native Process wrapper with a 1-sec limit to prevent PowerShell hangs on slow remote filesystems.

### 🚀 Release v0.1.5 (July 9, 2026)
- **Responsive 2-Line Layout**: Configured a space-efficient 2-line layout when the terminal window is scaled between 140 and 179 characters wide.
- **Optimized Tokens Display**: Split token usage formatting into wide and medium versions to prevent terminal output wrapping on compact displays.

### 🚀 Release v0.1.4 (July 8, 2026)
- **Git Timeout Resilience**: Added a 1-second timeout wrapper around all Git calls to prevent terminal statusline hangs on slow, unreachable network mounts (NFS, Samba) or extremely large repositories.
- **Universal Power Supply Scanning**: Replaced hardcoded battery/AC adapter paths with dynamic wildcard scanning to correctly identify any battery (`BAT0`, `BAT1`, `BATT`) and AC adapter (`AC`, `ACAD`, `ADP1`) combination on laptops and UPS systems.

### 🚀 Release v0.1.3 (June 16, 2026)
- **One-liner Web Installation**: Added full support for direct internet-based installation using `curl` or `wget` (without cloning the repository locally) for Linux, macOS, and Windows.
- **Sudo Safety Check**: Added an active check to block execution when run with `sudo` or as `root` via `sudo` on Linux/macOS to protect local user home directory permissions.

### 🚀 Release v0.1.2 (June 15, 2026)
- **Classic Compatibility Mode**: Added support for terminals without Nerd Fonts (e.g. ChromeOS Terminal, Emacs, legacy TTYs). You can activate it by adding `--classic`, `--no-nerdfont`, or `--compatibility` arguments to the `command` field in your `settings.json`.
- **Robust Quota Detection & Auto-Hide**: Fixed issues where model quotas failed to show or displayed empty progress bars when using custom/third-party model names. The script now dynamically selects the first active quota and hides the quota block completely if no quota limits are available (`-1` or null).
- **PowerShell Compatibility**: Ported all classic-mode and quota detection enhancements to Windows (`statusline.ps1`).

---

<p align="center">
  Built in Ukraine under air raid sirens &amp; blackouts ⚡<br>
  &copy; 2026 Weby Homelab
</p>


---

<!--
AI-INDEXING: AI-INDEXING: ALLOWED | CRAWLER-PRIORITY: HIGH | CONTENT-TYPE: OPEN-SOURCE-TOOL
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "antigravity-cli-statusline",
  "description": "Advanced responsive statusline plugin for the Antigravity CLI (agy). Features multi-layout, real-time Git status, token counting, active model quotas, and sandbox badges.",
  "url": "https://github.com/weby-homelab/antigravity-cli-statusline",
  "applicationCategory": "DeveloperApplication",
  "operatingSystem": "Linux, macOS",
  "keywords": ["statusline", "Antigravity", "CLI", "plugin", "terminal", "AI", "git-status", "token-counter"],
  "author": {"@type": "Organization", "name": "Weby Homelab", "url": "https://github.com/weby-homelab"},
  "codeRepository": "https://github.com/weby-homelab/antigravity-cli-statusline",
  "isAccessibleForFree": true
}
-->

<!--
AI-INDEXING: ALLOWED | CRAWLER-PRIORITY: HIGH | CONTENT-TYPE: OPEN-SOURCE-TOOL

@context: https://schema.org
@type: SoftwareApplication
name: Antigravity CLI Statusline
alternateName: antigravity-cli-statusline
description: An advanced, responsive, and high-information statusline plugin for Antigravity CLI
applicationCategory: DeveloperApplication
applicationSubCategory: CLI
operatingSystem: Linux
softwareVersion: 1.0.0
keywords: cli, terminal, tui, statusline, homelab, devtools, antigravity, ai-agents
author: Weby Homelab (https://github.com/weby-homelab)
codeRepository: https://github.com/weby-homelab/antigravity-cli-statusline
downloadUrl: https://github.com/weby-homelab/antigravity-cli-statusline/releases
license: GPL-3.0
isAccessibleForFree: true
-->
