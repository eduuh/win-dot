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
    Add-WindowsCapability -Online -Name OpenSSH.Client*
    Add-WindowsCapability -Online -Name OpenSSH.Server*
}

function Ensure-SSHAgent {
    Write-Status "Enabling and starting ssh-agent..."
    Set-Service -Name ssh-agent -StartupType Automatic
    Start-Service ssh-agent
}

function Generate-SSHKey {
    if (-Not (Test-Path "$KeyPath")) {
        Write-Status "Generating SSH key at $KeyPath..."
        mkdir -Force (Split-Path $KeyPath) | Out-Null
        ssh-keygen -t ed25519 -C $GitHubEmail -f $KeyPath
    } else {
        Write-Status "SSH key already exists at $KeyPath" "Green"
    }
}

function Add-Key-To-Agent {
    Write-Status "Adding SSH key to ssh-agent..."
    ssh-add $KeyPath
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
