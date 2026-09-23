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
bash "$HOME/.antigravity/uninstall.sh" >/dev/null 2>&1

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

bash "$HOME/.antigravity/uninstall.sh" >/dev/null 2>&1
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

# Test 6: Custom Install Directory & Uninstall
echo "--- Test 6: Custom Install Directory & Uninstall ---"
setup_sandbox
WORK_DIR="$HOME/work"
mkdir -p "$WORK_DIR"
CUSTOM_INSTALL_DIR="$WORK_DIR/custom 'statusline"
(
  cd "$WORK_DIR" || exit 1
  AGY_STATUSLINE_INSTALL_DIR="custom 'statusline" bash "$INSTALL_SH" >/dev/null 2>&1
)
AGY_STATUSLINE_INSTALL_DIR="$CUSTOM_INSTALL_DIR" bash "$INSTALL_SH" >/dev/null 2>&1
CUSTOM_INSTALL_DIR="$(cd -P -- "$CUSTOM_INSTALL_DIR" && pwd -P)"
settings="$HOME/.gemini/antigravity-cli/settings.json"
state="$HOME/.gemini/antigravity-cli/statusline_installed_state.json"
configured_cmd=$(jq -r '.statusLine.command // ""' "$settings")
stored_install_dir=$(jq -r '.install_dir // ""' "$state")
expected_script_path="$CUSTOM_INSTALL_DIR/statusline.sh"
printf -v expected_cmd '%q' "$expected_script_path"
custom_files_were_installed=false
if [ -f "$CUSTOM_INSTALL_DIR/statusline.sh" ] && [ -f "$CUSTOM_INSTALL_DIR/uninstall.sh" ]; then
  custom_files_were_installed=true
fi

if [ "$configured_cmd" = "$expected_cmd" ] && [ -f "$CUSTOM_INSTALL_DIR/statusline.sh" ]; then
  echo "  [PASS] Relative custom install path was resolved, quoted, and configured absolutely"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Custom install path was not resolved correctly (command: '$configured_cmd')"
  FAILED=$((FAILED + 1))
fi

configured_version=$(bash -c "$configured_cmd --version" 2>/dev/null || true)
if [ "$configured_version" = "Antigravity CLI Statusline v0.2.6" ]; then
  echo "  [PASS] Shell-quoted custom path with spaces and a quote executes correctly"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Configured command failed to execute from its quoted custom path"
  FAILED=$((FAILED + 1))
fi

if [ "$stored_install_dir" = "$CUSTOM_INSTALL_DIR" ]; then
  echo "  [PASS] Install snapshot records the effective custom directory"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Install snapshot has directory '$stored_install_dir' (expected '$CUSTOM_INSTALL_DIR')"
  FAILED=$((FAILED + 1))
fi

if AGY_STATUSLINE_INSTALL_DIR="$HOME/wrong location" bash "$CUSTOM_INSTALL_DIR/uninstall.sh" >/dev/null 2>&1; then
  echo "  [FAIL] Uninstaller accepted a location override that did not match its own directory"
  FAILED=$((FAILED + 1))
elif [ -f "$CUSTOM_INSTALL_DIR/statusline.sh" ] && [ -f "$CUSTOM_INSTALL_DIR/uninstall.sh" ]; then
  echo "  [PASS] Mismatched uninstall override is rejected without removing files"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Mismatched uninstall override removed installation files"
  FAILED=$((FAILED + 1))
fi

bash "$CUSTOM_INSTALL_DIR/uninstall.sh" >/dev/null 2>&1
if [ "$custom_files_were_installed" = true ] && [ ! -e "$CUSTOM_INSTALL_DIR/statusline.sh" ] && [ ! -e "$CUSTOM_INSTALL_DIR/uninstall.sh" ]; then
  echo "  [PASS] Uninstaller removed files from the snapshotted custom directory"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Uninstaller left active files in the custom directory"
  FAILED=$((FAILED + 1))
fi
cleanup_sandbox

