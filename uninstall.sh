#!/usr/bin/env bash
# uninstall.sh - Uninstaller for Linux & macOS

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}====================================================${RESET}"
echo -e "${YELLOW}  Uninstalling Antigravity CLI Statusline (Linux/Mac) ${RESET}"
echo -e "${BLUE}====================================================${RESET}"

INSTALL_DIR="$HOME/.antigravity"
SCRIPT_TARGET="${INSTALL_DIR}/statusline.sh"
UNINSTALL_TARGET="${INSTALL_DIR}/uninstall.sh"

if [ -f "$SCRIPT_TARGET" ]; then
  echo -e "Removing statusline script: ${SCRIPT_TARGET}..."
  rm -f "$SCRIPT_TARGET"
fi

SETTINGS_FILE="$HOME/.gemini/antigravity-cli/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
  echo -e "Disabling statusline in configuration..."
  # If a backup exists, restore it
  if [ -f "${SETTINGS_FILE}.bak" ]; then
    echo -e "Restoring backup settings from ${SETTINGS_FILE}.bak..."
    cat "${SETTINGS_FILE}.bak" > "$SETTINGS_FILE"
    rm -f "${SETTINGS_FILE}.bak"
  else
    if command -v jq &> /dev/null; then
      # Turn off statusLine configuration
      jq '.statusLine.enabled = false' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
      cat "${SETTINGS_FILE}.tmp" > "$SETTINGS_FILE"
      rm -f "${SETTINGS_FILE}.tmp"
      echo -e "Set statusLine.enabled to false."
    else
      echo -e "${YELLOW}Warning: 'jq' not found. Please manually set 'statusLine.enabled: false' in ${SETTINGS_FILE}${RESET}"
    fi
  fi
fi

# Finally, clean up itself and the directory if empty
if [ -f "$UNINSTALL_TARGET" ]; then
  echo -e "Removing uninstaller: ${UNINSTALL_TARGET}..."
  rm -f "$UNINSTALL_TARGET"
  rmdir "$INSTALL_DIR" 2>/dev/null || true
fi

echo -e "${BLUE}====================================================${RESET}"
echo -e "${GREEN}✓ Uninstallation completed successfully.${RESET}"
echo -e "${BLUE}====================================================${RESET}"
