# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.4] - 2026-09-11
### Added & Improved
- **Vim Editor Mode Indicator (Issue #62)**: Added dynamic Vim mode badge (`NORMAL`, `INSERT`, `VISUAL`, `VISUAL LINE`, fallback) into LINE1 across styled and classic layouts in `statusline.sh` and `statusline.ps1`. Documented in CLI `--legend` and `-Legend`. Participates in responsive width checks to prevent line wrapping.
- **Model-Aware Quota Parity**: Synchronized quota selection logic in `statusline.ps1` with Bash: third-party models (Claude, GPT, OpenAI) prioritize 3P quotas, while Gemini models prioritize Gemini quotas. Disappears cleanly when no quota is present.
- **Cross-Platform Test Suite & CI**: Added maintainable automated test suite (`tests/`) with 16 public JSON fixtures and GitHub Actions CI workflow matrix for Ubuntu, macOS, and Windows (Windows PowerShell 5.1 and PowerShell 7+).

### Fixed & Hardened
- **Windows Installation & Runtime Hardening (Issue #63)**:
  - Fixed command generation in `install.ps1` to prevent literal quotation marks in `-File` causing `Illegal characters in path` error. Supports paths with and without spaces. Deliberately uses `powershell.exe`.
  - Fixed `PSCustomObject` property addition in Windows PowerShell 5.1 using `Add-Member` to prevent `SetValueInvocationException`.
  - Ensured `statusline.ps1` includes UTF-8 BOM (`\xef\xbb\xbf`) for correct Nerd Font and Unicode rendering under legacy Windows non-UTF8 system locales.
  - Ensured `install.ps1` writes `settings.json` without UTF-8 BOM adhering to RFC 8259.
- **Context Token Accounting Fix (Section 5)**: Corrected context window used-token calculation: uses explicit `.context_window.total_tokens` when valid, or falls back to summing `total_input_tokens + total_output_tokens` (e.g., 88,244 + 61,074 = 149,318 tokens, 14.24%). Synchronized across Bash and PowerShell with consistent rounding (`149.3K`, `1.0M`).
- **Subagent Stale Zero Truth Cache Fix (Section 6)**: Eliminated the stale-zero suppression bug in `/tmp/agy_subagent_truth`. Incoming Antigravity payload is canonical technical truth; newly spawned subagents appear immediately (0 -> 1, 0 -> 3).
- **Portable Git Timeout Resilience (Section 7)**: Removed duplicate `run_with_timeout` definition in `statusline.sh`. Unified into a single robust helper using GNU `timeout` if available, bounded subshell fallback if absent (macOS friendly), and child process reaping without leaving zombies. Fixed asynchronous stream deadlock in PowerShell `Run-WithTimeout`.
- **Non-Destructive Installer & State Snapshot (Section 9)**:
  - Updated `statusLine.type` to official schema `"command"` (was `""`).
  - Implemented dedicated state snapshot (`statusline_installed_state.json`) preserving pre-installation statusLine state across repeated upgrades.
  - Uninstallation cleanly restores original `statusLine` or removes only `statusLine` without rolling back unrelated settings added before or after installation. Preserves unknown `statusLine` keys. Preserves symlinks on Linux, macOS, and Windows.
- **Input Hardening & Version Cleanup (Sections 13, 14)**: Added dynamic string sanitization (stripping newlines, CR, ANSI escapes, control chars). Unified version parsing to `0.2.4`, eliminating stale `v0.2.2`.
- **Responsive Layout Hardening (Issue #59 / Section 12)**: Hardened LINE1 width gating and truncation across both renderers to guarantee zero uncontrolled line wrapping across terminal widths 60 to 255.
- **Power & AC Supply Detection Fix (Issue #70)**: Fixed bug where power indicator remained stuck on `🔋 BAT` even when connected to AC power or running on desktop workstations. Excluded peripheral devices (`scope: Device`, `hidpp_*`, mice/keyboards) from overriding host AC status; inspected `type: Mains` and incoming USB chargers; evaluated battery charging status (`Charging`, `Full`, `Not charging` vs `Discharging`); recognized desktop hosts without batteries as AC mains; integrated multi-tier power detection in PowerShell (.NET `PowerStatus` -> `root/wmi:BatteryStatus` -> `Win32_Battery`); normalized classic mode rendering to prevent duplicate `AC AC`.

## [0.2.3] - 2026-09-03
### Added & Improved
- **Context Window & Token Usage Display**: Added token usage and context window limit metrics `(${CTX_USED_FMT}/${CTX_LIMIT_FMT})` directly into the `ctx` badge across both classic ANSI and 256-color pill layouts in `statusline.sh` and `statusline.ps1`.
- **Accurate Context Metric Extraction**: Fixed context usage calculation to accurately track active context window tokens (`total_input_tokens`) and added fallback calculation for context window size when missing.
- **Enhanced Human Format Rounding**: Improved `human_format` rounding for `K` and `M` token metrics.

### Fixed & Hardened
- **Prevent Premature Line Splitting (Issue #59)**: Corrected line-packing boundary check in classic mode to use full terminal width (`max_vis = COLS - 1`) without box-drawing border padding. Optimized wide-bar threshold to 235 columns, eliminating unnecessary line splits and empty row wrapping on wide displays (e.g., 237 columns).
- **PowerShell Parity & Fixes (PR #58)**: Ported `make_badge` and ANSI color mapper to `statusline.ps1`, restored `$LINE1` concatenation, corrected sandbox reference, and fixed quota bar colors.
- **Blocked Stdin Timeout Protection**: Added `run_with_timeout 0.25 cat` stdin timeout guard and immediate `exec 0</dev/null` in `statusline.sh` (and asynchronous `Task` timeout in `statusline.ps1`). Prevents the statusline script from hanging indefinitely during OAuth refresh, authentication, or conversation warm-up when `antigravity-cli` holds stdin open without sending data, avoiding hard SIGKILL shutdowns and plugin auto-disablement.

## [0.2.2] - 2026-07-22
### Fixed & Hardened
- **Atomic File Replacement**: Updated `install.sh` to copy files to temporary `.tmp` targets before executing an atomic `mv -f` replacement, preventing race-condition syntax errors when background statusline runners poll during installation.
- **Cross-Platform Battery Scanner**: Integrated native macOS `pmset` power/battery scanner fallback alongside Linux `/sys/class/power_supply` and Windows WMI/CIM.

## [0.2.1] - 2026-07-22
### Fixed & Hardened
- **Smart Dynamic Line-Packing Engine**: Replaced rigid fixed-line layouts with an adaptive, greedy line-packing engine. Telemetry badges dynamically flow into cleanly framed boxed rows (`╭─`, `├─`, `╰─`) according to exact visible character lengths, eliminating line wrapping across ALL terminal widths (from 60 to 250+ cols).
- **100% Telemetry Visibility**: Ensured zero fields are hidden or clipped regardless of terminal width while maintaining strict box border alignment.
- **Platform Parity**: Synchronized dynamic line-packing engine across Linux/macOS (`statusline.sh`) and Windows PowerShell (`statusline.ps1`).

## [0.2.0] - 2026-07-22
### Added
- **Maximized Telemetry Dashboard**: Restored and expanded full telemetry fields across all layouts, including User Plan Tier (`PLAN_TIER`), Account Email (`USER_EMAIL`), and turn-by-turn token delta counters (`turn: +IN/OUT`).
- **User Account Segment**: Added dynamic `👤 Plan (Email)` segment to LINE1 Powerline status bar for terminal widths >= 130 chars.
- **Detailed Token Metrics**: Enabled full session token breakdown (`(total: IN/OUT | turn: +IN/OUT)`) across Medium, Medium-Wide, and Wide layouts.
- **Full Platform Parity**: Synchronized all maximized telemetry fields across Linux/macOS (`statusline.sh`) and Windows PowerShell (`statusline.ps1`).

## [0.1.9] - 2026-07-22
### Fixed
- **Global Scope Syntax Error**: Fixed `local: can only be used in a function` crash on battery-powered laptops by removing invalid `local` keyword from global scope in battery scanner block.
- **Defensive Payload Sanitization**: Added regex-based numeric variable validation for all JSON telemetry fields in Bash (`statusline.sh`), ensuring safe execution under `set -e` even with malformed or invalid string inputs.
- **PowerShell Null-Safety**: Implemented defensive null navigation checks in `statusline.ps1` for missing `quota` and `context_window` JSON structures.
- **Symlink Preservation**: Updated `uninstall.ps1` to use `Get-Content | Out-File` pipeline when restoring `settings.json.bak`, preventing symlinks from being replaced by regular file copies on Windows.

## [0.1.8] - 2026-07-22
### Added
- **Layout Size Options**: Added `--compact`, `--medium`, and `--medium-wide` CLI override flags to force specific statusline widths.
- **Subagent Real-Time Caching**: Integrated `/tmp/agy_subagent_truth` caching to immediately drop the UI counter to 0 upon subagent process completion.
- **Real-Time Quota Countdown**: Implemented `_tick_countdown` in-memory helper to dynamically decrement reset timers on every prompt refresh.
- **3P Model Quota Resolver**: Added native Bash `case` pattern matcher to dynamically select Third-Party (Claude/GPT/OpenAI) or Gemini quotas.
### Fixed
- **macOS & Linux Power Supply Detection**: Replaced fragile `ls` subshell calls under `set -o pipefail` with direct glob expansion loops for `/sys/class/power_supply/*/online` and `/capacity`.
- **Locale Decimal Crash**: Added `export LC_NUMERIC=C` to prevent `printf` float syntax crashes in non-English locales.
- **Installer Safety**: Updated `install.sh` to use `jq --arg` for safe JSON escaping and added root/user home mismatch checks.

## [0.1.7] - 2026-07-13
### Fixed
- **Symlink Preservation**: Modified installers and uninstallers (`install.sh`, `uninstall.sh`, and `uninstall.ps1`) to avoid breaking symlinks when updating `settings.json`. Instead of using `mv`/`Move-Item` which replaces whole files, the scripts now use redirection (`cat > file`) and copying (`Copy-Item` / `Remove-Item`) to perform disjoint-key updates directly on the target configurations. This prevents breaking user setups managed by dotfile managers (like chezmoi, stow, or custom symlinked setups).

## [0.1.6] - 2026-07-09
### Added
- **PowerShell Git Timeout**: Added git command timeout wrapper in PowerShell (`statusline.ps1`) to prevent statusline hanging on slow or unresponsive git mounts.
### Changed
- **Load Average Optimization**: Optimized the `loadaverage` calculation routine in Linux/macOS to reduce background system invocation overhead.

## [0.1.5] - 2026-07-07
### Added
- **Responsive 2-Line Layout**: Implemented a dynamic 2-line layout that automatically triggers on smaller or scaled terminal windows to prevent clipping and text wrapping.
- **Documentation**: Added 2-Rows layout screenshots to the README layout showcase.

## [0.1.4] - 2026-07-06
### Added
- **Universal Power & Telemetry**: Added universal power scanning (battery status, power source detection) and Git timeout resilience.
- **Stacked Telemetry Info**: Enhanced all layouts to display stacked telemetry information (CLI version, user plan, host details, turn tokens, and battery status).
- **Legibility Improvements**: Resolved classic terminal color variables for better readability in high-contrast/classic layouts.
- **Statusline CLI Features**: Added statusline commands and options to print legend mapping in the console.
- **SEO & Discoverability**: Added JSON-LD metadata structure, `robots.txt`, and `sitemap.xml` for crawler indexing.

## [0.1.3] - 2026-07-04
### Added
- **One-Command Installation**: Integrated quick one-line installation support using `curl` and `wget` fetchers.
### Security
- **Sudo Prevention**: Modified the installers to refuse execution under `sudo` or as root, avoiding permission errors in user directories.
- **Executable Permissions**: Automated execution permission bits configuration (`chmod +x`) during bootstrapping.

## [0.1.2] - 2026-07-03
### Added
- **Classic Compatibility Mode**: Added support for standard and legacy terminals without Nerd Fonts or complex styling.
- **Quota simulator**: Enhanced simulator to support Gemini 5H/7D model quota rendering.
- **Branding**: Added Ukrainian language support references and homelab footer.

## [0.1.1] - 2026-07-02
### Added
- **Initial Release**: Initial commit of the `antigravity-cli-statusline` status bar extension.
- **Self-Clean Uninstaller**: Set up installer script to automatically copy the uninstaller to the target install directory and clean up intermediate setup caches.
