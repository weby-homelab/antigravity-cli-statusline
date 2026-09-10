#!/usr/bin/env bash
# tests/test_bash_renderer.sh - Comprehensive test suite for statusline.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATUSLINE="${REPO_ROOT}/statusline.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"

PASSED=0
FAILED=0

assert_contains() {
  local output="$1"
  local expected="$2"
  local desc="$3"
  if echo "$output" | grep -qF -- "$expected"; then
    echo "  [PASS] ${desc}"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] ${desc}"
    echo "         Expected to contain: '$expected'"
    echo "         Actual output: '$output'"
    FAILED=$((FAILED + 1))
  fi
}

assert_not_contains() {
  local output="$1"
  local unexpected="$2"
  local desc="$3"
  if ! echo "$output" | grep -qF -- "$unexpected"; then
    echo "  [PASS] ${desc}"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] ${desc} (unexpectedly contained: '$unexpected')"
    FAILED=$((FAILED + 1))
  fi
}

assert_exit_code() {
  local code="$1"
  local expected="$2"
  local desc="$3"
  if [ "$code" -eq "$expected" ]; then
    echo "  [PASS] ${desc} (exit ${code})"
    PASSED=$((PASSED + 1))
  else
    echo "  [FAIL] ${desc} (expected ${expected}, got ${code})"
    FAILED=$((FAILED + 1))
  fi
}

strip_ansi() {
  sed -E 's/\[[0-9;]*[a-zA-Z]//g' | tr -d ''
}

echo "============================================================"
echo " Running Bash Statusline Renderer Tests (statusline.sh)"
echo "============================================================"

# Test 1: Empty Stdin Resiliency
echo "--- Testing Stdin Resiliency ---"
out=$(printf "" | bash "$STATUSLINE" 2>&1)
res=$?
assert_exit_code "$res" 0 "Empty stdin does not crash"

# Test 2: CLI Flags
echo "--- Testing CLI Flags ---"
ver_out=$(bash "$STATUSLINE" --version 2>&1)
assert_contains "$ver_out" "0.2.4" "Version flag reports 0.2.4"
assert_not_contains "$ver_out" "0.2.2" "Version flag does not contain stale 0.2.2"
legend_out=$(bash "$STATUSLINE" --legend 2>&1)
assert_contains "$legend_out" "Legend" "Legend flag works"
assert_contains "$legend_out" "Vim" "Legend mentions Vim mode"

# Test 3: Context Window Metric Extraction & Calculation
echo "--- Testing Context Window Token Metrics ---"
ctx_calc_out=$(cat "${FIXTURES}/context_window_calc.json" | bash "$STATUSLINE" --classic 2>&1 || true)
ctx_calc_plain=$(echo "$ctx_calc_out" | strip_ansi)
assert_contains "$ctx_calc_plain" "14.2%" "Context used percentage ~14.2%"
assert_contains "$ctx_calc_plain" "1.0M" "Context limit ~1.0M (1048576)"
assert_contains "$ctx_calc_plain" "149.3K" "CTX_USED displays 149.3K (88244 + 61074)"

ctx_exp_out=$(cat "${FIXTURES}/context_window_explicit.json" | bash "$STATUSLINE" --classic 2>&1 || true)
ctx_exp_plain=$(echo "$ctx_exp_out" | strip_ansi)
assert_contains "$ctx_exp_plain" "149.3K" "Context explicit total_tokens displays 149.3K"

# Test 4: Model-aware Quota Resolution
echo "--- Testing Model-Aware Quota Selection ---"
claude_out=$(cat "${FIXTURES}/quota_both_claude_model.json" | bash "$STATUSLINE" --classic 2>&1 || true)
claude_plain=$(echo "$claude_out" | strip_ansi)
assert_contains "$claude_plain" "40%" "Claude model prefers 3P quota (40% vs 85%)"

gpt_out=$(cat "${FIXTURES}/quota_both_gpt_model.json" | bash "$STATUSLINE" --classic 2>&1 || true)
gpt_plain=$(echo "$gpt_out" | strip_ansi)
assert_contains "$gpt_plain" "40%" "GPT model prefers 3P quota (40% vs 85%)"

