<#
.SYNOPSIS
  Installs Desktop + Start Menu shortcuts that open Windows Terminal with two tabs:
    1. powershell-tmux (focused)
    2. ubuntu-wsl

.NOTES
  Idempotent: overwrites any existing "Terminal.lnk" with the same name.
  Run from anywhere:
    pwsh -ExecutionPolicy Bypass -File install-shortcuts.ps1
#>

[CmdletBinding()]
param(
    [string]$ShortcutName = 'Terminal.lnk'
)

$ErrorActionPreference = 'Stop'

$wt = (Get-Command wt.exe -ErrorAction SilentlyContinue)?.Source
if (-not $wt) { $wt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe' }
if (-not (Test-Path $wt)) {
    throw "wt.exe not found. Install Windows Terminal first."
}

$arguments = 'new-tab -p "powershell-tmux" `; new-tab -p "ubuntu-wsl" `; focus-tab -t 0'

$targets = @(
    [PSCustomObject]@{
        Name = 'Desktop'
        Path = Join-Path ([Environment]::GetFolderPath('Desktop')) $ShortcutName
    },
    [PSCustomObject]@{
        Name = 'Start Menu'
        Path = Join-Path ([Environment]::GetFolderPath('Programs')) $ShortcutName
    }
)

$shell = New-Object -ComObject WScript.Shell
foreach ($t in $targets) {
    if (Test-Path $t.Path) { Remove-Item $t.Path -Force }
    $sc = $shell.CreateShortcut($t.Path)
    $sc.TargetPath       = $wt
    $sc.Arguments        = $arguments
    $sc.WorkingDirectory = $env:USERPROFILE
    $sc.IconLocation     = "$wt,0"
    $sc.WindowStyle      = 1
    $sc.Description      = 'Windows Terminal: powershell-tmux + ubuntu-wsl tabs'
    $sc.Save()
    Write-Host "Created $($t.Name) shortcut: $($t.Path)"
}

Write-Host "Done."
