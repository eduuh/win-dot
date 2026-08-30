# Run as Administrator

# Check for Admin privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script as Administrator. Exiting..."
    exit
}

# Enable Developer Mode
Write-Host "Enabling Developer Mode..."
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /f /v "AllowDevelopmentWithoutDevLicense" /d "1"

# Enable WSL and Virtual Machine Platform
Write-Host "Enabling WSL and Virtual Machine Platform..."
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Optionally set WSL version 2 as default (requires restart and kernel update)
Write-Host "Setting WSL 2 as default (after kernel update)..."
wsl --set-default-version 2

# Install WSL kernel update (user must confirm download if not present)
#Write-Host "Opening WSL kernel update page for manual install..."
#Start-Process "https://aka.ms/wsl2kernel"


# Optional: Restart needed to finalize WSL setup
Write-Host "`nSetup complete. You should restart your computer to finish enabling WSL and Virtual Machine Platform."
