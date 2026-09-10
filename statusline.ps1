# Disable progress bar to speed up web requests or execution if any
$ProgressPreference = 'SilentlyContinue'

# Set Output Encoding to UTF-8 to support nerd font icons on Windows
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Check for CLI flags before reading stdin
foreach ($arg in $args) {
    $a = if ($arg) { $arg.ToString().ToLower() } else { "" }
    if ($a -in @("--version", "-version", "-v", "version")) {
        Write-Host "Antigravity CLI Statusline v0.2.4" -ForegroundColor Green
        exit
    }
    if ($a -in @("--legend", "-legend", "-l", "legend")) {
        Write-Host "🚀 Antigravity CLI Statusline Legend (v0.2.4)" -ForegroundColor Green
        Write-Host "This statusline adapts dynamically to your terminal width and theme settings.`n"
        
        Write-Host "LAYOUTS:" -ForegroundColor White
        Write-Host "  - Wide Layout (>= 180 chars): Single-row, full developer telemetry dashboard."
        Write-Host "  - Medium Layout (>= 90 chars): Two-line boxed block to prevent line wrap."
        Write-Host "  - Small Layout (< 90 chars): Minimalist indicator for status, model, context & tasks.`n"
        
        Write-Host "COMPONENTS & ICONS:" -ForegroundColor White
        Write-Host "  Field                Nerd Font   Classic     Description" -ForegroundColor White
        Write-Host "  --------------------------------------------------------------------------------"
        
        Write-Host "  State: READY         " -NoNewline; Write-Host "           " -ForegroundColor Green -NoNewline; Write-Host "●           " -ForegroundColor Green -NoNewline; Write-Host "Agent is idle, ready for user requests."
        Write-Host "  State: THINKING      " -NoNewline; Write-Host "󰟷           " -ForegroundColor Yellow -NoNewline; Write-Host "◆           " -ForegroundColor Yellow -NoNewline; Write-Host "Agent is processing/thinking."
        Write-Host "  State: WORKING       " -NoNewline; Write-Host "           " -ForegroundColor Cyan -NoNewline; Write-Host "⚙           " -ForegroundColor Cyan -NoNewline; Write-Host "Agent is executing background operations."
        Write-Host "  State: TOOL          " -NoNewline; Write-Host "           " -ForegroundColor Magenta -NoNewline; Write-Host "🔧          " -ForegroundColor Magenta -NoNewline; Write-Host "Agent is running a tool."
        Write-Host "  State: UNKNOWN       " -NoNewline; Write-Host "           " -ForegroundColor White -NoNewline; Write-Host "⏳          " -ForegroundColor White -NoNewline; Write-Host "Agent state is unknown or initializing."
        Write-Host "  Vim Mode             " -NoNewline; Write-Host "           " -ForegroundColor Blue -NoNewline; Write-Host "[MODE]      " -ForegroundColor Blue -NoNewline; Write-Host "Current Vim editor mode (NORMAL, INSERT, VISUAL)."
        Write-Host "  VCS Branch           " -NoNewline; Write-Host "           " -ForegroundColor Blue -NoNewline; Write-Host "/           " -ForegroundColor Gray -NoNewline; Write-Host "Current Git branch name (Red + * if dirty)."
        Write-Host "  Model                " -NoNewline; Write-Host "           " -ForegroundColor Magenta -NoNewline; Write-Host "(None)      " -ForegroundColor DarkGray -NoNewline; Write-Host "Current active LLM model name/ID."
        Write-Host "  Sandbox Network      " -NoNewline; Write-Host "󰒙           " -ForegroundColor Green -NoNewline; Write-Host "ON (net)    " -ForegroundColor Green -NoNewline; Write-Host "Sandbox enabled with internet access."
        Write-Host "  Sandbox Restricted   " -NoNewline; Write-Host "󰴴           " -ForegroundColor Green -NoNewline; Write-Host "ON (no-net) " -ForegroundColor Green -NoNewline; Write-Host "Sandbox enabled with network disabled."
        Write-Host "  Sandbox Off          " -NoNewline; Write-Host "󰦜           " -ForegroundColor Red -NoNewline; Write-Host "sandbox off " -ForegroundColor Gray -NoNewline; Write-Host "Sandbox is disabled (runs on host)."
        Write-Host "  Context Bar          " -NoNewline; Write-Host "󱍏           " -ForegroundColor Yellow -NoNewline; Write-Host "ctx         " -ForegroundColor Gray -NoNewline; Write-Host "Context window usage bar (10 or 20 segments)."
        Write-Host "  Artifacts            " -NoNewline; Write-Host "           " -ForegroundColor Blue -NoNewline; Write-Host "artifacts   " -ForegroundColor Gray -NoNewline; Write-Host "Number of active output artifacts."
        Write-Host "  Subagents            " -NoNewline; Write-Host "󱙺           " -ForegroundColor Cyan -NoNewline; Write-Host "subagents   " -ForegroundColor Gray -NoNewline; Write-Host "Number of spawned active subagents."
        Write-Host "  Background Tasks     " -NoNewline; Write-Host "           " -ForegroundColor Magenta -NoNewline; Write-Host "tasks       " -ForegroundColor Gray -NoNewline; Write-Host "Number of background tasks running."
        Write-Host "  Current Directory    " -NoNewline; Write-Host "           " -ForegroundColor Cyan -NoNewline; Write-Host "/           " -ForegroundColor Gray -NoNewline; Write-Host "Current working directory path (shortened)."
        Write-Host "  Conversation ID      " -NoNewline; Write-Host "󰍪           " -ForegroundColor Gray -NoNewline; Write-Host "/           " -ForegroundColor Gray -NoNewline; Write-Host "Short prefix of the current session ID."
        Write-Host "  Tokens Sum           " -NoNewline; Write-Host "           " -ForegroundColor Yellow -NoNewline; Write-Host "(None)      " -ForegroundColor DarkGray -NoNewline; Write-Host "Total input/output tokens parsed."
        Write-Host "  Quota Reset Time     " -NoNewline; Write-Host "⌛️          " -ForegroundColor Gray -NoNewline; Write-Host "⌛          " -ForegroundColor Gray -NoNewline; Write-Host "Remaining time until LLM quota resets."
        Write-Host "  Power Mains (AC)     " -NoNewline; Write-Host "󰚥           " -ForegroundColor Green -NoNewline; Write-Host "AC          " -ForegroundColor Green -NoNewline; Write-Host "Host is connected to external AC power."
        Write-Host "  Power Battery (UPS)  " -NoNewline; Write-Host "🔋           " -ForegroundColor Yellow -NoNewline; Write-Host "BAT         " -ForegroundColor Yellow -NoNewline; Write-Host "Host is running on battery (shows charge %)."
        
        Write-Host "`nTIPS:" -ForegroundColor White
        Write-Host "  To toggle Classic Icon mode, use the -classic or --classic option in settings.json configuration."
        exit
    }
}

