# tests/test_powershell_renderer.ps1 - PowerShell test suite for Windows CI
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$Ps1Statusline = Join-Path $RepoRoot "statusline.ps1"
$Ps1Install = Join-Path $RepoRoot "install.ps1"
$Ps1Uninstall = Join-Path $RepoRoot "uninstall.ps1"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Running PowerShell AST & Logic Verification Tests" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$Passed = 0
$Failed = 0

function Assert-Condition($Condition, $Message) {
    if ($Condition) {
        Write-Host "  [PASS] $Message" -ForegroundColor Green
        $script:Passed++
    } else {
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
        $script:Failed++
    }
}

# Test 1: Validate PowerShell Syntax via AST Parser
Write-Host "--- Test 1: PowerShell AST Syntax Validation ---"
foreach ($script in @($Ps1Statusline, $Ps1Install, $Ps1Uninstall)) {
    $fileName = Split-Path -Leaf $script
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        foreach ($err in $errors) {
            Write-Host "    [SYNTAX ERROR in $fileName]: Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Red
        }
    }
    Assert-Condition ($errors.Count -eq 0) "Script parses cleanly without syntax errors: $fileName"
}

# Test 2: BOM Byte Check on statusline.ps1
Write-Host "--- Test 2: BOM Byte Check ---"
$bytes = [System.IO.File]::ReadAllBytes($Ps1Statusline)
$hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
Assert-Condition $hasBom "statusline.ps1 starts with UTF-8 BOM bytes for Windows PowerShell 5.1"

