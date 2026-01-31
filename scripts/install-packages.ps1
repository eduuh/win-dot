# Windows Package Installation Script

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Status($msg, $color = "Cyan") {
    Write-Host "==> $msg" -ForegroundColor $color
}

function Install-ScoopPackage($package) {
    try {
        $pkgName = $package -replace '^[^/]+/', ''
        if (scoop list $pkgName 2>$null) {
            Write-Status "$pkgName already installed" "Green"
            return $true
        }

        Write-Status "Installing $package..."
        scoop install $package *>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Installed $package" "Green"
            return $true
        } else {
            Write-Status "Failed to install $package (exit code: $LASTEXITCODE)" "Yellow"
            return $false
        }
    }
    catch {
        Write-Status "Error installing $package`: $_" "Yellow"
        return $false
    }
}

function Install-WingetPackage($package) {
    try {
        Write-Status "Checking $package..."
        $installed = winget list --id $package --exact 2>$null
        if ($installed -match $package) {
            Write-Status "$package already installed" "Green"
            return $true
        }

        Write-Status "Installing $package..."
        winget install --id $package --source winget --accept-source-agreements --accept-package-agreements --silent
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Installed $package" "Green"
            return $true
        } else {
            Write-Status "Failed to install $package (exit code: $LASTEXITCODE)" "Yellow"
            return $false
        }
    }
    catch {
        Write-Status "Error installing $package`: $_" "Yellow"
        return $false
    }
}

# Check if Scoop is installed, install if needed
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Status "Installing Scoop package manager..."
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-WebRequest -UseBasicParsing -Uri get.scoop.sh | Invoke-Expression

        # Add Scoop to the current session path
        $env:PATH = "$env:USERPROFILE\scoop\shims;$env:PATH"

        # Verify Scoop is now available
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            throw "Scoop installation failed - command not found after install"
        }
        Write-Status "Scoop installed successfully" "Green"
    }
    catch {
        Write-Host "Failed to install Scoop: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Status "Scoop already installed" "Green"
}

# Scoop Packages
Write-Status "Setting up Scoop buckets..."
try {
    scoop update *>&1 | Out-Null
    scoop bucket add extras 2>$null
    scoop bucket add main 2>$null
    scoop bucket add versions 2>$null
    Write-Status "Scoop buckets configured" "Green"
}
catch {
    Write-Status "Warning: Issue configuring buckets: $_" "Yellow"
}

Write-Status "Installing Scoop packages..."
$scoopPackages = @("extras/obsidian","main/neovim","git", "nodejs-lts", "7zip", "gh", "fzf", "ripgrep", "make", "cmake", "bat", "starship")
$scoopFailed = @()
foreach ($tool in $scoopPackages) {
    if (-not (Install-ScoopPackage $tool)) {
        $scoopFailed += $tool
    }
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
    "DEVCOM.JetBrainsMonoNerdFont",
    "Microsoft.AzureCLI"
)

foreach ($pkg in $wingetPackages) {
    winget install --id $pkg --source winget --accept-source-agreements --accept-package-agreements
    Write-Host "Installed $pkg."
}

winget install GlazeWM --source winget --accept-source-agreements --accept-package-agreements

# Azure Authentication CLI
Write-Host "Installing Azure Authentication CLI..."
$env:AZUREAUTH_VERSION = '0.9.2'
$script = "${env:TEMP}\install.ps1"
$url = "https://raw.githubusercontent.com/AzureAD/microsoft-authentication-cli/${env:AZUREAUTH_VERSION}/install/install.ps1"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest $url -OutFile $script
if ($?) {
    & $script
    Write-Host "Installed Azure Authentication CLI."
}
if ($?) {
    Remove-Item $script
}

# PSMUX - PowerShell terminal multiplexer
Write-Host "Installing PSMUX..."
try {
    $psmuxInstallDir = "$env:LOCALAPPDATA\psmux"

    # Check if already installed
    if ((Test-Path "$psmuxInstallDir\psmux.exe") -and (Get-Command psmux -ErrorAction SilentlyContinue)) {
        Write-Host "PSMUX already installed" -ForegroundColor Green
    }
    else {
        $tempZip = "$env:TEMP\psmux-download.zip"
        $tempExtract = "$env:TEMP\psmux-extract"

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri 'https://github.com/marlocarlo/psmux/releases/download/v0.2.1/psmux-windows-x86_64.zip' -OutFile $tempZip

        if (Test-Path $tempExtract) { Remove-Item -Recurse -Force $tempExtract }
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        if (-not (Test-Path $psmuxInstallDir)) {
            New-Item -ItemType Directory -Path $psmuxInstallDir -Force | Out-Null
        }

        $sourceDir = Join-Path $tempExtract "psmux-windows-x86_64"
        Copy-Item -Path "$sourceDir\*.exe" -Destination $psmuxInstallDir -Force

        # Add to PATH
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($userPath -notlike "*$psmuxInstallDir*") {
            $newPath = "$userPath;$psmuxInstallDir"
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
            $env:Path = "$env:Path;$psmuxInstallDir"
        }

        # Cleanup
        Remove-Item $tempZip -Force
        Remove-Item -Recurse -Force $tempExtract

        Write-Host "Installed PSMUX" -ForegroundColor Green
    }
}
catch {
    Write-Host "Warning: Failed to install PSMUX: $_" -ForegroundColor Yellow
}

# Setup Neovim configuration
Write-Host "Setting up Neovim configuration..."
$nvimSetupScript = Join-Path $PSScriptRoot "setup-nvim-config.ps1"
if (Test-Path $nvimSetupScript) {
    & $nvimSetupScript
} else {
    Write-Host "Warning: setup-nvim-config.ps1 not found" -ForegroundColor Yellow
}

# Azure CLI Extensions
Write-Host "Installing Azure CLI extensions..."
if (Get-Command az -ErrorAction SilentlyContinue) {
    try {
        az extension add --name azure-devops --yes 2>&1 | Out-Host
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Installed Azure DevOps extension" -ForegroundColor Green
        } else {
            Write-Host "Warning: Failed to install Azure DevOps extension" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Warning: Error installing Azure DevOps extension: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "Azure CLI not found, skipping extension installation" -ForegroundColor Yellow
}

Write-Host "✅ Package installation complete."
