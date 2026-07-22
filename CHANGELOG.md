# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
