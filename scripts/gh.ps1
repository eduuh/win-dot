# GitHub SSH key setup for Windows (PowerShell)
# Requires Admin rights

# === Configuration ===
$GitHubEmail = "31909722+eduuh@users.noreply.github.com"
$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519"

function Write-Status($msg, $color = "Cyan") {
    Write-Host "==> $msg" -ForegroundColor $color
}

function Require-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Error "This script must be run as Administrator."
        exit 1
    }
}

function Install-OpenSSH {
    Write-Status "Installing OpenSSH..."
    try {
        $clientResult = Add-WindowsCapability -Online -Name OpenSSH.Client* -ErrorAction Stop
        if ($clientResult.State -eq "Installed") {
            Write-Status "OpenSSH Client installed" "Green"
        }
    }
    catch {
        Write-Status "Warning: OpenSSH Client may already be installed or failed: $_" "Yellow"
    }

    try {
        $serverResult = Add-WindowsCapability -Online -Name OpenSSH.Server* -ErrorAction Stop
        if ($serverResult.State -eq "Installed") {
            Write-Status "OpenSSH Server installed" "Green"
        }
    }
    catch {
        Write-Status "Warning: OpenSSH Server installation failed (not critical): $_" "Yellow"
    }
}

function Ensure-SSHAgent {
    Write-Status "Enabling and starting ssh-agent..."
    try {
        Set-Service -Name ssh-agent -StartupType Automatic -ErrorAction Stop
        Start-Service ssh-agent -ErrorAction Stop

        # Verify the service is running
        $service = Get-Service ssh-agent
        if ($service.Status -ne "Running") {
            throw "ssh-agent service is not running"
        }
        Write-Status "ssh-agent is running" "Green"
    }
    catch {
        Write-Host "Error: Failed to start ssh-agent: $_" -ForegroundColor Red
        exit 1
    }
}

function Generate-SSHKey {
    if (-Not (Test-Path "$KeyPath")) {
        Write-Status "Generating SSH key at $KeyPath..."
        try {
            $sshDir = Split-Path $KeyPath
            if (-not (Test-Path $sshDir)) {
                New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
            }

            # Generate key with empty passphrase
            ssh-keygen -t ed25519 -C $GitHubEmail -f $KeyPath -N '""' 2>&1 | Out-Host
            if ($LASTEXITCODE -ne 0) {
                throw "ssh-keygen failed with exit code $LASTEXITCODE"
            }

            if (-not (Test-Path "$KeyPath.pub")) {
                throw "SSH public key was not created"
            }
            Write-Status "SSH key generated successfully" "Green"
        }
        catch {
            Write-Host "Error: Failed to generate SSH key: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Status "SSH key already exists at $KeyPath" "Green"
    }
}

function Add-Key-To-Agent {
    Write-Status "Adding SSH key to ssh-agent..."
    try {
        # Check if key is already added
        $addedKeys = ssh-add -l 2>&1
        if ($addedKeys -match [regex]::Escape($KeyPath)) {
            Write-Status "SSH key already added to agent" "Green"
            return
        }

        ssh-add $KeyPath 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "ssh-add failed with exit code $LASTEXITCODE"
        }
        Write-Status "SSH key added to agent" "Green"
    }
    catch {
        Write-Host "Error: Failed to add SSH key to agent: $_" -ForegroundColor Red
        exit 1
    }
}

function Ensure-GitHubCLI {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Status "Installing GitHub CLI..."
        winget install --id GitHub.cli --source winget --accept-package-agreements --accept-source-agreements
    } else {
        Write-Status "GitHub CLI already installed" "Green"
    }
}

function GitHub-Auth {
    Write-Status "Authenticating with GitHub (interactive login)..."
    gh auth login --web --scopes "admin:public_key"
}

function Upload-SSHKey {
    $keyTitle = "$env:COMPUTERNAME $(Get-Date -Format 'yyyy-MM-dd')"
    Write-Status "Uploading SSH public key to GitHub with title '$keyTitle'..."
    gh ssh-key add "$KeyPath.pub" --title "$keyTitle"
}

# === Main ===

Require-Admin
Write-Status "Starting GitHub SSH setup for Windows..."

Install-OpenSSH
Ensure-SSHAgent
Generate-SSHKey
Add-Key-To-Agent
Ensure-GitHubCLI
GitHub-Auth
Upload-SSHKey

Write-Status "✅ GitHub SSH setup completed successfully!" "Green"
Write-Status "✅ You can now clone repositories using SSH" "Green"
