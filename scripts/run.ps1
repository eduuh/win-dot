param (
    [switch]$InstallKeyboard
)

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrator privileges. Attempting to elevate..."
    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptDirectory = Split-Path -Parent $scriptPath
    
    $elevationArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    if ($InstallKeyboard) {
        $elevationArgs += " -InstallKeyboard"
    }
    
    Start-Process PowerShell.exe -ArgumentList $elevationArgs -Verb RunAs
    exit
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Header($title) {
    $separator = "=" * 60
    Write-Host ""
    Write-Host $separator -ForegroundColor Yellow
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host $separator -ForegroundColor Yellow
    Write-Host ""
}

# Ask for confirmation
Write-Host "This script will run the following operations:" -ForegroundColor Yellow
Write-Host "  1. Configure Windows Development Environment (WSL, Developer Mode, etc.)" -ForegroundColor White
Write-Host "  2. Set up GitHub SSH access" -ForegroundColor White
Write-Host "  3. Install development tools (as regular user)" -ForegroundColor White
if ($InstallKeyboard) {
    Write-Host "  4. Install Capsicain keyboard customization" -ForegroundColor White
}
Write-Host ""
$confirmation = Read-Host "Do you want to proceed? (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "Operation cancelled. Exiting..." -ForegroundColor Red
    exit
}

try {
    Write-Header "Setting up Windows Development Environment"
    & "$scriptDirectory\win.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Windows setup failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    
    Write-Header "Setting up GitHub SSH Access"
    & "$scriptDirectory\gh.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "GitHub SSH setup failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    
    Write-Header "Installing Development Tools (as regular user)"
    
    $installScriptPath = "$scriptDirectory\install.ps1"
    $installArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$installScriptPath`""
    if ($InstallKeyboard) { 
        $installArgs += " -InstallKeyboard"
        Write-Host "Including Capsicain keyboard installation..." -ForegroundColor Cyan
    }
    
    $process = Start-Process PowerShell.exe -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        Write-Host "Tool installation failed with exit code $($process.ExitCode)" -ForegroundColor Red
        Write-Host "You can try running install.ps1 manually after this script completes." -ForegroundColor Yellow
    } else {
        Write-Host "Tool installation completed successfully." -ForegroundColor Green
    }
    
    Write-Header "Setup Complete"
    Write-Host "✅ All operations completed successfully!" -ForegroundColor Green
    Write-Host "👉 You may need to restart your computer for some changes to take effect." -ForegroundColor Yellow
}
catch {
    Write-Host "An error occurred during execution:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}