# Test 7: Reinstalling at the Default Directory Updates the Snapshot
echo "--- Test 7: Custom-to-Default Reinstall ---"
setup_sandbox
CUSTOM_INSTALL_DIR="$HOME/previous custom install"
AGY_STATUSLINE_INSTALL_DIR="$CUSTOM_INSTALL_DIR" bash "$INSTALL_SH" >/dev/null 2>&1
bash "$INSTALL_SH" >/dev/null 2>&1
settings="$HOME/.gemini/antigravity-cli/settings.json"
state="$HOME/.gemini/antigravity-cli/statusline_installed_state.json"
DEFAULT_INSTALL_DIR="$(cd -P -- "$HOME/.antigravity" && pwd -P)"
configured_cmd=$(jq -r '.statusLine.command // ""' "$settings")
stored_install_dir=$(jq -r '.install_dir // ""' "$state")
printf -v expected_default_command '%q' "$DEFAULT_INSTALL_DIR/statusline.sh"

if [ "$configured_cmd" = "$expected_default_command" ] && [ "$stored_install_dir" = "$DEFAULT_INSTALL_DIR" ]; then
  echo "  [PASS] Reinstall updates both the configured command and snapshot to the default directory"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Reinstall left a stale location (command: '$configured_cmd', snapshot: '$stored_install_dir')"
  FAILED=$((FAILED + 1))
fi

if bash "$CUSTOM_INSTALL_DIR/uninstall.sh" >/dev/null 2>&1; then
  echo "  [FAIL] Stale custom uninstaller was allowed to remove files after switching to default"
  FAILED=$((FAILED + 1))
elif [ -f "$DEFAULT_INSTALL_DIR/statusline.sh" ]; then
  echo "  [PASS] Stale custom uninstaller refuses to touch the active default installation"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Stale custom uninstaller affected the active default installation"
  FAILED=$((FAILED + 1))
fi

bash "$HOME/.antigravity/uninstall.sh" >/dev/null 2>&1
if [ ! -e "$DEFAULT_INSTALL_DIR/statusline.sh" ] && [ ! -e "$DEFAULT_INSTALL_DIR/uninstall.sh" ]; then
  echo "  [PASS] Uninstall removed the currently configured default installation"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Uninstall left the current default installation active"
  FAILED=$((FAILED + 1))
fi
cleanup_sandbox

# Test 8: Refuse to Overwrite Unowned Custom Files
echo "--- Test 8: Protect Existing Custom Files ---"
setup_sandbox
CUSTOM_INSTALL_DIR="$HOME/custom install"
mkdir -p "$CUSTOM_INSTALL_DIR"
printf '%s\n' "user-owned data" > "$CUSTOM_INSTALL_DIR/statusline.sh"
if AGY_STATUSLINE_INSTALL_DIR="$CUSTOM_INSTALL_DIR" bash "$INSTALL_SH" >/dev/null 2>&1; then
  echo "  [FAIL] Installer overwrote an unowned statusline.sh in the custom directory"
  FAILED=$((FAILED + 1))
elif [ "$(cat "$CUSTOM_INSTALL_DIR/statusline.sh")" = "user-owned data" ] && [ ! -e "$CUSTOM_INSTALL_DIR/uninstall.sh" ]; then
  echo "  [PASS] Installer refuses to overwrite files not owned by the active statusline configuration"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Refused install changed unrelated files in the custom directory"
  FAILED=$((FAILED + 1))
fi
cleanup_sandbox

# Test 9: Reject Git Worktree Targets Before Creating Them
echo "--- Test 9: Git Worktree Target Preflight ---"
setup_sandbox
GIT_WORKTREE="$HOME/existing project"
mkdir -p "$GIT_WORKTREE/.git"
ln -s "$GIT_WORKTREE" "$HOME/project-link"
CUSTOM_INSTALL_DIR="$HOME/project-link/custom statusline"
if AGY_STATUSLINE_INSTALL_DIR="$CUSTOM_INSTALL_DIR" bash "$INSTALL_SH" >/dev/null 2>&1; then
  echo "  [FAIL] Installer accepted a target inside a Git worktree"
  FAILED=$((FAILED + 1))
elif [ ! -e "$GIT_WORKTREE/custom statusline" ]; then
  echo "  [PASS] Git worktree target is rejected before creating directories"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Rejected Git worktree target left a new directory behind"
  FAILED=$((FAILED + 1))
fi
cleanup_sandbox

echo "============================================================"
echo " Installer Tests: ${PASSED} passed, ${FAILED} failed"
echo "============================================================"
[ "$FAILED" -eq 0 ] || exit 1
