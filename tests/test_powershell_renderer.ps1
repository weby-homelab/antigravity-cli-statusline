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
    Assert-Condition ($delayedResult -eq $delayedPayload) "stdin payload arriving after 400 ms is read instead of discarded"

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

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PowerShell Tests: $Passed passed, $Failed failed" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ($Failed -gt 0) { exit 1 } else { exit 0 }
