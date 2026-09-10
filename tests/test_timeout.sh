#!/usr/bin/env bash
# tests/test_timeout.sh - Tests timeout behavior and fallback without GNU timeout

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATUSLINE="${REPO_ROOT}/statusline.sh"

PASSED=0
FAILED=0

echo "============================================================"
echo " Running Timeout Guard Tests"
echo "============================================================"

# Test 1: Stdin hang with timeout tool available
echo "--- Testing Stdin Timeout Protection (Normal Path) ---"
FIFO=$(mktemp -u)
mkfifo "$FIFO"
( sleep 5 > "$FIFO" ) 2>/dev/null &
WRITER_PID=$!

start_s=$(date +%s)
out=$(bash "$STATUSLINE" < "$FIFO" 2>&1 || true)
end_s=$(date +%s)
elapsed=$((end_s - start_s))

kill "$WRITER_PID" 2>/dev/null || true
wait "$WRITER_PID" 2>/dev/null || true
rm -f "$FIFO"

echo "  Elapsed time on blocked stdin: ${elapsed}s"
if [ "$elapsed" -lt 2 ]; then
  echo "  [PASS] Blocked stdin terminated within deadline (${elapsed}s < 2s)"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Blocked stdin took too long: ${elapsed}s"
  FAILED=$((FAILED + 1))
fi

# Test 2: Fallback without GNU timeout
echo "--- Testing Timeout Fallback (Without GNU timeout) ---"
FAKE_BIN_DIR=$(mktemp -d)
cat << 'EOF' > "${FAKE_BIN_DIR}/timeout"
#!/bin/sh
exit 127
EOF
chmod +x "${FAKE_BIN_DIR}/timeout"

FIFO_FB=$(mktemp -u)
mkfifo "$FIFO_FB"
( sleep 5 > "$FIFO_FB" ) 2>/dev/null &
WRITER_PID_FB=$!

start_fb=$(date +%s)
out_fb=$(PATH="${FAKE_BIN_DIR}:${PATH}" bash "$STATUSLINE" < "$FIFO_FB" 2>&1 || true)
end_fb=$(date +%s)
elapsed_fb=$((end_fb - start_fb))

kill "$WRITER_PID_FB" 2>/dev/null || true
wait "$WRITER_PID_FB" 2>/dev/null || true
rm -rf "$FAKE_BIN_DIR" "$FIFO_FB"

echo "  Elapsed time without timeout command: ${elapsed_fb}s"
if [ "$elapsed_fb" -lt 2 ]; then
  echo "  [PASS] Fallback timeout terminated safely (${elapsed_fb}s)"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Fallback timeout hung (${elapsed_fb}s)"
  FAILED=$((FAILED + 1))
fi

echo "============================================================"
echo " Timeout Tests Completed: ${PASSED} passed, ${FAILED} failed"
echo "============================================================"
[ "$FAILED" -eq 0 ] || exit 1
