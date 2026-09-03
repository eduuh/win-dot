# win-dot

Windows-side configuration: PowerShell profile, Windows Terminal, GlazeWM,
VS Code, keyboard, and the `.wslconfig` that sizes the WSL VM.

## Where this repo lives

It has to sit on the **Windows filesystem** — everything here is read by Windows
applications, which cannot see into the WSL filesystem in any useful way.

There are two ways it gets there, and they land in the **same directory**:

| you start from | what clones it | path |
|---|---|---|
| Windows | the PowerShell steps below | `$HOME\projects\win-dot` |
| WSL | [`eduuh/dotfiles`](https://github.com/eduuh/dotfiles) `setup.sh` | `/mnt/c/Users/<you>/projects/win-dot` |

Those are the same folder seen from either side, so whichever you run first, the
other is a no-op rather than a second copy. The WSL setup also symlinks
`~/projects/win-dot` at it, so `wt`, `tat` and `bn` list it like any other repo
while the files stay on the Windows side.

In dotfiles that routing comes from naming the repo in **both**
`REGULAR_CLONE_REPOS` and `WINDOWS_CLONE_REPOS` — the first makes it a flat
clone, the second redirects that clone to the Windows filesystem. Either list on
its own silently puts it inside WSL, where Windows tooling cannot reach it.

## `.wslconfig`

`.wslconfig` in this repo is the source of truth for the WSL VM's resources, but
WSL reads it from `C:\Users\<you>\.wslconfig`, so it has to be copied there.
It is only read when the VM boots — after changing it, run `wsl --shutdown` from
Windows and start a new WSL session, or the old limits stay in force.

Only settings that actually deviate from the WSL2 defaults belong in it. The
defaults are 50% of host RAM and every logical processor, so a `processors=`
line is normally redundant — and an over-large value is clamped silently, which
makes the file look configured when it is not.

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

# 3. Download win-dot — skip if the WSL dotfiles setup already cloned it here
git clone https://github.com/eduuh/win-dot.git $HOME\projects\win-dot

# 4. Configure Windows (opens an Administrator prompt)
& "$HOME\projects\win-dot\scripts\run.ps1"

# 5. Install packages in this non-Administrator window
& "$HOME\projects\win-dot\scripts\install.ps1"

# 6. Set up the dot command
& "$HOME\projects\win-dot\scripts\setup-git.ps1"
```

Restart PowerShell after installation.
