Set-PSReadlineOption -EditMode vi -BellStyle None

$env:XDG_CONFIG_HOME = "$HOME\.config"

function dot {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Args
    )
    git --git-dir="$HOME/projects/win-dot-bare" --work-tree="$HOME" @Args
}

# Legacy alias for `dot` from the previous profile
Set-Alias -Name dotfiles -Value dot -Scope Global -Force

function setgit {
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
}

# Unix-flavoured aliases for btop4win
if (Get-Command btop -ErrorAction SilentlyContinue) {
    Set-Alias -Name htop -Value btop -Scope Global -Force
    Set-Alias -Name top  -Value btop -Scope Global -Force
}

function d2w {
    <#
    .SYNOPSIS
        Live-preview a D2 diagram in the browser and open it in an editor.

    .DESCRIPTION
        Runs `d2 --watch` on the given file (or a scratch file if none is
        provided), opens the result in the default browser, and launches
        an editor on the source file so you can iterate. Save in the
        editor and the browser refreshes automatically.

        Editor resolution order: -Editor parameter, $env:VISUAL, $env:EDITOR,
        nvim, code, notepad.

    .EXAMPLE
        d2w diagram.d2

    .EXAMPLE
        d2w                       # opens the scratch file
        d2w -Editor code          # force VS Code as editor
        d2w -NoEditor             # watch only, don't launch an editor
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$File,

        [int]$Port = 0,

        [string]$Editor,

        [switch]$NoEditor,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$ExtraArgs
    )

    if (-not (Get-Command d2 -ErrorAction SilentlyContinue)) {
        Write-Host "d2 is not installed. Install it with: scoop install d2" -ForegroundColor Yellow
        return
    }

    if (-not $File) {
        $notesDir = Join-Path $HOME "projects\personal-notes\d2"
        if (Test-Path $notesDir) {
            $scratchDir = $notesDir
        } else {
            $scratchDir = Join-Path $env:TEMP "d2-scratch"
            if (-not (Test-Path $scratchDir)) {
                New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
            }
        }
        $File = Join-Path $scratchDir "scratch.d2"
        if (-not (Test-Path $File)) {
            @(
                "# Scratch D2 file — edit and save to live-reload in the browser.",
                "",
                "hello -> world"
            ) | Set-Content -Path $File -Encoding UTF8
        }
        Write-Host "Using scratch file: $File" -ForegroundColor Cyan
    }

    # Resolve absolute path so editor + d2 see the same file
    $File = (Resolve-Path -LiteralPath $File).Path

    # Launch editor in the background so d2 --watch can take the foreground
    if (-not $NoEditor) {
        $editorCandidates = @($Editor, $env:VISUAL, $env:EDITOR, 'nvim', 'code', 'notepad') |
            Where-Object { $_ -and $_.Trim() }
        $editorCmd = $null
        foreach ($candidate in $editorCandidates) {
            if (Get-Command $candidate -ErrorAction SilentlyContinue) { $editorCmd = $candidate; break }
        }
        if ($editorCmd) {
            Write-Host "Editing with: $editorCmd $File" -ForegroundColor Cyan
            try {
                Start-Process -FilePath $editorCmd -ArgumentList @($File) -ErrorAction Stop | Out-Null
            } catch {
                Write-Host "Could not launch editor '$editorCmd': $_" -ForegroundColor Yellow
            }
        } else {
            Write-Host "No editor found (set `$env:EDITOR or pass -Editor). Skipping." -ForegroundColor Yellow
        }
    }

    $d2Args = @('--watch')
    if ($Port -gt 0) {
        $d2Args += @('--port', "$Port")
    }
    if ($ExtraArgs) {
        $d2Args += $ExtraArgs
    }
    $d2Args += $File

    & d2 @d2Args
}

# Starship prompt — keep last so it can read our env setup
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# Per-machine private overrides (identities, work-only helpers, secrets).
# This file is gitignored — keep anything sensitive there.
$localProfile = Join-Path $HOME ".config\powershell\profile.local.ps1"
if (Test-Path $localProfile) {
    . $localProfile
}
