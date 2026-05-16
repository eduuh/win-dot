# Win-dot

Automated Windows development environment setup and dotfiles management.

## First Time Setup

### 1. Clone the Dotfiles Repository

```powershell
# Clone as a bare repository
git clone --bare git@github.com:eduuh/win-dot.git $HOME/projects/win-dot-bare
```

### 2. Set Up the `dot` Command

The `dot` command manages your dotfiles. It's automatically available after you reload PowerShell (the profile is already in the repo).

To use it immediately in your current session:

```powershell
. $PROFILE
```

Now you can use `dot` like `git`:

```powershell
# Hide untracked files in status
dot config status.showUntrackedFiles no

# Check out your dotfiles
dot checkout
```

**Note:** If `dot checkout` fails due to existing files, back them up and try again:

```powershell
mkdir ~\dotfiles-backup
# Move conflicting files to backup folder, then retry checkout
```

### 3. Run the Setup Script

```powershell
cd $HOME\scripts
./run.ps1
```

Or with keyboard customization:

```powershell
./run.ps1 -InstallKeyboard
```

That's it! Your development environment is now configured.

---

## What Gets Installed

### Core Tools
- **Scoop** & **Winget** - Package managers
- **Git** & **GitHub CLI** - Version control
- **Node.js LTS** - JavaScript runtime
- **Neovim** - Text editor
- **Starship** - Shell prompt
- **D2** - Type-to-draw diagrams (live-preview in browser via `d2w`)
- **psmux** - tmux-compatible multiplexer for Windows (reads `~/.tmux.conf`)
- **btop4win** - htop-equivalent process/resource monitor (`btop`)

### Development Utilities
- fzf, ripgrep, bat, 7zip, make, cmake

### Applications
- **GlazeWM** - Tiling window manager
- **Zebar** - Status bar
- **PowerToys** - Windows utilities
- **Obsidian** - Note-taking
- **.NET SDK** - Development framework
- **JetBrains Mono Nerd Font**

### Windows Features
- Developer Mode
- WSL 2
- OpenSSH

### Optional
- **Capsicain** - Keyboard customization

---

## Daily Usage

### Managing Dotfiles

Use `dot` instead of `git` to manage your dotfiles:

```powershell
# Check status
dot status

# Add files
dot add .config/powershell/profile.ps1

# Commit changes
dot commit -m "Update PowerShell profile"

# Push to remote
dot push
```

### Available Scripts

All scripts are in `$HOME\scripts`:

| Script | Purpose |
|--------|---------|
| `run.ps1` | Complete setup (recommended for first run) |
| `win.ps1` | Configure Windows development features |
| `gh.ps1` | Set up GitHub SSH authentication |
| `install-packages.ps1` | Install all tools and applications |
| `install-keyboard.ps1` | Install Capsicain keyboard customization |
| `clone-repos.ps1` | Clone your project repositories |
| `setup-nvim-config.ps1` | Set up Neovim configuration |

---

## Requirements

- Windows 10/11
- PowerShell 5.1+
- Administrator privileges
- Internet connection

---

## Troubleshooting

**Profile not loading?**
Restart PowerShell or run `. $PROFILE`

**Scoop install fails?**
Run as Administrator and check your execution policy: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

**SSH key issues?**
Run `./scripts/gh.ps1` to reconfigure GitHub authentication

**GlazeWM not tiling properly?**
Reload config with `glazewm reload` or restart GlazeWM