# Test 3: Path with Spaces Quoting
Write-Host "--- Test 3: Path Quoting Generation ---"
$mockTarget = "C:\Program Files\Antigravity CLI\statusline.ps1"
$escaped = $mockTarget.Replace('\', '/')
$commandString = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$escaped`""
Assert-Condition ($commandString -match '^powershell\.exe -NoProfile -ExecutionPolicy Bypass -File "C:/Program Files/Antigravity CLI/statusline.ps1"') "Command string quotes path with spaces safely"

# Test 4: PSCustomObject Manipulation Safety
Write-Host "--- Test 4: PSCustomObject Property Handling in PS 5.1 ---"
$jsonText = '{"unrelated": 1}'
$obj = ConvertFrom-Json $jsonText
if ($obj.PSObject.Properties['statusLine']) {
    $obj.statusLine = @{ type = "command"; command = "test"; enabled = $true }
} else {
    $obj | Add-Member -NotePropertyName 'statusLine' -NotePropertyValue @{ type = "command"; command = "test"; enabled = $true } -Force
}
Assert-Condition ($obj.unrelated -eq 1 -and $obj.statusLine.type -eq "command") "PSCustomObject safely adds statusLine without throwing"

# Test 5: Delayed and Blocked Stdin Handling
Write-Host "--- Test 5: Bounded Stdin Read with Delayed Payload ---"
$statuslineAst = [System.Management.Automation.Language.Parser]::ParseFile($Ps1Statusline, [ref]$tokens, [ref]$errors)
$readFunctionAst = $statuslineAst.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq "Read-StatuslineInput"
}, $true)
Assert-Condition ($null -ne $readFunctionAst) "statusline.ps1 provides a bounded Read-StatuslineInput helper"

if ($null -ne $readFunctionAst) {
    . ([scriptblock]::Create($readFunctionAst.Extent.Text))

    Add-Type -TypeDefinition @"
using System.Threading;
public sealed class StatuslineTestTextReader : System.IO.TextReader {
    private readonly string content;
    private readonly int delayMilliseconds;
    public StatuslineTestTextReader(string content, int delayMilliseconds) {
        this.content = content;
        this.delayMilliseconds = delayMilliseconds;
    }
    public override string ReadToEnd() {
        Thread.Sleep(delayMilliseconds);
        return content;
    }
}
"@

    $delayedPayload = '{"agent_state":"thinking","terminal_width":80}'
    $delayedReader = New-Object -TypeName StatuslineTestTextReader -ArgumentList $delayedPayload, 400
    $delayedResult = Read-StatuslineInput -Reader $delayedReader -TimeoutMilliseconds 1500
    Assert-Condition ($delayedResult -eq $delayedPayload) "stdin payload arriving after 400 ms is read instead of discarded (got '$delayedResult')"

    $blockedReader = New-Object -TypeName StatuslineTestTextReader -ArgumentList "", 1500
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $blockedResult = Read-StatuslineInput -Reader $blockedReader -TimeoutMilliseconds 250
    $timer.Stop()
    Assert-Condition ($blockedResult -eq "{}" -and $timer.ElapsedMilliseconds -lt 1000) "blocked stdin returns a renderable fallback within a bounded deadline"
}

# Test 6: Configurable Installation Path Normalization
Write-Host "--- Test 6: Configurable Installation Path Normalization ---"
$installAst = [System.Management.Automation.Language.Parser]::ParseFile($Ps1Install, [ref]$tokens, [ref]$errors)
$resolveFunctionAst = $installAst.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq "Resolve-InstallDirectory"
}, $true)
Assert-Condition ($null -ne $resolveFunctionAst) "install.ps1 provides an install path normalization helper"

if ($null -ne $resolveFunctionAst) {
    . ([scriptblock]::Create($resolveFunctionAst.Extent.Text))
    $fakeHome = Join-Path ([System.IO.Path]::GetTempPath()) "Antigravity Test Home"
    $relativePath = Resolve-InstallDirectory -Path "relative statusline dir" -HomePath $fakeHome
    $expectedRelativePath = [System.IO.Path]::GetFullPath("relative statusline dir")
    Assert-Condition ($relativePath -eq $expectedRelativePath) "relative install paths resolve to absolute paths"

    $homeRelativePath = Resolve-InstallDirectory -Path "~/custom statusline" -HomePath $fakeHome
    $expectedHomeRelativePath = [System.IO.Path]::GetFullPath((Join-Path $fakeHome "custom statusline"))
    Assert-Condition ($homeRelativePath -eq $expectedHomeRelativePath) "~/ install paths expand under the selected home directory"
}

# Test 7: Snapshot Location Updates Preserve the Original Configuration
Write-Host "--- Test 7: Install Snapshot Location Update ---"
$snapshotFunctionAst = $installAst.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq "Update-StatuslineInstallSnapshot"
}, $true)
Assert-Condition ($null -ne $snapshotFunctionAst) "install.ps1 provides a snapshot location update helper"

if ($null -ne $snapshotFunctionAst) {
    . ([scriptblock]::Create($snapshotFunctionAst.Extent.Text))
    $tempSnapshot = Join-Path ([System.IO.Path]::GetTempPath()) ("statusline-state-" + [Guid]::NewGuid().ToString() + ".json")
    $initialSnapshot = '{"statusLine_existed":true,"original_statusLine":{"command":"before"}}'
    [System.IO.File]::WriteAllText($tempSnapshot, $initialSnapshot, (New-Object System.Text.UTF8Encoding($false)))
    try {
        $encoding = New-Object System.Text.UTF8Encoding($false)
        Update-StatuslineInstallSnapshot -Path $tempSnapshot -InstallDirectory "C:\statusline custom" -Encoding $encoding
        $updatedSnapshot = Get-Content -Raw -Path $tempSnapshot -Encoding UTF8 | ConvertFrom-Json
        $preservedOriginal = $updatedSnapshot.original_statusLine.command -eq "before"
        $storedPath = ($updatedSnapshot.install_dir -eq "C:\statusline custom") -and
            ($updatedSnapshot.AGY_STATUSLINE_INSTALL_DIR -eq "C:\statusline custom")
        Assert-Condition ($preservedOriginal -and $storedPath) "snapshot path updates retain the original statusLine state"
    } finally {
        if (Test-Path $tempSnapshot) { Remove-Item -Path $tempSnapshot -Force }
    }
}

# Helper to execute statusline.ps1 in an isolated PowerShell child process
function Invoke-StatuslineProcess($payload, [string[]]$arguments) {
    $pInfo = New-Object System.Diagnostics.ProcessStartInfo
    $pInfo.FileName = (Get-Process -Id $PID).Path
    $statuslineArg = if ($Ps1Statusline.Contains(' ')) { "`"$Ps1Statusline`"" } else { $Ps1Statusline }
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $statuslineArg)
    if ($arguments) { $argList += $arguments }
    $pInfo.Arguments = $argList -join " "
    $pInfo.RedirectStandardInput = $true
    $pInfo.RedirectStandardOutput = $true
    $pInfo.RedirectStandardError = $true
    $pInfo.UseShellExecute = $false
    $pInfo.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($pInfo)
    $proc.StandardInput.Write($payload)
    $proc.StandardInput.Close()
    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    if (-not $proc.WaitForExit(15000)) {
        try { $proc.Kill() } catch {}
        throw "statusline.ps1 execution timed out"
    }
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    if ($proc.ExitCode -ne 0) {
        throw "statusline.ps1 exited with code $($proc.ExitCode): $stderr"
    }
    return $stdout
}