# Read JSON input from stdin with timeout protection (prevents hanging on blocked pipe)
$inputJson = ""
try {
    if ([Console]::IsInputRedirected) {
        $task = [System.Threading.Tasks.Task]::Run([System.Func[string]]{ [Console]::In.ReadToEnd() })
        if ($task.Wait(250)) {
            $inputJson = $task.Result
        }
    } else {
        $inputJson = $input | Out-String
    }
} catch {
    $inputJson = ""
}
if (-not $inputJson -or $inputJson.Trim().Length -eq 0) {
    # If no stdin or read timed out, output nothing and exit
    exit
}

# Parse JSON safely
try {
    $data = ConvertFrom-Json $inputJson
} catch {
    exit
}

# Helper functions for input hardening & safe type parsing
function Sanitize-String($str) {
    if (-not $str) { return "" }
    $clean = $str.ToString() -replace '\x1b\[[0-9;?]*[a-zA-Z]', '' -replace '\x1b\([a-zA-Z]', '' -replace '\x1b', ''
    $clean = $clean -replace '[\x00-\x1f\x7f]', ''
    return $clean.Trim()
}

function Safe-Int($val, $default = 0) {
    if ($val -eq $null) { return $default }
    $res = 0
    if ([int]::TryParse($val.ToString(), [ref]$res)) { return $res }
    return $default
}

function Safe-Int64($val, $default = 0) {
    if ($val -eq $null) { return $default }
    $res = [int64]0
    if ([int64]::TryParse($val.ToString(), [ref]$res)) { return $res }
    return $default
}

function Safe-Double($val, $default = 0.0) {
    if ($val -eq $null) { return $default }
    $res = [double]0.0
    if ([double]::TryParse($val.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$res)) { return $res }
    return $default
}

# Extract properties with fallbacks & input hardening
$STATE = if ($data.agent_state) { Sanitize-String $data.agent_state } else { "idle" }
$USED_PCT = if ($data.context_window.used_percentage -ne $null) { Safe-Double $data.context_window.used_percentage 0.0 } else { 0.0 }
$VCS_BRANCH = if ($data.vcs.branch) { Sanitize-String $data.vcs.branch } else { "" }
$VCS_DIRTY = if ($data.vcs.dirty -ne $null) { [bool]$data.vcs.dirty } else { $false }
$VCS_TYPE = if ($data.vcs.type) { Sanitize-String $data.vcs.type } else { "" }
$SANDBOX = if ($data.sandbox.enabled -ne $null) { [bool]$data.sandbox.enabled } else { $false }
$SANDBOX_NET = if ($data.sandbox.allow_network -ne $null) { [bool]$data.sandbox.allow_network } else { $false }
$ARTIFACTS = if ($data.artifact_count -ne $null) { Safe-Int $data.artifact_count 0 } else { 0 }
$SUBAGENTS = if ($data.subagents -and $data.subagents.GetType().IsArray) { $data.subagents.Length } else { 0 }
$BG_TASKS = if ($data.task_count -ne $null) { Safe-Int $data.task_count 0 } else { 0 }
$MODEL_ID = if ($data.model.id) { Sanitize-String $data.model.id } else { "" }
$MODEL_NAME = if ($data.model.display_name) { Sanitize-String $data.model.display_name } else { "" }
$COLS = if ($data.terminal_width -ne $null) { Safe-Int $data.terminal_width 80 } else { 80 }
if ($COLS -le 0) { $COLS = 80 }
$CWD = if ($data.cwd) { Sanitize-String $data.cwd } else { "" }
$CONV_ID = if ($data.conversation_id) { Sanitize-String $data.conversation_id } else { "" }
$CLI_VERSION = if ($data.version) { Sanitize-String $data.version } else { "" }
$PLAN_TIER = if ($data.plan_tier) { Sanitize-String $data.plan_tier } else { "" }
$USER_EMAIL = if ($data.email) { Sanitize-String $data.email } else { "" }
$TURN_INPUT_TOKENS = if ($data.context_window.current_usage.input_tokens -ne $null) { Safe-Int64 $data.context_window.current_usage.input_tokens 0 } else { 0 }
$TURN_OUTPUT_TOKENS = if ($data.context_window.current_usage.output_tokens -ne $null) { Safe-Int64 $data.context_window.current_usage.output_tokens 0 } else { 0 }

# Vim Mode (#62)
$VIM_MODE = if ($data.vim -and $data.vim.mode) { Sanitize-String $data.vim.mode } else { $null }

# Context tokens calculation (Section 5)
$INPUT_TOKENS = if ($data.context_window.total_input_tokens -ne $null) { Safe-Int64 $data.context_window.total_input_tokens 0 } else { 0 }
$OUTPUT_TOKENS = if ($data.context_window.total_output_tokens -ne $null) { Safe-Int64 $data.context_window.total_output_tokens 0 } else { 0 }
$CTX_LIMIT = if ($data.context_window.context_window_size -ne $null) { Safe-Int64 $data.context_window.context_window_size 0 } else { 0 }

$RAW_TOTAL = if ($data.context_window.total_tokens -ne $null) { Safe-Int64 $data.context_window.total_tokens 0 } else { 0 }
if ($RAW_TOTAL -gt 0) {
    $CTX_USED = $RAW_TOTAL
} else {
    $CTX_USED = $INPUT_TOKENS + $OUTPUT_TOKENS
}

