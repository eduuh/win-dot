# Bootstrap or attach the default psmux session.
#
# Layout:
#   window 1: notes     (helix on ~/projects/branch-notes-work)
#   window 2: personal  (helix on ~/projects/personal-notes)
#   window 3: htop      (btop4win running in the foreground)
#
# Idempotent: if the session already exists we just attach.

param(
    [string]$Name = "main"
)

# --- Locate psmux ---------------------------------------------------------
$psmux = (Get-Command psmux -ErrorAction SilentlyContinue).Source
if (-not $psmux) {
    Write-Host "psmux is not on PATH. Install with: winget install marlocarlo.psmux" -ForegroundColor Yellow
    return
}

# --- Locate helix and btop (both optional, with graceful fallback) -------
$hx   = (Get-Command hx   -ErrorAction SilentlyContinue).Source
$btop = (Get-Command btop -ErrorAction SilentlyContinue).Source

# --- Where notes live -----------------------------------------------------
$workNotesDir     = Join-Path $HOME "projects\branch-notes-work"
$personalNotesDir = Join-Path $HOME "projects\personal-notes"

# Helper: helix on a dir if both exist, else a plain shell.
function New-NotesWindow {
    param([string]$WinName, [string]$Dir, [bool]$IsFirst)

    $argsBase = if ($IsFirst) { @('new-session', '-d', '-s', $Name) } else { @('new-window', '-t', "${Name}:") }

    if ($hx -and (Test-Path $Dir)) {
        & $psmux @argsBase -n $WinName -c $Dir $hx "."
    } else {
        if (-not $hx) { Write-Host "helix not found; '$WinName' window will be a plain shell." -ForegroundColor Yellow }
        if (-not (Test-Path $Dir)) { Write-Host "notes dir missing ($Dir); '$WinName' window will be a plain shell." -ForegroundColor Yellow }
        if ($IsFirst) {
            & $psmux @argsBase -n $WinName
        } else {
            & $psmux @argsBase -n $WinName -c $HOME
        }
    }
}

# --- Create session if missing --------------------------------------------
& $psmux has-session -t $Name 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {

    # Window 1: notes (work)
    New-NotesWindow -WinName 'notes'    -Dir $workNotesDir     -IsFirst $true

    # Window 2: personal notes
    New-NotesWindow -WinName 'personal' -Dir $personalNotesDir -IsFirst $false

    # Window 3: htop — only if btop is available.
    if ($btop) {
        & $psmux new-window -t "${Name}:" -n htop $btop
    }

    # Land on the notes window when we attach.
    & $psmux select-window -t "${Name}:notes" 2>&1 | Out-Null
}

# --- Attach ---------------------------------------------------------------
& $psmux attach -t $Name


