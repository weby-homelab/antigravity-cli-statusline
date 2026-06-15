# install.ps1 - PowerShell installer for Windows

Write-Host "====================================================" -ForegroundColor Blue
Write-Host "  Installing Antigravity CLI Statusline (Windows)  " -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Blue

$installDir = Join-Path $HOME ".antigravity"
if (-not (Test-Path $installDir)) {
    Write-Host "Creating installation directory: $installDir"
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

$sourceScript = Join-Path $PSScriptRoot "statusline.ps1"
$targetScript = Join-Path $installDir "statusline.ps1"

if (-not (Test-Path $sourceScript)) {
    Write-Error "Could not find statusline.ps1 in: $PSScriptRoot"
    exit 1
}

Write-Host "Copying statusline.ps1 to $targetScript..."
Copy-Item -Path $sourceScript -Destination $targetScript -Force

# Configuration file
$settingsFile = "$HOME\.gemini\antigravity-cli\settings.json"
$settingsDir = Split-Path $settingsFile

if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir | Out-Null
}

# Format script path for settings.json compatibility (using forward slashes)
$escapedScriptPath = $targetScript.Replace('\', '/')
$commandString = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$escapedScriptPath`""

Write-Host "Configuring statusline in settings.json..."
if (Test-Path $settingsFile) {
    # Backup existing settings
    Copy-Item -Path $settingsFile -Destination "${settingsFile}.bak" -Force
    Write-Host "Backup of settings.json saved to ${settingsFile}.bak"

    $json = Get-Content -Raw -Path $settingsFile | ConvertFrom-Json
    if ($null -eq $json) {
        $json = @{}
    }
    
    # Update statusLine
    $json.statusLine = @{
        type = ""
        command = $commandString
        enabled = $true
    }
    
    $json | ConvertTo-Json -Depth 100 | Out-File -FilePath $settingsFile -Encoding utf8
} else {
    $config = @{
        statusLine = @{
            type = ""
            command = $commandString
            enabled = $true
        }
    }
    $config | ConvertTo-Json -Depth 100 | Out-File -FilePath $settingsFile -Encoding utf8
}

Write-Host "====================================================" -ForegroundColor Blue
Write-Host "🎉 Installation completed successfully!" -ForegroundColor Green
Write-Host "Restart your Antigravity CLI session to see your new statusline."
Write-Host "====================================================" -ForegroundColor Blue
