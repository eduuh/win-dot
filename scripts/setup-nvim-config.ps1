# Setup Neovim configuration
# Clones nvim config from GitHub to the correct location

function Write-Status($msg, $color = "Cyan") {
    Write-Host "==> $msg" -ForegroundColor $color
}

$GitHubUser = "eduuh"
$ConfigRepo = "nvim"

# Neovim on Windows looks for config in different locations:
# - Native Windows: %LOCALAPPDATA%\nvim
# - Git Bash/WSL: ~/.config/nvim
# Check which location nvim expects
$XdgConfigPath = Join-Path $env:USERPROFILE ".config\nvim"
$WindowsConfigPath = Join-Path $env:LOCALAPPDATA "nvim"

# Use .config/nvim for Git Bash compatibility (default for Scoop install)
$NvimConfigPath = $XdgConfigPath

Write-Status "Setting up Neovim configuration..."

# Check if config already exists
if (Test-Path $NvimConfigPath) {
    Write-Status "Neovim config already exists at $NvimConfigPath" "Yellow"

    # Check if it's a git repository
    if (Test-Path (Join-Path $NvimConfigPath ".git")) {
        Write-Status "Pulling latest changes..." "Cyan"
        Push-Location $NvimConfigPath
        try {
            git pull 2>&1 | Out-Host
            if ($LASTEXITCODE -eq 0) {
                Write-Status "Updated Neovim config" "Green"
            } else {
                Write-Status "Failed to update Neovim config" "Red"
            }
        }
        catch {
            Write-Status "Error updating config: $_" "Red"
        }
        finally {
            Pop-Location
        }
    }
    exit 0
}

# Clone the config repository
$sshUrl = "git@github.com:${GitHubUser}/${ConfigRepo}.git"
Write-Status "Cloning Neovim config from $sshUrl..." "Cyan"

try {
    git clone $sshUrl $NvimConfigPath 2>&1 | Out-Host
    if ($LASTEXITCODE -eq 0) {
        Write-Status "Successfully cloned Neovim config to $NvimConfigPath" "Green"
    } else {
        Write-Status "Failed to clone Neovim config" "Red"
        exit 1
    }
}
catch {
    Write-Status "Error cloning config: $_" "Red"
    exit 1
}

Write-Status "✅ Neovim configuration setup complete!" "Green"
Write-Status "Config location: $NvimConfigPath" "Green"
