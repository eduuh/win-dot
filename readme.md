# Win-dot scripts

A collection of PowerShell scripts for Windows development environment setup and configuration.

## Available Scripts

### Run Script (Recommended)

The main runner script that executes GitHub SSH setup, Windows configuration, and installs development tools with administrator privileges:

```powershell
cd $HOME\projects\win-dot\scripts
./run.ps1
```

To also install the Capsicain keyboard customization:

```powershell
cd $HOME\projects\win-dot\scripts
./run.ps1 -InstallKeyboard
```

### Individual Scripts

#### GitHub SSH Setup

Set up SSH keys for GitHub:

```powershell
cd $HOME\projects\win-dot\scripts
./gh.ps1
```

#### Windows Development Configuration

Configure Windows for development (enables Developer Mode, WSL, etc.):

```powershell
cd $HOME\projects\win-dot\scripts
./win.ps1
```

#### Development Tool Installation

Install common development tools using Scoop and Winget:

```powershell
cd $HOME\projects\win-dot\scripts
./install.ps1
```

To include Capsicain keyboard customization:

```powershell
cd $HOME\projects\win-dot\scripts
./install.ps1 -InstallKeyboard
```

## Requirements

- Windows 10/11
- PowerShell (run as Administrator)


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