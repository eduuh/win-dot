# Win-dot scripts

A collection of PowerShell scripts for Windows development environment setup and configuration.

## Available Scripts

### Run Script (Recommended)

The main runner script that executes both GitHub SSH setup and Windows configuration with administrator privileges:

```powershell
cd $HOME\projects\win-dot\scripts
./run.ps1
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

Install common development tools using Scoop:

```powershell
cd $HOME\projects\win-dot\scripts
./install.ps1
```

## Requirements

- Windows 10/11
- PowerShell (run as Administrator)