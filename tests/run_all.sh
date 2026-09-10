#!/usr/bin/env bash
# tests/run_all.sh - Master test runner orchestrator

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "############################################################"
echo "  ANTIGRAVITY CLI STATUSLINE — COMPREHENSIVE TEST SUITE     "
echo "############################################################"

TOTAL_SUITES=0
FAILED_SUITES=0

run_suite() {
  local name="$1"
  local cmd="$2"
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  echo ""
  echo ">>> [SUITE ${TOTAL_SUITES}] Running ${name}..."
  if eval "$cmd"; then
    echo ">>> [SUITE ${TOTAL_SUITES}] ${name}: COMPLETED SUCCESSFULLY"
  else
    echo ">>> [SUITE ${TOTAL_SUITES}] ${name}: ENCOUNTERED FAILURES"
    FAILED_SUITES=$((FAILED_SUITES + 1))
  fi
}

run_suite "Bash Statusline Renderer" "bash ${SCRIPT_DIR}/test_bash_renderer.sh"
run_suite "Stdin Timeout Protection" "bash ${SCRIPT_DIR}/test_timeout.sh"
run_suite "Subagent Cache Transitions" "bash ${SCRIPT_DIR}/test_subagent_cache.sh"
run_suite "Installer Configuration Management" "bash ${SCRIPT_DIR}/test_install_bash.sh"

if command -v python3 >/dev/null 2>&1; then
  run_suite "Windows & PowerShell Python Tests" "python3 ${SCRIPT_DIR}/test_windows.py"
fi

echo ""
echo "############################################################"
if [ "$FAILED_SUITES" -eq 0 ]; then
  echo "  TEST SUMMARY: ALL ${TOTAL_SUITES} TEST SUITES PASSED! 🎉"
  echo "############################################################"
  exit 0
else
  echo "  TEST SUMMARY: ${FAILED_SUITES} OF ${TOTAL_SUITES} TEST SUITES FAILED"
  echo "############################################################"
  exit 1
fi
