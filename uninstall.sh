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

SETTINGS_FILE="$HOME/.gemini/antigravity-cli/settings.json"
SETTINGS_DIR="$(dirname "$SETTINGS_FILE")"
STATE_FILE="${SETTINGS_DIR}/statusline_installed_state.json"

resolve_directory_path() {
  local path="$1"
  local absolute_path parent base

  case "$path" in
    "~") path="$HOME" ;;
    "~/"*) path="$HOME${path:1}" ;;
    "~"*)
      echo -e "${RED}Error: Only '~' and '~/...' home-directory shortcuts are supported.${RESET}" >&2
      return 1
      ;;
  esac

  case "$path" in
    /*) absolute_path="$path" ;;
    *) absolute_path="$PWD/$path" ;;
  esac

  if [ -d "$absolute_path" ]; then
    (cd -P -- "$absolute_path" && pwd)
    return
  fi

  parent="$(dirname "$absolute_path")"
  base="$(basename "$absolute_path")"
  if [ -d "$parent" ]; then
    parent="$(cd -P -- "$parent" && pwd)"
    printf '%s/%s' "${parent%/}" "$base"
  else
    printf '%s' "$absolute_path"
  fi
}

UNINSTALLER_SOURCE="${BASH_SOURCE[0]}"
if [ -L "$UNINSTALLER_SOURCE" ]; then
  echo -e "${RED}Error: Refusing to uninstall through a symbolic link.${RESET}" >&2
  exit 1
fi
case "$UNINSTALLER_SOURCE" in
  /*) ;;
  *) UNINSTALLER_SOURCE="$PWD/$UNINSTALLER_SOURCE" ;;
esac
INSTALL_DIR="$(cd -P -- "$(dirname "$UNINSTALLER_SOURCE")" && pwd -P)"
if [ "$INSTALL_DIR" = "/" ]; then
  echo -e "${RED}Error: Refusing to uninstall from the filesystem root.${RESET}" >&2
  exit 1
fi
PARENT_CHECK_DIR="$INSTALL_DIR"
while [ "$PARENT_CHECK_DIR" != "/" ]; do
  if [ -e "$PARENT_CHECK_DIR/.git" ]; then
    echo -e "${RED}Error: Refusing to remove files inside a Git working tree.${RESET}" >&2
    exit 1
  fi
  PARENT_CHECK_DIR="$(dirname "$PARENT_CHECK_DIR")"
done
SCRIPT_TARGET="${INSTALL_DIR}/statusline.sh"
UNINSTALL_TARGET="${INSTALL_DIR}/uninstall.sh"

if [ -n "${AGY_STATUSLINE_INSTALL_DIR:-}" ]; then
  REQUESTED_INSTALL_DIR="$(resolve_directory_path "$AGY_STATUSLINE_INSTALL_DIR")" || exit 1
  if [ "$REQUESTED_INSTALL_DIR" != "$INSTALL_DIR" ]; then
    echo -e "${RED}Error: AGY_STATUSLINE_INSTALL_DIR does not match this uninstaller's location. No files were removed.${RESET}" >&2
    exit 1
  fi
fi

if [ -f "$STATE_FILE" ]; then
  SNAPSHOT_INSTALL_DIR="$(jq -r '.install_dir // .AGY_STATUSLINE_INSTALL_DIR // empty' "$STATE_FILE" 2>/dev/null || true)"
  if [ -n "$SNAPSHOT_INSTALL_DIR" ]; then
    SNAPSHOT_INSTALL_DIR="$(resolve_directory_path "$SNAPSHOT_INSTALL_DIR")" || exit 1
    if [ "$SNAPSHOT_INSTALL_DIR" != "$INSTALL_DIR" ]; then
      echo -e "${RED}Error: The saved install location does not match this uninstaller. No files were removed.${RESET}" >&2
      exit 1
    fi
  fi
fi

if [ ! -f "$SETTINGS_FILE" ] || ! command -v jq &> /dev/null; then
  echo -e "${RED}Error: Cannot verify the active settings command. No files were removed.${RESET}" >&2
  exit 1
fi
CURRENT_COMMAND="$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null || true)"
QUOTED_SCRIPT_TARGET="${SCRIPT_TARGET//\'/\'\\\'\'}"
EXPECTED_COMMAND="'${QUOTED_SCRIPT_TARGET}'"
if [[ "$CURRENT_COMMAND" != "$EXPECTED_COMMAND" && "$CURRENT_COMMAND" != "$EXPECTED_COMMAND "* && \
      "$CURRENT_COMMAND" != "$SCRIPT_TARGET" && "$CURRENT_COMMAND" != "$SCRIPT_TARGET "* ]]; then
  echo -e "${RED}Error: settings.json does not point to this installation. No files were removed.${RESET}" >&2
  exit 1
fi

if [ -L "$SCRIPT_TARGET" ] || [ -L "$UNINSTALL_TARGET" ]; then
  echo -e "${RED}Error: Refusing to remove symbolic-link targets.${RESET}" >&2
  exit 1
fi

if [ -f "$SCRIPT_TARGET" ]; then
  echo -e "Removing statusline script: ${SCRIPT_TARGET}..."
  rm -f "$SCRIPT_TARGET"
fi

if [ -f "$SETTINGS_FILE" ]; then
  if [ -f "$STATE_FILE" ]; then
    echo -e "Restoring statusline configuration from state snapshot..."
    if command -v jq &> /dev/null; then
      existed=$(jq -r '.statusLine_existed // false' "$STATE_FILE" 2>/dev/null || echo "false")
      if [ "$existed" = "true" ]; then
        orig_val=$(jq '.original_statusLine' "$STATE_FILE")
        jq --argjson orig "$orig_val" '.statusLine = $orig' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
        cat "${SETTINGS_FILE}.tmp" > "$SETTINGS_FILE"
        rm -f "${SETTINGS_FILE}.tmp"
        echo -e "Restored original statusLine configuration."
      else
        jq 'del(.statusLine)' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp"
        cat "${SETTINGS_FILE}.tmp" > "$SETTINGS_FILE"
        rm -f "${SETTINGS_FILE}.tmp"
        echo -e "Removed statusLine configuration from settings.json."
      fi
    else
      echo -e "${YELLOW}Warning: 'jq' not found. Cannot safely modify ${SETTINGS_FILE}${RESET}"
    fi
    rm -f "$STATE_FILE"
    rm -f "${SETTINGS_FILE}.bak"
  elif [ -f "${SETTINGS_FILE}.bak" ]; then
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

# Ensure state snapshot is removed even if settings.json was deleted externally
rm -f "$STATE_FILE" 2>/dev/null || true

# Finally, clean up itself and the directory if empty
if [ -f "$UNINSTALL_TARGET" ]; then
  echo -e "Removing uninstaller: ${UNINSTALL_TARGET}..."
  rm -f "$UNINSTALL_TARGET"
  rmdir "$INSTALL_DIR" 2>/dev/null || true
fi

echo -e "${BLUE}====================================================${RESET}"
echo -e "${GREEN}✓ Uninstallation completed successfully.${RESET}"
echo -e "${BLUE}====================================================${RESET}"
