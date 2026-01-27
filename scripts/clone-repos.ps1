# Clone GitHub repositories using SSH
# Run gh.ps1 first to set up SSH keys

# === Configuration ===
$BaseDir = "C:\Users\edwinmuraya\repos"
$GitHubUser = "eduuh"

# Add your repositories here
$Repositories = @(
    "win-dot",
    "personal-notes",
    "capsicain"
)

function Write-Status($msg, $color = "Cyan") {
    Write-Host "==> $msg" -ForegroundColor $color
}

function Test-GitInstalled {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Git is not installed. Please install Git first." -ForegroundColor Red
        exit 1
    }
}

function Test-SSHKey {
    $keyPath = "$env:USERPROFILE\.ssh\id_ed25519"
    if (-not (Test-Path $keyPath)) {
        Write-Host "Warning: SSH key not found at $keyPath" -ForegroundColor Yellow
        Write-Host "Run gh.ps1 to set up SSH keys before cloning." -ForegroundColor Yellow
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne "y") {
            exit 1
        }
    }
}

function Clone-Repository($repoName) {
    $sshUrl = "git@github.com:${GitHubUser}/${repoName}.git"
    $targetPath = Join-Path $BaseDir $repoName

    if (Test-Path $targetPath) {
        Write-Status "Repository '$repoName' already exists at $targetPath" "Yellow"

        # Check if it's a git repository and offer to pull
        if (Test-Path (Join-Path $targetPath ".git")) {
            Write-Status "Pulling latest changes..." "Cyan"
            Push-Location $targetPath
            try {
                git pull 2>&1 | Out-Host
                if ($LASTEXITCODE -eq 0) {
                    Write-Status "Updated $repoName" "Green"
                } else {
                    Write-Status "Failed to update $repoName" "Red"
                }
            }
            catch {
                Write-Status "Error updating ${repoName}: $_" "Red"
            }
            finally {
                Pop-Location
            }
        }
        return
    }

    Write-Status "Cloning $repoName from $sshUrl..." "Cyan"
    try {
        git clone $sshUrl $targetPath 2>&1 | Out-Host
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Successfully cloned $repoName" "Green"
        } else {
            Write-Status "Failed to clone $repoName" "Red"
        }
    }
    catch {
        Write-Status "Error cloning ${repoName}: $_" "Red"
    }
}

# === Main ===

Write-Status "Starting repository cloning process..." "Cyan"

Test-GitInstalled
Test-SSHKey

# Create base directory if it doesn't exist
if (-not (Test-Path $BaseDir)) {
    Write-Status "Creating base directory at $BaseDir..." "Cyan"
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
}

Write-Status "Cloning $($Repositories.Count) repositories to $BaseDir..." "Cyan"

foreach ($repo in $Repositories) {
    Clone-Repository $repo
    Write-Host ""  # Empty line for readability
}

Write-Status "✅ Repository cloning complete!" "Green"
Write-Status "Repositories are located at: $BaseDir" "Green"
