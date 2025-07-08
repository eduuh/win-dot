# Windows Package Installation Script

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Check if Scoop is installed, install if needed
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Scoop package manager..."
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-WebRequest -UseBasicParsing -Uri get.scoop.sh | Invoke-Expression
    
    # Add Scoop to the current session path
    $env:PATH = "$env:USERPROFILE\scoop\shims;$env:PATH"
    Write-Host "Scoop installed successfully."
}

# Scoop Packages
Write-Host "Installing Scoop packages..."
scoop update
scoop bucket add extras
scoop bucket add main
scoop bucket add versions

$scoopPackages = @("extras/obsidian","main/neovim","git", "nodejs-lts", "7zip", "gh", "fzf", "ripgrep", "make", "cmake", "bat")
foreach ($tool in $scoopPackages) {
    scoop install $tool
    Write-Host "Installed $tool."
}

# Winget Packages
Write-Host "Installing Winget packages..."
$wingetPackages = @(
    "glzr-io.glazewm",
    "glzr-io.zebar",
    "Microsoft.PowerToys",
    "Microsoft.PowerShell.Preview",
    "Microsoft.DotNet.SDK.9",
    "Microsoft.DotNet.DesktopRuntime.9",
    "Microsoft.DotNet.AspNetCore.6",
    "Microsoft.DotNet.DesktopRuntime.6",
    "Microsoft.DotNet.AspNetCore.6",
    "DEVCOM.JetBrainsMonoNerdFont"
)

foreach ($pkg in $wingetPackages) {
    winget install --id $pkg --source winget --accept-source-agreements --accept-package-agreements
    Write-Host "Installed $pkg."
}

winget install GlazeWM --source winget --accept-source-agreements --accept-package-agreements

Write-Host "✅ Package installation complete."
