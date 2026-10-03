#!/usr/bin/env bash
# tests/test_bash_renderer.sh - Comprehensive test suite for statusline.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
STATUSLINE="${REPO_ROOT}/statusline.sh"
FIXTURES="${SCRIPT_DIR}/fixtures"
# Keep live Git branch data out of fixtures so it cannot change layout assertions.
TEST_WORKDIR="$(mktemp -d)"
cd "$TEST_WORKDIR" || exit 1

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

# A CLI may start the statusline before its payload is ready. Keep the reader
# bounded, but allow normal process scheduling and pipe startup to complete.
delayed_out=$({ sleep 0.4; cat "${FIXTURES}/context_window_calc.json"; } | bash "$STATUSLINE" --classic 2>&1 || true)
delayed_plain=$(echo "$delayed_out" | strip_ansi)
assert_contains "$delayed_plain" "14.2%" "Payload arriving after 400ms is still rendered"

# Test 2: CLI Flags
echo "--- Testing CLI Flags ---"
ver_out=$(bash "$STATUSLINE" --version 2>&1)
assert_contains "$ver_out" "0.3.0" "Version flag reports 0.3.0"
assert_not_contains "$ver_out" "0.2.6" "Version flag does not contain stale 0.2.6"
assert_not_contains "$ver_out" "0.2.5" "Version flag does not contain stale 0.2.5"
assert_not_contains "$ver_out" "0.2.4" "Version flag does not contain stale 0.2.4"
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

# Test 8: Telemetry Customization & Suppression Flags
echo "--- Testing Telemetry Customization & Suppression Flags ---"

# Baseline run with full payload at 200 cols (all fields active)
base_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=200 bash "$STATUSLINE" 2>&1 || true)
base_plain=$(echo "$base_out" | strip_ansi)
base_classic=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=200 bash "$STATUSLINE" --classic 2>&1 || true)
base_classic_plain=$(echo "$base_classic" | strip_ansi)

# Verify baseline contains expected indicators
assert_contains "$base_plain" "WORKING" "Baseline contains state WORKING"
assert_contains "$base_plain" "NORMAL" "Baseline contains vim mode NORMAL"
assert_contains "$base_plain" "qa/test-fixtures" "Baseline contains branch"
assert_contains "$base_plain" "Gemini 2.0 Flash" "Baseline contains model"
assert_contains "$base_plain" "qa-fixtures" "Baseline contains dir"
assert_contains "$base_plain" "62e3d023" "Baseline contains conversation ID"
assert_contains "$base_plain" "rekvizitor" "Baseline contains user account"
assert_contains "$base_plain" "v0.2.4" "Baseline contains version"
assert_contains "$base_plain" "14.2%" "Baseline contains context bar percentage"
assert_contains "$base_plain" "88.2K/61.1K" "Baseline contains token sum"
assert_contains "$base_plain" "RAM:" "Baseline contains sys RAM"
assert_contains "$base_plain" "net-on" "Baseline contains sandbox status"
assert_contains "$base_plain" "5H" "Baseline contains quota 5H"
assert_contains "$base_plain" "7D" "Baseline contains quota 7D"
assert_contains "$base_plain" "AC" "Baseline contains power AC"
assert_contains "$base_classic_plain" "artifacts 3" "Baseline classic contains artifacts"
assert_contains "$base_classic_plain" "subagents 2" "Baseline classic contains subagents"
assert_contains "$base_classic_plain" "tasks 2" "Baseline classic contains tasks"

# 8a: Header Segments Individual Suppression
# --no-state
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-state 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "WORKING" "--no-state suppresses agent state"

# --no-vim and alias --no-vim-mode
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-vim 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "NORMAL" "--no-vim suppresses vim mode"
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-vim-mode 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "NORMAL" "--no-vim-mode suppresses vim mode"

# --no-branch and alias --no-git
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-branch 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "qa/test-fixtures" "--no-branch suppresses VCS branch"
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-git 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "qa/test-fixtures" "--no-git suppresses VCS branch"

# --no-model
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-model 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "Gemini 2.0 Flash" "--no-model suppresses active model"