$testPayload = '{"agent_state":"working","terminal_width":150,"vcs":{"branch":"main","dirty":false},"model":{"id":"gemini-2.0-flash","display_name":"Gemini 2.0 Flash"},"context_window":{"used_percentage":14.2,"total_input_tokens":88244,"total_output_tokens":61074,"context_window_size":1048576},"vim":{"mode":"NORMAL"},"conversation_id":"c40d17f851f8","plan_tier":"Pro","email":"test@example.com"}'

# Test 8: Telemetry Suppression Flags & POSIX/PowerShell Switch Parity
Write-Host "--- Test 8: Telemetry Suppression Flags & Switch Parity ---"
$baseOut = Invoke-StatuslineProcess -Payload $testPayload -Arguments @()
Assert-Condition ($baseOut -match "WORKING") "Baseline output contains agent state"
Assert-Condition ($baseOut -match "NORMAL") "Baseline output contains vim mode"
Assert-Condition ($baseOut -match '(main| main)') "Baseline output contains VCS branch"
Assert-Condition ($baseOut -match "Gemini 2\.0 Flash") "Baseline output contains active model"
Assert-Condition ($baseOut -match "ctx") "Baseline output contains context bar"

# Agent state suppression parity
$noStatePosix = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("--no-state")
$noStatePs = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("-NoState")
Assert-Condition ($noStatePosix -notmatch "WORKING") "--no-state suppresses agent state"
Assert-Condition ($noStatePs -notmatch "WORKING") "-NoState suppresses agent state"

# Vim mode suppression parity
$noVimPosix = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("--no-vim")
$noVimPs = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("-NoVim")
Assert-Condition ($noVimPosix -notmatch "NORMAL") "--no-vim suppresses vim mode"
Assert-Condition ($noVimPs -notmatch "NORMAL") "-NoVim suppresses vim mode"

# VCS Branch suppression parity
$noBranchPosix = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("--no-branch")
$noBranchPs = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("-NoBranch")
Assert-Condition ($noBranchPosix -notmatch "main") "--no-branch suppresses git branch"
Assert-Condition ($noBranchPs -notmatch "main") "-NoBranch suppresses git branch"

# Model suppression parity
$noModelPosix = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("--no-model")
$noModelPs = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("-NoModel")
Assert-Condition ($noModelPosix -notmatch "Gemini 2\.0 Flash") "--no-model suppresses active model"
Assert-Condition ($noModelPs -notmatch "Gemini 2\.0 Flash") "-NoModel suppresses active model"

# Working directory suppression parity
$noDirPosix = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("--no-dir")
$noDirPs = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("-NoDir")
Assert-Condition ($noDirPosix -match "WORKING") "--no-dir runs cleanly"
Assert-Condition ($noDirPs -match "WORKING") "-NoDir runs cleanly"

# Context bar suppression parity
$noCtxPosix = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("--no-context")
$noCtxPs = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("-NoContext")
Assert-Condition ($noCtxPosix -notmatch "ctx") "--no-context suppresses context bar"
Assert-Condition ($noCtxPs -notmatch "ctx") "-NoContext suppresses context bar"