if ($USED_PCT -eq 0 -and $CTX_LIMIT -gt 0 -and $CTX_USED -gt 0) {
    $USED_PCT = [Math]::Round(($CTX_USED / $CTX_LIMIT) * 100, 1)
}
if (($CTX_LIMIT -eq 0 -or $CTX_LIMIT -eq $null) -and $CTX_USED -gt 0 -and $USED_PCT -gt 0) {
    $CTX_LIMIT = [int64][Math]::Floor($CTX_USED * 100 / $USED_PCT)
}
$REM_PCT = if ($data.context_window.remaining_percentage -ne $null) { Safe-Double $data.context_window.remaining_percentage 100.0 } else { 100.0 }

# Quotas
$hasQuota = ($null -ne $data.quota)
$GEMINI_5H = if ($hasQuota -and $null -ne $data.quota.'gemini-5h' -and $null -ne $data.quota.'gemini-5h'.remaining_fraction) {
    $rf = Safe-Double $data.quota.'gemini-5h'.remaining_fraction -1.0
    if ($rf -ge 0.0) { [Math]::Round($rf * 100, 1) } else { -1 }
} else { -1 }

$GEMINI_WK = if ($hasQuota -and $null -ne $data.quota.'gemini-weekly' -and $null -ne $data.quota.'gemini-weekly'.remaining_fraction) {
    $rf = Safe-Double $data.quota.'gemini-weekly'.remaining_fraction -1.0
    if ($rf -ge 0.0) { [Math]::Round($rf * 100, 1) } else { -1 }
} else { -1 }

$TP_5H = if ($hasQuota -and $null -ne $data.quota.'3p-5h' -and $null -ne $data.quota.'3p-5h'.remaining_fraction) {
    $rf = Safe-Double $data.quota.'3p-5h'.remaining_fraction -1.0
    if ($rf -ge 0.0) { [Math]::Round($rf * 100, 1) } else { -1 }
} else { -1 }

$TP_WK = if ($hasQuota -and $null -ne $data.quota.'3p-weekly' -and $null -ne $data.quota.'3p-weekly'.remaining_fraction) {
    $rf = Safe-Double $data.quota.'3p-weekly'.remaining_fraction -1.0
    if ($rf -ge 0.0) { [Math]::Round($rf * 100, 1) } else { -1 }
} else { -1 }

$GEMINI_5H_RESET = if ($hasQuota -and $null -ne $data.quota.'gemini-5h' -and $null -ne $data.quota.'gemini-5h'.reset_in_seconds) { Safe-Int $data.quota.'gemini-5h'.reset_in_seconds -1 } else { -1 }
$GEMINI_WK_RESET = if ($hasQuota -and $null -ne $data.quota.'gemini-weekly' -and $null -ne $data.quota.'gemini-weekly'.reset_in_seconds) { Safe-Int $data.quota.'gemini-weekly'.reset_in_seconds -1 } else { -1 }
$TP_5H_RESET = if ($hasQuota -and $null -ne $data.quota.'3p-5h' -and $null -ne $data.quota.'3p-5h'.reset_in_seconds) { Safe-Int $data.quota.'3p-5h'.reset_in_seconds -1 } else { -1 }
$TP_WK_RESET = if ($hasQuota -and $null -ne $data.quota.'3p-weekly' -and $null -ne $data.quota.'3p-weekly'.reset_in_seconds) { Safe-Int $data.quota.'3p-weekly'.reset_in_seconds -1 } else { -1 }

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

