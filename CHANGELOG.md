# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
