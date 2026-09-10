#!/usr/bin/env bash
# tests/test_install_bash.sh - Validates install.sh & uninstall.sh state management

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_SH="${REPO_ROOT}/install.sh"
UNINSTALL_SH="${REPO_ROOT}/uninstall.sh"

PASSED=0
FAILED=0

setup_sandbox() {
  TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"
  mkdir -p "$HOME/.gemini/antigravity-cli"
}

cleanup_sandbox() {
  rm -rf "$TEST_HOME"
}

echo "============================================================"
echo " Running Bash Installer & Uninstaller Tests"
echo "============================================================"

# Test 1: Fresh Install
echo "--- Test 1: Fresh Install ---"
setup_sandbox
bash "$INSTALL_SH" >/dev/null 2>&1
settings="$HOME/.gemini/antigravity-cli/settings.json"
if [ -f "$settings" ]; then
  enabled=$(jq -r '.statusLine.enabled // false' "$settings")
  cmd=$(jq -r '.statusLine.command // ""' "$settings")
  sl_type=$(jq -r '.statusLine.type // ""' "$settings")
  
  if [ "$enabled" = "true" ] && [[ "$cmd" == *"statusline.sh"* ]]; then
    echo "  [PASS] Fresh install configured enabled statusline command"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] Fresh install missing command or enabled status"
    FAILED=$((FAILED + 1))
  fi

  if [ "$sl_type" = "command" ]; then
    echo "  [PASS] statusLine.type is correctly set to 'command'"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] statusLine.type is '$sl_type' (expected 'command')"
    FAILED=$((FAILED + 1))
  fi
else
  echo "  [FAIL] settings.json was not created"
  FAILED=$((FAILED + 1))
fi
cleanup_sandbox

# Test 2: Upgrade Preserves Unrelated Settings & Unknown Fields
echo "--- Test 2: Upgrade Preservation ---"
setup_sandbox
settings="$HOME/.gemini/antigravity-cli/settings.json"
cat << 'EOF' > "$settings"
{
  "theme": "dark",
  "editor.fontSize": 14,
  "statusLine": {
    "type": "command",
    "customPreservedField": "keep_me_123",
    "command": "/old/path/statusline.sh",
    "enabled": true
  }
}
EOF

bash "$INSTALL_SH" >/dev/null 2>&1
theme=$(jq -r '.theme // ""' "$settings")
font=$(jq -r '."editor.fontSize" // 0' "$settings")
custom=$(jq -r '.statusLine.customPreservedField // ""' "$settings")

if [ "$theme" = "dark" ] && [ "$font" -eq 14 ]; then
  echo "  [PASS] Unrelated settings (theme, fontSize) preserved during install"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Unrelated settings were lost during upgrade"
  FAILED=$((FAILED + 1))
fi

if [ "$custom" = "keep_me_123" ]; then
  echo "  [PASS] Unknown statusLine fields preserved during upgrade"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Unknown statusLine fields wiped out (got: '$custom')"
  FAILED=$((FAILED + 1))
fi
cleanup_sandbox

# Test 3: Repeated Upgrade & Uninstall Restoration
echo "--- Test 3: Repeated Upgrade & Uninstall Restoration ---"
setup_sandbox
settings="$HOME/.gemini/antigravity-cli/settings.json"
echo '{"userOriginalPref": "true", "otherSetting": 42}' > "$settings"

# Install 1
bash "$INSTALL_SH" >/dev/null 2>&1
# Install 2 (Upgrade)
bash "$INSTALL_SH" >/dev/null 2>&1
# Install 3 (Upgrade again)
bash "$INSTALL_SH" >/dev/null 2>&1

# User makes an unrelated change AFTER installation
jq '.userAddedLater = "hello"' "$settings" > "${settings}.tmp" && mv "${settings}.tmp" "$settings"

# Uninstall
bash "$UNINSTALL_SH" >/dev/null 2>&1

restored_orig=$(jq -r '.userOriginalPref // ""' "$settings" 2>/dev/null || echo "")
restored_later=$(jq -r '.userAddedLater // ""' "$settings" 2>/dev/null || echo "")
has_statusline=$(jq -r '.statusLine // empty' "$settings" 2>/dev/null || echo "")

if [ "$restored_orig" = "true" ] && [ "$restored_later" = "hello" ] && [ -z "$has_statusline" ]; then
  echo "  [PASS] Uninstall removed only statusLine and preserved unrelated pre/post install settings"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Uninstall restoration failed (orig: '$restored_orig', later: '$restored_later', statusLine: '$has_statusline')"
  FAILED=$((FAILED + 1))
fi
cleanup_sandbox

# Test 4: Symlink Preservation
echo "--- Test 4: Symlink Preservation ---"
setup_sandbox
DOTFILES_DIR="$HOME/dotfiles"
mkdir -p "$DOTFILES_DIR"
TARGET_FILE="$DOTFILES_DIR/settings.json"
echo '{"dotfilesManaged": true}' > "$TARGET_FILE"
ln -s "$TARGET_FILE" "$HOME/.gemini/antigravity-cli/settings.json"

bash "$INSTALL_SH" >/dev/null 2>&1
if [ -L "$HOME/.gemini/antigravity-cli/settings.json" ]; then
  echo "  [PASS] settings.json remained a symlink after install"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] settings.json symlink was replaced by regular file"
  FAILED=$((FAILED + 1))
fi

bash "$UNINSTALL_SH" >/dev/null 2>&1
if [ -L "$HOME/.gemini/antigravity-cli/settings.json" ]; then
  echo "  [PASS] settings.json remained a symlink after uninstall"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] settings.json symlink broken after uninstall"
  FAILED=$((FAILED + 1))
fi
cleanup_sandbox

# Test 5: Malformed settings.json safe failure
echo "--- Test 5: Malformed settings.json Handling ---"
setup_sandbox
settings="$HOME/.gemini/antigravity-cli/settings.json"
echo "{ invalid json content ... " > "$settings"

bash "$INSTALL_SH" >/dev/null 2>&1 || true
content=$(cat "$settings")
if [[ "$content" == *"{ invalid json content"* ]]; then
  echo "  [PASS] Malformed settings.json was not overwritten or clobbered"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Malformed settings.json was corrupted: $content"
  FAILED=$((FAILED + 1))
fi
cleanup_sandbox

echo "============================================================"
echo " Installer Tests: ${PASSED} passed, ${FAILED} failed"
echo "============================================================"
[ "$FAILED" -eq 0 ] || exit 1