# --no-dir and alias --no-cwd
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-dir 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "qa-fixtures" "--no-dir suppresses working directory"
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-cwd 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "qa-fixtures" "--no-cwd suppresses working directory"

# --no-conv and alias --no-conversation
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-conv 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "62e3d023" "--no-conv suppresses conversation prefix"
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-conversation 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "62e3d023" "--no-conversation suppresses conversation prefix"

# --no-account and aliases --no-user, --no-plan
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-account 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "rekvizitor" "--no-account suppresses user account info"
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-user 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "rekvizitor" "--no-user suppresses user account info"
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-plan 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "rekvizitor" "--no-plan suppresses user account info"

# --no-host
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-host 2>&1 || true)
assert_not_contains "$out" "󰒋" "--no-host suppresses host indicator"

# --no-version
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-version 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "v0.2.4" "--no-version suppresses version badge"

# 8b: Pill Badges Individual Suppression
# --no-context-usage and alias --no-context
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-context-usage 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "14.2%" "--no-context-usage suppresses context bar"
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-context 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "14.2%" "--no-context suppresses context bar"

# --no-tokens-usage and alias --no-tokens
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-tokens-usage 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "88.2K/61.1K" "--no-tokens-usage suppresses token usage badge"
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-tokens 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "88.2K/61.1K" "--no-tokens suppresses token usage badge"

# --no-cost
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-cost 2>&1)
res=$?
assert_exit_code "$res" 0 "--no-cost flag runs safely"

# --no-sys and aliases --no-system, --no-resources
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-sys 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "RAM:" "--no-sys suppresses CPU/RAM badge"
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-system 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "RAM:" "--no-system suppresses CPU/RAM badge"
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-resources 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "RAM:" "--no-resources suppresses CPU/RAM badge"

# --no-artifacts
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --classic --no-artifacts 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "artifacts" "--no-artifacts suppresses artifacts badge"

# --no-subagents
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --classic --no-subagents 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "subagents" "--no-subagents suppresses subagents badge"

# --no-tasks
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --classic --no-tasks 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "tasks" "--no-tasks suppresses tasks badge"

# --no-sandbox
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-sandbox 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "net-on" "--no-sandbox suppresses sandbox badge"

# --no-quota
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-quota 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "5H" "--no-quota suppresses 5H quota bar"
assert_not_contains "$(echo "$out" | strip_ansi)" "7D" "--no-quota suppresses 7D quota bar"

# --no-power
out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-power 2>&1 || true)
assert_not_contains "$(echo "$out" | strip_ansi)" "AC" "--no-power suppresses AC power badge"

# 8c: Combinations & Presets
# Privacy mode preset: hides git branch, cwd, conversation, user account, host
priv_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-git --no-cwd --no-conv --no-account --no-host 2>&1 || true)
priv_plain=$(echo "$priv_out" | strip_ansi)
assert_not_contains "$priv_plain" "qa/test-fixtures" "Privacy mode hides git branch"
assert_not_contains "$priv_plain" "qa-fixtures" "Privacy mode hides current directory"
assert_not_contains "$priv_plain" "62e3d023" "Privacy mode hides conversation ID"
assert_not_contains "$priv_plain" "rekvizitor" "Privacy mode hides user account"
assert_contains "$priv_plain" "WORKING" "Privacy mode preserves agent state"
assert_contains "$priv_plain" "Gemini 2.0 Flash" "Privacy mode preserves active model"
assert_contains "$priv_plain" "14.2%" "Privacy mode preserves context metrics"

# Minimalist preset: hides heavy telemetry badges and Line 1 metadata
min_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --no-dir --no-conv --no-account --no-host --no-version --no-tokens --no-sys --no-artifacts --no-subagents --no-tasks --no-sandbox --no-quota --no-power 2>&1 || true)
min_plain=$(echo "$min_out" | strip_ansi)
assert_contains "$min_plain" "WORKING" "Minimalist preset preserves state"
assert_contains "$min_plain" "Gemini 2.0 Flash" "Minimalist preset preserves model"
assert_contains "$min_plain" "14.2%" "Minimalist preset preserves context bar"
assert_not_contains "$min_plain" "RAM:" "Minimalist preset suppresses sys metrics"
assert_not_contains "$min_plain" "5H" "Minimalist preset suppresses quota"
assert_not_contains "$min_plain" "AC" "Minimalist preset suppresses power"

