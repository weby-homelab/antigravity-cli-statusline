# Disable progress bar to speed up web requests or execution if any
$ProgressPreference = 'SilentlyContinue'

# Set Output Encoding to UTF-8 to support nerd font icons on Windows
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Read JSON input from stdin
$inputJson = $input | Out-String
if (-not $inputJson -or $inputJson.Trim().Length -eq 0) {
    # If no stdin, output nothing and exit
    exit
}

# Parse JSON safely
try {
    $data = ConvertFrom-Json $inputJson
} catch {
    exit
}

# Extract properties with fallbacks
$STATE = if ($data.agent_state) { $data.agent_state } else { "idle" }
$USED_PCT = if ($data.context_window.used_percentage -ne $null) { $data.context_window.used_percentage } else { 0 }
$VCS_BRANCH = if ($data.vcs.branch) { $data.vcs.branch } else { "" }
$VCS_DIRTY = if ($data.vcs.dirty -ne $null) { $data.vcs.dirty } else { $false }
$VCS_TYPE = if ($data.vcs.type) { $data.vcs.type } else { "" }
$SANDBOX = if ($data.sandbox.enabled -ne $null) { $data.sandbox.enabled } else { $false }
$SANDBOX_NET = if ($data.sandbox.allow_network -ne $null) { $data.sandbox.allow_network } else { $false }
$ARTIFACTS = if ($data.artifact_count -ne $null) { $data.artifact_count } else { 0 }
$SUBAGENTS = if ($data.subagents -and $data.subagents.GetType().IsArray) { $data.subagents.Length } else { 0 }
$BG_TASKS = if ($data.task_count -ne $null) { $data.task_count } else { 0 }
$MODEL_ID = if ($data.model.id) { $data.model.id } else { "" }
$MODEL_NAME = if ($data.model.display_name) { $data.model.display_name } else { "" }
$COLS = if ($data.terminal_width -ne $null) { $data.terminal_width } else { 80 }
$CWD = if ($data.cwd) { $data.cwd } else { "" }
$CONV_ID = if ($data.conversation_id) { $data.conversation_id } else { "" }

$INPUT_TOKENS = if ($data.context_window.total_input_tokens -ne $null) { $data.context_window.total_input_tokens } else { 0 }
$OUTPUT_TOKENS = if ($data.context_window.total_output_tokens -ne $null) { $data.context_window.total_output_tokens } else { 0 }
$CTX_LIMIT = if ($data.context_window.context_window_size -ne $null) { $data.context_window.context_window_size } else { 0 }
$CTX_USED = $INPUT_TOKENS + $OUTPUT_TOKENS
$REM_PCT = if ($data.context_window.remaining_percentage -ne $null) { $data.context_window.remaining_percentage } else { 100 }

# Quotas
$GEMINI_5H = if ($data.quota.'gemini-5h'.remaining_fraction -ne $null) { [Math]::Round($data.quota.'gemini-5h'.remaining_fraction * 100, 1) } else { -1 }
$GEMINI_WK = if ($data.quota.'gemini-weekly'.remaining_fraction -ne $null) { [Math]::Round($data.quota.'gemini-weekly'.remaining_fraction * 100, 1) } else { -1 }
$TP_5H = if ($data.quota.'3p-5h'.remaining_fraction -ne $null) { [Math]::Round($data.quota.'3p-5h'.remaining_fraction * 100, 1) } else { -1 }
$TP_WK = if ($data.quota.'3p-weekly'.remaining_fraction -ne $null) { [Math]::Round($data.quota.'3p-weekly'.remaining_fraction * 100, 1) } else { -1 }

$GEMINI_5H_RESET = if ($data.quota.'gemini-5h'.reset_in_seconds -ne $null) { $data.quota.'gemini-5h'.reset_in_seconds } else { -1 }
$GEMINI_WK_RESET = if ($data.quota.'gemini-weekly'.reset_in_seconds -ne $null) { $data.quota.'gemini-weekly'.reset_in_seconds } else { -1 }
$TP_5H_RESET = if ($data.quota.'3p-5h'.reset_in_seconds -ne $null) { $data.quota.'3p-5h'.reset_in_seconds } else { -1 }
$TP_WK_RESET = if ($data.quota.'3p-weekly'.reset_in_seconds -ne $null) { $data.quota.'3p-weekly'.reset_in_seconds } else { -1 }

