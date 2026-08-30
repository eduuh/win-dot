# win-dot

## Installation

Run in a normal, non-Administrator PowerShell window:

```powershell
# 1. Install or update Scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
} else {
    scoop update
}

# 2. Install Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    scoop install git
}

# 3. Download win-dot
git clone https://github.com/eduuh/win-dot.git $HOME\projects\win-dot

# 4. Configure Windows (opens an Administrator prompt)
& "$HOME\projects\win-dot\scripts\run.ps1"

# 5. Install packages in this non-Administrator window
& "$HOME\projects\win-dot\scripts\install.ps1"

# 6. Set up the dot command
& "$HOME\projects\win-dot\scripts\setup-git.ps1"
```

Restart PowerShell after installation.
