#!/bin/bash
# statusline.sh - Resilient and Maximized Telemetry Statusline for Antigravity CLI
# Built with premium 256-color powerline theme & instant system diagnostics

set -euo pipefail
export LC_NUMERIC=C
USE_CLASSIC_ICONS=false
CLI_COLS_OVERRIDE=""

for arg in "$@"; do
  case "$arg" in
    --version|-v)
      echo "Antigravity CLI Statusline v0.2.5"
      exit 0
      ;;
    --legend|-l|legend)
      echo -e "\033[92m\033[1m🚀 Antigravity CLI Maximized Statusline Legend (v0.2.5)\033[0m"
      echo -e "This statusline adapts dynamically to terminal width and displays high-density system & agent telemetry."
      echo -e ""
      echo -e "\033[1mLAYOUTS & AUTO-PACKING:\033[0m"
      echo -e "  - \033[1mSmart Dynamic Line-Packing Engine:\033[0m Telemetry badges automatically pack into cleanly framed boxed rows (╭─, ├─, ╰─) without line wrapping."
      echo -e ""
      echo -e "\033[1mCOMPONENTS & ICONS:\033[0m"
      echo -e "  \033[1mField                Nerd Font   Classic     Description\033[0m"
      echo -e "  --------------------------------------------------------------------------------"
      echo -e "  State: READY                   ●           Agent is idle, ready for user requests."
      echo -e "  State: THINKING      󰟷          ◆           Agent is processing/thinking."
      echo -e "  State: WORKING                 ⚙           Agent is executing background operations."
      echo -e "  State: TOOL                    🔧          Agent is running a tool."
      echo -e "  Vim Editor Mode                [MODE]      Active Vim editor mode (NORMAL, INSERT, VISUAL, etc.)."
      echo -e "  VCS Branch                     ╱           Current Git branch name (Red + * if dirty)."
      echo -e "  Model                          (None)      Current active LLM model name/ID."
      echo -e "  User Account         👤          (None)      Active user subscription plan and email."
      echo -e "  Sandbox Network      󰒙          ON (net)    Sandbox enabled with internet access."
      echo -e "  Sandbox Restricted   󰴴          ON (no-net) Sandbox enabled with network disabled."
      echo -e "  Sandbox Off          󰦜          sandbox off Sandbox is disabled (runs on host)."
      echo -e "  Context Bar          󱍏          ctx         Context window usage bar (10 or 20 segments)."
      echo -e "  Tokens Sum                     (None)      Total input/output tokens & turn token delta."
      echo -e "  Sys resources                  sys         Host CPU load average & memory utilization."
      echo -e "  Artifacts                      artifacts   Number of active output artifacts."
      echo -e "  Subagents            󱙺          subagents   Number of spawned active subagents."
      echo -e "  Background Tasks               tasks       Number of background tasks running."
      echo -e "  Current Directory              ╱           Current working directory path (shortened)."
      echo -e "  Conversation ID      󰍪          ╱           Short prefix of the current session ID."
      echo -e "  Quota Reset Time     ⌛️         ⌛          Remaining time until LLM quota resets."
      echo -e "  Power Mains (AC)     󰚥          AC          Host is connected to external AC power."
      echo -e "  Power Battery (UPS)  🔋          BAT         Host is running on battery (shows charge %)."
      exit 0
      ;;
    --compact)
      CLI_COLS_OVERRIDE=89
      ;;
    --medium)
      CLI_COLS_OVERRIDE=120
      ;;
    --medium-wide)
      CLI_COLS_OVERRIDE=150
      ;;
    --classic|--no-nerdfont|--compatibility)
      USE_CLASSIC_ICONS=true
      ;;
  esac
done

