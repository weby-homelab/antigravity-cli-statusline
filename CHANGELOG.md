# Changelog

All notable changes to this project will be documented in this file.

## [0.1.7] - 2026-07-13
### Fixed
- **Symlink Preservation**: Modified installers and uninstallers (`install.sh`, `uninstall.sh`, and `uninstall.ps1`) to avoid breaking symlinks when updating `settings.json`. Instead of using `mv`/`Move-Item` which replaces whole files, the scripts now use redirection (`cat > file`) and copying (`Copy-Item` / `Remove-Item`) to perform disjoint-key updates directly on the target configurations. This prevents breaking user setups managed by dotfile managers (like chezmoi, stow, or custom symlinked setups).
