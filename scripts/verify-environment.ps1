# Verify-environment.ps1
# End-to-end smoke test for the win-dot scaffold.
# Exits 0 on full pass, non-zero on failure (with a per-check report).

$ErrorActionPreference = 'Continue'

$results = New-Object System.Collections.ArrayList
function Test-Case($name, [scriptblock]$body) {
    Write-Host "▶ $name" -ForegroundColor Cyan
    try {
        $detail = & $body
        Write-Host "  ✅ PASS  $detail" -ForegroundColor Green
        [void]$results.Add([pscustomobject]@{ name = $name; pass = $true; detail = "$detail" })
    } catch {
        Write-Host "  ❌ FAIL  $($_.Exception.Message)" -ForegroundColor Red
        [void]$results.Add([pscustomobject]@{ name = $name; pass = $false; detail = $_.Exception.Message })
    }
}

# ---------------------------------------------------------------------------
# 1. Tool binaries on disk + resolvable on PATH
# ---------------------------------------------------------------------------
Test-Case 'pwsh.exe resolvable on persisted PATH' {
    $found = (& cmd /c 'where pwsh.exe' 2>&1) | Select-Object -First 1
    if (-not $found -or -not (Test-Path $found)) { throw "pwsh.exe not found via PATH: $found" }
    $found
}

Test-Case 'psmux.exe resolvable on persisted PATH and reports 3.x' {
    $found = (& cmd /c 'where psmux.exe' 2>&1) | Select-Object -First 1
    if (-not $found -or -not (Test-Path $found)) { throw "psmux.exe not found: $found" }
    $ver = (& psmux version 2>&1) -join ' '
    if ($ver -notmatch 'psmux 3\.') { throw "psmux is not 3.x: $ver" }
    "$found ($ver)"
}

# ---------------------------------------------------------------------------
# 2. ~/.tmux.conf loads cleanly into psmux
# ---------------------------------------------------------------------------
Test-Case '~/.tmux.conf exists' {
    if (-not (Test-Path "$HOME\.tmux.conf")) { throw "missing $HOME\.tmux.conf" }
    "{0} bytes" -f (Get-Item "$HOME\.tmux.conf").Length
}

# Reset psmux server for a clean test
& psmux kill-server 2>&1 | Out-Null
Start-Sleep -Seconds 1

Test-Case 'psmux applies prefix=C-Space from .tmux.conf' {
    & psmux new-session -d -s verify 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
    $prefix = ((& psmux show-options -g prefix 2>&1) -join ' ').Trim()
    if ($prefix -notmatch 'C-Space') { throw "prefix is $prefix, expected C-Space" }
    $prefix
}

Test-Case 'psmux applies default-shell=pwsh' {
    $shell = ((& psmux show-options -g default-shell 2>&1) -join ' ').Trim()
    if ($shell -notmatch 'pwsh') { throw "default-shell is $shell" }
    $shell
}

Test-Case 'psmux applies history-limit=100000' {
    $hl = ((& psmux show-options -g history-limit 2>&1) -join ' ').Trim()
    if ($hl -notmatch '100000') { throw "history-limit is $hl" }
    $hl
}

Test-Case 'psmux key binding: prefix v -> split-window -h' {
    $keys = & psmux list-keys 2>&1
    $match = $keys | Where-Object { $_ -match '^bind-key -T prefix v\s' }
    if (-not $match) { throw "no binding for prefix v" }
    "$match"
}

Test-Case 'psmux key binding: prefix s -> split-window -v' {
    $keys = & psmux list-keys 2>&1
    $match = $keys | Where-Object { $_ -match '^bind-key -T prefix s\s' }
    if (-not $match) { throw "no binding for prefix s" }
    "$match"
}

Test-Case 'psmux copy-mode-vi y pipes to clip.exe' {
    $keys = & psmux list-keys 2>&1
    $match = $keys | Where-Object { $_ -match 'copy-mode-vi y\s.*clip\.exe' }
    if (-not $match) { throw "no clip.exe yank binding" }
    "$match"
}

