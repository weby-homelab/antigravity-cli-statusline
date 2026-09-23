# install.ps1 - PowerShell installer for Windows

# Path.GetFullPath makes caller-supplied relative locations absolute before storing them.
# Microsoft Learn: https://learn.microsoft.com/dotnet/api/system.io.path.getfullpath
function Resolve-InstallDirectory {
    param(
        [AllowNull()][string]$Path,
        [Parameter(Mandatory = $true)][string]$HomePath
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Join-Path $HomePath ".antigravity"
    } elseif ($Path -eq "~") {
        $Path = $HomePath
    } elseif ($Path.StartsWith("~/") -or $Path.StartsWith("~\")) {
        $Path = Join-Path $HomePath $Path.Substring(2)
    } elseif ($Path.StartsWith("~")) {
        throw "Only '~' and '~/...' home-directory shortcuts are supported."
    }

    return [System.IO.Path]::GetFullPath($Path)
}

function Update-StatuslineInstallSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$InstallDirectory,
        [Parameter(Mandatory = $true)][System.Text.Encoding]$Encoding
    )

    $state = Get-Content -Raw -LiteralPath $Path -Encoding UTF8 | ConvertFrom-Json
    foreach ($propertyName in @("install_dir", "AGY_STATUSLINE_INSTALL_DIR")) {
        if ($null -ne $state.PSObject.Properties[$propertyName]) {
            $state.$propertyName = $InstallDirectory
        } else {
            $state | Add-Member -MemberType NoteProperty -Name $propertyName -Value $InstallDirectory -Force
        }
    }

    $stateJson = $state | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($Path, $stateJson, $Encoding)
}

Write-Host "====================================================" -ForegroundColor Blue
Write-Host "  Installing Antigravity CLI Statusline (Windows)  " -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Blue

