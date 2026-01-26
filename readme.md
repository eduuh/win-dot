# Win-dot

Automated Windows development environment setup and dotfiles management using PowerShell scripts.

## Quick Start

Run the complete setup (requires Administrator privileges):

```powershell
cd $HOME\projects\win-dot\scripts
./run.ps1
```

With optional Capsicain keyboard customization:

```powershell
./run.ps1 -InstallKeyboard
```

## What Gets Installed

### Package Managers
- **Scoop** - Command-line installer for Windows
- **Winget** - Windows Package Manager

### Development Tools (via Scoop)
- Git
- GitHub CLI (gh)
- Node.js LTS
- Neovim
- 7zip
- fzf (fuzzy finder)
- ripgrep (fast search)
- make & cmake
- bat (cat alternative)
- **Starship** (cross-shell prompt)

### Applications (via Winget)
- GlazeWM (tiling window manager)
- Zebar (status bar)
- Microsoft PowerToys
- PowerShell Preview
- .NET SDK 9 & Desktop Runtime
- .NET 6 Runtime & ASP.NET Core
- JetBrains Mono Nerd Font
- Obsidian (notes)

### Authentication & Cloud
- **Azure Authentication CLI** (version 0.9.2)
- GitHub SSH key setup with ED25519 encryption

### Windows Features
- Developer Mode enabled
- WSL 2 (Windows Subsystem for Linux)
- Virtual Machine Platform
- OpenSSH client and server

### Optional
- **Capsicain** keyboard customization (with `-InstallKeyboard` flag)

## Available Scripts

### `run.ps1` (Recommended)

Main orchestration script that runs the complete setup:
1. Windows development configuration (`win.ps1`)
2. GitHub SSH setup (`gh.ps1`)
3. Package installation (`install.ps1`)
4. Optional keyboard setup

**Usage:**
```powershell
cd $HOME\projects\win-dot\scripts
./run.ps1                    # Standard setup
./run.ps1 -InstallKeyboard   # Include Capsicain keyboard
```

### `gh.ps1`

Configures GitHub authentication with SSH keys:
- Installs OpenSSH
- Generates ED25519 SSH key
- Authenticates with GitHub CLI
- Uploads public key to GitHub

**Usage:**
```powershell
./gh.ps1
```

### `win.ps1`

Configures Windows for development:
- Enables Developer Mode
- Installs and configures WSL 2
- Enables Virtual Machine Platform

**Usage:**
```powershell
./win.ps1
```

### `install.ps1`

Orchestrates package installation:
- Calls `install-packages.ps1`
- Optionally calls `install-keyboard.ps1`

**Usage:**
```powershell
./install.ps1                    # Standard installation
./install.ps1 -InstallKeyboard   # Include keyboard setup
```

### `install-packages.ps1`

Installs all development tools and applications via Scoop and Winget.

**Usage:**
```powershell
./install-packages.ps1
```

### `install-keyboard.ps1`

Clones and sets up Capsicain keyboard customization:
- Clones repo to `~/projects/keyboard/repo`
- Downloads latest release from GitHub
- Updates if already installed

**Usage:**
```powershell
./install-keyboard.ps1
```

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Administrator privileges (for most scripts)
- Internet connection


## Powershell Dotfiles setup

```powershell
git clone --bare git@github.com:eduuh/win-dot.git $HOME/projects/win-dot-bare

function dot {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )
    git --git-dir="$HOME/projects/win-dot-bare" --work-tree="$HOME" @Args
}


dot config status.showUntrackedFiles no
```