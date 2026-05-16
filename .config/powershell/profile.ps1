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

function Invoke-EdgeBookmark {
    <#
    .SYNOPSIS
        Fuzzy-pick a Microsoft Edge bookmark with fzf and open it.

    .DESCRIPTION
        Reads the Edge "Bookmarks" JSON for the given profile
        (Default by default), flattens every folder into a path,
        and pipes the result through fzf. The selected bookmark is
        opened in Edge — or, with switches, copied to the clipboard,
        returned to the pipeline, or just listed.

    .EXAMPLE
        go fav                         # pick + open in Edge

    .EXAMPLE
        go fav -CopyUrl                # copy the URL to clipboard

    .EXAMPLE
        go fav -EdgeProfile 'Profile 1'

    .EXAMPLE
        go fav -List | Where-Object Path -like 'bookmark_bar/Work*'

    .EXAMPLE
        go fav -Edit                   # open Edge's favorites manager
    #>
    [CmdletBinding()]
    param(
        [string]$EdgeProfile = 'Default',
        [switch]$CopyUrl,
        [switch]$PrintUrl,
        [switch]$List,
        [switch]$Edit
    )

    if ($Edit) {
        # Open Edge's native favorites manager so the user can rename / move /
        # delete bookmarks safely. We deliberately do not mutate the Bookmarks
        # JSON ourselves — Edge's checksum + file-lock semantics make in-place
        # edits fragile and likely to be silently reverted.
        if (Get-Command msedge -ErrorAction SilentlyContinue) {
            Start-Process 'msedge' 'edge://favorites/'
        } else {
            Start-Process 'edge://favorites/'
        }
        return
    }

    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Host "fzf is not installed. Install with: scoop install fzf" -ForegroundColor Yellow
        return
    }

    $bookmarksPath = Join-Path $env:LOCALAPPDATA "Microsoft\Edge\User Data\$EdgeProfile\Bookmarks"
    if (-not (Test-Path -LiteralPath $bookmarksPath)) {
        Write-Host "Edge bookmarks file not found: $bookmarksPath" -ForegroundColor Yellow
        return
    }

    try {
        $json = Get-Content -LiteralPath $bookmarksPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Host "Failed to parse Edge bookmarks JSON: $_" -ForegroundColor Yellow
        return
    }

    $items = [System.Collections.Generic.List[object]]::new()

    function Add-EdgeBookmarkNode {
        param($Node, $Path)
        if (-not $Node -or -not $Node.children) { return }
        foreach ($child in $Node.children) {
            if ($child.type -eq 'folder') {
                Add-EdgeBookmarkNode -Node $child -Path "$Path/$($child.name)"
            } elseif ($child.type -eq 'url') {
                $items.Add([pscustomobject]@{
                    Name = [string]$child.name
                    Url  = [string]$child.url
                    Path = $Path.TrimStart('/')
                })
            }
        }
    }

    foreach ($rootKey in @('bookmark_bar', 'other', 'synced')) {
        $root = $json.roots.$rootKey
        if ($root) { Add-EdgeBookmarkNode -Node $root -Path $rootKey }
    }

    if (-not $items.Count) {
        Write-Host "No bookmarks found in profile '$EdgeProfile'." -ForegroundColor Yellow
        return
    }

    if ($List) { return $items }

    # Tab-separated columns: Name<TAB>Path<TAB>URL. Strip embedded tabs/newlines
    # so fzf's field splitting stays sane.
    $clean = { param($s) ($s -replace "[`t`r`n]", ' ') }
    $tab   = [char]9
    $lines = foreach ($it in $items) {
        (& $clean $it.Name) + $tab + (& $clean $it.Path) + $tab + (& $clean $it.Url)
    }

    $selected = $lines | & fzf `
        --delimiter $tab `
        --with-nth=1,2 `
        --preview "echo {3}" `
        --preview-window=down:3:wrap `
        --header "Enter: open in Edge  |  Ctrl-E: edit links in Edge's favorites manager" `
        --bind "ctrl-e:execute-silent(start edge://favorites/)+abort" `
        --prompt="go fav> "
    if (-not $selected) { return }

    $url = ($selected -split $tab)[2]
    if (-not $url) { return }

    if ($CopyUrl)  {
        Set-Clipboard -Value $url
        Write-Host "Copied: $url" -ForegroundColor Green
        return
    }
    if ($PrintUrl) { return $url }

    if (Get-Command msedge -ErrorAction SilentlyContinue) {
        Start-Process 'msedge' $url
    } else {
        Start-Process $url
    }
}

function Get-GoProjectFolders {
    <#
    .SYNOPSIS
        Enumerate one-level directories under $HOME\projects.
    .DESCRIPTION
        Shared source for `go folder` and `go explorer`. Returns an empty
        array (with a friendly message) if the projects root does not exist.
    #>
    [CmdletBinding()]
    param()
    $root = Join-Path $HOME 'projects'
    if (-not (Test-Path -LiteralPath $root)) {
        Write-Host "Projects root not found: $root" -ForegroundColor Yellow
        return @()
    }
    Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue
}

function Invoke-GoFolder {
    [CmdletBinding()]
    param()
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Host "fzf is not installed. Install with: scoop install fzf" -ForegroundColor Yellow
        return
    }
    $folders = @(Get-GoProjectFolders)
    if (-not $folders -or $folders.Count -eq 0) { return }
    $tab = [char]9
    $lines = $folders | ForEach-Object { $_.Name + $tab + $_.FullName }
    $selected = $lines | & fzf --delimiter $tab --with-nth=1 --prompt='go folder> '
    if (-not $selected) { return }
    $path = ($selected -split $tab)[1]
    if ($path) { Set-Location -LiteralPath $path }
}

function Invoke-GoExplorer {
    [CmdletBinding()]
    param()
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Host "fzf is not installed. Install with: scoop install fzf" -ForegroundColor Yellow
        return
    }
    $folders = @(Get-GoProjectFolders)
    if (-not $folders -or $folders.Count -eq 0) { return }
    $tab = [char]9
    $lines = $folders | ForEach-Object { $_.Name + $tab + $_.FullName }
    $selected = $lines | & fzf --delimiter $tab --with-nth=1 --prompt='go explorer> '
    if (-not $selected) { return }
    $path = ($selected -split $tab)[1]
    if ($path) { Start-Process explorer.exe -ArgumentList $path }
}

function Invoke-GoApp {
    <#
    .SYNOPSIS
        Fuzzy-pick a Start Menu app (classic + UWP) and launch it.
    .DESCRIPTION
        Uses Get-StartApps so UWP/AppX apps like Clipchamp, Settings, Photos
        — which have no .lnk entries under Start Menu\Programs — are included.
        Launch path is shell:AppsFolder\<AppID>, which works uniformly for
        both classic Win32 and modern UWP apps.
    #>
    [CmdletBinding()]
    param()
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Host "fzf is not installed. Install with: scoop install fzf" -ForegroundColor Yellow
        return
    }
    if (-not (Get-Command Get-StartApps -ErrorAction SilentlyContinue)) {
        Write-Host "Get-StartApps not available (Windows 10+ required)." -ForegroundColor Yellow
        return
    }
    $apps = @(Get-StartApps)
    if (-not $apps -or $apps.Count -eq 0) {
        Write-Host "No Start Menu apps found." -ForegroundColor Yellow
        return
    }
    $tab    = [char]9
    $clean  = { param($s) ([string]$s -replace "[`t`r`n]", ' ') }
    $lines  = foreach ($a in $apps) { (& $clean $a.Name) + $tab + (& $clean $a.AppID) }
    $selected = $lines | & fzf --delimiter $tab --with-nth=1 --prompt='go app> '
    if (-not $selected) { return }
    $appId = ($selected -split $tab)[1]
    if ($appId) { Start-Process "shell:AppsFolder\$appId" }
}

