# install.ps1 - PowerShell installer for Windows

Write-Host "====================================================" -ForegroundColor Blue
Write-Host "  Installing Antigravity CLI Statusline (Windows)  " -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Blue

$installDir = Join-Path $HOME ".antigravity"
if (-not (Test-Path $installDir)) {
    Write-Host "Creating installation directory: $installDir"
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

$targetScript = Join-Path $installDir "statusline.ps1"
$targetUninstall = Join-Path $installDir "uninstall.ps1"

$rawUrl = "https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main"

# Check if we have local files
$isLocal = $false
if ($PSScriptRoot) {
    $sourceScript = Join-Path $PSScriptRoot "statusline.ps1"
    if (Test-Path $sourceScript) {
        $isLocal = $true
    }
}

$targetScriptTmp = "$targetScript.tmp"
$targetUninstallTmp = "$targetUninstall.tmp"

if ($isLocal) {
    Write-Host "Installing from local files..."
    $sourceScript = Join-Path $PSScriptRoot "statusline.ps1"
    $sourceUninstall = Join-Path $PSScriptRoot "uninstall.ps1"
    
    Write-Host "Copying statusline.ps1 to $targetScriptTmp..."
    Copy-Item -Path $sourceScript -Destination $targetScriptTmp -Force
    
    if (Test-Path $sourceUninstall) {
        Write-Host "Copying uninstall.ps1 to $targetUninstallTmp..."
        Copy-Item -Path $sourceUninstall -Destination $targetUninstallTmp -Force
    }
} else {
    Write-Host "Installing from remote repository..."
    Write-Host "Downloading statusline.ps1 to temporary file..."
    Invoke-WebRequest -Uri "$rawUrl/statusline.ps1" -OutFile $targetScriptTmp -UseBasicParsing -ErrorAction Stop
    
    Write-Host "Downloading uninstall.ps1 to temporary file..."
    Invoke-WebRequest -Uri "$rawUrl/uninstall.ps1" -OutFile $targetUninstallTmp -UseBasicParsing -ErrorAction Stop
}

# Validate expected content of statusline.ps1 before replacing live file
if (-not (Test-Path $targetScriptTmp) -or (Get-Item $targetScriptTmp).Length -eq 0) {
    Write-Error "Error: statusline.ps1 temporary file is missing or empty. Installation aborted."
    if (Test-Path $targetScriptTmp) { Remove-Item -Path $targetScriptTmp -Force }
    if (Test-Path $targetUninstallTmp) { Remove-Item -Path $targetUninstallTmp -Force }
    exit 1
}

$tempContent = Get-Content -Raw -Path $targetScriptTmp
if ($tempContent -notmatch "statusline|antigravity") {
    Write-Error "Error: statusline.ps1 content validation failed. Installation aborted."
    Remove-Item -Path $targetScriptTmp -Force
    if (Test-Path $targetUninstallTmp) { Remove-Item -Path $targetUninstallTmp -Force }
    exit 1
}

# Atomically move temporary files into live destination
Move-Item -Path $targetScriptTmp -Destination $targetScript -Force
if (Test-Path $targetUninstallTmp) {
    Move-Item -Path $targetUninstallTmp -Destination $targetUninstall -Force
}

# Configuration file
$settingsFile = "$HOME\.gemini\antigravity-cli\settings.json"
$settingsDir = Split-Path $settingsFile

if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir | Out-Null
}