# Test 9: Header Collapse & Full Suppression
echo "--- Testing Header Collapse & Full Suppression ---"

# 9a: Header Collapse: Passing all Line 1 suppression flags omits Line 1 and renders first badge row with '╭─'
all_l1_flags="--no-state --no-vim --no-branch --no-model --no-dir --no-conv --no-account --no-host --no-version"
hc_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" $all_l1_flags 2>&1 || true)
hc_first_line=$(echo "$hc_out" | head -n 1)

assert_not_contains "$hc_out" "WORKING" "Header Collapse omits state"
assert_not_contains "$hc_out" "NORMAL" "Header Collapse omits vim mode"
assert_not_contains "$hc_out" "qa/test-fixtures" "Header Collapse omits branch"
assert_not_contains "$hc_out" "Gemini 2.0 Flash" "Header Collapse omits model"
assert_contains "$hc_first_line" "╭─" "Header Collapse starts first badge row with ╭─"
assert_not_contains "$hc_first_line" "├─" "Header Collapse first row does not start with divider ├─"
assert_contains "$hc_first_line" "ctx" "Header Collapse first row contains context badge"

# 9b: Header Collapse with single badge row
hc_single_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" $all_l1_flags --no-tokens --no-sys --no-artifacts --no-subagents --no-tasks --no-sandbox --no-quota --no-power 2>&1 || true)
hc_single_lines=$(echo "$hc_single_out" | grep -c .)
assert_contains "$hc_single_out" "╭─" "Single-row collapsed badge starts with ╭─"
if [ "$hc_single_lines" -eq 1 ]; then
  echo "  [PASS] Single-row collapsed badge renders exactly 1 row"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Single-row collapsed badge expected 1 row, got $hc_single_lines"
  FAILED=$((FAILED + 1))
fi

# 9c: Header Collapse in Classic Mode
hc_classic_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --classic $all_l1_flags 2>&1 || true)
assert_not_contains "$hc_classic_out" "WORKING" "Classic Header Collapse omits Line 1"
hc_classic_first=$(echo "$hc_classic_out" | head -n 1)
assert_contains "$hc_classic_first" "ctx" "Classic Header Collapse first line begins with badges"

# 9d: Full Suppression: Line 1 + Line 2 suppression produces clean empty output
all_flags="--no-state --no-vim --no-branch --no-model --no-dir --no-conv --no-account --no-host --no-version --no-context --no-tokens --no-cost --no-sys --no-artifacts --no-subagents --no-tasks --no-sandbox --no-quota --no-power"
full_supp_out=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" $all_flags 2>&1 || true)
full_supp_plain=$(echo "$full_supp_out" | tr -d '[:space:]')
if [ -z "$full_supp_plain" ]; then
  echo "  [PASS] Full suppression produces clean empty output (0 bytes)"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Full suppression expected empty output, got: '$full_supp_out'"
  FAILED=$((FAILED + 1))
fi

# 9e: Full Suppression in Classic Mode
full_supp_classic=$(cat "${FIXTURES}/full_payload.json" | STATUSLINE_POWER_SUPPLY_DIR="$MOCK_PSY/s1" COLUMNS=150 bash "$STATUSLINE" --classic $all_flags 2>&1 || true)
full_supp_classic_plain=$(echo "$full_supp_classic" | tr -d '[:space:]')
if [ -z "$full_supp_classic_plain" ]; then
  echo "  [PASS] Full suppression in classic mode produces clean empty output"
  PASSED=$((PASSED + 1))
else
  echo "  [FAIL] Full suppression in classic mode expected empty output, got: '$full_supp_classic'"
  FAILED=$((FAILED + 1))
fi

rm -rf "$MOCK_PSY"
rm -rf "$TEST_WORKDIR"

echo "============================================================"
echo " Statusline Tests Completed: ${PASSED} passed, ${FAILED} failed"
echo "============================================================"
[ "$FAILED" -eq 0 ] || exit 1