# Timeout Process Helper (reads streams asynchronously to prevent pipe deadlocks)
function Run-WithTimeout {
    param(
        [string]$Command,
        [string[]]$Arguments,
        [int]$TimeoutMs = 1000
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command
    $psi.Arguments = $Arguments -join " "
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi

    try {
        if ($proc.Start()) {
            $outTask = $proc.StandardOutput.ReadToEndAsync()
            $errTask = $proc.StandardError.ReadToEndAsync()
            if ($proc.WaitForExit($TimeoutMs)) {
                [System.Threading.Tasks.Task]::WaitAll(@($outTask, $errTask), 200) | Out-Null
                return $outTask.Result
            } else {
                try { $proc.Kill() } catch {}
            }
        }
    } catch {}
    return $null
}

# VCS directly from git (Bypasses JSON caches)
$GIT_DIR = if ($CWD) { $CWD } else { "." }
if (Test-Path "$GIT_DIR") {
    $gitBranch = Run-WithTimeout -Command "git" -Arguments @("-C", "`"$GIT_DIR`"", "rev-parse", "--abbrev-ref", "HEAD")
    if ($gitBranch) {
        $VCS_BRANCH = $gitBranch.Trim()
        $VCS_TYPE = "git"
        $status = Run-WithTimeout -Command "git" -Arguments @("-C", "`"$GIT_DIR`"", "status", "--porcelain")
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
    $d = [double]$num
    if ($d -ge 1000000.0) {
        $val = [Math]::Round($d / 1000000.0, 1)
        return $val.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture) + "M"
    }
    if ($d -ge 1000.0) {
        $val = [Math]::Round($d / 1000.0, 1)
        return $val.ToString("0.0", [System.Globalization.CultureInfo]::InvariantCulture) + "K"
    }
    return $num.ToString()
}

$INPUT_TOK_FMT = human_format $INPUT_TOKENS
$OUTPUT_TOK_FMT = human_format $OUTPUT_TOKENS
$CTX_LIMIT_FMT = human_format $CTX_LIMIT
$CTX_USED_FMT = human_format $CTX_USED
$TURN_INPUT_FMT = human_format $TURN_INPUT_TOKENS
$TURN_OUTPUT_FMT = human_format $TURN_OUTPUT_TOKENS

function shorten_path($path) {
    if (-not $path) { return "" }
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
    if ($homeDir -and $path.StartsWith($homeDir)) {
        $path = "~" + $path.Substring($homeDir.Length)
    }
    $leaf = Split-Path $path -Leaf
    if (-not $leaf) { $leaf = $path }
    if ($leaf.Length -gt 18) {
        $leaf = $leaf.Substring(0, 15) + "..."
    }
    if ($path.Length -gt 25) {
        return "..." + $leaf
    }
    return $path
}
$CWD_SHORT = shorten_path $CWD

# ─── Parse CLI Arguments & Theme ─────────────────────────────────────────────
$USE_CLASSIC_ICONS = $false
foreach ($arg in $args) {
    $a = if ($arg) { $arg.ToString().ToLower() } else { "" }
    if ($a -in @("--classic", "-classic", "-c", "classic", "--no-nerdfont", "-no-nerdfont", "--compatibility", "-compatibility")) {
        $USE_CLASSIC_ICONS = $true
    }
}

if ($USE_CLASSIC_ICONS) {
    $DOT_L1 = "${FG_GRAY} ╱ ${R}"
    $DOT_L2 = "${FG_GRAY} · ${R}"
    $ICON_READY = "●"
    $ICON_THINKING = "◆"
    $ICON_WORKING = "⚙"
    $ICON_TOOL = "🔧"
    $ICON_STATE_UNKNOWN = "⏳"
    $ICON_VCS = "╱"
    $ICON_MODEL = ""
    $ICON_SANDBOX_NET = "ON (net)"
    $ICON_SANDBOX_NONET = "ON (no-net)"
    $ICON_SANDBOX_OFF = "OFF"
    $ICON_CONTEXT_BAR = "ctx"
    $ICON_ARTIFACTS = "artifacts"
    $ICON_SUBAGENTS = "subagents"
    $ICON_TASKS = "tasks"
    $ICON_DIR = "╱"
    $ICON_CONV = "╱"
    $ICON_TOK_SUM = ""
    $ICON_RESET = "⌛"
    $ICON_AC = "AC"
    $ICON_BAT = "BAT"
} else {
    $DOT_L1 = "${FG_GRAY} | ${R}"
    $DOT_L2 = "${FG_GRAY} | ${R}"
    $ICON_READY = ""
    $ICON_THINKING = "󰟷"
    $ICON_WORKING = ""
    $ICON_TOOL = ""
    $ICON_STATE_UNKNOWN = ""
    $ICON_VCS = ""
    $ICON_MODEL = ""
    $ICON_SANDBOX_NET = "󰒙"
    $ICON_SANDBOX_NONET = "󰴴"
    $ICON_SANDBOX_OFF = "󰦜"
    $ICON_CONTEXT_BAR = "󱍏"
    $ICON_ARTIFACTS = ""
    $ICON_SUBAGENTS = "󱙺"
    $ICON_TASKS = ""
    $ICON_DIR = ""
    $ICON_CONV = "󰍪"
    $ICON_TOK_SUM = ""
    $ICON_RESET = "⌛️"
    $ICON_AC = "󰚥"
    $ICON_BAT = "🔋"
}

function visible_len($str) {
    if (-not $str) { return 0 }
    $stripped = $str -replace '\x1b\[[0-9;?]*[a-zA-Z]', '' -replace '\x1b\([a-zA-Z]', '' -replace '\x1b', ''
    return $stripped.Length
}

function to_ansi_color($code) {
    switch ($code) {
        "220" { return $FG_YELLOW }
        "75"  { return $FG_BRIGHT_CYAN }
        "37"  { return $FG_CYAN }
        "135" { return $FG_MAGENTA }
        "76"  { return $FG_GREEN }
        "197" { return $FG_RED }
        "214" { return $FG_BRIGHT_YELLOW }
        "244" { return $FG_GRAY }
        default { return "" }
    }
}

function make_badge($icon, $val, $icon_color) {
    $bg_color = "236"
    if ($USE_CLASSIC_ICONS) {
        $ansi_c = to_ansi_color $icon_color
        if ($icon -eq $val) {
            return "${ansi_c}${val}${R}"
        } else {
            return "${ansi_c}${icon} ${NUM_COLOR}${val}${R}"
        }
    } else {
        return "$ESC[38;5;${bg_color}m$ESC[48;5;${bg_color}m$ESC[38;5;${icon_color}m${icon} $ESC[38;5;255m${B}${val}${R}$ESC[38;5;${bg_color}m${R}"
    }
}

# Version (>= 120 cols)
$CLI_VER_FMT = ""
if ($CLI_VERSION -and $COLS -ge 120) {
    $ver = $CLI_VERSION
    if ($ver.Length -gt 16) { $ver = $ver.Substring(0, 13) + "..." }
    $CLI_VER_FMT = "${DOT_L1}${FG_GRAY}v${ver}${R}"
}

# User Plan & Account (>= 130 cols)
$USER_FMT = ""
if (($PLAN_TIER -or $USER_EMAIL) -and $COLS -ge 130) {
    $userInfo = ""
    if ($PLAN_TIER -and $USER_EMAIL) {
        $userInfo = "${PLAN_TIER} (${USER_EMAIL})"
    } elseif ($PLAN_TIER) {
        $userInfo = $PLAN_TIER
    } else {
        $userInfo = $USER_EMAIL
    }
    if ($userInfo.Length -gt 25) {
        $userInfo = $userInfo.Substring(0, 22) + "..."
    }
    if ($USE_CLASSIC_ICONS) {
        $USER_FMT = "${DOT_L1}${FG_GRAY}${userInfo}${R}"
    } else {
        $USER_FMT = "${DOT_L1}${FG_GRAY}󰇮 ${userInfo}${R}"
    }
}

# Hostname and Tailscale IP (>= 110 cols)
$HOST_NAME = ""
try { $HOST_NAME = [System.Net.Dns]::GetHostName() } catch {}
$TS_IP = ""
try {
    if (Get-Command tailscale -ErrorAction SilentlyContinue) {
        $tsStatus = tailscale ip -4 2>$null
        if ($tsStatus) { $TS_IP = $tsStatus.Trim() }
    }
} catch {}

$HOST_FMT = ""
if ($HOST_NAME -and $COLS -ge 110) {
    $hostDetails = $HOST_NAME
    if ($TS_IP) {
        $hostDetails = "${HOST_NAME} (${TS_IP})"
    }
    if ($hostDetails.Length -gt 25) {
        $hostDetails = $hostDetails.Substring(0, 22) + "..."
    }
    if ($USE_CLASSIC_ICONS) {
        $HOST_FMT = "${DOT_L1}${FG_BRIGHT_BLUE}${hostDetails}${R}"
    } else {
        $HOST_FMT = "${DOT_L1}${FG_BRIGHT_BLUE}󰒋 ${hostDetails}${R}"
    }
}

# Power Status
$POWER_FMT = ""
try {
    $ac_online = $null
    $bat_cap = $null
    $has_battery = $false

    # 1. Primary: .NET SystemInformation PowerStatus (Works in Windows PowerShell 5.1 & Core on Windows)
    try {
        if (-not ([System.Management.Automation.PSTypeName]'System.Windows.Forms.SystemInformation').Type) {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        }
        if (([System.Management.Automation.PSTypeName]'System.Windows.Forms.SystemInformation').Type) {
            $pStatus = [System.Windows.Forms.SystemInformation]::PowerStatus
            if ($pStatus) {
                $lineStatus = $pStatus.PowerLineStatus.ToString()
                if ($lineStatus -eq "Online") {
                    $ac_online = $true
                } elseif ($lineStatus -eq "Offline") {
                    $ac_online = $false
                }
                $chargeStatus = $pStatus.BatteryChargeStatus
                if (-not $chargeStatus.HasFlag([System.Windows.Forms.BatteryChargeStatus]::NoSystemBattery)) {
                    $has_battery = $true
                    $pct = [int][Math]::Round($pStatus.BatteryLifePercent * 100)
                    if ($pct -ge 0 -and $pct -le 100) {
                        $bat_cap = $pct
                    }
                }
            }
        }
    } catch {}

    # 2. Secondary fallback: root/wmi:BatteryStatus (AC line online check)
    if ($ac_online -eq $null) {
        try {
            $wmiBat = Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue
            if ($wmiBat) {
                $firstBat = if ($wmiBat -is [array]) { $wmiBat[0] } else { $wmiBat }
                if ($firstBat.PowerOnline -ne $null) {
                    $ac_online = [bool]$firstBat.PowerOnline
                    $has_battery = $true
                }
            }
        } catch {}
    }

    # 3. Tertiary fallback: Win32_Battery
    if ($ac_online -eq $null) {
        try {
            $win32Bat = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
            if ($win32Bat) {
                $has_battery = $true
                $bObj = if ($win32Bat -is [array]) { $win32Bat[0] } else { $win32Bat }
                $st = [int]$bObj.BatteryStatus
                if ($bObj.EstimatedChargeRemaining -ne $null) {
                    $bat_cap = [int]$bObj.EstimatedChargeRemaining
                }
                # 3=Fully Charged, 6,7,8,9=Charging -> AC Online
                if ($st -in 3, 6, 7, 8, 9) {
                    $ac_online = $true
                } elseif ($st -in 1, 2, 4, 5) {
                    $ac_online = $false
                }
            }
        } catch {}
    }

    # Desktop PC without battery
    if ($ac_online -eq $null -and -not $has_battery) {
        $ac_online = $true
    }

    if ($ac_online -eq $true) {
        $POWER_FMT = (make_badge $ICON_AC "AC" "76")
    } elseif ($has_battery -or $ac_online -eq $false) {
        $lbl = if ($bat_cap -ne $null -and $bat_cap -ge 0) { "${bat_cap}%" } else { "BAT" }
        $POWER_FMT = (make_badge $ICON_BAT $lbl "214")
    }
} catch {}

# State Indicator
$S = ""
switch ($STATE) {
    "idle"     { $S = "${FG_BRIGHT_GREEN}${B} ${ICON_READY} READY${R}" }
    "thinking" { $S = "${FG_BRIGHT_YELLOW}${B} ${ICON_THINKING} THINKING${R}" }
    "working"  { $S = "${FG_BRIGHT_CYAN}${B} ${ICON_WORKING} WORKING${R}" }
    "tool_use" { $S = "${FG_BRIGHT_MAGENTA}${B} ${ICON_TOOL} TOOL${R}" }
    default    { $S = "${FG_WHITE}${B} ${ICON_STATE_UNKNOWN} $($STATE.ToUpper())${R}" }
}

# Vim Mode (#62)
$VIM_FMT = ""
if ($VIM_MODE) {
    $vim_mode_upper = $VIM_MODE.ToUpper()
    $vim_color = $FG_BRIGHT_CYAN
    switch -Wildcard ($vim_mode_upper) {
        "NORMAL"        { $vim_color = $FG_BRIGHT_BLUE }
        "INSERT"        { $vim_color = $FG_BRIGHT_GREEN }
        "VISUAL*"       { $vim_color = $FG_BRIGHT_MAGENTA }
        default         { $vim_color = $FG_BRIGHT_CYAN }
    }
    if ($USE_CLASSIC_ICONS) {
        $VIM_FMT = "${DOT_L1}${vim_color}[${VIM_MODE}]${R}"
    } else {
        $VIM_FMT = "${DOT_L1}${vim_color}${B}[${VIM_MODE}]${R}"
    }
}

# VCS Branch details
$V = ""
if ($VCS_BRANCH) {
    $max_b = if ($COLS -lt 90) { 16 } elseif ($COLS -lt 120) { 24 } else { 35 }
    $b_name = $VCS_BRANCH
    if ($b_name.Length -gt $max_b) {
        $b_name = $b_name.Substring(0, $max_b - 3) + "..."
    }
    if ($VCS_DIRTY -eq $true) {
        if ($USE_CLASSIC_ICONS) {
            $V = "${DOT_L1}${FG_BRIGHT_RED}${b_name}${FG_BRIGHT_YELLOW}*${R}"
        } else {
            $V = "${DOT_L1}${R}${FG_BRIGHT_RED}${ICON_VCS} ${b_name}${FG_BRIGHT_YELLOW}*${R}"
        }
    } else {
        if ($USE_CLASSIC_ICONS) {
            $V = "${DOT_L1}${FG_BRIGHT_BLUE}${b_name}${R}"
        } else {
            $V = "${DOT_L1}${R}${FG_BRIGHT_BLUE}${ICON_VCS} ${b_name}${R}"
        }
    }
}

# Model details
$disp = if ($MODEL_NAME) { $MODEL_NAME } else { $MODEL_ID }
$M = ""
if ($disp) {
    $max_m = if ($COLS -lt 90) { 16 } elseif ($COLS -lt 120) { 24 } else { 35 }
    if ($disp.Length -gt $max_m) {
        $disp = $disp.Substring(0, $max_m - 3) + "..."
    }
    if ($USE_CLASSIC_ICONS) {
        $M = "${DOT_L1}${FG_BRIGHT_MAGENTA}${I}${disp}${R}"
    } else {
        $M = "${DOT_L1}${FG_BRIGHT_MAGENTA}${I}${ICON_MODEL} ${disp}${R}"
    }
}

# Sandbox Badge
$SB = ""
if ($SANDBOX -eq $true) {
    if ($SANDBOX_NET -eq $true) {
        $SB = "${FG_GREEN}${ICON_SANDBOX_NET} ON (net)${R}"
    } else {
        $SB = "${FG_GREEN}${ICON_SANDBOX_NONET} ON (no-net)${R}"
    }
} else {
    if ($USE_CLASSIC_ICONS) {
        $SB = "${FG_GRAY}sandbox off${R}"
    } else {
        $SB = "${FG_RED}${ICON_SANDBOX_OFF} OFF${R}"
    }
}

# Context bar (wide bar requires >= 235 cols)
$BAR_LEN = if ($COLS -ge 235) { 20 } else { 10 }
$FILLED = [int][Math]::Floor(($PCT_INT * $BAR_LEN) / 100)
$REMAINDER = ($PCT_INT * $BAR_LEN) % 100

$FILL_COLOR = $FG_YELLOW
if ($PCT_INT -ge 90) { $FILL_COLOR = $FG_BRIGHT_RED }
elseif ($PCT_INT -ge 60) { $FILL_COLOR = $FG_BRIGHT_YELLOW }

if ($USE_CLASSIC_ICONS) {
    $BAR = ""
    for ($i = 0; $i -lt $BAR_LEN; $i++) {
        if ($i -lt $FILLED) {
            $BAR += "█"
        } elseif ($i -eq $FILLED) {
            if ($REMAINDER -ge 75) { $BAR += "▓" }
            elseif ($REMAINDER -ge 50) { $BAR += "▒" }
            elseif ($REMAINDER -ge 25) { $BAR += "░" }
            else { $BAR += "·" }
        } else {
            $BAR += "·"
        }
    }
    if ($CTX_LIMIT -gt 0) {
        $CTX_BAR = "${FG_GRAY}ctx ${FILL_COLOR}${BAR} ${NUM_COLOR}${PCT_FMT}%${R} ${FG_GRAY}(${CTX_USED_FMT}/${CTX_LIMIT_FMT})${R}"
    } elseif ($CTX_USED -gt 0) {
        $CTX_BAR = "${FG_GRAY}ctx ${FILL_COLOR}${BAR} ${NUM_COLOR}${PCT_FMT}%${R} ${FG_GRAY}(${CTX_USED_FMT})${R}"
    } else {
        $CTX_BAR = "${FG_GRAY}ctx ${FILL_COLOR}${BAR} ${NUM_COLOR}${PCT_FMT}%${R}"
    }
} else {
    $label_bg = "236"
    $bar_bg = "235"
    if ($PCT_INT -ge 90) { $bar_c = "197" } else { $bar_c = "214" }
    $BAR = ""
    for ($i = 0; $i -lt $BAR_LEN; $i++) {
        if ($i -lt $FILLED) {
            $BAR += "$ESC[38;5;${bar_c}m█$ESC[0m"
        } elseif ($i -eq $FILLED) {
            if ($REMAINDER -ge 75) { $BAR += "$ESC[38;5;${bar_c}m▓$ESC[0m" }
            elseif ($REMAINDER -ge 50) { $BAR += "$ESC[38;5;${bar_c}m▒$ESC[0m" }
            else { $BAR += "$ESC[38;5;${bar_c}m░$ESC[0m" }
        } else {
            $BAR += "$ESC[38;5;236m░$ESC[0m"
        }
    }
    if ($CTX_LIMIT -gt 0) {
        $CTX_BAR = "$ESC[38;5;${label_bg}m$ESC[48;5;${label_bg}m$ESC[38;5;220m${ICON_CONTEXT_BAR} ctx$ESC[48;5;${bar_bg}m ${BAR}$ESC[48;5;${label_bg}m $ESC[38;5;220m$ESC[1m${PCT_FMT}%$ESC[22m $ESC[38;5;250m(${CTX_USED_FMT}/${CTX_LIMIT_FMT})$ESC[0m$ESC[38;5;${label_bg}m$ESC[0m"
    } elseif ($CTX_USED -gt 0) {
        $CTX_BAR = "$ESC[38;5;${label_bg}m$ESC[48;5;${label_bg}m$ESC[38;5;220m${ICON_CONTEXT_BAR} ctx$ESC[48;5;${bar_bg}m ${BAR}$ESC[48;5;${label_bg}m $ESC[38;5;220m$ESC[1m${PCT_FMT}%$ESC[22m $ESC[38;5;250m(${CTX_USED_FMT})$ESC[0m$ESC[38;5;${label_bg}m$ESC[0m"
    } else {
        $CTX_BAR = "$ESC[38;5;${label_bg}m$ESC[48;5;${label_bg}m$ESC[38;5;220m${ICON_CONTEXT_BAR} ctx$ESC[48;5;${bar_bg}m ${BAR}$ESC[48;5;${label_bg}m $ESC[38;5;220m$ESC[1m${PCT_FMT}%$ESC[0m$ESC[38;5;${label_bg}m$ESC[0m"
    }
}

# Stats badges
if ($USE_CLASSIC_ICONS) {
    $ART_FMT = "${FG_GRAY}artifacts ${NUM_COLOR}${ARTIFACTS}${R}"
    $SUB_FMT = "${FG_GRAY}subagents ${NUM_COLOR}${SUBAGENTS}${R}"
    $BG_FMT = "${FG_GRAY}tasks ${NUM_COLOR}${BG_TASKS}${R}"
} else {
    $ART_FMT = (make_badge $ICON_ARTIFACTS $ARTIFACTS "75")
    $SUB_FMT = (make_badge $ICON_SUBAGENTS $SUBAGENTS "37")
    $BG_FMT = (make_badge $ICON_TASKS $BG_TASKS "135")
}

$DIR_FMT = ""
if ($CWD_SHORT) {
    if ($USE_CLASSIC_ICONS) {
        $DIR_FMT = "${DOT_L1}${FG_CYAN}${CWD_SHORT}${R}"
    } else {
        $DIR_FMT = "${DOT_L1}${FG_CYAN}${ICON_DIR} ${CWD_SHORT}${R}"
    }
}

$CONV_FMT = ""
if ($CONV_ID -and $COLS -ge 80) {
    $short_conv = $CONV_ID.Substring(0, [Math]::Min(8, $CONV_ID.Length))
    if ($USE_CLASSIC_ICONS) {
        $CONV_FMT = "${DOT_L1}${FG_GRAY}${short_conv}${R}"
    } else {
        $CONV_FMT = "${DOT_L1}${FG_GRAY}${ICON_CONV} ${short_conv}${R}"
    }
}

$TOK_DETAILS_WIDE = ""
$TOK_DETAILS_MED = ""
if ($CTX_USED -gt 0) {
    $turnStr = ""
    if (($TURN_INPUT_TOKENS -gt 0 -or $TURN_OUTPUT_TOKENS -gt 0) -and $COLS -ge 100) {
        $turnStr = " | turn: +${TURN_INPUT_FMT}/${TURN_OUTPUT_FMT}"
    }
    if ($USE_CLASSIC_ICONS) {
        $TOK_DETAILS_WIDE = " (${CTX_USED_FMT}/${CTX_LIMIT_FMT})${DOT_L2}(total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turnStr})"
        $TOK_DETAILS_MED = " (${CTX_USED_FMT}/${CTX_LIMIT_FMT})"
    } else {
        $TOK_DETAILS_WIDE = " (${CTX_USED_FMT}/${CTX_LIMIT_FMT})${DOT_L2}${FG_YELLOW}${ICON_TOK_SUM} ${R} (total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turnStr})"
        $TOK_DETAILS_MED = " (${CTX_USED_FMT}/${CTX_LIMIT_FMT})"
    }
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
    $reset_label = " ${ICON_RESET} "
    $separator = if ($USE_CLASSIC_ICONS) { "${FG_GRAY} · ${R}" } else { "${FG_GRAY}| ${R}" }

    if ($val -eq $null -or $val -lt 0) {
        $bar = ""
        for ($i = 0; $i -lt 20; $i++) {
            if ($USE_CLASSIC_ICONS) { $bar += "·" } else { $bar += "░" }
        }
        return "${separator}${FG_BRIGHT_WHITE}${B}${label}${R} ${FG_GRAY}${bar} N/A${R}"
    }

    $val_int = [int][Math]::Floor($val)
    $text_color = $FG_BRIGHT_GREEN
    if ($val_int -lt 20) { $text_color = $FG_BRIGHT_RED }
    elseif ($val_int -lt 50) { $text_color = $FG_BRIGHT_YELLOW }

    $bar_len = if ($COLS -ge 235) { 15 } else { 8 }
    $filled = [int][Math]::Floor(($val_int * $bar_len) / 100)
    $remainder = ($val_int * $bar_len) % 100

    $bar = ""
    for ($i = 0; $i -lt $bar_len; $i++) {
        if ($i -lt $filled) {
            if ($USE_CLASSIC_ICONS) {
                $bar += "█"
            } else {
                $bar += "${bar_color}█${R}"
            }
        } elseif ($i -eq $filled) {
            if ($USE_CLASSIC_ICONS) {
                if ($remainder -ge 75) { $bar += "▓" }
                elseif ($remainder -ge 50) { $bar += "▒" }
                elseif ($remainder -ge 25) { $bar += "░" }
                else { $bar += "·" }
            } else {
                if ($remainder -ge 75) { $bar += "${bar_color}▓${R}${FG_GRAY}" }
                elseif ($remainder -ge 50) { $bar += "${bar_color}▒${R}${FG_GRAY}" }
                elseif ($remainder -ge 25) { $bar += "${bar_color}░${R}${FG_GRAY}" }
                else { $bar += "${FG_GRAY}░${R}" }
            }
        } else {
            if ($USE_CLASSIC_ICONS) {
                $bar += "·"
            } else {
                $bar += "${FG_GRAY}░${R}"
            }
        }
    }

    $reset_str = ""
    $t = format_reset_time $reset_sec
    if ($t) { $reset_str = "${reset_label}${t}" }

    $val_fmt = [int][Math]::Round($val)
    if ($USE_CLASSIC_ICONS) {
        return "${separator}${FG_BRIGHT_WHITE}${B}${label}${R} ${bar_color}${bar}${R} ${text_color}${val_fmt}%${R}${reset_str}"
    } else {
        return "${separator}${FG_BRIGHT_WHITE}${B}${label}${R} ${bar} ${text_color}${val_fmt}%${R}${reset_str}"
    }
}

# Determine active quota based on model-aware prioritization
$is3P = $false
$modelToCheck = "$MODEL_ID $MODEL_NAME"
if ($modelToCheck -match '(?i)(claude|gpt|anthropic|openai|\bo1\b|\bo3\b|3p)') {
    $is3P = $true
}

if ($is3P) {
    if (($TP_5H -ne $null -and $TP_5H -ne -1) -or ($TP_WK -ne $null -and $TP_WK -ne -1)) {
        $Q_5H = $TP_5H
        $Q_WK = $TP_WK
        $Q_5H_R = $TP_5H_RESET
        $Q_WK_R = $TP_WK_RESET
    } elseif (($GEMINI_5H -ne $null -and $GEMINI_5H -ne -1) -or ($GEMINI_WK -ne $null -and $GEMINI_WK -ne -1)) {
        $Q_5H = $GEMINI_5H
        $Q_WK = $GEMINI_WK
        $Q_5H_R = $GEMINI_5H_RESET
        $Q_WK_R = $GEMINI_WK_RESET
    } else {
        $Q_5H = -1
        $Q_WK = -1
        $Q_5H_R = -1
        $Q_WK_R = -1
    }
} else {
    if (($GEMINI_5H -ne $null -and $GEMINI_5H -ne -1) -or ($GEMINI_WK -ne $null -and $GEMINI_WK -ne -1)) {
        $Q_5H = $GEMINI_5H
        $Q_WK = $GEMINI_WK
        $Q_5H_R = $GEMINI_5H_RESET
        $Q_WK_R = $GEMINI_WK_RESET
    } elseif (($TP_5H -ne $null -and $TP_5H -ne -1) -or ($TP_WK -ne $null -and $TP_WK -ne -1)) {
        $Q_5H = $TP_5H
        $Q_WK = $TP_WK
        $Q_5H_R = $TP_5H_RESET
        $Q_WK_R = $TP_WK_RESET
    } else {
        $Q_5H = -1
        $Q_WK = -1
        $Q_5H_R = -1
        $Q_WK_R = -1
    }
}

$QUOTA_FMT = ""
if (($Q_5H -ne $null -and $Q_5H -ne -1) -or ($Q_WK -ne $null -and $Q_WK -ne -1)) {
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

# Smart Dynamic Line-Packing Engine
$LINE1 = "$S$VIM_FMT$V$M$DIR_FMT$CONV_FMT$HOST_FMT$USER_FMT$CLI_VER_FMT"

# Responsive layout protection: ensure LINE1 never wraps on widths 60-255
$max_l1 = if ($USE_CLASSIC_ICONS) { $COLS - 1 } else { $COLS - 3 }
if ((visible_len $LINE1) -gt $max_l1) {
    $LINE1 = "$S$VIM_FMT$V$M$DIR_FMT$CONV_FMT$HOST_FMT$CLI_VER_FMT"
}
if ((visible_len $LINE1) -gt $max_l1) {
    $LINE1 = "$S$VIM_FMT$V$M$DIR_FMT$CONV_FMT$HOST_FMT"
}
if ((visible_len $LINE1) -gt $max_l1) {
    $LINE1 = "$S$VIM_FMT$V$M$DIR_FMT$CONV_FMT"
}
if ((visible_len $LINE1) -gt $max_l1) {
    $LINE1 = "$S$VIM_FMT$V$M$DIR_FMT"
}
if ((visible_len $LINE1) -gt $max_l1) {
    $LINE1 = "$S$VIM_FMT$V$M"
}
if ((visible_len $LINE1) -gt $max_l1) {
    $LINE1 = "$S$VIM_FMT$V"
}
if ((visible_len $LINE1) -gt $max_l1) {
    $LINE1 = "$S$VIM_FMT"
}
if ((visible_len $LINE1) -gt $max_l1) {
    $LINE1 = "$S"
}

$BADGE_LIST = @()
if ($CTX_BAR) { $BADGE_LIST += $CTX_BAR }
if ($CTX_USED -gt 0) {
    $turn_str = ""
    if (($TURN_INPUT_TOKENS -gt 0 -or $TURN_OUTPUT_TOKENS -gt 0) -and $COLS -ge 100) {
        $turn_str = " | turn: +${TURN_INPUT_FMT}/${TURN_OUTPUT_FMT}"
    }
    if ($USE_CLASSIC_ICONS) {
        $BADGE_LIST += "(total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turn_str})"
    } else {
        $BADGE_LIST += (make_badge $ICON_TOK_SUM "total: ${INPUT_TOK_FMT}/${OUTPUT_TOK_FMT}${turn_str}" "220")
    }
}
if ($ART_FMT) { $BADGE_LIST += $ART_FMT }
if ($SUB_FMT) { $BADGE_LIST += $SUB_FMT }
if ($BG_FMT) { $BADGE_LIST += $BG_FMT }
if ($SB) { $BADGE_LIST += $SB }
if ($Q_5H -ne $null -and $Q_5H -ne -1) { $BADGE_LIST += (make_quota_bar $Q_5H "5H" $FG_BRIGHT_CYAN $Q_5H_R) }
if ($Q_WK -ne $null -and $Q_WK -ne -1) { $BADGE_LIST += (make_quota_bar $Q_WK "7D" $FG_BRIGHT_MAGENTA $Q_WK_R) }
if ($POWER_FMT) { $BADGE_LIST += $POWER_FMT }

$PACKED_LINES = @()
$curr_line = ""
$curr_vis = 0
$max_vis = if ($USE_CLASSIC_ICONS) { $COLS - 1 } else { $COLS - 4 }
if ($max_vis -lt 30) { $max_vis = 30 }

foreach ($badge in $BADGE_LIST) {
    if (-not $badge) { continue }
    $b_vis = visible_len $badge
    if (-not $curr_line) {
        $curr_line = $badge
        $curr_vis = $b_vis
    } elseif (($curr_vis + 2 + $b_vis) -le $max_vis) {
        $curr_line += "  $badge"
        $curr_vis += 2 + $b_vis
    } else {
        $PACKED_LINES += $curr_line
        $curr_line = $badge
        $curr_vis = $b_vis
    }
}
if ($curr_line) { $PACKED_LINES += $curr_line }

if ($USE_CLASSIC_ICONS) {
    $LINE1
    foreach ($pline in $PACKED_LINES) { $pline }
} else {
    "${FG_GRAY}╭─${R}${LINE1}"
    $total_packed = $PACKED_LINES.Count
    for ($i = 0; $i -lt $total_packed; $i++) {
        if (($i + 1) -eq $total_packed) {
            "${FG_GRAY}╰─${R}$($PACKED_LINES[$i])"
        } else {
            "${FG_GRAY}├─${R}$($PACKED_LINES[$i])"
        }
    }
}
