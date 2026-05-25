# Keyflow Keyboard Setup Script
# Downloads & installs:
#   1. The Interception kernel driver (requires admin + reboot)
#   2. The latest Keyflow release from github.com/eduuh/keyflow
#   3. Registers keyflow.exe to run at Windows login (HKCU Run key)
#
# Usage:
#   .\install-keyboard.ps1                  # full install
#   .\install-keyboard.ps1 -SkipDriver      # skip Interception (already installed)
#   .\install-keyboard.ps1 -NoStartup       # don't register login startup
#   .\install-keyboard.ps1 -Tag v2.0.2      # pin a specific Keyflow version

[CmdletBinding()]
param(
    [switch]$SkipDriver,
    [switch]$NoStartup,
    [string]$Tag,
    [string]$InstallPath = (Join-Path ([Environment]::GetFolderPath('UserProfile')) "projects\keyboard\release")
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Status($msg, $color = "Cyan") { Write-Host "==> $msg" -ForegroundColor $color }

# ============================================================
# Interception driver
# ============================================================

# Interception hooks into the keyboard input stack by adding "keyboard" to the
# UpperFilters list on the keyboard device class. If it's there, the driver is
# active. This is more reliable than poking at services or driver files.
function Test-InterceptionInstalled {
    $keyboardClass = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96b-e325-11ce-bfc1-08002be10318}"
    $filters = (Get-ItemProperty $keyboardClass -Name UpperFilters -ErrorAction SilentlyContinue).UpperFilters
    return ($filters -contains 'keyboard')
}