# ANSI Helpers
$ESC = [char]27
$R = "$ESC[0m"
$B = "$ESC[1m"
$D = "$ESC[2m"
$I = "$ESC[3m"

$FG_BLACK = "$ESC[30m"
$FG_RED = "$ESC[31m"
$FG_GREEN = "$ESC[32m"
$FG_YELLOW = "$ESC[33m"
$FG_BLUE = "$ESC[34m"
$FG_MAGENTA = "$ESC[35m"
$FG_CYAN = "$ESC[36m"
$FG_WHITE = "$ESC[37m"

$FG_GRAY = "$ESC[90m"
$FG_BRIGHT_RED = "$ESC[91m"
$FG_BRIGHT_GREEN = "$ESC[92m"
$FG_BRIGHT_YELLOW = "$ESC[93m"
$FG_BRIGHT_BLUE = "$ESC[94m"
$FG_BRIGHT_MAGENTA = "$ESC[95m"
$FG_BRIGHT_CYAN = "$ESC[96m"
$FG_BRIGHT_WHITE = "$ESC[97m"

$NUM_COLOR = "${FG_BRIGHT_WHITE}${B}"
$DOT = "${FG_GRAY} | ${R}"

# VCS directly from git (Bypasses JSON caches)
$GIT_DIR = if ($CWD) { $CWD } else { "." }
if (Test-Path "$GIT_DIR") {
    $gitBranch = git -C "$GIT_DIR" rev-parse --abbrev-ref HEAD 2>$null
    if ($gitBranch) {
        $VCS_BRANCH = $gitBranch.Trim()
        $VCS_TYPE = "git"
        $status = git -C "$GIT_DIR" status --porcelain 2>$null
        if ($status) {
            $VCS_DIRTY = $true
        } else {
            $VCS_DIRTY = $false
        }
    }
}

# Format percentages
$PCT_FMT = $USED_PCT.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture)
$PCT_INT = [int][Math]::Floor($USED_PCT)

# Formatting helpers
function human_format($num) {
    if ($num -eq $null -or $num -eq 0) { return "0" }
    if ($num -ge 1000000) {
        $val = [Math]::Round($num / 1000000, 1)
        return $val.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture) + "M"
    }
    if ($num -ge 1000) {
        $val = [Math]::Round($num / 1000, 1)
        return $val.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture) + "K"
    }
    return $num.ToString()
}

$INPUT_TOK_FMT = human_format $INPUT_TOKENS
$OUTPUT_TOK_FMT = human_format $OUTPUT_TOKENS
$CTX_LIMIT_FMT = human_format $CTX_LIMIT
$CTX_USED_FMT = human_format $CTX_USED

function shorten_path($path) {
    if (-not $path) { return "" }
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
    if ($homeDir -and $path.StartsWith($homeDir)) {
        $path = "~" + $path.Substring($homeDir.Length)
    }
    if ($path.Length -gt 25) {
        return "..." + (Split-Path $path -Leaf)
    }
    return $path
}
$CWD_SHORT = shorten_path $CWD

function visible_len($str) {
    # Strips ESC sequences and counts visible length
    $stripped = $str -replace '\x1b\[[0-9;]*m', ''
    return $stripped.Length
}

# State Indicator
$S = ""
switch ($STATE) {
    "idle"     { $S = "${FG_BRIGHT_GREEN}${B}  READY${R}" }
    "thinking" { $S = "${FG_BRIGHT_YELLOW}${B} 󰟷 THINKING${R}" }
    "working"  { $S = "${FG_BRIGHT_CYAN}${B}  WORKING${R}" }
    "tool_use" { $S = "${FG_BRIGHT_MAGENTA}${B}  TOOL${R}" }
    default    { $S = "${FG_WHITE}${B}  $($STATE.ToUpper())${R}" }
}

# VCS branch details
$V = ""
if ($VCS_BRANCH) {
    if ($VCS_DIRTY -eq $true) {
        $V = "${DOT}${R}${FG_BRIGHT_RED} ${VCS_BRANCH}${FG_BRIGHT_YELLOW}*${R}"
    } else {
        $V = "${DOT}${R}${FG_BRIGHT_BLUE} ${VCS_BRANCH}${R}"
    }
}

