# uninstall.ps1 - Uninstaller for Windows/PowerShell

Write-Host "====================================================" -ForegroundColor Blue
Write-Host "  Uninstalling Antigravity CLI Statusline (Windows)  " -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Blue

$installDir = Join-Path $HOME ".antigravity"
$targetScript = Join-Path $installDir "statusline.ps1"
$targetUninstall = Join-Path $installDir "uninstall.ps1"

if (Test-Path $targetScript) {
    Write-Host "Removing statusline script: $targetScript..."
    Remove-Item -Path $targetScript -Force
}

$settingsFile = "$HOME\.gemini\antigravity-cli\settings.json"

if (Test-Path $settingsFile) {
    if (Test-Path "${settingsFile}.bak") {
        Write-Host "Restoring backup settings from ${settingsFile}.bak..."
        Get-Content -Raw -Path "${settingsFile}.bak" | Out-File -FilePath $settingsFile -Encoding utf8
        Remove-Item -Path "${settingsFile}.bak" -Force
    } else {
        Write-Host "Disabling statusLine in settings.json..."
        $json = Get-Content -Raw -Path $settingsFile | ConvertFrom-Json
        if ($null -ne $json.statusLine) {
            $json.statusLine.enabled = $false
            $json | ConvertTo-Json -Depth 100 | Out-File -FilePath $settingsFile -Encoding utf8
        }
    }
}

if (Test-Path $targetUninstall) {
    Write-Host "Removing uninstaller: $targetUninstall..."
    Remove-Item -Path $targetUninstall -Force
    # Remove directory if empty
    if ((Get-ChildItem -Path $installDir | Measure-Object).Count -eq 0) {
        Remove-Item -Path $installDir -Force
    }
}

Write-Host "====================================================" -ForegroundColor Blue
Write-Host "✓ Uninstallation completed successfully." -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Blue
