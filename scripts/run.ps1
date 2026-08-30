if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrator privileges. Attempting to elevate..."
    $scriptPath = $MyInvocation.MyCommand.Path
    $elevationArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

    $process = Start-Process PowerShell.exe -ArgumentList $elevationArgs -Verb RunAs -Wait -PassThru
    exit $process.ExitCode
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
    Write-Header "Setup Complete"
    Write-Host "Windows setup completed successfully." -ForegroundColor Green
    Write-Host "You may need to restart your computer for some changes to take effect." -ForegroundColor Yellow
}
catch {
    Write-Host "An error occurred during execution:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}