gemini_out=$(cat "${FIXTURES}/quota_both_gemini_model.json" | bash "$STATUSLINE" --classic 2>&1 || true)
gemini_plain=$(echo "$gemini_out" | strip_ansi)
assert_contains "$gemini_plain" "85%" "Gemini model prefers Gemini quota (85% vs 40%)"

# Test 5: Issue #62 Vim Mode Rendering
echo "--- Testing Vim Mode Integration (#62) ---"
for mode_pair in "vim_normal.json:NORMAL" "vim_insert.json:INSERT" "vim_visual.json:VISUAL" "vim_visual_line.json:VISUAL LINE" "vim_unknown.json:CUSTOM_MODE"; do
  fix="${mode_pair%%:*}"
  expected_mode="${mode_pair##*:}"
  v_out=$(cat "${FIXTURES}/${fix}" | bash "$STATUSLINE" --classic 2>&1 || true)
  v_plain=$(echo "$v_out" | strip_ansi)
  assert_contains "$v_plain" "$expected_mode" "Vim mode $expected_mode rendered"
done

# Absent vim object -> no vim indicator
min_out=$(cat "${FIXTURES}/minimal_payload.json" | bash "$STATUSLINE" --classic 2>&1 || true)
min_plain=$(echo "$min_out" | strip_ansi)
assert_not_contains "$min_plain" "NORMAL" "Absent vim object does not display NORMAL"
assert_not_contains "$min_plain" "INSERT" "Absent vim object does not display INSERT"

