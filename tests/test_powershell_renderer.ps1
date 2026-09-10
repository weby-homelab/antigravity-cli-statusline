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
$escaped = $mockTarget.Replace('', '/')
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

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " PowerShell Tests: $Passed passed, $Failed failed" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ($Failed -gt 0) { exit 1 } else { exit 0 }