function Test-IsAdmin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    return ([System.Security.Principal.WindowsPrincipal]$id).IsInRole(
        [System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-InterceptionDriver {
    if (-not (Test-IsAdmin)) {
        throw "Installing the Interception driver requires Administrator. Re-run this script in an elevated PowerShell."
    }

    Write-Status "Fetching latest Interception release..."
    $api = Invoke-RestMethod -Uri "https://api.github.com/repos/oblitum/Interception/releases/latest"
    $asset = $api.assets | Where-Object { $_.name -match '^Interception(\.zip)?$' } | Select-Object -First 1
    if (-not $asset) {
        # Fallback: known-good asset URL pattern
        $asset = @{
            name                 = "Interception.zip"
            browser_download_url = "https://github.com/oblitum/Interception/releases/download/$($api.tag_name)/Interception.zip"
        }
    }

    $tmpDir = Join-Path $env:TEMP "interception-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    try {
        $zip = Join-Path $tmpDir $asset.name
        Write-Status "Downloading $($api.tag_name)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
        Expand-Archive -Path $zip -DestinationPath $tmpDir -Force

        $installer = Get-ChildItem -Path $tmpDir -Recurse -Filter "install-interception.exe" |
                     Select-Object -First 1
        if (-not $installer) {
            throw "install-interception.exe not found inside $($asset.name)"
        }

        Write-Status "Running install-interception.exe /install"
        # Use the installer's own folder as CWD; some versions look for sibling files there.
        Push-Location $installer.Directory.FullName
        try {
            & $installer.FullName /install | Out-Host
            # $ErrorActionPreference = Stop doesn't apply to native exes — check manually.
            if ($LASTEXITCODE -ne 0) {
                throw "install-interception.exe exited with code $LASTEXITCODE"
            }
        } finally {
            Pop-Location
        }

        Write-Status "Interception driver installed. A reboot is required to activate it." "Yellow"
        $answer = Read-Host "Reboot now? [y/N]"
        if ($answer -match '^[Yy]') {
            # No -Force: respect other apps' "you have unsaved work" prompts.
            Restart-Computer
        } else {
            Write-Host ""
            Write-Host "Reboot when convenient, then run this script again with -SkipDriver to finish the Keyflow install." -ForegroundColor Yellow
            exit 0
        }
    } finally {
        Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Keyflow release
# ============================================================

function Get-KeyflowRelease($tag) {
    if ($tag) {
        return @{
            tag       = $tag
            zipUrl    = "https://github.com/eduuh/keyflow/releases/download/$tag/keyflow-release.zip"
            shaUrl    = "https://github.com/eduuh/keyflow/releases/download/$tag/keyflow-release.zip.sha256"
        }
    }
    $api = Invoke-RestMethod -Uri "https://api.github.com/repos/eduuh/keyflow/releases/latest"
    return @{
        tag    = $api.tag_name
        zipUrl = ($api.assets | Where-Object { $_.name -eq "keyflow-release.zip"        } | Select-Object -First 1).browser_download_url
        shaUrl = ($api.assets | Where-Object { $_.name -eq "keyflow-release.zip.sha256" } | Select-Object -First 1).browser_download_url
    }
}

function Install-Keyflow($release, $installPath) {
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null

    # Safety guard before the destructive Remove-Item below: refuse to wipe
    # anything that looks like a system root. Require at least three path
    # segments under the drive letter (e.g. C:\Users\name\foo is OK; C:\Users
    # or C:\ is not).
    $resolved = (Resolve-Path $installPath -ErrorAction Stop).Path.TrimEnd('\','/')
    $forbidden = @($env:USERPROFILE, $env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)},
                   "C:\", "C:\Users", "C:\Windows") | Where-Object { $_ }
    if ($forbidden -contains $resolved) {
        throw "Refusing to use '$resolved' as install path — looks like a system root."
    }
    $segments = ($resolved -split '[\\/]') | Where-Object { $_ }
    if ($segments.Count -lt 3) {
        throw "Refusing to use '$resolved' as install path — too shallow ($($segments.Count) segments). Pick a deeper directory."
    }

    # Preserve user-customized config.json across reinstalls so they don't
    # lose their layout each time they upgrade.
    $existingConfig = Join-Path $installPath "config.json"
    $configBackup = $null
    if (Test-Path $existingConfig) {
        $configBackup = Join-Path $env:TEMP "keyflow-config-$(Get-Random).json"
        Copy-Item $existingConfig $configBackup -Force
        Write-Status "Backing up existing config.json"
    }

    # Clean install dir so stale capsicain/older keyflow files don't linger.
    Get-ChildItem $installPath -Force | Remove-Item -Recurse -Force

    $zip = Join-Path $installPath "keyflow-release.zip"
    Write-Status "Downloading Keyflow $($release.tag)..."
    Invoke-WebRequest -Uri $release.zipUrl -OutFile $zip

    if ($release.shaUrl) {
        # Fetch the sidecar separately from the comparison so a network failure
        # warns-and-continues, but an actual hash mismatch hard-fails.
        $expected = $null
        try {
            $expected = ((Invoke-WebRequest -Uri $release.shaUrl).Content -split '\s+')[0].Trim().ToLower()
        } catch {
            Write-Host "WARNING: could not fetch checksum, skipping verification: $_" -ForegroundColor Yellow
        }
        if ($expected) {
            $actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
            if ($expected -ne $actual) {
                Remove-Item $zip -Force
                throw "SHA256 mismatch! expected=$expected actual=$actual"
            }
            Write-Status "Checksum verified" "Green"
        }
    }

    Expand-Archive -Path $zip -DestinationPath $installPath -Force
    Remove-Item $zip -Force

    if ($configBackup) {
        Move-Item $configBackup $existingConfig -Force
        Write-Status "Restored your config.json"
    }
}

# ============================================================
# Windows login startup
# ============================================================

function Set-LoginStartup($exePath) {
    # HKCU\...\Run runs once per user login. keyflow.exe pins CWD to its own
    # directory at startup (WindowsPlatformInit ctor → SetCurrentDirectoryW),
    # so the registry value doesn't need to specify a working directory.
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

    # Tidy up any old Capsicain entry from a prior install — having both run
    # at login fights for keyboard ownership.
    if ((Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).PSObject.Properties['Capsicain']) {
        Remove-ItemProperty -Path $regPath -Name "Capsicain" -Force
        Write-Status "Removed stale Capsicain login entry" "Yellow"
    }

    Set-ItemProperty -Path $regPath -Name "Keyflow" -Value "`"$exePath`""
    Write-Status "Registered Keyflow for Windows login: $exePath" "Green"
}

# ============================================================
# Main flow
# ============================================================

Write-Status "Keyflow install starting"
Write-Host "  Install path: $InstallPath"

# --- Interception driver ---
if ($SkipDriver) {
    Write-Status "Skipping Interception driver step (-SkipDriver)"
} elseif (Test-InterceptionInstalled) {
    Write-Status "Interception driver already installed" "Green"
} else {
    Install-InterceptionDriver  # exits if user defers reboot
}

# --- Keyflow release ---
$release = Get-KeyflowRelease -tag $Tag
if (-not $release.zipUrl) {
    throw "Could not locate keyflow-release.zip for $($release.tag)"
}
Install-Keyflow -release $release -installPath $InstallPath

$exePath = Join-Path $InstallPath "keyflow.exe"
if (-not (Test-Path $exePath)) {
    throw "Install completed but keyflow.exe is missing at $exePath"
}

# --- Login startup ---
if ($NoStartup) {
    Write-Status "Skipping login startup registration (-NoStartup)"
} else {
    Set-LoginStartup -exePath $exePath
}

Write-Host ""
Write-Host "Keyflow $($release.tag) installed." -ForegroundColor Green
Write-Host "  exe:    $exePath"
Write-Host "  config: $(Join-Path $InstallPath 'config.json')"
if (Test-InterceptionInstalled) {
    Write-Host "Launch now:  & '$exePath'" -ForegroundColor Cyan
} else {
    Write-Host "Reboot to activate the Interception driver, then sign back in to start Keyflow." -ForegroundColor Yellow
}
