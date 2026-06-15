#!/usr/bin/env bash
# install.sh - Installer for Linux & macOS

set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0;5m' # No Color
NC_BOLD='\033[1m'
RESET='\033[0m'

echo -e "${BLUE}====================================================${RESET}"
echo -e "${GREEN}  Installing Antigravity CLI Statusline (Linux/Mac) ${RESET}"
echo -e "${BLUE}====================================================${RESET}"

# 1. Dependency checks
echo -e "Checking dependencies..."
if ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: 'jq' is not installed. Please install it first (e.g. 'apt install jq' or 'brew install jq').${RESET}"
  exit 1
fi
if ! command -v git &> /dev/null; then
  echo -e "${YELLOW}Warning: 'git' is not installed. Git branch info will not be available.${RESET}"
fi
echo -e "${GREEN}✓ Dependencies checked.${RESET}"

# 2. Setup directory
INSTALL_DIR="$HOME/.antigravity"
echo -e "Creating directory ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"

# 3. Copy files
SCRIPT_SOURCE="$(dirname "$0")/statusline.sh"
SCRIPT_TARGET="${INSTALL_DIR}/statusline.sh"

if [ ! -f "$SCRIPT_SOURCE" ]; then
  echo -e "${RED}Error: Cannot find statusline.sh in $(dirname "$0")${RESET}"
  exit 1
fi

echo -e "Copying statusline.sh to ${SCRIPT_TARGET}..."
cp "$SCRIPT_SOURCE" "$SCRIPT_TARGET"
chmod +x "$SCRIPT_TARGET"

# 4. Configure settings.json
SETTINGS_FILE="$HOME/.gemini/antigravity-cli/settings.json"
SETTINGS_DIR="$(dirname "$SETTINGS_FILE")"

echo -e "Configuring settings file: ${SETTINGS_FILE}..."
if [ -f "$SETTINGS_FILE" ]; then
  # Make a backup
  cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
  echo -e "${YELLOW}Backed up original settings to ${SETTINGS_FILE}.bak${RESET}"

  # Merge using jq
  jq '.statusLine = { "type": "", "command": "'"${SCRIPT_TARGET}"'", "enabled": true }' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
  mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
else
  # Create directory if missing
  mkdir -p "$SETTINGS_DIR"
  # Write new config
  echo -e "Creating a new settings.json configuration..."
  cat <<EOF > "$SETTINGS_FILE"
{
  "statusLine": {
    "type": "",
    "command": "${SCRIPT_TARGET}",
    "enabled": true
  }
}
EOF
fi

echo -e "${BLUE}====================================================${RESET}"
echo -e "${GREEN}🎉 Installation completed successfully!${RESET}"
echo -e "Start a new antigravity session to see your new statusline."
echo -e "${BLUE}====================================================${RESET}"