# Format script path for settings.json compatibility (using forward slashes)
$escapedScriptPath = $targetScript.Replace('\', '/')
$extraArgs = ""
if ($args.Count -gt 0) {
    $extraArgs = " " + ($args -join " ")
}

# Ensure paths with spaces are quoted cleanly without nested literal escaped quotes
if ($escapedScriptPath -match '\s') {
    $fileArg = "`"$escapedScriptPath`""
} else {
    $fileArg = "$escapedScriptPath"
}
$commandString = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fileArg$extraArgs"

Write-Host "Configuring statusline in settings.json..."
$snapshotFile = Join-Path $settingsDir "statusline_installed_state.json"
$altSnapshotFile = Join-Path $installDir "statusline_installed_state.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (Test-Path $settingsFile) {
    # Validate JSON syntax to prevent clobbering malformed configurations
    $rawSettings = Get-Content -Raw -Path $settingsFile -Encoding UTF8
    if ($null -ne $rawSettings -and $rawSettings.Trim().Length -gt 0) {
        try {
            $json = $rawSettings | ConvertFrom-Json
        } catch {
            Write-Error "Error: settings.json contains malformed or invalid JSON. Aborting installation."
            exit 1
        }
    } else {
        $json = [PSCustomObject]@{}
    }

    if ($null -eq $json) {
        $json = [PSCustomObject]@{}
    }

    # Dedicated state snapshot: preserve initial snapshot on repeated installs/upgrades
    if (-not (Test-Path $snapshotFile) -and -not (Test-Path $altSnapshotFile)) {
        $hasStatusLine = ($null -ne $json.PSObject.Properties['statusLine'])
        $origStatusLine = if ($hasStatusLine) { $json.statusLine } else { $null }
        $snapshotObj = [PSCustomObject]@{
            statusLine_existed = $hasStatusLine
            original_statusLine = $origStatusLine
        }
        $snapshotJson = $snapshotObj | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($snapshotFile, $snapshotJson, $utf8NoBom)
        if (Test-Path $installDir) {
            [System.IO.File]::WriteAllText($altSnapshotFile, $snapshotJson, $utf8NoBom)
        }
        Write-Host "Saved initial state snapshot to $snapshotFile"
    }

    # Backup existing settings conservatively if no backup exists
    if (-not (Test-Path "${settingsFile}.bak")) {
        Copy-Item -Path $settingsFile -Destination "${settingsFile}.bak" -Force
        Write-Host "Backup of settings.json saved to ${settingsFile}.bak"
    }

    # Property-safe addition/update on PSCustomObject, preserving unknown fields
    if ($null -eq $json.PSObject.Properties['statusLine']) {
        $statusLineObj = [PSCustomObject]@{
            type = "command"
            command = $commandString
            enabled = $true
        }
        $json | Add-Member -MemberType NoteProperty -Name 'statusLine' -Value $statusLineObj -Force
    } else {
        $currentSl = $json.statusLine
        if ($currentSl -is [System.Collections.IDictionary]) {
            $currentSl['type'] = "command"
            $currentSl['command'] = $commandString
            $currentSl['enabled'] = $true
        } else {
            if ($null -ne $currentSl.PSObject.Properties['type']) {
                $currentSl.type = "command"
            } else {
                $currentSl | Add-Member -MemberType NoteProperty -Name 'type' -Value "command" -Force
            }
            if ($null -ne $currentSl.PSObject.Properties['command']) {
                $currentSl.command = $commandString
            } else {
                $currentSl | Add-Member -MemberType NoteProperty -Name 'command' -Value $commandString -Force
            }
            if ($null -ne $currentSl.PSObject.Properties['enabled']) {
                $currentSl.enabled = $true
            } else {
                $currentSl | Add-Member -MemberType NoteProperty -Name 'enabled' -Value $true -Force
            }
        }
    }

    $jsonString = $json | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($settingsFile, $jsonString, $utf8NoBom)
} else {
    # New configuration: record initial state snapshot
    if (-not (Test-Path $snapshotFile) -and -not (Test-Path $altSnapshotFile)) {
        $snapshotObj = [PSCustomObject]@{
            statusLine_existed = $false
            original_statusLine = $null
        }
        $snapshotJson = $snapshotObj | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($snapshotFile, $snapshotJson, $utf8NoBom)
        if (Test-Path $installDir) {
            [System.IO.File]::WriteAllText($altSnapshotFile, $snapshotJson, $utf8NoBom)
        }
    }

    $config = [PSCustomObject]@{
        statusLine = [PSCustomObject]@{
            type = "command"
            command = $commandString
            enabled = $true
        }
    }
    $jsonString = $config | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($settingsFile, $jsonString, $utf8NoBom)
}

Write-Host "====================================================" -ForegroundColor Blue
Write-Host "🎉 Installation completed successfully!" -ForegroundColor Green
Write-Host "Restart your Antigravity CLI session to see your new statusline."
Write-Host "Uninstaller copied to: $targetUninstall"
Write-Host ""
Write-Host "To view the legend of all statusline icons and components, run:"
Write-Host "  powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fileArg -Legend" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Blue
