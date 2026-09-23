# uninstall.ps1 - Uninstaller for Windows/PowerShell

# Path.GetFullPath makes saved or caller-supplied relative locations absolute.
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

Write-Host "====================================================" -ForegroundColor Blue
Write-Host "  Uninstalling Antigravity CLI Statusline (Windows)  " -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Blue

$settingsFile = "$HOME\.gemini\antigravity-cli\settings.json"
$settingsDir = Split-Path $settingsFile
$snapshotFile = Join-Path $settingsDir "statusline_installed_state.json"
$stateInstallDir = $null
if (Test-Path -LiteralPath $snapshotFile) {
    try {
        $savedState = Get-Content -Raw -LiteralPath $snapshotFile -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $savedState.install_dir) {
            $stateInstallDir = [string]$savedState.install_dir
        } elseif ($null -ne $savedState.AGY_STATUSLINE_INSTALL_DIR) {
            $stateInstallDir = [string]$savedState.AGY_STATUSLINE_INSTALL_DIR
        }
    } catch {
        Write-Warning "Could not read the install location from the state snapshot: $_"
    }
}

$installDirInput = $env:AGY_STATUSLINE_INSTALL_DIR
if ([string]::IsNullOrWhiteSpace($installDirInput)) {
    $installDirInput = $stateInstallDir
}
$requestedInstallDir = Resolve-InstallDirectory -Path $installDirInput -HomePath $HOME
$installDir = Resolve-InstallDirectory -Path $PSScriptRoot -HomePath $HOME
if (-not [string]::Equals($requestedInstallDir, $installDir, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "The requested or saved location does not match this uninstaller. No files were removed."
    exit 1
}
if ([string]::Equals($installDir, [System.IO.Path]::GetPathRoot($installDir), [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "Refusing to uninstall from the filesystem root. No files were removed."
    exit 1
}
$parentDirectory = New-Object System.IO.DirectoryInfo($installDir)
while ($null -ne $parentDirectory) {
    if (Test-Path -LiteralPath (Join-Path $parentDirectory.FullName ".git")) {
        Write-Error "Refusing to remove files inside a Git working tree. No files were removed."
        exit 1
    }
    $parentDirectory = $parentDirectory.Parent
}

$targetScript = Join-Path $installDir "statusline.ps1"
$targetUninstall = Join-Path $installDir "uninstall.ps1"

if (-not (Test-Path -LiteralPath $settingsFile)) {
    Write-Error "Cannot verify settings.json ownership. No files were removed."
    exit 1
}
try {
    $currentSettings = Get-Content -Raw -LiteralPath $settingsFile -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Error "Cannot verify the configured statusline command. No files were removed."
    exit 1
}

$escapedScriptPath = $targetScript.Replace('\', '/')
$fileArg = if ($escapedScriptPath -match '\s') { "`"$escapedScriptPath`"" } else { $escapedScriptPath }
$expectedCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fileArg"
$currentCommand = [string]$currentSettings.statusLine.command
$commandMatches = [string]::Equals($currentCommand, $expectedCommand, [System.StringComparison]::OrdinalIgnoreCase) -or
    $currentCommand.StartsWith($expectedCommand + " ", [System.StringComparison]::OrdinalIgnoreCase)
if (-not $commandMatches) {
    Write-Error "settings.json does not point to this installation. No files were removed."
    exit 1
}

foreach ($targetPath in @($installDir, $targetScript, $targetUninstall)) {
    if (Test-Path -LiteralPath $targetPath) {
        $targetItem = Get-Item -LiteralPath $targetPath -Force
        if (($targetItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Write-Error "Refusing to uninstall through a symbolic link or reparse point. No files were removed."
            exit 1
        }
    }
}

if (Test-Path -LiteralPath $targetScript) {
    Write-Host "Removing statusline script: $targetScript..."
    Remove-Item -LiteralPath $targetScript -Force
}

$altSnapshotFile = Join-Path $installDir "statusline_installed_state.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$activeSnapshot = $null
if (Test-Path -LiteralPath $snapshotFile) {
    $activeSnapshot = $snapshotFile
} elseif (Test-Path -LiteralPath $altSnapshotFile) {
    $activeSnapshot = $altSnapshotFile
}

if (Test-Path -LiteralPath $settingsFile) {
    if ($null -ne $activeSnapshot) {
        Write-Host "Restoring statusline configuration from state snapshot..."
        try {
            $rawState = Get-Content -Raw -LiteralPath $activeSnapshot -Encoding UTF8
            $state = $rawState | ConvertFrom-Json
            $rawSettings = Get-Content -Raw -LiteralPath $settingsFile -Encoding UTF8
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
        if (Test-Path -LiteralPath $snapshotFile) { Remove-Item -LiteralPath $snapshotFile -Force }
        if (Test-Path -LiteralPath $altSnapshotFile) { Remove-Item -LiteralPath $altSnapshotFile -Force }
        if (Test-Path -LiteralPath "${settingsFile}.bak") { Remove-Item -LiteralPath "${settingsFile}.bak" -Force }
    } elseif (Test-Path -LiteralPath "${settingsFile}.bak") {
        Write-Host "Restoring backup settings from ${settingsFile}.bak..."
        $bakContent = Get-Content -Raw -LiteralPath "${settingsFile}.bak" -Encoding UTF8
        [System.IO.File]::WriteAllText($settingsFile, $bakContent, $utf8NoBom)
        Remove-Item -LiteralPath "${settingsFile}.bak" -Force
    } else {
        Write-Host "Disabling statusLine in settings.json..."
        try {
            $json = Get-Content -Raw -LiteralPath $settingsFile -Encoding UTF8 | ConvertFrom-Json
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
if (Test-Path -LiteralPath $snapshotFile) { Remove-Item -LiteralPath $snapshotFile -Force }
if (Test-Path -LiteralPath $altSnapshotFile) { Remove-Item -LiteralPath $altSnapshotFile -Force }

if (Test-Path -LiteralPath $targetUninstall) {
    Write-Host "Removing uninstaller: $targetUninstall..."
    Remove-Item -LiteralPath $targetUninstall -Force
    # Remove directory if empty
    if ((Get-ChildItem -LiteralPath $installDir | Measure-Object).Count -eq 0) {
        Remove-Item -LiteralPath $installDir -Force
    }
}

Write-Host "====================================================" -ForegroundColor Blue
Write-Host "✓ Uninstallation completed successfully." -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Blue