Test-Case 'psmux lazygit popup binding (prefix g)' {
    $keys = & psmux list-keys 2>&1
    $match = $keys | Where-Object { $_ -match '^bind-key -T prefix g\s.*lazygit' }
    if (-not $match) { throw "no lazygit popup binding" }
    "$match"
}

Test-Case 'psmux workflow popup bindings: C-o (tat), o (worktree picker)' {
    # C-s/C-w/T pickers were retired in favour of the tmux-workflow popups.
    $keys = & psmux list-keys 2>&1
    $co = $keys | Where-Object { $_ -match '^bind-key -T prefix C-o\s.*display-popup' }
    $o  = $keys | Where-Object { $_ -match '^bind-key -T prefix o\s.*display-popup' }
    if (-not $co) { throw 'missing C-o tat popup binding' }
    if (-not $o)  { throw 'missing o worktree popup binding' }
    'C-o + o popups bound'
}

Test-Case 'psmux can split + create multiple panes' {
    & psmux split-window -h -t verify 2>&1 | Out-Null
    & psmux split-window -v -t verify 2>&1 | Out-Null
    $count = (& psmux list-panes -t verify 2>&1 | Measure-Object).Count
    if ($count -lt 3) { throw "expected >=3 panes, got $count" }
    "$count panes"
}

& psmux kill-server 2>&1 | Out-Null

# ---------------------------------------------------------------------------
# 3. Launch chain: absolute pwsh.exe -> psmux new-session
# ---------------------------------------------------------------------------
Test-Case 'absolute pwsh.exe launches and resolves psmux' {
    $abs = 'C:\Program Files\PowerShell\7-preview\pwsh.exe'
    if (-not (Test-Path $abs)) { throw "pwsh.exe missing at $abs" }
    $out = & cmd /c "`"$abs`" -NoLogo -NoProfile -Command `"(Get-Command psmux).Source; psmux version`"" 2>&1
    $joined = ($out -join ' ')
    if ($joined -notmatch 'psmux 3\.') { throw "no psmux 3.x in output: $joined" }
    'pwsh -> psmux 3.x OK'
}

Test-Case 'Terminal profile commandline can be invoked end-to-end' {
    & psmux kill-server 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    $abs = 'C:\Program Files\PowerShell\7-preview\pwsh.exe'
    # Run the EXACT command the Terminal profile uses, but with -d so it backgrounds
    & cmd /c "`"$abs`" -NoLogo -NoProfile -Command `"psmux new-session -d -s main; psmux ls`"" 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    $sessions = (& psmux ls 2>&1) -join ' '
    if ($sessions -notmatch 'main:') { throw "session 'main' not created: $sessions" }
    & psmux kill-server 2>&1 | Out-Null
    'session main created via profile command'
}

# ---------------------------------------------------------------------------
# 4. Windows Terminal settings.json
# ---------------------------------------------------------------------------
$settings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
# c0ffee01... is the 'notes' profile (formerly 'powershell-tmux'); it kept its guid
# across the rename. ubuntu-wsl is now the deliberate default profile.
$notesGuid = '{c0ffee01-d2c0-4e8a-b1a7-7373731ad510}'
$wslGuid   = '{4ff56d04-d9cf-57ea-bae2-ad396374e7e3}'

Test-Case 'Windows Terminal settings.json exists and is valid JSON' {
    if (-not (Test-Path $settings)) { throw "settings.json missing" }
    $obj = Get-Content $settings -Raw | ConvertFrom-Json
    if (-not $obj) { throw "failed to parse" }
    "{0} profiles, default={1}" -f $obj.profiles.list.Count, $obj.defaultProfile
}

Test-Case 'Default profile is ubuntu-wsl' {
    $obj = Get-Content $settings -Raw | ConvertFrom-Json
    if ($obj.defaultProfile -ne $wslGuid) { throw "defaultProfile is $($obj.defaultProfile)" }
    $obj.defaultProfile
}

