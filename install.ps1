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

if ($isLocal) {
    Write-Host "Installing from local files..."
    $sourceScript = Join-Path $PSScriptRoot "statusline.ps1"
    $sourceUninstall = Join-Path $PSScriptRoot "uninstall.ps1"
    
    Write-Host "Copying statusline.ps1 to $targetScript..."
    Copy-Item -Path $sourceScript -Destination $targetScript -Force
    
    if (Test-Path $sourceUninstall) {
        Write-Host "Copying uninstall.ps1 to $targetUninstall..."
        Copy-Item -Path $sourceUninstall -Destination $targetUninstall -Force
    }
} else {
    Write-Host "Installing from remote repository..."
    Write-Host "Downloading statusline.ps1..."
    Invoke-WebRequest -Uri "$rawUrl/statusline.ps1" -OutFile $targetScript -UseBasicParsing
    
    Write-Host "Downloading uninstall.ps1..."
    Invoke-WebRequest -Uri "$rawUrl/uninstall.ps1" -OutFile $targetUninstall -UseBasicParsing
}

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
Write-Host "Uninstaller copied to: $targetUninstall"
Write-Host ""
Write-Host "To view the legend of all statusline icons and components, run:"
Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File `"$escapedScriptPath`" -Legend" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Blue