# Token summary suppression parity
$noTokPosix = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("--no-tokens")
$noTokPs = Invoke-StatuslineProcess -Payload $testPayload -Arguments @("-NoTokens")
Assert-Condition ($noTokPosix -notmatch "total:") "--no-tokens suppresses token summary"
Assert-Condition ($noTokPs -notmatch "total:") "-NoTokens suppresses token summary"

# Test 9: Header Collapse Logic
Write-Host "--- Test 9: Header Collapse Logic ---"
$allL1 = @("--no-state", "--no-vim", "--no-branch", "--no-model", "--no-dir", "--no-conv", "--no-account", "--no-host", "--no-version")
$hcOut = Invoke-StatuslineProcess -Payload $testPayload -Arguments $allL1
$hcLines = @($hcOut -split "`r?`n" | Where-Object { $_ -match '\S' })
Assert-Condition ($hcOut -notmatch "WORKING") "Header Collapse omits agent state"
Assert-Condition ($hcOut -notmatch "NORMAL") "Header Collapse omits vim mode"
Assert-Condition ($hcLines.Count -gt 0 -and $hcLines[0] -match "╭─") "Header Collapse first row starts with ╭─"
Assert-Condition ($hcLines.Count -gt 0 -and $hcLines[0] -notmatch "├─") "Header Collapse first row does not start with divider ├─"
Assert-Condition ($hcLines.Count -gt 0 -and $hcLines[0] -match "ctx") "Header Collapse first row contains context badge"

# 9b: Single row collapsed badge
$singleBadgeArgs = $allL1 + @("--no-tokens", "--no-sys", "--no-artifacts", "--no-subagents", "--no-tasks", "--no-sandbox", "--no-quota", "--no-power")
$singleOut = Invoke-StatuslineProcess -Payload $testPayload -Arguments $singleBadgeArgs
$singleLines = @($singleOut -split "`r?`n" | Where-Object { $_ -match '\S' })
Assert-Condition ($singleLines.Count -eq 1) "Single-row collapsed badge renders exactly 1 row (got $($singleLines.Count))"
Assert-Condition ($singleLines.Count -eq 1 -and $singleLines[0] -match "╭─") "Single-row collapsed badge starts with ╭─"

# 9c: Classic Header Collapse
$classicHcOut = Invoke-StatuslineProcess -Payload $testPayload -Arguments (@("--classic") + $allL1)
$classicHcLines = @($classicHcOut -split "`r?`n" | Where-Object { $_ -match '\S' })
Assert-Condition ($classicHcOut -notmatch "WORKING") "Classic Header Collapse omits Line 1"
Assert-Condition ($classicHcLines.Count -gt 0 -and $classicHcLines[0] -match "ctx") "Classic Header Collapse first line begins with badges"

# Test 10: Full Suppression Logic
Write-Host "--- Test 10: Full Suppression Logic ---"
$allSuppArgs = $allL1 + @("--no-context", "--no-tokens", "--no-cost", "--no-sys", "--no-artifacts", "--no-subagents", "--no-tasks", "--no-sandbox", "--no-quota", "--no-power")
$fullSuppOut = Invoke-StatuslineProcess -Payload $testPayload -Arguments $allSuppArgs
$fullSuppClean = $fullSuppOut.Trim()
Assert-Condition ([string]::IsNullOrEmpty($fullSuppClean)) "Full suppression produces clean empty output (0 bytes)"

$fullSuppClassicOut = Invoke-StatuslineProcess -Payload $testPayload -Arguments (@("--classic") + $allSuppArgs)
$fullSuppClassicClean = $fullSuppClassicOut.Trim()
Assert-Condition ([string]::IsNullOrEmpty($fullSuppClassicClean)) "Full suppression in classic mode produces clean empty output"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PowerShell Tests: $Passed passed, $Failed failed" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ($Failed -gt 0) { exit 1 } else { exit 0 }
