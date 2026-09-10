#!/usr/bin/env bash
# tests/test_subagent_cache.sh - Verifies subagent transitions (0->1, 1->0, 0->3)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATUSLINE="${REPO_ROOT}/statusline.sh"

PASSED=0
FAILED=0

strip_ansi() {
  sed -E 's/\[[0-9;]*[a-zA-Z]//g' | tr -d ''
}

echo "============================================================"
echo " Running Subagent State Transition Tests"
echo "============================================================"

# Transition 1: 0 subagents
echo "--- Test 1: 0 Subagents ---"
payload_0='{"agent_state":"idle","terminal_width":120,"subagents":[]}'
out_0=$(echo "$payload_0" | bash "$STATUSLINE" --classic 2>&1)
plain_0=$(echo "$out_0" | strip_ansi)
if ! echo "$plain_0" | grep -qiE "subagent"; then
  echo "  [PASS] 0 subagents displays cleanly without subagents badge"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] 0 subagents unexpectedly displayed subagents badge: $plain_0"
  FAILED=$((FAILED + 1))
fi

# Transition 2: 0 -> 1 shows 1 immediately (stale cached 0 must NOT suppress fresh positive 1)
echo "--- Test 2: Transition 0 -> 1 Subagent ---"
payload_1='{"agent_state":"idle","terminal_width":120,"subagents":[{"id":"sub-1","name":"worker","status":"running"}]}'
out_1=$(echo "$payload_1" | bash "$STATUSLINE" --classic 2>&1)
plain_1=$(echo "$out_1" | strip_ansi)
if echo "$plain_1" | grep -qF "1" && echo "$plain_1" | grep -qiE "subagent"; then
  echo "  [PASS] 0 -> 1 shows 1 subagent immediately"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] 0 -> 1 failed to show 1 subagent (got: $plain_1)"
  FAILED=$((FAILED + 1))
fi

# Transition 3: 1 -> 0 shows 0 immediately when payload says 0
echo "--- Test 3: Transition 1 -> 0 Subagents ---"
out_1_to_0=$(echo "$payload_0" | bash "$STATUSLINE" --classic 2>&1)
plain_1_to_0=$(echo "$out_1_to_0" | strip_ansi)
if ! echo "$plain_1_to_0" | grep -qiE "subagent"; then
  echo "  [PASS] 1 -> 0 shows 0 immediately"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] 1 -> 0 failed: still shows subagent: $plain_1_to_0"
  FAILED=$((FAILED + 1))
fi

# Transition 4: 0 -> 3 shows 3 immediately
echo "--- Test 4: Transition 0 -> 3 Subagents ---"
payload_3='{"agent_state":"idle","terminal_width":120,"subagents":[{"id":"1"},{"id":"2"},{"id":"3"}]}'
out_3=$(echo "$payload_3" | bash "$STATUSLINE" --classic 2>&1)
plain_3=$(echo "$out_3" | strip_ansi)
if echo "$plain_3" | grep -qF "3" && echo "$plain_3" | grep -qiE "subagent"; then
  echo "  [PASS] 0 -> 3 shows 3 subagents immediately"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] 0 -> 3 failed to show 3 subagents (got: $plain_3)"
  FAILED=$((FAILED + 1))
fi

echo "============================================================"
echo " Subagent Tests Completed: ${PASSED} passed, ${FAILED} failed"
echo "============================================================"
[ "$FAILED" -eq 0 ] || exit 1
