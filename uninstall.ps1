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
$settingsDir = Split-Path $settingsFile
$snapshotFile = Join-Path $settingsDir "statusline_installed_state.json"
$altSnapshotFile = Join-Path $installDir "statusline_installed_state.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$activeSnapshot = $null
if (Test-Path $snapshotFile) {
    $activeSnapshot = $snapshotFile
} elseif (Test-Path $altSnapshotFile) {
    $activeSnapshot = $altSnapshotFile
}

if (Test-Path $settingsFile) {
    if ($null -ne $activeSnapshot) {
        Write-Host "Restoring statusline configuration from state snapshot..."
        try {
            $rawState = Get-Content -Raw -Path $activeSnapshot -Encoding UTF8
            $state = $rawState | ConvertFrom-Json
            $rawSettings = Get-Content -Raw -Path $settingsFile -Encoding UTF8
            $json = $rawSettings | ConvertFrom-Json
            
            if ($null -ne $json) {
                if ($state.statusLine_existed -eq $true) {
                    Write-Host "Restoring original statusLine configuration..."
                    if ($null -ne $json.PSObject.Properties['statusLine']) {
                        $json.statusLine = $state.original_statusLine
                    } else {
                        $json | Add-Member -MemberType NoteProperty -Name 'statusLine' -Value $state.original_statusLine -Force
                    }
                } else {
                    Write-Host "Removing statusLine property from settings.json..."
                    if ($json -is [System.Collections.IDictionary]) {
                        $json.Remove('statusLine')
                    } elseif ($null -ne $json.PSObject.Properties['statusLine']) {
                        $json.PSObject.Properties.Remove('statusLine')
                    }
                }
                $jsonString = $json | ConvertTo-Json -Depth 100
                [System.IO.File]::WriteAllText($settingsFile, $jsonString, $utf8NoBom)
            }
        } catch {
            Write-Warning "Could not restore from state snapshot: $_"
        }
        if (Test-Path $snapshotFile) { Remove-Item -Path $snapshotFile -Force }
        if (Test-Path $altSnapshotFile) { Remove-Item -Path $altSnapshotFile -Force }
        if (Test-Path "${settingsFile}.bak") { Remove-Item -Path "${settingsFile}.bak" -Force }
    } elseif (Test-Path "${settingsFile}.bak") {
        Write-Host "Restoring backup settings from ${settingsFile}.bak..."
        $bakContent = Get-Content -Raw -Path "${settingsFile}.bak" -Encoding UTF8
        [System.IO.File]::WriteAllText($settingsFile, $bakContent, $utf8NoBom)
        Remove-Item -Path "${settingsFile}.bak" -Force
    } else {
        Write-Host "Disabling statusLine in settings.json..."
        try {
            $json = Get-Content -Raw -Path $settingsFile -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $json -and $null -ne $json.PSObject.Properties['statusLine']) {
                if ($null -ne $json.statusLine.PSObject.Properties['enabled']) {
                    $json.statusLine.enabled = $false
                } else {
                    $json.statusLine | Add-Member -MemberType NoteProperty -Name 'enabled' -Value $false -Force
                }
                $jsonString = $json | ConvertTo-Json -Depth 100
                [System.IO.File]::WriteAllText($settingsFile, $jsonString, $utf8NoBom)
            }
        } catch {
            Write-Warning "Could not disable statusLine: $_"
        }
    }
}

# Clean up snapshots if settings file was already deleted
if (Test-Path $snapshotFile) { Remove-Item -Path $snapshotFile -Force }
if (Test-Path $altSnapshotFile) { Remove-Item -Path $altSnapshotFile -Force }

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
