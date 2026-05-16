# Bootstrap or attach the default psmux session.
#
# Layout:
#   window 1: notes  (helix on ~/projects/branch-notes-work)
#   window 2: htop   (btop4win running in the foreground)
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

# --- Where work branch-notes live ----------------------------------------
$notesDir = Join-Path $HOME "projects\branch-notes-work"

# --- Create session if missing --------------------------------------------
& $psmux has-session -t $Name 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {

    # Window 1: notes — helix on work branch-notes if both exist, else shell.
    if ($hx -and (Test-Path $notesDir)) {
        & $psmux new-session -d -s $Name -n notes -c $notesDir $hx "."
    } else {
        if (-not $hx)   { Write-Host "helix not found; window 1 will be a plain shell." -ForegroundColor Yellow }
        if (-not (Test-Path $notesDir)) { Write-Host "branch-notes dir missing ($notesDir); window 1 will be a plain shell." -ForegroundColor Yellow }
        & $psmux new-session -d -s $Name -n notes
    }

    # Window 2: htop — only if btop is available.
    if ($btop) {
        & $psmux new-window -t "${Name}:" -n htop $btop
    }

    # Land on the notes window when we attach.
    & $psmux select-window -t "${Name}:notes" 2>&1 | Out-Null
}

# --- Attach ---------------------------------------------------------------
& $psmux attach -t $Name

