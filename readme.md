# win-dot

Windows dotfiles, bare-repo style. A fresh machine becomes Windows Terminal → `psmux` → Helix on branch-notes + `btop`, plus pwsh 7 with starship and a `dot` command for the dotfiles themselves.

## Bootstrap

```powershell
# 1. Clone bare
git clone --bare https://github.com/eduuh/win-dot.git $HOME\projects\win-dot-bare

# 2. Define dot, lay files into $HOME
function dot { git --git-dir="$HOME\projects\win-dot-bare" --work-tree="$HOME" @args }
dot config status.showUntrackedFiles no
dot checkout    # back up any conflicting files in $HOME if it errors, then retry

# 3. Install everything (admin)
$HOME\scripts\run.ps1
```

That's it. `run.ps1` orchestrates `win.ps1` → `gh.ps1` → `install.ps1` and ends by writing a PowerShell profile stub at the host's real `$PROFILE` (see [docs/architecture.md](docs/architecture.md)).

## Per-machine private bits

```powershell
Copy-Item $HOME\.gitconfig.local.example                      $HOME\.gitconfig.local
Copy-Item $HOME\.config\powershell\profile.local.ps1.example  $HOME\.config\powershell\profile.local.ps1
```

Both are gitignored. Use them for work identities, tenant IDs, anything you don't want public.

## Commands

| | |
|---|---|
| `dot ...` | git against the dotfiles bare repo (also aliased `dotfiles`) |
| `d2w [file]` | live-preview a [D2](https://d2lang.com) diagram in the browser; opens the file in `$EDITOR` |
| `go <sub>` | fzf launcher: `fav` (Edge bookmarks) · `folder` (cd into `~/projects/*`) · `explorer` (same, in File Explorer) · `app` (Start-Menu apps, classic + UWP) · `cs` (GitHub Codespaces). `go` alone prints help. |
| `htop` / `top` | aliases for `btop` |
| `pwsh -NoProfile -File $HOME\scripts\verify-environment.ps1` | run the 25-check smoke suite |

## Layout

```text
.config/powershell/profile.ps1    # canonical pwsh profile (THE source of truth)
.config/tmux/start-main.ps1       # psmux session launcher (notes / personal / htop)
.config/wt/install-shortcuts.ps1  # creates Desktop + Start Menu "Terminal" shortcut
                                  # (Windows Terminal w/ powershell-tmux + ubuntu-wsl tabs)
.gitconfig                         # global git; [include]s ~/.gitconfig.local
.tmux.conf                         # psmux config (WSL parity)
AppData/.../settings.json          # Windows Terminal: powershell-tmux + ubuntu-wsl
scripts/                           # run.ps1, win.ps1, gh.ps1, install-packages.ps1, …
docs/architecture.md               # the why
```

Helix config lives in its own repo: [eduuh/hx](https://github.com/eduuh/hx). The bootstrap clones it to `~/projects/hx` and runs `install.ps1` from there, so the same config works on Linux / macOS too.

PowerShell `$PROFILE` files are deliberately not tracked — their path depends on OneDrive KFM and the pwsh host. The installer writes a stub at runtime instead.

## Requirements

Windows 10/11 · pwsh 5.1+ (installer pulls 7) · Administrator · GitHub repo access.