# ─── stdin timeout guard & portable timeout ──────────────────────────────────
# The CLI statusline runner kills the script if stdin hangs indefinitely.
# We read stdin with a short deadline and close it immediately.
run_with_timeout() {
  local timeout_sec="1"
  if [[ "${1:-}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    timeout_sec="$1"
    shift
  fi

  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_sec" "$@"
    return $?
  fi

  # Bounded subshell fallback without GNU timeout (e.g. macOS / BSD)
  "$@" <&0 &
  local target_pid=$!
  (
    trap 'kill $(jobs -p) 2>/dev/null || true; exit 0' TERM INT HUP EXIT
    ( sleep "$timeout_sec" 2>/dev/null || sleep 1 ) &
    wait $! 2>/dev/null || true
    kill -TERM "$target_pid" 2>/dev/null || true
    sleep 0.1 2>/dev/null || true
    kill -KILL "$target_pid" 2>/dev/null || true
  ) >/dev/null 2>&1 &
  local timer_pid=$!

  wait "$target_pid" 2>/dev/null
  local target_res=$?

  kill -TERM "$timer_pid" 2>/dev/null || true
  wait "$timer_pid" 2>/dev/null || true
  return $target_res
}

my_in=$(readlink /proc/self/fd/0 2>/dev/null || true)
INPUT_JSON=$(run_with_timeout 0.25 cat 2>/dev/null || true)
exec 0</dev/null
if [ -z "$INPUT_JSON" ]; then
  # If stdin timed out on a pipe, unblock upstream pipeline sibling
  if [[ "$my_in" =~ ^pipe: ]]; then
    for cpid in $(cat "/proc/$PPID/task/$PPID/children" 2>/dev/null); do
      if [ "$cpid" != "$$" ] && [ "$(readlink "/proc/$cpid/fd/1" 2>/dev/null)" = "$my_in" ]; then
        kill "$cpid" 2>/dev/null || true
      fi
    done
  fi
  INPUT_JSON="{}"
fi

# ─── ANSI Helpers (Standard colors) ───────────────────────────────────────────
R="\033[0m"         # Reset
B="\033[1m"         # Bold
D="\033[2m"         # Dim
I="\033[3m"         # Italic

# Foreground standard colors for classic fallback
FG_BLACK="\033[30m"
FG_RED="\033[31m"
FG_GREEN="\033[32m"
FG_YELLOW="\033[33m"
FG_BLUE="\033[34m"
FG_MAGENTA="\033[35m"
FG_CYAN="\033[36m"
FG_WHITE="\033[37m"

FG_GRAY="\033[90m"
FG_BRIGHT_RED="\033[91m"
FG_BRIGHT_GREEN="\033[92m"
FG_BRIGHT_YELLOW="\033[93m"
FG_BRIGHT_BLUE="\033[94m"
FG_BRIGHT_MAGENTA="\033[95m"
FG_BRIGHT_CYAN="\033[96m"
FG_BRIGHT_WHITE="\033[97m"

NUM_COLOR="${FG_BRIGHT_WHITE}${B}"

# ─── Parse JSON from stdin (Single jq pass for performance) ──────────────────
{
  read -r STATE
  read -r VIM_MODE
  read -r USED_PCT
  read -r VCS_BRANCH
  read -r VCS_DIRTY
  read -r VCS_TYPE
  read -r VCS_CLIENT
  read -r SANDBOX
  read -r SANDBOX_NET
  read -r ARTIFACTS
  read -r SUBAGENTS
  read -r BG_TASKS
  read -r MODEL_ID
  read -r MODEL_NAME
  read -r COLS
  read -r CWD
  read -r CONV_ID
  read -r PRODUCT
  read -r INPUT_TOKENS
  read -r OUTPUT_TOKENS
  read -r CTX_LIMIT
  read -r CTX_USED
  read -r REM_PCT
  read -r GEMINI_5H
  read -r GEMINI_WK
  read -r TP_5H
  read -r TP_WK
  read -r GEMINI_5H_RESET
  read -r GEMINI_WK_RESET
  read -r TP_5H_RESET
  read -r TP_WK_RESET
  read -r CLI_VERSION
  read -r PLAN_TIER
  read -r USER_EMAIL
  read -r TURN_INPUT_TOKENS
  read -r TURN_OUTPUT_TOKENS
} <<< "$(
  printf '%s' "$INPUT_JSON" | jq -r '
    (.agent_state // "idle"),
    (.vim.mode // ""),
    (if (.context_window.used_percentage | type == "number") then .context_window.used_percentage else 0 end),
    (.vcs.branch // ""),
    (.vcs.dirty // false),
    (.vcs.type // ""),
    (.vcs.client // ""),
    (.sandbox.enabled // false),
    (.sandbox.allow_network // false),
    (.artifact_count // 0),
    (if .subagents | type == "array" then (.subagents | length) else 0 end),
    (.task_count // 0),
    (.model.id // ""),
    (.model.display_name // ""),
    (.terminal_width // 80),
    (.cwd // ""),
    (.conversation_id // ""),
    (.product // ""),
    (if (.context_window.total_input_tokens | type == "number") then .context_window.total_input_tokens else 0 end),
    (if (.context_window.total_output_tokens | type == "number") then .context_window.total_output_tokens else 0 end),
    (if (.context_window.context_window_size | type == "number") then .context_window.context_window_size else 0 end),
    (if (.context_window.total_tokens | type == "number") and .context_window.total_tokens > 0 then
      .context_window.total_tokens
    else
      ((if (.context_window.total_input_tokens | type == "number") then .context_window.total_input_tokens else 0 end) +
       (if (.context_window.total_output_tokens | type == "number") then .context_window.total_output_tokens else 0 end))
    end),
    (.context_window.remaining_percentage // 100),
    (if .quota["gemini-5h"].remaining_fraction != null then ((.quota["gemini-5h"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (if .quota["gemini-weekly"].remaining_fraction != null then ((.quota["gemini-weekly"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (if .quota["3p-5h"].remaining_fraction != null then ((.quota["3p-5h"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (if .quota["3p-weekly"].remaining_fraction != null then ((.quota["3p-weekly"].remaining_fraction * 1000 | round) / 10) else -1 end),
    (.quota["gemini-5h"].reset_in_seconds // -1),
    (.quota["gemini-weekly"].reset_in_seconds // -1),
    (.quota["3p-5h"].reset_in_seconds // -1),
    (.quota["3p-weekly"].reset_in_seconds // -1),
    (.version // ""),
    (.plan_tier // ""),
    (.email // ""),
    (.context_window.current_usage.input_tokens // 0),
    (.context_window.current_usage.output_tokens // 0)
  ' 2>/dev/null || printf "idle\n\n0\n\nfalse\n\n\nfalse\nfalse\n0\n0\n0\n\n\n80\n\n\n\n0\n0\n0\n0\n100\n-1\n-1\n-1\n-1\n-1\n-1\n-1\n-1\n\n\n\n0\n0\n"
)"

# ─── Dynamic String Sanitization (Defensive against ANSI, newlines, control chars)
sanitize_str() {
  local s="$1"
  s=$(printf '%s' "$s" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g')
  printf '%s' "$s" | tr -d '[:cntrl:]'
}

STATE=$(sanitize_str "$STATE")
VIM_MODE=$(sanitize_str "$VIM_MODE")
VCS_BRANCH=$(sanitize_str "$VCS_BRANCH")
VCS_TYPE=$(sanitize_str "$VCS_TYPE")
MODEL_ID=$(sanitize_str "$MODEL_ID")
MODEL_NAME=$(sanitize_str "$MODEL_NAME")
CWD=$(sanitize_str "$CWD")
CONV_ID=$(sanitize_str "$CONV_ID")
PRODUCT=$(sanitize_str "$PRODUCT")
CLI_VERSION=$(sanitize_str "$CLI_VERSION")
PLAN_TIER=$(sanitize_str "$PLAN_TIER")
USER_EMAIL=$(sanitize_str "$USER_EMAIL")

# ─── Numeric Payload Sanitization (Defensive against invalid/string JSON values) ──
if ! [[ "$USED_PCT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then USED_PCT=0; fi
if [ -n "$CLI_COLS_OVERRIDE" ]; then
  COLS="$CLI_COLS_OVERRIDE"
elif [ -n "${COLUMNS:-}" ] && [ "$COLUMNS" -gt 0 ] 2>/dev/null; then
  COLS="$COLUMNS"
fi
if ! [[ "$COLS" =~ ^[0-9]+$ ]] || [ "$COLS" -lt 40 ]; then COLS=80; fi

if ! [[ "$ARTIFACTS" =~ ^[0-9]+$ ]]; then ARTIFACTS=0; fi
if ! [[ "$SUBAGENTS" =~ ^[0-9]+$ ]]; then SUBAGENTS=0; fi
if ! [[ "$BG_TASKS" =~ ^[0-9]+$ ]]; then BG_TASKS=0; fi
if ! [[ "$INPUT_TOKENS" =~ ^[0-9]+$ ]]; then INPUT_TOKENS=0; fi
if ! [[ "$OUTPUT_TOKENS" =~ ^[0-9]+$ ]]; then OUTPUT_TOKENS=0; fi
if ! [[ "$CTX_LIMIT" =~ ^[0-9]+$ ]]; then CTX_LIMIT=0; fi
if ! [[ "$CTX_USED" =~ ^[0-9]+$ ]]; then CTX_USED=0; fi
if [ "$CTX_LIMIT" -eq 0 ] 2>/dev/null && [ "$CTX_USED" -gt 0 ] 2>/dev/null; then
  pct_whole=${USED_PCT%.*}
  pct_whole=${pct_whole:-0}
  if [ "$pct_whole" -gt 0 ]; then
    CTX_LIMIT=$(( CTX_USED * 100 / pct_whole ))
  fi
fi
if ! [[ "$TURN_INPUT_TOKENS" =~ ^[0-9]+$ ]]; then TURN_INPUT_TOKENS=0; fi
if ! [[ "$TURN_OUTPUT_TOKENS" =~ ^[0-9]+$ ]]; then TURN_OUTPUT_TOKENS=0; fi

if ! [[ "$GEMINI_5H" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then GEMINI_5H="-1"; fi
if ! [[ "$GEMINI_WK" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then GEMINI_WK="-1"; fi
if ! [[ "$TP_5H" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then TP_5H="-1"; fi
if ! [[ "$TP_WK" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then TP_WK="-1"; fi

if ! [[ "$GEMINI_5H_RESET" =~ ^[0-9]+$ ]]; then GEMINI_5H_RESET="-1"; fi
if ! [[ "$GEMINI_WK_RESET" =~ ^[0-9]+$ ]]; then GEMINI_WK_RESET="-1"; fi
if ! [[ "$TP_5H_RESET" =~ ^[0-9]+$ ]]; then TP_5H_RESET="-1"; fi
if ! [[ "$TP_WK_RESET" =~ ^[0-9]+$ ]]; then TP_WK_RESET="-1"; fi


_tick_countdown() {
  local val="$1"
  local cache_file="$2"
  local now; now=$(date +%s)

  if [ -z "$val" ] || [ "$val" -le 0 ] 2>/dev/null; then
    rm -f "$cache_file" 2>/dev/null || true
    echo "-1"
    return
  fi

  if [ -f "$cache_file" ]; then
    local cached; cached=$(< "$cache_file") 2>/dev/null || cached=""
    local orig_val="${cached%%:*}"
    local orig_time="${cached##*:}"
    orig_val=${orig_val:-0}
    orig_time=${orig_time:-0}

    local elapsed=$(( now - orig_time ))
    local live=$(( orig_val - elapsed ))
    local drift=$(( val - orig_val ))
    if [ "$drift" -lt 0 ]; then drift=$(( -drift )); fi

    if [ "$drift" -gt 120 ] || [ "$live" -le 0 ]; then
      echo "${val}:${now}" > "$cache_file" 2>/dev/null || true
      echo "$val"
    else
      echo "$live"
    fi
  else
    echo "${val}:${now}" > "$cache_file" 2>/dev/null || true
    echo "$val"
  fi
}

# Set dynamic width boundaries
# Wide bars (20/15 segments) require >= 235 columns to fit alongside full telemetry without split
if [ "$COLS" -ge 235 ]; then
  BAR_LEN=20
  QUOTA_BAR_LEN=15
else
  BAR_LEN=10
  QUOTA_BAR_LEN=8
fi

# Define Theme Colors and Icons
if [ "$USE_CLASSIC_ICONS" = "true" ]; then
  DOT_L1="${FG_GRAY} ╱ ${R}"
  DOT_L2="${FG_GRAY} · ${R}"
  ICON_READY="●"
  ICON_THINKING="◆"
  ICON_WORKING="⚙"
  ICON_TOOL="🔧"
  ICON_STATE_UNKNOWN="⏳"
  ICON_VCS="╱"
  ICON_MODEL=""
  ICON_SANDBOX_NET="ON (net)"
  ICON_SANDBOX_NONET="ON (no-net)"
  ICON_SANDBOX_OFF="OFF"
  ICON_CONTEXT_BAR="ctx"
  ICON_ARTIFACTS="artifacts"
  ICON_SUBAGENTS="subagents"
  ICON_TASKS="tasks"
  ICON_DIR="╱"
  ICON_CONV="╱"
  ICON_TOK_SUM=""
  ICON_RESET="⌛"
  ICON_AC="AC"
  ICON_BAT="BAT"
  ICON_SYS="sys"

  # Standard 16-color mappings for classic mode
  BG_READY="${FG_GREEN}"
  FG_READY_TEXT="${B}"
  BG_THINKING="${FG_YELLOW}"
  FG_THINKING_TEXT="${B}"
  BG_WORKING="${FG_CYAN}"
  FG_WORKING_TEXT="${B}"
  BG_TOOL="${FG_MAGENTA}"
  FG_TOOL_TEXT="${B}"
  BG_UNKNOWN="${FG_WHITE}"
  FG_UNKNOWN_TEXT="${B}"

  BG_GIT_CLEAN="${FG_BLUE}"
  FG_GIT_CLEAN_TEXT="${B}"
  BG_GIT_DIRTY="${FG_RED}"
  FG_GIT_DIRTY_TEXT="${B}"

  BG_MODEL="${FG_MAGENTA}"
  FG_MODEL_TEXT=""

  BG_DIR="${FG_CYAN}"
  FG_DIR_TEXT=""

  BG_META="${FG_GRAY}"
  FG_META_TEXT=""

  # Vim editor mode colors (Classic)
  case "$VIM_MODE" in
    NORMAL)
      BG_VIM="${FG_BLUE}${B}"
      ;;
    INSERT)
      BG_VIM="${FG_GREEN}${B}"
      ;;
    VISUAL|VISUAL\ LINE)
      BG_VIM="${FG_MAGENTA}${B}"
      ;;
    *)
      BG_VIM="${FG_CYAN}${B}"
      ;;
  esac
else
  DOT_L1="${FG_GRAY} | ${R}"
  DOT_L2="${FG_GRAY} | ${R}"
  ICON_READY=""
  ICON_THINKING="󰟷"
  ICON_WORKING=""
  ICON_TOOL=""
  ICON_STATE_UNKNOWN=""
  ICON_VCS=""
  ICON_MODEL=""
  ICON_SANDBOX_NET="󰒙"
  ICON_SANDBOX_NONET="󰴴"
  ICON_SANDBOX_OFF="󰦜"
  ICON_CONTEXT_BAR="󱍏"
  ICON_ARTIFACTS=""
  ICON_SUBAGENTS="󱙺"
  ICON_TASKS=""
  ICON_DIR=""
  ICON_CONV="󰍪"
  ICON_TOK_SUM=""
  ICON_RESET="⌛️"
  ICON_AC="󰚥"
  ICON_BAT="🔋"
  ICON_SYS=""

  # Premium 256-color palette mappings
  BG_READY="\033[48;5;76m"
  FG_READY_TEXT="\033[38;5;232m\033[1m"
  
  BG_THINKING="\033[48;5;214m"
  FG_THINKING_TEXT="\033[38;5;232m\033[1m"
  
  BG_WORKING="\033[48;5;37m"
  FG_WORKING_TEXT="\033[38;5;232m\033[1m"
  
  BG_TOOL="\033[48;5;135m"
  FG_TOOL_TEXT="\033[38;5;255m\033[1m"
  
  BG_UNKNOWN="\033[48;5;244m"
  FG_UNKNOWN_TEXT="\033[38;5;255m\033[1m"
  
  BG_GIT_CLEAN="\033[48;5;33m"
  FG_GIT_CLEAN_TEXT="\033[38;5;255m\033[1m"
  
  BG_GIT_DIRTY="\033[48;5;197m"
  FG_GIT_DIRTY_TEXT="\033[38;5;255m\033[1m"
  
  BG_MODEL="\033[48;5;63m"
  FG_MODEL_TEXT="\033[38;5;255m\033[1m"
  
  BG_DIR="\033[48;5;38m"
  FG_DIR_TEXT="\033[38;5;232m\033[1m"
  
  BG_META="\033[48;5;236m"
  FG_META_TEXT="\033[38;5;250m"

  # Vim editor mode colors (Styled)
  case "$VIM_MODE" in
    NORMAL)
      BG_VIM="\033[48;5;33m"
      FG_VIM="\033[38;5;255m\033[1m"
      ;;
    INSERT)
      BG_VIM="\033[48;5;76m"
      FG_VIM="\033[38;5;232m\033[1m"
      ;;
    VISUAL|VISUAL\ LINE)
      BG_VIM="\033[48;5;135m"
      FG_VIM="\033[38;5;255m\033[1m"
      ;;
    *)
      BG_VIM="\033[48;5;37m"
      FG_VIM="\033[38;5;232m\033[1m"
      ;;
  esac
fi

GIT_DIR="${CWD:-.}"
git_branch=$(run_with_timeout 1 git -C "$GIT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -n "$git_branch" ]; then
  VCS_BRANCH="$git_branch"
  VCS_TYPE="git"
  if run_with_timeout 1 git -C "$GIT_DIR" status --porcelain 2>/dev/null | grep -q .; then
    VCS_DIRTY="true"
  else
    VCS_DIRTY="false"
  fi
else
  if [ -n "$VCS_BRANCH" ]; then
    VCS_TYPE="${VCS_TYPE:-git}"
  else
    VCS_TYPE=""
    VCS_DIRTY="false"
  fi
fi

# ─── Dynamic CPU load & RAM diagnostics (Pure Bash, instant) ────────────────
MEM_PCT=""
LOAD_1M=""
if [ -f /proc/meminfo ]; then
  mem_total=0
  mem_avail=0
  while read -r name value unit; do
    if [ "$name" = "MemTotal:" ]; then
      mem_total=$value
    elif [ "$name" = "MemAvailable:" ]; then
      mem_avail=$value
      break
    fi
  done < /proc/meminfo
  if [ "$mem_total" -gt 0 ]; then
    MEM_PCT=$(( (mem_total - mem_avail) * 100 / mem_total ))
  fi
fi
if [ -f /proc/loadavg ]; then
  read -r load_1m rest < /proc/loadavg
  LOAD_1M=$load_1m
fi

# ─── Helpers for values ──────────────────────────────────────────────────────
PCT_FMT=$(LC_NUMERIC=C printf "%.1f" "$USED_PCT" 2>/dev/null || echo "0.0")
PCT_INT=${USED_PCT%.*}; PCT_INT=${PCT_INT:-0}

human_format() {
  local num=$1
  if [ -z "$num" ] || [ "$num" -eq 0 ] 2>/dev/null; then
    echo "0"
    return
  fi
  if [ "$num" -ge 999500 ] 2>/dev/null; then
    echo "$(( (num + 50000) / 1000000 )).$((( (num + 50000) % 1000000 ) / 100000 ))M"
  elif [ "$num" -ge 1000 ] 2>/dev/null; then
    echo "$(( (num + 50) / 1000 )).$((( (num + 50) % 1000 ) / 100 ))K"
  else
    echo "$num"
  fi
}

INPUT_TOK_FMT=$(human_format "$INPUT_TOKENS")
OUTPUT_TOK_FMT=$(human_format "$OUTPUT_TOKENS")
CTX_LIMIT_FMT=$(human_format "$CTX_LIMIT")
CTX_USED_FMT=$(human_format "$CTX_USED")
TURN_INPUT_FMT=$(human_format "$TURN_INPUT_TOKENS")
TURN_OUTPUT_FMT=$(human_format "$TURN_OUTPUT_TOKENS")

shorten_path() {
  local path=$1
  if [ -z "$path" ]; then
    echo ""
    return
  fi
  path="${path/#$HOME/\~}"
  if [ "${#path}" -gt 25 ]; then
    echo "...$(basename "$path")"
  else
    echo "$path"
  fi
}
CWD_SHORT=$(shorten_path "$CWD")

visible_len() {
  printf '%s' "$(echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g')" | wc -m
}

# Get Tailscale and Host Info
HOST_NAME=$(hostname 2>/dev/null || echo "")
TS_IP=$(ip -4 addr show dev tailscale0 2>/dev/null | grep -o 'inet [0-9.]*' | cut -d' ' -f2 || echo "")
HOST_INFO=""
if [ -n "$HOST_NAME" ]; then
  if [ -n "$TS_IP" ]; then
    HOST_INFO="${HOST_NAME} (${TS_IP})"
  else
    HOST_INFO="${HOST_NAME}"
  fi
fi

# ─── Power / Battery Scanner ─────────────────────────────────────────────────
POWER_FMT=""
AC_CONNECTED=0
HAS_SYS_BATTERY=0
SYS_BAT_CAP=""
POWER_DIR="${STATUSLINE_POWER_SUPPLY_DIR:-/sys/class/power_supply}"

if [ -d "$POWER_DIR" ]; then
  has_ac_adapter=0
  for d in "$POWER_DIR"/*; do
    [ -d "$d" ] || continue
    dev_name=$(basename "$d")

    # Skip peripheral devices (mice, keyboards, controllers)
    scope=$(cat "$d/scope" 2>/dev/null || echo "")
    if [ "$scope" = "Device" ] || [[ "$dev_name" =~ ^hidpp_ ]] || [[ "$dev_name" =~ mouse ]] || [[ "$dev_name" =~ keyboard ]]; then
      continue
    fi

    psy_type=$(cat "$d/type" 2>/dev/null || echo "")

    # Check for AC / Mains / USB chargers
    if [ "$psy_type" = "Mains" ] || [[ "$dev_name" =~ ^(AC|ACAD|ADP|Mains) ]]; then
      has_ac_adapter=1
      if [ -f "$d/online" ]; then
        online_val=$(cat "$d/online" 2>/dev/null || echo "0")
        if [ "$online_val" = "1" ]; then
          AC_CONNECTED=1
        fi
      fi
    elif [ "$psy_type" = "USB" ]; then
      if [[ ! "$dev_name" =~ ucsi-source ]]; then
        if [ -f "$d/online" ]; then
          online_val=$(cat "$d/online" 2>/dev/null || echo "0")
          if [ "$online_val" = "1" ]; then
            AC_CONNECTED=1
            has_ac_adapter=1
          fi
        fi
      fi
    elif [ "$psy_type" = "Battery" ] || [ "$psy_type" = "UPS" ] || [[ "$dev_name" =~ ^BAT ]]; then
      HAS_SYS_BATTERY=1
      b_status=$(cat "$d/status" 2>/dev/null || echo "")
      b_cap=$(cat "$d/capacity" 2>/dev/null || echo "")
      if [ -n "$b_cap" ] && [ -z "$SYS_BAT_CAP" ]; then
        SYS_BAT_CAP="$b_cap"
      fi
      if [ "$b_status" = "Charging" ] || [ "$b_status" = "Full" ] || [ "$b_status" = "Not charging" ]; then
        AC_CONNECTED=1
      fi
    fi
  done

  # Desktop / server without system battery and without laptop AC adapter
  if [ "$HAS_SYS_BATTERY" -eq 0 ] && [ "$has_ac_adapter" -eq 0 ]; then
    AC_CONNECTED=1
  fi
elif command -v pmset &>/dev/null; then
  pmset_out=$(pmset -g batt 2>/dev/null || echo "")
  if [ -z "$pmset_out" ] || echo "$pmset_out" | grep -q -i "No battery"; then
    AC_CONNECTED=1
    HAS_SYS_BATTERY=0
  elif echo "$pmset_out" | grep -q "AC Power"; then
    AC_CONNECTED=1
    HAS_SYS_BATTERY=1
    SYS_BAT_CAP=$(echo "$pmset_out" | grep -o "[0-9]\{1,3\}%" | tr -d "%" | head -n 1 || echo "")
  elif echo "$pmset_out" | grep -q "Battery Power"; then
    AC_CONNECTED=0
    HAS_SYS_BATTERY=1
    SYS_BAT_CAP=$(echo "$pmset_out" | grep -o "[0-9]\{1,3\}%" | tr -d "%" | head -n 1 || echo "")
  else
    AC_CONNECTED=1
  fi
fi

# ─── Segment powerline formatter ──────────────────────────────────────────────
make_segment() {
  local bg_color="$1"
  local fg_text="$2"
  local text="$3"
  local next_bg="$4"
  
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    echo -n "${bg_color}${text}${R} "
    return
  fi

  local current_bg_code="${bg_color}"
  local next_bg_code="${next_bg}"
  local fg_sep_code=$(echo -n "$current_bg_code" | sed 's/48;/38;/')
  
  if [ -n "$next_bg_code" ]; then
    echo -n "${current_bg_code}${fg_text} ${text} ${next_bg_code}${fg_sep_code}${R}"
  else
    echo -n "${current_bg_code}${fg_text} ${text} \033[0m${fg_sep_code}${R}"
  fi
}

to_ansi_color() {
  local code="$1"
  case "$code" in
    75)  echo -n "${FG_BRIGHT_BLUE}" ;;
    37)  echo -n "${FG_BRIGHT_CYAN}" ;;
    135) echo -n "${FG_BRIGHT_MAGENTA}" ;;
    76)  echo -n "${FG_BRIGHT_GREEN}" ;;
    197) echo -n "${FG_BRIGHT_RED}" ;;
    214) echo -n "${FG_BRIGHT_YELLOW}" ;;
    244) echo -n "${FG_GRAY}" ;;
    *)   echo -n "" ;;
  esac
}

# ─── Rounded Pill badge formatter ─────────────────────────────────────────────
make_badge() {
  local icon="$1"
  local val="$2"
  local icon_color="$3"
  local bg_color="236"
  
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    local ansi_c=$(to_ansi_color "$icon_color")
    if [ "$icon" = "$val" ]; then
      echo -n "${ansi_c}${val}${R}"
    else
      echo -n "${ansi_c}${icon} ${NUM_COLOR}${val}${R}"
    fi
    return
  fi

  echo -n "\033[38;5;${bg_color}m\033[48;5;${bg_color}m\033[38;5;${icon_color}m${icon} \033[38;5;255m\033[1m${val}\033[0m\033[38;5;${bg_color}m\033[0m"
}

# ─── Quota formatting ────────────────────────────────────────────────────────
format_reset_time() {
  local sec=$1
  if [ -z "$sec" ] || [ "$sec" -le 0 ]; then
    echo -n ""
    return
  fi

  local days=$((sec / 86400))
  local rem=$((sec % 86400))
  local hours=$((rem / 3600))
  rem=$((rem % 3600))
  local mins=$((rem / 60))

  if [ "$days" -gt 0 ]; then
    if [ "$hours" -gt 0 ]; then
      echo -n "${days}d ${hours}h"
    else
      echo -n "${days}d"
    fi
  elif [ "$hours" -gt 0 ]; then
    if [ "$mins" -gt 0 ]; then
      echo -n "${hours}h ${mins}m"
    else
      echo -n "${hours}h"
    fi
  elif [ "$mins" -gt 0 ]; then
    echo -n "${mins}m"
  else
    echo -n "<1m"
  fi
}

make_quota_bar() {
  local val=$1
  local label=$2
  local bar_color_num=$3
  local reset_sec=$4
  
  local reset_label=" ${ICON_RESET} "
  local separator=""
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    separator="${FG_GRAY} · ${R}"
  else
    separator=" "
  fi
  
  if [ -z "$val" ] || [[ "$val" == -* ]]; then
    local bar=""
    for ((i = 0; i < QUOTA_BAR_LEN; i++)); do
      if [ "$USE_CLASSIC_ICONS" = "true" ]; then
        bar="${bar}·"
      else
        bar="${bar}░"
      fi
    done
    echo -n "${separator}${FG_BRIGHT_WHITE}${B}${label}${R} ${FG_GRAY}${bar} N/A${R}"
    return
  fi

  local val_int=${val%.*}
  val_int=${val_int:-0}
  
  local text_color="76"
  if [ "$val_int" -lt 20 ]; then
    text_color="197"
  elif [ "$val_int" -lt 50 ]; then
    text_color="214"
  fi

  local filled=$((val_int * QUOTA_BAR_LEN / 100))
  local remainder=$(( (val_int * QUOTA_BAR_LEN) % 100 ))
  
  local bar=""
  for ((i = 0; i < QUOTA_BAR_LEN; i++)); do
    if [ "$i" -lt "$filled" ]; then
      if [ "$USE_CLASSIC_ICONS" = "true" ]; then
        bar="${bar}█"
      else
        bar="${bar}\033[38;5;${bar_color_num}m█${R}"
      fi
    elif [ "$i" -eq "$filled" ]; then
      if [ "$USE_CLASSIC_ICONS" = "true" ]; then
        if [ "$remainder" -ge 75 ]; then bar="${bar}▓"
        elif [ "$remainder" -ge 50 ]; then bar="${bar}▒"
        elif [ "$remainder" -ge 25 ]; then bar="${bar}░"
        else                               bar="${bar}·"
        fi
      else
        if [ "$remainder" -ge 75 ]; then
          bar="${bar}\033[38;5;${bar_color_num}m▓${R}${FG_GRAY}"
        elif [ "$remainder" -ge 50 ]; then
          bar="${bar}\033[38;5;${bar_color_num}m▒${R}${FG_GRAY}"
        elif [ "$remainder" -ge 25 ]; then
          bar="${bar}\033[38;5;${bar_color_num}m░${R}${FG_GRAY}"
        else
          bar="${bar}${FG_GRAY}░${R}"
        fi
      fi
    else
      if [ "$USE_CLASSIC_ICONS" = "true" ]; then
        bar="${bar}·"
      else
        bar="${bar}${FG_GRAY}░${R}"
      fi
    fi
  done

  local reset_str=""
  if [ -n "$reset_sec" ] && [ "$reset_sec" -gt 0 ]; then
    reset_str="${reset_label}$(format_reset_time "$reset_sec")"
  fi

  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    local text_ansi=$(to_ansi_color "$text_color")
    local bar_ansi=$(to_ansi_color "$bar_color_num")
    echo -n "${separator}${FG_BRIGHT_WHITE}${B}${label}${R} ${bar_ansi}${bar}${R} ${text_ansi}${val}%${R}${reset_str}"
  else
    local label_bg="236"
    local bar_bg="235"
    echo -n "${separator}\033[38;5;${label_bg}m\033[48;5;${label_bg}m\033[38;5;${text_color}m${label}\033[48;5;${bar_bg}m \033[0m${bar}\033[48;5;${label_bg}m \033[38;5;${text_color}m\033[1m${val}%\033[0m\033[38;5;${label_bg}m\033[0m${reset_str}"
  fi
}

# Determine active quota based on actual availability
IS_3P=false
case "$MODEL_ID" in
  *[Cc][Ll][Aa][Uu][Dd][Ee]*|*[Gg][Pp][Tt]*|*[Aa][Nn][Tt][Hh][Rr][Oo][Pp][Ii][Cc]*|*[Oo][Pp][Ee][Nn][Aa][Ii]*|*[Oo]1*|*[Oo]3*|*3[Pp]*)
    IS_3P=true
    ;;
esac

if [ "$IS_3P" = true ]; then
  if { [ -n "$TP_5H" ] && [ "$TP_5H" != "-1" ]; } || { [ -n "$TP_WK" ] && [ "$TP_WK" != "-1" ]; }; then
    Q_5H="$TP_5H"
    Q_WK="$TP_WK"
    Q_5H_R="$TP_5H_RESET"
    Q_WK_R="$TP_WK_RESET"
  elif { [ -n "$GEMINI_5H" ] && [ "$GEMINI_5H" != "-1" ]; } || { [ -n "$GEMINI_WK" ] && [ "$GEMINI_WK" != "-1" ]; }; then
    Q_5H="$GEMINI_5H"
    Q_WK="$GEMINI_WK"
    Q_5H_R="$GEMINI_5H_RESET"
    Q_WK_R="$GEMINI_WK_RESET"
  else
    Q_5H="-1"
    Q_WK="-1"
    Q_5H_R="-1"
    Q_WK_R="-1"
  fi
else
  if { [ -n "$GEMINI_5H" ] && [ "$GEMINI_5H" != "-1" ]; } || { [ -n "$GEMINI_WK" ] && [ "$GEMINI_WK" != "-1" ]; }; then
    Q_5H="$GEMINI_5H"
    Q_WK="$GEMINI_WK"
    Q_5H_R="$GEMINI_5H_RESET"
    Q_WK_R="$GEMINI_WK_RESET"
  elif { [ -n "$TP_5H" ] && [ "$TP_5H" != "-1" ]; } || { [ -n "$TP_WK" ] && [ "$TP_WK" != "-1" ]; }; then
    Q_5H="$TP_5H"
    Q_WK="$TP_WK"
    Q_5H_R="$TP_5H_RESET"
    Q_WK_R="$TP_WK_RESET"
  else
    Q_5H="-1"
    Q_WK="-1"
    Q_5H_R="-1"
    Q_WK_R="-1"
  fi
fi


if [ "${Q_5H_R:- -1}" -gt 0 ] 2>/dev/null; then
  Q_5H_R=$(_tick_countdown "$Q_5H_R" "/tmp/agy_quota_5h_reset")
fi
if [ "${Q_WK_R:- -1}" -gt 0 ] 2>/dev/null; then
  Q_WK_R=$(_tick_countdown "$Q_WK_R" "/tmp/agy_quota_wk_reset")
fi

QUOTA_FMT=""
if { [ -n "$Q_5H" ] && [ "$Q_5H" != "-1" ]; } || { [ -n "$Q_WK" ] && [ "$Q_WK" != "-1" ]; }; then
  QUOTA_FMT="$(make_quota_bar "$Q_5H" "5H" "37" "$Q_5H_R") $(make_quota_bar "$Q_WK" "7D" "135" "$Q_WK_R")"
fi

# Right-align printing helper
print_right_aligned() {
  local left="$1"
  local right="$2"
  local total_cols="$3"

  local left_vis right_vis pad
  left_vis=$(visible_len "$left")
  right_vis=$(visible_len "$right")

  pad=$(( total_cols - left_vis - right_vis ))
  [ "$pad" -lt 1 ] && pad=1

  printf "%b%*s%b\n" "$left" "$pad" "" "$right"
}

# ─── Context Bar Formatting ──────────────────────────────────────────────────
FILLED=$((PCT_INT * BAR_LEN / 100))
REMAINDER=$(( (PCT_INT * BAR_LEN) % 100 ))

if   [ "$PCT_INT" -ge 90 ]; then FILL_COLOR="$FG_BRIGHT_RED"
elif [ "$PCT_INT" -ge 60 ]; then FILL_COLOR="$FG_BRIGHT_YELLOW"
else                              FILL_COLOR="$FG_YELLOW"
fi

if [ "$USE_CLASSIC_ICONS" = "true" ]; then
  BAR=""
  for ((i = 0; i < BAR_LEN; i++)); do
    if   [ "$i" -lt "$FILLED" ]; then
      BAR="${BAR}█"
    elif [ "$i" -eq "$FILLED" ]; then
      if   [ "$REMAINDER" -ge 75 ]; then BAR="${BAR}▓"
      elif [ "$REMAINDER" -ge 50 ]; then BAR="${BAR}▒"
      elif [ "$REMAINDER" -ge 25 ]; then BAR="${BAR}░"
      else                               BAR="${BAR}·"
      fi
    else BAR="${BAR}·"
    fi
  done
  if [ "$CTX_LIMIT" -gt 0 ] 2>/dev/null; then
    CTX_BAR="${FG_GRAY}ctx ${FILL_COLOR}${BAR} ${NUM_COLOR}${PCT_FMT}%${R} ${FG_GRAY}(${CTX_USED_FMT}/${CTX_LIMIT_FMT})${R}"
  elif [ "$CTX_USED" -gt 0 ] 2>/dev/null; then
    CTX_BAR="${FG_GRAY}ctx ${FILL_COLOR}${BAR} ${NUM_COLOR}${PCT_FMT}%${R} ${FG_GRAY}(${CTX_USED_FMT})${R}"
  else
    CTX_BAR="${FG_GRAY}ctx ${FILL_COLOR}${BAR} ${NUM_COLOR}${PCT_FMT}%${R}"
  fi
else
  # Color palette based on context size
  if [ "$PCT_INT" -ge 90 ]; then bar_c="197"; else bar_c="214"; fi
  BAR=""
  for ((i = 0; i < BAR_LEN; i++)); do
    if   [ "$i" -lt "$FILLED" ]; then
      BAR="${BAR}\033[38;5;${bar_c}m█\033[0m"
    elif [ "$i" -eq "$FILLED" ]; then
      if   [ "$REMAINDER" -ge 75 ]; then
        BAR="${BAR}\033[38;5;${bar_c}m▓\033[0m"
      elif [ "$REMAINDER" -ge 50 ]; then
        BAR="${BAR}\033[38;5;${bar_c}m▒\033[0m"
      else
        BAR="${BAR}\033[38;5;${bar_c}m░\033[0m"
      fi
    else
      BAR="${BAR}\033[38;5;236m░\033[0m"
    fi
  done
  
  # Pill badge for Context Bar
  label_bg="236"
  bar_bg="235"
  if [ "$CTX_LIMIT" -gt 0 ] 2>/dev/null; then
    CTX_BAR="\033[38;5;${label_bg}m\033[48;5;${label_bg}m\033[38;5;220m${ICON_CONTEXT_BAR} ctx\033[48;5;${bar_bg}m ${BAR}\033[48;5;${label_bg}m \033[38;5;220m\033[1m${PCT_FMT}%\033[22m \033[38;5;250m(${CTX_USED_FMT}/${CTX_LIMIT_FMT})\033[0m\033[38;5;${label_bg}m\033[0m"
  elif [ "$CTX_USED" -gt 0 ] 2>/dev/null; then
    CTX_BAR="\033[38;5;${label_bg}m\033[48;5;${label_bg}m\033[38;5;220m${ICON_CONTEXT_BAR} ctx\033[48;5;${bar_bg}m ${BAR}\033[48;5;${label_bg}m \033[38;5;220m\033[1m${PCT_FMT}%\033[22m \033[38;5;250m(${CTX_USED_FMT})\033[0m\033[38;5;${label_bg}m\033[0m"
  else
    CTX_BAR="\033[38;5;${label_bg}m\033[48;5;${label_bg}m\033[38;5;220m${ICON_CONTEXT_BAR} ctx\033[48;5;${bar_bg}m ${BAR}\033[48;5;${label_bg}m \033[38;5;220m\033[1m${PCT_FMT}%\033[0m\033[38;5;${label_bg}m\033[0m"
  fi
fi

# ─── Statistics & Telemetry Badges ──────────────────────────────────────────
ART_FMT=$(make_badge "${ICON_ARTIFACTS}" "${ARTIFACTS}" "75")
if [ "${SUBAGENTS:-0}" -gt 0 ] 2>/dev/null; then
  SUB_FMT=$(make_badge "${ICON_SUBAGENTS}" "${SUBAGENTS}" "37")
else
  SUB_FMT=""
fi
BG_FMT=$(make_badge "${ICON_TASKS}" "${BG_TASKS}" "135")

# System Resources (RAM & Load average)
SYS_FMT=""
if [ -n "$MEM_PCT" ] && [ -n "$LOAD_1M" ]; then
  sys_color="76"
  load_int=${LOAD_1M%.*}
  load_int=${load_int:-0}
  if [ "$MEM_PCT" -ge 80 ] 2>/dev/null || [ "$load_int" -ge 8 ] 2>/dev/null; then
    sys_color="197"
  elif [ "$MEM_PCT" -ge 65 ] 2>/dev/null; then
    sys_color="214"
  fi
  SYS_FMT=$(make_badge "${ICON_SYS}" "RAM:${MEM_PCT}% | ld:${LOAD_1M}" "$sys_color")
fi

# Sandbox Badge
SB_FMT=""
if [ "$SANDBOX" = "true" ]; then
  if [ "$SANDBOX_NET" = "true" ]; then
    SB_FMT=$(make_badge "${ICON_SANDBOX_NET}" "net-on" "76")
  else
    SB_FMT=$(make_badge "${ICON_SANDBOX_NONET}" "net-off" "214")
  fi
else
  SB_FMT=$(make_badge "${ICON_SANDBOX_OFF}" "host" "244")
fi

# Power Badge
POWER_FMT=""
if [ "$AC_CONNECTED" = "1" ]; then
  POWER_FMT=$(make_badge "${ICON_AC}" "AC" "76")
elif [ "$HAS_SYS_BATTERY" = "1" ]; then
  label="BAT"
  if [ -n "$SYS_BAT_CAP" ]; then
    label="${SYS_BAT_CAP}%"
  fi
  POWER_FMT=$(make_badge "${ICON_BAT}" "$label" "214")
fi

# Token counters
TOK_DETAILS_WIDE=""
TOK_DETAILS_MED=""
if [ "$CTX_USED" -gt 0 ] 2>/dev/null; then
  turn_str=""
  if [ "$TURN_INPUT_TOKENS" -gt 0 ] || [ "$TURN_OUTPUT_TOKENS" -gt 0 ]; then
    turn_str=" | turn: +${TURN_INPUT_FMT}/${TURN_OUTPUT_FMT}"
  fi
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    TOK_DETAILS_WIDE=" (${CTX_USED_FMT}/${CTX_LIMIT_FMT})${DOT_L2}(total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turn_str})"
    TOK_DETAILS_MED=" (${CTX_USED_FMT}/${CTX_LIMIT_FMT})"
  else
    TOK_DETAILS_WIDE=" (${CTX_USED_FMT}/${CTX_LIMIT_FMT})${DOT_L2}${FG_YELLOW}${ICON_TOK_SUM} ${R} (total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turn_str})"
    TOK_DETAILS_MED=" (${CTX_USED_FMT}/${CTX_LIMIT_FMT})"
  fi
fi

MODEL_DISP="${MODEL_NAME:-$MODEL_ID}"

# ─── Dynamic LINE1 Assembly (Powerline segments) ────────────────────────────
truncate_str() {
  local str="$1"
  local max_l="$2"
  if [ "${#str}" -gt "$max_l" ] && [ "$max_l" -gt 3 ]; then
    echo "${str:0:$((max_l - 3))}..."
  else
    echo "$str"
  fi
}

calc_line1_len() {
  local is_classic="$1"
  shift
  local total=0
  if [ "$is_classic" = "true" ]; then
    for s in "$@"; do
      local l; l=$(visible_len "$s")
      total=$(( total + l + 1 ))
    done
  else
    total=2
    for s in "$@"; do
      local l; l=$(visible_len "$s")
      total=$(( total + l + 3 ))
    done
  fi
  echo "$total"
}

ACTIVE_SEGS=()
ACTIVE_BGS=()
ACTIVE_FGS=()

# 1. State
case "$STATE" in
  idle)     
    STATE_SEG="${ICON_READY} READY"
    STATE_BG="$BG_READY"
    STATE_FG="$FG_READY_TEXT"
    ;;
  thinking) 
    STATE_SEG="${ICON_THINKING} THINKING"
    STATE_BG="$BG_THINKING"
    STATE_FG="$FG_THINKING_TEXT"
    ;;
  working)  
    STATE_SEG="${ICON_WORKING} WORKING"
    STATE_BG="$BG_WORKING"
    STATE_FG="$FG_WORKING_TEXT"
    ;;
  tool_use) 
    STATE_SEG="${ICON_TOOL} TOOL"
    STATE_BG="$BG_TOOL"
    STATE_FG="$FG_TOOL_TEXT"
    ;;
  *)        
    STATE_SEG="${ICON_STATE_UNKNOWN} $(echo "$STATE" | tr '[:lower:]' '[:upper:]')"
    STATE_BG="$BG_UNKNOWN"
    STATE_FG="$FG_UNKNOWN_TEXT"
    ;;
esac
ACTIVE_SEGS+=("$STATE_SEG")
ACTIVE_BGS+=("$STATE_BG")
ACTIVE_FGS+=("$STATE_FG")

# 2. Vim Editor Mode (Issue #62)
if [ -n "$VIM_MODE" ]; then
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    VIM_SEG="[${VIM_MODE}]"
    VIM_BG="$BG_VIM"
    VIM_FG=""
  else
    VIM_SEG="${VIM_MODE}"
    VIM_BG="$BG_VIM"
    VIM_FG="$FG_VIM"
  fi
  ACTIVE_SEGS+=("$VIM_SEG")
  ACTIVE_BGS+=("$VIM_BG")
  ACTIVE_FGS+=("$VIM_FG")
fi

# Determine responsive length limits based on COLS
if [ "$COLS" -lt 70 ]; then
  max_m=12; max_b=12; max_d=10
elif [ "$COLS" -lt 85 ]; then
  max_m=16; max_b=14; max_d=12
elif [ "$COLS" -lt 100 ]; then
  max_m=20; max_b=18; max_d=14
elif [ "$COLS" -lt 130 ]; then
  max_m=26; max_b=22; max_d=16
elif [ "$COLS" -lt 180 ]; then
  max_m=34; max_b=28; max_d=20
elif [ "$COLS" -lt 235 ]; then
  max_m=46; max_b=36; max_d=24
else
  max_m=70; max_b=50; max_d=30
fi

# 3. VCS Branch
if [ -n "$VCS_BRANCH" ]; then
  b_disp=$(truncate_str "$VCS_BRANCH" "$max_b")
  [ "$VCS_DIRTY" = "true" ] && b_disp="${b_disp}*"
  ACTIVE_SEGS+=("${ICON_VCS} ${b_disp}")
  if [ "$VCS_DIRTY" = "true" ]; then
    ACTIVE_BGS+=("$BG_GIT_DIRTY")
    ACTIVE_FGS+=("$FG_GIT_DIRTY_TEXT")
  else
    ACTIVE_BGS+=("$BG_GIT_CLEAN")
    ACTIVE_FGS+=("$FG_GIT_CLEAN_TEXT")
  fi
fi

# 4. Model
if [ -n "$MODEL_DISP" ]; then
  m_disp=$(truncate_str "$MODEL_DISP" "$max_m")
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    ACTIVE_SEGS+=("${m_disp}")
  else
    ACTIVE_SEGS+=("${ICON_MODEL} ${m_disp}")
  fi
  ACTIVE_BGS+=("$BG_MODEL")
  ACTIVE_FGS+=("$FG_MODEL_TEXT")
fi

# Clamp essential segments if they exceed COLS
while [ "$(calc_line1_len "$USE_CLASSIC_ICONS" "${ACTIVE_SEGS[@]}")" -gt "$COLS" ]; do
  if [ "$max_m" -gt 8 ] && [ -n "$MODEL_DISP" ]; then
    max_m=$(( max_m - 3 ))
    m_disp=$(truncate_str "$MODEL_DISP" "$max_m")
    if [ "$USE_CLASSIC_ICONS" = "true" ]; then m_seg="${m_disp}"; else m_seg="${ICON_MODEL} ${m_disp}"; fi
    for ((idx=0; idx<${#ACTIVE_SEGS[@]}; idx++)); do
      if [[ "${ACTIVE_SEGS[idx]}" =~ ${m_disp:0:4} ]]; then
        ACTIVE_SEGS[idx]="$m_seg"
        break
      fi
    done
  elif [ "$max_b" -gt 8 ] && [ -n "$VCS_BRANCH" ]; then
    max_b=$(( max_b - 3 ))
    b_disp=$(truncate_str "$VCS_BRANCH" "$max_b")
    [ "$VCS_DIRTY" = "true" ] && b_disp="${b_disp}*"
    vcs_seg="${ICON_VCS} ${b_disp}"
    for ((idx=0; idx<${#ACTIVE_SEGS[@]}; idx++)); do
      if [[ "${ACTIVE_SEGS[idx]}" =~ ${ICON_VCS} ]]; then
        ACTIVE_SEGS[idx]="$vcs_seg"
        break
      fi
    done
  else
    break
  fi
done

# 5. Directory
if [ -n "$CWD_SHORT" ]; then
  d_disp=$(truncate_str "$CWD_SHORT" "$max_d")
  d_seg="${ICON_DIR} ${d_disp}"
  if [ "$(calc_line1_len "$USE_CLASSIC_ICONS" "${ACTIVE_SEGS[@]}" "$d_seg")" -le "$COLS" ]; then
    ACTIVE_SEGS+=("$d_seg")
    ACTIVE_BGS+=("$BG_DIR")
    ACTIVE_FGS+=("$FG_DIR_TEXT")
  fi
fi

# 6. Conversation
if [ -n "$CONV_ID" ] && [ "$COLS" -ge 80 ]; then
  conv_seg="${ICON_CONV} ${CONV_ID:0:8}"
  if [ "$(calc_line1_len "$USE_CLASSIC_ICONS" "${ACTIVE_SEGS[@]}" "$conv_seg")" -le "$COLS" ]; then
    ACTIVE_SEGS+=("$conv_seg")
    ACTIVE_BGS+=("$BG_META")
    ACTIVE_FGS+=("$FG_META_TEXT")
  fi
fi

# 7. User Plan & Account
if { [ -n "$PLAN_TIER" ] || [ -n "$USER_EMAIL" ]; } && [ "$COLS" -ge 130 ]; then
  u_label="${PLAN_TIER}"
  if [ -n "$USER_EMAIL" ]; then
    if [ -n "$u_label" ]; then
      u_label="${u_label} (${USER_EMAIL})"
    else
      u_label="${USER_EMAIL}"
    fi
  fi
  u_label=$(truncate_str "$u_label" 25)
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    u_seg="${u_label}"
  else
    u_seg="👤 ${u_label}"
  fi
  if [ "$(calc_line1_len "$USE_CLASSIC_ICONS" "${ACTIVE_SEGS[@]}" "$u_seg")" -le "$COLS" ]; then
    ACTIVE_SEGS+=("$u_seg")
    ACTIVE_BGS+=("$BG_META")
    ACTIVE_FGS+=("$FG_META_TEXT")
  fi
fi

# 8. Host IP
if [ -n "$HOST_INFO" ] && [ "$COLS" -ge 110 ]; then
  host_label=$(truncate_str "$HOST_INFO" 20)
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    host_seg="${host_label}"
  else
    host_seg="󰒋 ${host_label}"
  fi
  if [ "$(calc_line1_len "$USE_CLASSIC_ICONS" "${ACTIVE_SEGS[@]}" "$host_seg")" -le "$COLS" ]; then
    ACTIVE_SEGS+=("$host_seg")
    ACTIVE_BGS+=("$BG_META")
    ACTIVE_FGS+=("$FG_META_TEXT")
  fi
fi

# 9. Version
if [ -n "$CLI_VERSION" ] && [ "$COLS" -ge 120 ]; then
  ver_label=$(truncate_str "v${CLI_VERSION}" 10)
  if [ "$(calc_line1_len "$USE_CLASSIC_ICONS" "${ACTIVE_SEGS[@]}" "$ver_label")" -le "$COLS" ]; then
    ACTIVE_SEGS+=("$ver_label")
    ACTIVE_BGS+=("$BG_META")
    ACTIVE_FGS+=("$FG_META_TEXT")
  fi
fi

# Safeguard: pop from end if still exceeds
while [ "${#ACTIVE_SEGS[@]}" -gt 1 ] && [ "$(calc_line1_len "$USE_CLASSIC_ICONS" "${ACTIVE_SEGS[@]}")" -gt "$COLS" ]; do
  last_idx=$(( ${#ACTIVE_SEGS[@]} - 1 ))
  unset "ACTIVE_SEGS[last_idx]"
  unset "ACTIVE_BGS[last_idx]"
  unset "ACTIVE_FGS[last_idx]"
  ACTIVE_SEGS=("${ACTIVE_SEGS[@]}")
  ACTIVE_BGS=("${ACTIVE_BGS[@]}")
  ACTIVE_FGS=("${ACTIVE_FGS[@]}")
done

# Assemble LINE1 with powerline transitions
LINE1=""
num_segs=${#ACTIVE_SEGS[@]}
for ((i = 0; i < num_segs; i++)); do
  next_bg=""
  if [ "$((i + 1))" -lt "$num_segs" ]; then
    next_bg="${ACTIVE_BGS[i+1]}"
  fi
  LINE1="${LINE1}$(make_segment "${ACTIVE_BGS[i]}" "${ACTIVE_FGS[i]}" "${ACTIVE_SEGS[i]}" "$next_bg")"
done

# ─── Smart Dynamic Line-Packing Engine ───────────────────────────────────────
# Collect all active telemetry badges into an ordered array
BADGE_LIST=()

# 1. Context Usage Bar
[ -n "$CTX_BAR" ] && BADGE_LIST+=("$CTX_BAR")

# 2. Token Details Badge
if [ "$CTX_USED" -gt 0 ] 2>/dev/null; then
  turn_str=""
  if [ "$TURN_INPUT_TOKENS" -gt 0 ] || [ "$TURN_OUTPUT_TOKENS" -gt 0 ]; then
    turn_str=" | turn: +${TURN_INPUT_FMT}/${TURN_OUTPUT_FMT}"
  fi
  if [ "$USE_CLASSIC_ICONS" = "true" ]; then
    BADGE_LIST+=("(total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turn_str})")
  else
    BADGE_LIST+=("$(make_badge "${ICON_TOK_SUM}" "total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turn_str}" "220")")
  fi
fi

# 3. System Resources (RAM & Load)
[ -n "$SYS_FMT" ] && BADGE_LIST+=("$SYS_FMT")

# 4. Artifacts Counter
[ -n "$ART_FMT" ] && BADGE_LIST+=("$ART_FMT")

# 5. Subagents Counter
[ -n "$SUB_FMT" ] && BADGE_LIST+=("$SUB_FMT")

# 6. Background Tasks Counter
[ -n "$BG_FMT" ] && BADGE_LIST+=("$BG_FMT")

# 7. Sandbox Status
[ -n "$SB_FMT" ] && BADGE_LIST+=("$SB_FMT")

# 8. Quotas
if { [ -n "$Q_5H" ] && [ "$Q_5H" != "-1" ]; }; then
  BADGE_LIST+=("$(make_quota_bar "$Q_5H" "5H" "37" "$Q_5H_R")")
fi
if { [ -n "$Q_WK" ] && [ "$Q_WK" != "-1" ]; }; then
  BADGE_LIST+=("$(make_quota_bar "$Q_WK" "7D" "135" "$Q_WK_R")")
fi

# 9. Power Status
[ -n "$POWER_FMT" ] && BADGE_LIST+=("$POWER_FMT")

# Greedy Line-Packing Routine
PACKED_LINES=()
curr_line=""
# Classic mode lacks box-drawing borders (╭─, ├─, ╰─), so it uses full terminal width
if [ "$USE_CLASSIC_ICONS" = "true" ]; then
  max_vis=$(( COLS - 1 ))
else
  max_vis=$(( COLS - 4 ))
fi
if [ "$max_vis" -lt 40 ]; then max_vis=40; fi

for badge in "${BADGE_LIST[@]}"; do
  [ -z "$badge" ] && continue
  b_vis=$(visible_len "$badge")
  
  if [ -z "$curr_line" ]; then
    curr_line="$badge"
    curr_vis=$b_vis
  elif [ $(( curr_vis + 2 + b_vis )) -le "$max_vis" ]; then
    curr_line="${curr_line}  ${badge}"
    curr_vis=$(( curr_vis + 2 + b_vis ))
  else
    PACKED_LINES+=("$curr_line")
    curr_line="$badge"
    curr_vis=$b_vis
  fi
done
[ -n "$curr_line" ] && PACKED_LINES+=("$curr_line")

# Output rendering with dynamic box borders
if [ "$USE_CLASSIC_ICONS" = "true" ]; then
  echo -e "${LINE1}"
  for pline in "${PACKED_LINES[@]}"; do
    echo -e "${pline}"
  done
else
  echo -e "${FG_GRAY}╭─${R}${LINE1}"
  total_packed=${#PACKED_LINES[@]}
  for ((i = 0; i < total_packed; i++)); do
    if [ "$((i + 1))" -eq "$total_packed" ]; then
      echo -e "${FG_GRAY}╰─${R}${PACKED_LINES[i]}"
    else
      echo -e "${FG_GRAY}├─${R}${PACKED_LINES[i]}"
    fi
  done
fi
