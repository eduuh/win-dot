$ErrorActionPreference = "Stop"

$bareRepository = Join-Path $HOME "projects\win-dot-bare"

if (-not (Test-Path (Join-Path $bareRepository "HEAD"))) {
    git clone --bare https://github.com/eduuh/win-dot.git $bareRepository
}

git --git-dir="$bareRepository" config status.showUntrackedFiles no
git --git-dir="$bareRepository" config submodule..bin/tmux-workflow.ignore all
git --git-dir="$bareRepository" --work-tree="$HOME" checkout --force
git --git-dir="$bareRepository" --work-tree="$HOME" submodule update --init --recursive

Write-Host "Git dotfiles setup complete. Restart your terminal before using 'dot'." -ForegroundColor Green