# Model details
$disp = if ($MODEL_NAME) { $MODEL_NAME } else { $MODEL_ID }
$M = ""
if ($disp) {
    $M = "${FG_GRAY}${DOT}${FG_BRIGHT_MAGENTA}${I} ${disp}${R}"
}

# Sandbox Badge
$SB = ""
if ($SANDBOX -eq $true) {
    if ($SANDBOX_NET -eq $true) {
        $SB = "${FG_GREEN}󰒙 ${FG_BRIGHT_GREEN}${B}ON (net)${R}"
    } else {
        $SB = "${FG_GREEN}󰴴 ${FG_BRIGHT_GREEN}${B}ON (no-net)${R}"
    }
} else {
    $SB = "${FG_RED}󰦜 ${FG_BRIGHT_RED}${B}OFF${R}"
}

# Context bar
$BAR_LEN = 20
$FILLED = [int][Math]::Floor(($PCT_INT * $BAR_LEN) / 100)
$REMAINDER = ($PCT_INT * $BAR_LEN) % 100

$FILL_COLOR = $FG_YELLOW
if ($PCT_INT -ge 90) { $FILL_COLOR = $FG_BRIGHT_RED }
elseif ($PCT_INT -ge 60) { $FILL_COLOR = $FG_BRIGHT_YELLOW }

$BAR = ""
for ($i = 0; $i -lt $BAR_LEN; $i++) {
    if ($i -lt $FILLED) {
        $BAR += "${FILL_COLOR}█${R}"
    } elseif ($i -eq $FILLED) {
        if ($REMAINDER -ge 75) { $BAR += "${FILL_COLOR}▓${R}${FG_GRAY}" }
        elseif ($REMAINDER -ge 50) { $BAR += "${FILL_COLOR}▒${R}${FG_GRAY}" }
        else { $BAR += "${FILL_COLOR}░${R}${FG_GRAY}" }
    } else {
        $BAR += "${FG_GRAY}░${R}"
    }
}
$CTX_BAR = "${FG_YELLOW}󱍏  ${R}${BAR} ${NUM_COLOR}${PCT_FMT}%${R}"

# Stats badges
$ART_FMT = "${FG_BLUE} ${NUM_COLOR}${ARTIFACTS}${R}"
$SUB_FMT = "${FG_CYAN}󱙺 ${NUM_COLOR}${SUBAGENTS}${R}"
$BG_FMT = "${FG_MAGENTA} ${NUM_COLOR}${BG_TASKS}${R}"

$DIR_FMT = ""
if ($CWD_SHORT) {
    $DIR_FMT = "${FG_GRAY}${DOT}${FG_CYAN} ${R}${CWD_SHORT}${R}"
}

$CONV_FMT = ""
if ($CONV_ID) {
    $short_conv = $CONV_ID.Substring(0, [Math]::Min(8, $CONV_ID.Length))
    $CONV_FMT = "${FG_GRAY}${DOT}${FG_GRAY}󰍪 ${short_conv}${R}"
}

$TOK_DETAILS = ""
if ($CTX_USED -gt 0) {
    $TOK_DETAILS = " (${CTX_USED_FMT}/${CTX_LIMIT_FMT})"
}

# Quota bars
function format_reset_time($sec) {
    if ($sec -eq $null -or $sec -le 0) { return "" }
    $days = [int][Math]::Floor($sec / 86400)
    $rem = $sec % 86400
    $hours = [int][Math]::Floor($rem / 3600)
    $rem = $rem % 3600
    $mins = [int][Math]::Floor($rem / 60)

    if ($days -gt 0) {
        if ($hours -gt 0) { return "${days}d ${hours}h" }
        return "${days}d"
    }
    if ($hours -gt 0) {
        if ($mins -gt 0) { return "${hours}h ${mins}m" }
        return "${hours}h"
    }
    if ($mins -gt 0) { return "${mins}m" }
    return "<1m"
}