function Invoke-GhCodespaceAuthRefresh {
    <#
    .SYNOPSIS
        Run `gh auth refresh -h github.com -s codespace` interactively.
    .DESCRIPTION
        Triggers gh's device-code flow so the user can grant the `codespace`
        OAuth scope without remembering the exact command. Returns $true on
        success, $false otherwise.
    #>
    [CmdletBinding()]
    param()
    Write-Host "Refreshing gh auth with 'codespace' scope (one-time device-code prompt)..." -ForegroundColor Cyan
    & gh auth refresh -h github.com -s codespace
    return ($LASTEXITCODE -eq 0)
}

function Invoke-GoCodespace {
    <#
    .SYNOPSIS
        Fuzzy-pick a GitHub Codespace and open it in local VS Code.
    .DESCRIPTION
        Requires `gh` with codespaces access. If `gh codespace list` or
        `gh codespace code` fails (typically because the token lacks the
        `codespace` scope), automatically runs
        `gh auth refresh -h github.com -s codespace` and retries once, so
        the user doesn't have to remember the magic command.
    #>
    [CmdletBinding()]
    param()
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Host "fzf is not installed. Install with: scoop install fzf" -ForegroundColor Yellow
        return
    }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "gh is not installed. Install with: scoop install gh" -ForegroundColor Yellow
        return
    }

    # Try once. If gh codespace list fails, assume an auth/scope issue,
    # refresh interactively, and retry exactly once.
    $json = & gh codespace list --json name,repository,state 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $json) {
        if (-not (Invoke-GhCodespaceAuthRefresh)) {
            Write-Host "Auth refresh failed. Try 'gh auth login' manually, then re-run 'go cs'." -ForegroundColor Yellow
            return
        }
        $json = & gh codespace list --json name,repository,state 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $json) {
            Write-Host "Still couldn't list codespaces after auth refresh." -ForegroundColor Yellow
            return
        }
    }

    try {
        $cs = @($json | ConvertFrom-Json)
    } catch {
        Write-Host "Failed to parse codespace list: $_" -ForegroundColor Yellow
        return
    }
    if (-not $cs -or $cs.Count -eq 0) {
        Write-Host "No codespaces found. Create one with: gh codespace create" -ForegroundColor Yellow
        return
    }

    $tab   = [char]9
    $clean = { param($s) ([string]$s -replace "[`t`r`n]", ' ') }
    $lines = foreach ($c in $cs) {
        (& $clean $c.name) + $tab + (& $clean $c.repository) + $tab + (& $clean $c.state)
    }
    $selected = $lines | & fzf --delimiter $tab --with-nth=2,3,1 --prompt='go cs> '
    if (-not $selected) { return }
    $name = ($selected -split $tab)[0]
    if (-not $name) { return }

    & gh codespace code -c $name
    if ($LASTEXITCODE -ne 0) {
        # Rare: list succeeded but code step failed on auth. Refresh + retry once.
        if (Invoke-GhCodespaceAuthRefresh) {
            & gh codespace code -c $name
        }
    }
}

