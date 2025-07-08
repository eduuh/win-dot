# Windows Development Environment Setup Script

param (
    [switch]$InstallKeyboard
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "Starting Windows development environment setup..."

# Install packages (Scoop and Winget)
Write-Host "Installing packages..."
& "$PSScriptRoot\install-packages.ps1"

# Install keyboard if requested
if ($InstallKeyboard) {
    Write-Host "Installing Capsicain keyboard..."
    & "$PSScriptRoot\install-keyboard.ps1"
}
else {
    Write-Host "Skipping Capsicain keyboard installation. To install later, run with --installkeyboard flag."
}

Write-Host "✅ Setup complete. Restart your terminal."
