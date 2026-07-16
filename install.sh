#!/usr/bin/env bash
# install.sh - Installer for Linux & macOS

set -euo pipefail

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Check if running via sudo
if [ -n "${SUDO_USER:-}" ]; then
  echo -e "${RED}Error: This script should NOT be run with sudo or as root via sudo.${RESET}"
  echo -e "${YELLOW}The statusline installs locally in your home directory (~/.antigravity).${RESET}"
  echo -e "${YELLOW}Running with sudo will cause file permission issues for your user account.${RESET}"
  echo -e "Please run the installation command without sudo:"
  echo -e "${GREEN}curl -fsSL https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main/install.sh | bash${RESET}"
  exit 1
fi

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

# 3. Copy/Download files
SCRIPT_TARGET="${INSTALL_DIR}/statusline.sh"
UNINSTALL_TARGET="${INSTALL_DIR}/uninstall.sh"

LOCAL_DIR=""
if [ -f "$(dirname "$0")/statusline.sh" ]; then
  LOCAL_DIR="$(dirname "$0")"
fi

RAW_URL="https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main"

if [ -n "$LOCAL_DIR" ]; then
  echo -e "Installing from local files..."
  cp "${LOCAL_DIR}/statusline.sh" "$SCRIPT_TARGET"
  chmod +x "$SCRIPT_TARGET"
  if [ -f "${LOCAL_DIR}/uninstall.sh" ]; then
    cp "${LOCAL_DIR}/uninstall.sh" "$UNINSTALL_TARGET"
    chmod +x "$UNINSTALL_TARGET"
  fi
else
  echo -e "Installing from remote repository..."
  if command -v curl &> /dev/null; then
    echo -e "Downloading statusline.sh using curl..."
    curl -fsSL "${RAW_URL}/statusline.sh" -o "$SCRIPT_TARGET"
    echo -e "Downloading uninstall.sh using curl..."
    curl -fsSL "${RAW_URL}/uninstall.sh" -o "$UNINSTALL_TARGET"
  elif command -v wget &> /dev/null; then
    echo -e "Downloading statusline.sh using wget..."
    wget -qO "$SCRIPT_TARGET" "${RAW_URL}/statusline.sh"
    echo -e "Downloading uninstall.sh using wget..."
    wget -qO "$UNINSTALL_TARGET" "${RAW_URL}/uninstall.sh"
  else
    echo -e "${RED}Error: Neither curl nor wget is installed. Cannot download files.${RESET}"
    exit 1
  fi
  chmod +x "$SCRIPT_TARGET"
  chmod +x "$UNINSTALL_TARGET"
fi

# Capture optional script arguments to pass to the statusline (e.g. --medium)
EXTRA_ARGS=""
if [ "$#" -gt 0 ]; then
  EXTRA_ARGS=" $@"
fi
COMMAND_STRING="${SCRIPT_TARGET}${EXTRA_ARGS}"

# 4. Configure settings.json
SETTINGS_FILE="$HOME/.gemini/antigravity-cli/settings.json"
SETTINGS_DIR="$(dirname "$SETTINGS_FILE")"

echo -e "Configuring settings file: ${SETTINGS_FILE}..."
if [ -f "$SETTINGS_FILE" ]; then
  # Make a backup
  cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
  echo -e "${YELLOW}Backed up original settings to ${SETTINGS_FILE}.bak${RESET}"

  # Merge using jq
  jq '.statusLine = { "type": "", "command": "'"${COMMAND_STRING}"'", "enabled": true }' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
  cat "${SETTINGS_FILE}.tmp" > "$SETTINGS_FILE"
  rm -f "${SETTINGS_FILE}.tmp"
else
  # Create directory if missing
  mkdir -p "$SETTINGS_DIR"
  # Write new config
  echo -e "Creating a new settings.json configuration..."
  cat <<EOF > "$SETTINGS_FILE"
{
  "statusLine": {
    "type": "",
    "command": "${COMMAND_STRING}",
    "enabled": true
  }
}
EOF
fi

echo -e "${BLUE}====================================================${RESET}"
echo -e "${GREEN}🎉 Installation completed successfully!${RESET}"
echo -e "Start a new antigravity session to see your new statusline."
echo -e "Uninstaller copied to: ${UNINSTALL_TARGET}"
echo -e ""
echo -e "To view the legend of all statusline icons and components, run:"
echo -e "  ${GREEN}${SCRIPT_TARGET} --legend${RESET}"
echo -e "${BLUE}====================================================${RESET}"