function Invoke-GoView {
    <#
    .SYNOPSIS
        Open a URL in a clean, throwaway Edge window with most features disabled.
    .DESCRIPTION
        Useful for "just show me this page" — screenshots, demos, or isolating
        whether a site is broken by your installed extensions/profile state.

        Defaults:
          * Chromeless app-style window (no tabs, no address bar)
          * Throwaway user-data-dir under $env:TEMP (no cookies/history/extensions reused)
          * Background networking, sync, translate, and shopping/Copilot features off

        Switches:
          -Window       Full window (tabs + address bar) instead of --app.
          -Guest        Use Edge guest mode instead of a temp user-data-dir.
          -KeepProfile  Reuse your default Edge profile (cookies/login persist).
                        Implies the same feature disables but no isolation.
    .EXAMPLE
        go view https://example.com
    .EXAMPLE
        go view https://github.com -Window
    .EXAMPLE
        go view https://mail.google.com -KeepProfile
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Url,
        [switch] $Window,
        [switch] $Guest,
        [switch] $KeepProfile
    )

    if ($Url -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') {
        $Url = "https://$Url"
    }

    $edge = Get-Command msedge -ErrorAction SilentlyContinue
    if (-not $edge) {
        $candidates = @(
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        )
        $edgePath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $edgePath) {
            Write-Host "Could not find msedge.exe on PATH or in Program Files." -ForegroundColor Yellow
            return
        }
    } else {
        $edgePath = $edge.Source
    }

    $disabledFeatures = @(
        'msEdgeShoppingFeatures',
        'msImplicitSignin',
        'msSidebar',
        'msEdgeCopilotPagePromo',
        'msEdgeBingChatEntry'
    ) -join ','

    $argList = @(
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-extensions',
        '--disable-sync',
        '--disable-translate',
        '--disable-background-networking',
        '--disable-background-mode',
        '--disable-component-update',
        "--disable-features=$disabledFeatures"
    )

    if ($Guest) {
        $argList += '--guest'
    } elseif (-not $KeepProfile) {
        $stamp   = [Guid]::NewGuid().ToString('N').Substring(0, 8)
        $dataDir = Join-Path $env:TEMP "edge-view-$stamp"
        $argList += "--user-data-dir=$dataDir"
    }

    if ($Window) {
        $argList += $Url
    } else {
        $argList += "--app=$Url"
    }

    Start-Process -FilePath $edgePath -ArgumentList $argList | Out-Null
}

# Single source of truth for `go` subcommands. Adding one is a one-line edit
# here — the dispatcher, help text, and tab completion all read from this map.
$script:GoSubcommands = [ordered]@{
    fav      = @{ Handler = 'Invoke-EdgeBookmark'; Description = 'Fuzzy-pick an Edge bookmark and open it' }
    folder   = @{ Handler = 'Invoke-GoFolder';     Description = 'Fuzzy-pick a folder under ~/projects and cd into it' }
    explorer = @{ Handler = 'Invoke-GoExplorer';   Description = 'Fuzzy-pick a folder under ~/projects and open it in Explorer' }
    app      = @{ Handler = 'Invoke-GoApp';        Description = 'Fuzzy-pick a Start Menu app (classic + UWP) and launch it' }
    code     = @{ Handler = 'Invoke-GoCodespace';  Description = 'Fuzzy-pick a GitHub Codespace and open it in VS Code'; Aliases = @('cs') }
    view     = @{ Handler = 'Invoke-GoView';       Description = 'Open a URL in a clean throwaway Edge window (-Window, -Guest, -KeepProfile)' }
}