# Test 6: Terminal Width Boundaries & Line-Packing Engine
echo "--- Testing Terminal Width Packing (Zero Wrapping) ---"
TEST_WIDTHS=(60 80 89 100 120 130 150 179 180 200 234 235 237 255)
overflow_count=0
for w in "${TEST_WIDTHS[@]}"; do
  for fixture in "full_payload.json" "long_values.json"; do
    for mode in "" "--classic"; do
      out=$(cat "${FIXTURES}/${fixture}" | COLUMNS="$w" bash "$STATUSLINE" $mode 2>&1 || true)
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        plain=$(printf "%s" "$line" | strip_ansi)
        len=${#plain}
        if [ "$len" -gt "$w" ]; then
          echo "  [FAIL] Overflow at width ${w} with ${fixture} (${mode}): visible length ${len} > ${w}"
          echo "         Line: $plain"
          overflow_count=$((overflow_count + 1))
        fi
      done <<< "$out"
    done
  done
done
if [ "$overflow_count" -eq 0 ]; then
  echo "  [PASS] All output lines strictly <= COLUMNS across tested widths (60 to 255)"
  PASSED=$((PASSED + 1))
else
  FAILED=$((FAILED + 1))
fi

# Test 7: Power Supply & Battery Detection (Issue #70)
echo "--- Testing Power Supply & Battery Detection ---"
MOCK_PSY=$(mktemp -d)

# 7a: Laptop on AC charging
mkdir -p "$MOCK_PSY/s1/AC" "$MOCK_PSY/s1/BAT0"
echo "Mains" > "$MOCK_PSY/s1/AC/type"; echo "1" > "$MOCK_PSY/s1/AC/online"
echo "Battery" > "$MOCK_PSY/s1/BAT0/type"; echo "Charging" > "$MOCK_PSY/s1/BAT0/status"; echo "45" > "$MOCK_PSY/s1/BAT0/capacity"
p_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" bash "$STATUSLINE" 2>&1 || true)
assert_contains "$p_out" "AC" "Laptop on AC charging renders AC badge"
assert_not_contains "$p_out" "BAT" "Laptop on AC charging does not render BAT"

# 7b: Laptop on AC threshold (Not charging)
mkdir -p "$MOCK_PSY/s2/AC" "$MOCK_PSY/s2/BAT0"
echo "Mains" > "$MOCK_PSY/s2/AC/type"; echo "1" > "$MOCK_PSY/s2/AC/online"
echo "Battery" > "$MOCK_PSY/s2/BAT0/type"; echo "Not charging" > "$MOCK_PSY/s2/BAT0/status"; echo "80" > "$MOCK_PSY/s2/BAT0/capacity"
p_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s2" bash "$STATUSLINE" 2>&1 || true)
assert_contains "$p_out" "AC" "Laptop on AC threshold (Not charging) renders AC badge"

# 7c: Laptop on Battery discharging with capacity
mkdir -p "$MOCK_PSY/s3/AC" "$MOCK_PSY/s3/BAT0"
echo "Mains" > "$MOCK_PSY/s3/AC/type"; echo "0" > "$MOCK_PSY/s3/AC/online"
echo "Battery" > "$MOCK_PSY/s3/BAT0/type"; echo "Discharging" > "$MOCK_PSY/s3/BAT0/status"; echo "65" > "$MOCK_PSY/s3/BAT0/capacity"
p_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s3" bash "$STATUSLINE" 2>&1 || true)
assert_contains "$p_out" "65%" "Laptop on battery discharging renders 65%"
assert_contains "$p_out" "🔋" "Laptop on battery discharging renders battery icon"

# 7d: Laptop on AC with peripheral mouse (hidpp_battery_0 scope: Device online: 0)
mkdir -p "$MOCK_PSY/s4/AC" "$MOCK_PSY/s4/BAT0" "$MOCK_PSY/s4/hidpp_battery_0"
echo "Mains" > "$MOCK_PSY/s4/AC/type"; echo "1" > "$MOCK_PSY/s4/AC/online"
echo "Battery" > "$MOCK_PSY/s4/BAT0/type"; echo "Charging" > "$MOCK_PSY/s4/BAT0/status"; echo "90" > "$MOCK_PSY/s4/BAT0/capacity"
echo "Battery" > "$MOCK_PSY/s4/hidpp_battery_0/type"; echo "Device" > "$MOCK_PSY/s4/hidpp_battery_0/scope"; echo "0" > "$MOCK_PSY/s4/hidpp_battery_0/online"
p_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s4" bash "$STATUSLINE" 2>&1 || true)
assert_contains "$p_out" "AC" "Peripheral mouse with online: 0 does not mask AC power"
assert_not_contains "$p_out" "BAT" "Peripheral mouse does not cause BAT badge when AC connected"

# 7e: Desktop workstation with only peripheral devices (scope: Device)
mkdir -p "$MOCK_PSY/s5/hidpp_battery_0" "$MOCK_PSY/s5/ucsi-source-psy"
echo "Battery" > "$MOCK_PSY/s5/hidpp_battery_0/type"; echo "Device" > "$MOCK_PSY/s5/hidpp_battery_0/scope"; echo "0" > "$MOCK_PSY/s5/hidpp_battery_0/online"
echo "USB" > "$MOCK_PSY/s5/ucsi-source-psy/type"; echo "Device" > "$MOCK_PSY/s5/ucsi-source-psy/scope"; echo "0" > "$MOCK_PSY/s5/ucsi-source-psy/online"
p_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s5" bash "$STATUSLINE" 2>&1 || true)
assert_contains "$p_out" "AC" "Desktop workstation with peripherals renders AC power"
assert_not_contains "$p_out" "BAT" "Desktop workstation does not render BAT"

# 7f: Classic mode AC formatting (single AC, not AC AC)
c_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" bash "$STATUSLINE" --classic 2>&1 || true)
c_plain=$(echo "$c_out" | strip_ansi)
assert_contains "$c_plain" "AC" "Classic mode renders AC"
assert_not_contains "$c_plain" "AC AC" "Classic mode does not duplicate AC AC"

rm -rf "$MOCK_PSY"

echo "============================================================"
echo " Statusline Tests Completed: ${PASSED} passed, ${FAILED} failed"
echo "============================================================"
[ "$FAILED" -eq 0 ] || exit 1
