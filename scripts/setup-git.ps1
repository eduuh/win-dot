$ErrorActionPreference = "Stop"

# `dot` is plain git pointed at this repo's git dir with $HOME as the work tree,
# so there is one clone, not a separate bare copy.
$repository = Join-Path $HOME "projects\win-dot"
$gitDirectory = Join-Path $repository ".git"

if (-not (Test-Path $gitDirectory)) {
    git clone https://github.com/eduuh/win-dot.git $repository
}

git --git-dir="$gitDirectory" config submodule..bin/tmux-workflow.ignore all
git --git-dir="$gitDirectory" --work-tree="$HOME" checkout --force
git --git-dir="$gitDirectory" --work-tree="$HOME" submodule update --init --recursive

Write-Host "Git dotfiles setup complete. Restart your terminal before using 'dot'." -ForegroundColor Green