function Resolve-GoSubcommand {
    param([string]$Name)
    if (-not $Name) { return $null }
    if ($script:GoSubcommands.Contains($Name)) { return $Name }
    foreach ($k in $script:GoSubcommands.Keys) {
        $aliases = $script:GoSubcommands[$k].Aliases
        if ($aliases -and ($aliases -contains $Name)) { return $k }
    }
    return $null
}

function Show-GoHelp {
    Write-Host "go — fzf launcher for bookmarks, folders, apps, and codespaces" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: go <subcommand> [args...]"
    Write-Host ""
    Write-Host "Subcommands:"
    foreach ($k in $script:GoSubcommands.Keys) {
        $entry = $script:GoSubcommands[$k]
        $label = $k
        if ($entry.Aliases) { $label = "$k (" + ($entry.Aliases -join ', ') + ')' }
        Write-Host ("  {0,-14} {1}" -f $label, $entry.Description)
    }
}

function Invoke-Go {
    <#
    .SYNOPSIS
        Subcommand dispatcher for the `go` launcher.
    .EXAMPLE
        go              # show help
        go fav          # pick a bookmark
        go folder       # cd into a project
        go explorer     # open a project folder in Explorer
        go app          # launch a Start Menu app (e.g. Clipchamp)
        go code         # open a GitHub Codespace (alias: go cs)
        go view <url>   # open a URL in a clean throwaway Edge window
    #>
    [CmdletBinding()]
    [Alias('go')]
    param(
        [Parameter(Position = 0)]
        [string]$Subcommand,

        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Rest
    )

    if (-not $Subcommand -or $Subcommand -in @('help','-h','--help')) {
        Show-GoHelp
        return
    }

    $resolved = Resolve-GoSubcommand $Subcommand
    if (-not $resolved) {
        Write-Warning "Unknown subcommand '$Subcommand'"
        Show-GoHelp
        return
    }

    $handler = $script:GoSubcommands[$resolved].Handler

    if (-not $Rest -or $Rest.Count -eq 0) {
        & $handler
        return
    }

    # PowerShell strips -Name semantics when forwarding via [string[]] splat,
    # so reconstruct a hashtable of named args by introspecting the handler's
    # parameter metadata (which params are [switch]).
    $handlerInfo = Get-Command $handler -ErrorAction Stop
    $switchNames = @($handlerInfo.Parameters.Values |
        Where-Object { $_.SwitchParameter } |
        ForEach-Object { $_.Name })

    $named      = @{}
    $positional = @()
    $i = 0
    while ($i -lt $Rest.Count) {
        $token = $Rest[$i]
        if ($token -match '^-(?<n>[A-Za-z_][A-Za-z0-9_]*)$') {
            $name      = $Matches['n']
            $isSwitch  = $switchNames | Where-Object { $_ -like "$name*" } | Select-Object -First 1
            if ($isSwitch) {
                $named[$isSwitch] = $true
                $i += 1
            } elseif ($i + 1 -lt $Rest.Count) {
                $named[$name] = $Rest[$i + 1]
                $i += 2
            } else {
                $named[$name] = $true
                $i += 1
            }
        } else {
            $positional += $token
            $i += 1
        }
    }

    & $handler @named @positional
}

# Tab completion for `go <Tab>` and `Invoke-Go -Subcommand <Tab>`. Driven by
# the same $script:GoSubcommands map so a new subcommand auto-completes.
$goCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $entries = foreach ($k in $script:GoSubcommands.Keys) {
        [pscustomobject]@{ Name = $k; Desc = $script:GoSubcommands[$k].Description }
        foreach ($a in @($script:GoSubcommands[$k].Aliases)) {
            if ($a) {
                [pscustomobject]@{ Name = $a; Desc = "$($script:GoSubcommands[$k].Description) (alias of $k)" }
            }
        }
    }
    $entries |
        Where-Object { $_.Name -like "$wordToComplete*" } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_.Name, $_.Name, 'ParameterValue', $_.Desc
            )
        }
}
foreach ($cmd in 'go', 'Invoke-Go') {
    Register-ArgumentCompleter -CommandName $cmd -ParameterName Subcommand -ScriptBlock $goCompleter
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