function make_quota_bar($val, $label, $bar_color, $reset_sec) {
    if ($val -eq $null -or $val -lt 0) {
        $bar = "░" * 20
        return "${FG_GRAY}| ${R}${FG_BRIGHT_WHITE}${B}${label}${R} ${FG_GRAY}${bar} N/A${R}"
    }

    $val_int = [int][Math]::Floor($val)
    $text_color = $FG_BRIGHT_GREEN
    if ($val_int -lt 20) { $text_color = $FG_BRIGHT_RED }
    elseif ($val_int -lt 50) { $text_color = $FG_BRIGHT_YELLOW }

    $bar_len = 20
    $filled = [int][Math]::Floor(($val_int * $bar_len) / 100)
    $remainder = ($val_int * $bar_len) % 100

    $bar = ""
    for ($i = 0; $i -lt $bar_len; $i++) {
        if ($i -lt $filled) {
            $bar += "${bar_color}█${R}"
        } elseif ($i -eq $filled) {
            if ($remainder -ge 75) { $bar += "${bar_color}▓${R}${FG_GRAY}" }
            elseif ($remainder -ge 50) { $bar += "${bar_color}▒${R}${FG_GRAY}" }
            elseif ($remainder -ge 25) { $bar += "${bar_color}░${R}${FG_GRAY}" }
            else { $bar += "${FG_GRAY}░${R}" }
        } else {
            $bar += "${FG_GRAY}░${R}"
        }
    }

    $reset_str = ""
    $t = format_reset_time $reset_sec
    if ($t) { $reset_str = " ⌛️ $t" }

    $val_fmt = $val.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture)
    return "${FG_GRAY}| ${R}${FG_BRIGHT_WHITE}${B}${label}${R} ${bar} ${text_color}${val_fmt}%${R}${reset_str}"
}

$model_lower = $MODEL_ID.ToLower()
if ($MODEL_NAME) { $model_lower = $MODEL_NAME.ToLower() }

if ($model_lower.Contains("gemini")) {
    $Q_5H = $GEMINI_5H
    $Q_WK = $GEMINI_WK
    $Q_5H_R = $GEMINI_5H_RESET
    $Q_WK_R = $GEMINI_WK_RESET
} else {
    $Q_5H = $TP_5H
    $Q_WK = $TP_WK
    $Q_5H_R = $TP_5H_RESET
    $Q_WK_R = $TP_WK_RESET
}

$QUOTA_FMT = ""
if ($Q_5H -ne -1 -or $Q_WK -ne -1) {
    $QUOTA_FMT = "$((make_quota_bar $Q_5H "5H" $FG_BRIGHT_CYAN $Q_5H_R)) $((make_quota_bar $Q_WK "7D" $FG_BRIGHT_MAGENTA $Q_WK_R))"
}

# Right-align helper
function print_right_aligned($left, $right, $total_cols) {
    $left_vis = visible_len $left
    $right_vis = visible_len $right
    $pad = $total_cols - $left_vis - $right_vis
    if ($pad -lt 1) { $pad = 1 }
    $spaces = " " * $pad
    return "${left}${spaces}${right}"
}

# Output Assembly based on Column Width
if ($COLS -ge 180) {
    $LINE1 = "${S}${M}${DIR_FMT}${V}${CONV_FMT}"
    if ($CTX_USED -gt 0) {
        $TOK_DETAILS = " (${CTX_USED_FMT}/${CTX_LIMIT_FMT})${DOT}${FG_YELLOW} ${R} (${INPUT_TOK_FMT} in/${OUTPUT_TOK_FMT} out)"
    }
    $LINE2 = "${ART_FMT}${DOT}${SUB_FMT}${DOT}${BG_FMT}${DOT}${SB}${DOT}${CTX_BAR}${TOK_DETAILS}${DOT}${QUOTA_FMT}"
    print_right_aligned $LINE1 $LINE2 $COLS
} elseif ($COLS -ge 90) {
    $LINE1 = "${S}${M}${DIR_FMT}${V}"
    $LINE2 = " ${CTX_BAR}${TOK_DETAILS}${DOT}${ART_FMT}${DOT}${SUB_FMT}${DOT}${BG_FMT}${DOT}${SB}${DOT}${QUOTA_FMT}"
    "${FG_GRAY}╭─${R}${LINE1}`n${FG_GRAY}╰─${R}${LINE2}"
} else {
    $M_SHORT = ""
    if ($disp) {
        $M_SHORT = "${FG_GRAY} ╱ ${FG_BRIGHT_MAGENTA} ${disp}${R}"
    }
    "${S}${M_SHORT}`n${CTX_BAR}${DOT}${BG_FMT}${DOT}${QUOTA_FMT}"
}