# The process-scoped environment value is inherited from the invoking shell.
# Microsoft Learn: https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_environment_variables
$installDir = Resolve-InstallDirectory -Path $env:AGY_STATUSLINE_INSTALL_DIR -HomePath $HOME
if ([string]::Equals($installDir, [System.IO.Path]::GetPathRoot($installDir), [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "The filesystem root cannot be used as an install directory."
    exit 1
}
$parentDirectory = New-Object System.IO.DirectoryInfo($installDir)
while ($null -ne $parentDirectory) {
    if (Test-Path -LiteralPath (Join-Path $parentDirectory.FullName ".git")) {
        Write-Error "Refusing to install inside a Git working tree."
        exit 1
    }
    $parentDirectory = $parentDirectory.Parent
}
if (-not (Test-Path -LiteralPath $installDir)) {
    Write-Host "Creating installation directory: $installDir"
    [System.IO.Directory]::CreateDirectory($installDir) | Out-Null
}

$targetScript = Join-Path $installDir "statusline.ps1"
$targetUninstall = Join-Path $installDir "uninstall.ps1"
$settingsFile = "$HOME\.gemini\antigravity-cli\settings.json"
$settingsDir = Split-Path $settingsFile

$escapedScriptPath = $targetScript.Replace('\', '/')
$fileArg = if ($escapedScriptPath -match '\s') { "`"$escapedScriptPath`"" } else { $escapedScriptPath }
$expectedCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fileArg"
if ((Test-Path -LiteralPath $targetScript) -or (Test-Path -LiteralPath $targetUninstall)) {
    if (-not (Test-Path -LiteralPath $settingsFile)) {
        Write-Error "Refusing to overwrite existing files without an active settings.json command."
        exit 1
    }
    try {
        $existingSettings = Get-Content -Raw -LiteralPath $settingsFile -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Error "Refusing to overwrite existing files because settings.json is invalid."
        exit 1
    }
    $existingCommand = [string]$existingSettings.statusLine.command
    $commandMatches = [string]::Equals($existingCommand, $expectedCommand, [System.StringComparison]::OrdinalIgnoreCase) -or
        $existingCommand.StartsWith($expectedCommand + " ", [System.StringComparison]::OrdinalIgnoreCase)
    if (-not $commandMatches) {
        Write-Error "Refusing to overwrite files not referenced by the active statusline settings."
        exit 1
    }
    foreach ($targetPath in @($targetScript, $targetUninstall)) {
        if (Test-Path -LiteralPath $targetPath) {
            $targetItem = Get-Item -LiteralPath $targetPath -Force
            if (($targetItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                Write-Error "Refusing to replace a symbolic link or reparse point."
                exit 1
            }
        }
    }
}

$rawUrl = "https://raw.githubusercontent.com/weby-homelab/antigravity-cli-statusline/main"

# Check if we have local files
$isLocal = $false
if ($PSScriptRoot) {
    $sourceScript = Join-Path $PSScriptRoot "statusline.ps1"
    if (Test-Path -LiteralPath $sourceScript) {
        $isLocal = $true
    }
}

if ($isLocal) {
    $sourceDirectory = [System.IO.Path]::GetFullPath($PSScriptRoot)
    if ([string]::Equals($sourceDirectory, $installDir, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Error "The install directory cannot be the source repository."
        exit 1
    }
}

$targetScriptTmp = "$targetScript.tmp.$([Guid]::NewGuid().ToString('N'))"
$targetUninstallTmp = "$targetUninstall.tmp.$([Guid]::NewGuid().ToString('N'))"

if ($isLocal) {
    Write-Host "Installing from local files..."
    $sourceScript = Join-Path $PSScriptRoot "statusline.ps1"
    $sourceUninstall = Join-Path $PSScriptRoot "uninstall.ps1"
    
    Write-Host "Copying statusline.ps1 to $targetScriptTmp..."
    Copy-Item -LiteralPath $sourceScript -Destination $targetScriptTmp -Force
    
    if (Test-Path -LiteralPath $sourceUninstall) {
        Write-Host "Copying uninstall.ps1 to $targetUninstallTmp..."
        Copy-Item -LiteralPath $sourceUninstall -Destination $targetUninstallTmp -Force
    }
} else {
    Write-Host "Installing from remote repository..."
    Write-Host "Downloading statusline.ps1 to temporary file..."
    Invoke-WebRequest -Uri "$rawUrl/statusline.ps1" -OutFile $targetScriptTmp -UseBasicParsing -ErrorAction Stop
    
    Write-Host "Downloading uninstall.ps1 to temporary file..."
    Invoke-WebRequest -Uri "$rawUrl/uninstall.ps1" -OutFile $targetUninstallTmp -UseBasicParsing -ErrorAction Stop
}

# Validate expected content of statusline.ps1 before replacing live file
if (-not (Test-Path -LiteralPath $targetScriptTmp) -or (Get-Item -LiteralPath $targetScriptTmp).Length -eq 0) {
    Write-Error "Error: statusline.ps1 temporary file is missing or empty. Installation aborted."
    if (Test-Path -LiteralPath $targetScriptTmp) { Remove-Item -LiteralPath $targetScriptTmp -Force }
    if (Test-Path -LiteralPath $targetUninstallTmp) { Remove-Item -LiteralPath $targetUninstallTmp -Force }
    exit 1
}

$tempContent = Get-Content -Raw -LiteralPath $targetScriptTmp
if ($tempContent -notmatch "statusline|antigravity") {
    Write-Error "Error: statusline.ps1 content validation failed. Installation aborted."
    Remove-Item -LiteralPath $targetScriptTmp -Force
    if (Test-Path -LiteralPath $targetUninstallTmp) { Remove-Item -LiteralPath $targetUninstallTmp -Force }
    exit 1
}

# Atomically move temporary files into live destination
Move-Item -LiteralPath $targetScriptTmp -Destination $targetScript -Force
if (Test-Path -LiteralPath $targetUninstallTmp) {
    Move-Item -LiteralPath $targetUninstallTmp -Destination $targetUninstall -Force
}

# Configuration file
[System.IO.Directory]::CreateDirectory($settingsDir) | Out-Null

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

if (Test-Path -LiteralPath $settingsFile) {
    # Validate JSON syntax to prevent clobbering malformed configurations
    $rawSettings = Get-Content -Raw -LiteralPath $settingsFile -Encoding UTF8
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
    if (-not (Test-Path -LiteralPath $snapshotFile) -and -not (Test-Path -LiteralPath $altSnapshotFile)) {
        $hasStatusLine = ($null -ne $json.PSObject.Properties['statusLine'])
        $origStatusLine = if ($hasStatusLine) { $json.statusLine } else { $null }
        $snapshotObj = [PSCustomObject]@{
            statusLine_existed = $hasStatusLine
            original_statusLine = $origStatusLine
        }
        $snapshotJson = $snapshotObj | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($snapshotFile, $snapshotJson, $utf8NoBom)
        if (Test-Path -LiteralPath $installDir) {
            [System.IO.File]::WriteAllText($altSnapshotFile, $snapshotJson, $utf8NoBom)
        }
        Write-Host "Saved initial state snapshot to $snapshotFile"
    }

    # Backup existing settings conservatively if no backup exists
    if (-not (Test-Path -LiteralPath "${settingsFile}.bak")) {
        Copy-Item -LiteralPath $settingsFile -Destination "${settingsFile}.bak" -Force
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
    if (-not (Test-Path -LiteralPath $snapshotFile) -and -not (Test-Path -LiteralPath $altSnapshotFile)) {
        $snapshotObj = [PSCustomObject]@{
            statusLine_existed = $false
            original_statusLine = $null
        }
        $snapshotJson = $snapshotObj | ConvertTo-Json -Depth 100
        [System.IO.File]::WriteAllText($snapshotFile, $snapshotJson, $utf8NoBom)
        if (Test-Path -LiteralPath $installDir) {
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

if (-not (Test-Path -LiteralPath $snapshotFile) -and (Test-Path -LiteralPath $altSnapshotFile)) {
    Copy-Item -LiteralPath $altSnapshotFile -Destination $snapshotFile -Force
}
Update-StatuslineInstallSnapshot -Path $snapshotFile -InstallDirectory $installDir -Encoding $utf8NoBom
$snapshotJson = Get-Content -Raw -LiteralPath $snapshotFile -Encoding UTF8
[System.IO.File]::WriteAllText($altSnapshotFile, $snapshotJson, $utf8NoBom)

Write-Host "====================================================" -ForegroundColor Blue
Write-Host "🎉 Installation completed successfully!" -ForegroundColor Green
Write-Host "Restart your Antigravity CLI session to see your new statusline."
Write-Host "Uninstaller copied to: $targetUninstall"
Write-Host ""
Write-Host "To view the legend of all statusline icons and components, run:"
Write-Host "  powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fileArg -Legend" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Blue