Test-Case 'Exactly 2 profiles are visible (notes + ubuntu-wsl)' {
    $obj = Get-Content $settings -Raw | ConvertFrom-Json
    $visible = $obj.profiles.list | Where-Object { -not $_.hidden }
    $names = ($visible | ForEach-Object { $_.name }) -join ', '
    if ($visible.Count -ne 2) { throw "expected 2, got $($visible.Count): $names" }
    if ($names -notmatch 'notes') { throw "missing notes: $names" }
    if ($names -notmatch 'ubuntu-wsl') { throw "missing ubuntu-wsl: $names" }
    $names
}

Test-Case 'notes profile launches PowerShell' {
    $obj = Get-Content $settings -Raw | ConvertFrom-Json
    $p = $obj.profiles.list | Where-Object { $_.guid -eq $notesGuid }
    if (-not $p) { throw "notes profile ($notesGuid) not found" }
    if ($p.name -ne 'notes') { throw "guid $notesGuid is named '$($p.name)', expected 'notes'" }
    if ($p.commandline -notmatch '\bpwsh\.exe\b') { throw "notes commandline does not launch pwsh: $($p.commandline)" }
    "commandline: $($p.commandline)"
}

# ---------------------------------------------------------------------------
# 5. install-packages.ps1 syntax + content
# ---------------------------------------------------------------------------
Test-Case 'install-packages.ps1 parses as valid PowerShell' {
    $f = "$HOME\projects\win-dot\scripts\install-packages.ps1"
    $tokens = $null; $errs = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tokens, [ref]$errs) | Out-Null
    if ($errs.Count -gt 0) { throw "$($errs.Count) parse errors: $(($errs | Select-Object -First 3 | ForEach-Object { $_.Message }) -join '; ')" }
    "$($tokens.Count) tokens, 0 errors"
}

Test-Case 'install-packages.ps1 installs psmux and fixes pwsh PATH' {
    $c = Get-Content "$HOME\projects\win-dot\scripts\install-packages.ps1" -Raw
    if ($c -notmatch 'marlocarlo\.psmux') { throw "no modern psmux install" }
    if ($c -notmatch 'PowerShell\\\\7-preview' -and $c -notmatch 'PowerShell\\7-preview') { throw "no pwsh PATH fix" }
    'psmux + pwsh PATH fix present'
}

# ---------------------------------------------------------------------------
# 6. Tracked-files drift check
# ---------------------------------------------------------------------------
Test-Case 'tracked .tmux.conf in win-dot matches live ~/.tmux.conf' {
    $a = Get-FileHash "$HOME\.tmux.conf" -Algorithm SHA256
    $b = Get-FileHash "$HOME\projects\win-dot\.tmux.conf" -Algorithm SHA256
    if ($a.Hash -ne $b.Hash) { throw "hashes differ" }
    $a.Hash.Substring(0,12)
}

Test-Case 'tracked Terminal settings.json matches live settings.json' {
    $live = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $tracked = "$HOME\projects\win-dot\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $a = Get-FileHash $live -Algorithm SHA256
    $b = Get-FileHash $tracked -Algorithm SHA256
    if ($a.Hash -ne $b.Hash) { throw "hashes differ" }
    $a.Hash.Substring(0,12)
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
$pass = ($results | Where-Object { $_.pass }).Count
$fail = ($results | Where-Object { -not $_.pass }).Count

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Yellow
Write-Host "  Verification: $pass passed, $fail failed" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
Write-Host ("=" * 70) -ForegroundColor Yellow

if ($fail -gt 0) {
    Write-Host ""
    Write-Host "Failures:" -ForegroundColor Red
    $results | Where-Object { -not $_.pass } | ForEach-Object {
        Write-Host "  ❌ $($_.name)" -ForegroundColor Red
        Write-Host "     $($_.detail)" -ForegroundColor DarkGray
    }
    exit 1
}
exit 0
