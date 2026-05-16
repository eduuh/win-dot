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

Test-Case 'd2.exe resolvable and reports version' {
    $found = (& cmd /c 'where d2.exe' 2>&1) | Select-Object -First 1
    if (-not $found) { throw "d2.exe not found on PATH" }
    $ver = (& d2 --version 2>&1) -join ' '
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

Test-Case 'psmux picker bindings: T, C-s, C-w' {
    $keys = & psmux list-keys 2>&1
    $t = $keys | Where-Object { $_ -match '^bind-key -T prefix T\s' }
    $cs = $keys | Where-Object { $_ -match '^bind-key -T prefix C-s\s' }
    $cw = $keys | Where-Object { $_ -match '^bind-key -T prefix C-w\s' }
    if (-not $t) { throw 'missing T binding' }
    if (-not $cs) { throw 'missing C-s binding' }
    if (-not $cw) { throw 'missing C-w binding' }
    "T+C-s+C-w bound"
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
$tmuxGuid = '{c0ffee01-d2c0-4e8a-b1a7-7373731ad510}'
$wslGuid  = '{4ff56d04-d9cf-57ea-bae2-ad396374e7e3}'

Test-Case 'Windows Terminal settings.json exists and is valid JSON' {
    if (-not (Test-Path $settings)) { throw "settings.json missing" }
    $obj = Get-Content $settings -Raw | ConvertFrom-Json
    if (-not $obj) { throw "failed to parse" }
    "{0} profiles, default={1}" -f $obj.profiles.list.Count, $obj.defaultProfile
}

Test-Case 'Default profile is powershell-tmux' {
    $obj = Get-Content $settings -Raw | ConvertFrom-Json
    if ($obj.defaultProfile -ne $tmuxGuid) { throw "defaultProfile is $($obj.defaultProfile)" }
    $obj.defaultProfile
}

Test-Case 'Exactly 2 profiles are visible (powershell-tmux + ubuntu-wsl)' {
    $obj = Get-Content $settings -Raw | ConvertFrom-Json
    $visible = $obj.profiles.list | Where-Object { -not $_.hidden }
    $names = ($visible | ForEach-Object { $_.name }) -join ', '
    if ($visible.Count -ne 2) { throw "expected 2, got $($visible.Count): $names" }
    if ($names -notmatch 'powershell-tmux') { throw "missing powershell-tmux: $names" }
    if ($names -notmatch 'ubuntu-wsl') { throw "missing ubuntu-wsl: $names" }
    $names
}

Test-Case 'powershell-tmux uses absolute pwsh path' {
    $obj = Get-Content $settings -Raw | ConvertFrom-Json
    $p = $obj.profiles.list | Where-Object { $_.guid -eq $tmuxGuid }
    if ($p.commandline -notmatch 'C:\\Program Files\\PowerShell') { throw "no abs pwsh path: $($p.commandline)" }
    if ($p.commandline -notmatch 'psmux new-session -A -s main') { throw "no psmux command: $($p.commandline)" }
    'commandline OK'
}

# ---------------------------------------------------------------------------
# 5. PowerShell profile: d2w function
# ---------------------------------------------------------------------------
Test-Case 'PowerShell profile defines d2w function' {
    $profilePath = "$HOME\projects\win-dot\.config\powershell\profile.ps1"
    if (-not (Test-Path $profilePath)) { throw "profile missing" }
    $content = Get-Content $profilePath -Raw
    if ($content -notmatch 'function d2w') { throw "no d2w function defined" }
    "profile.ps1 = $((Get-Item $profilePath).Length) bytes"
}

Test-Case 'd2w runs end-to-end (creates watch server, serves SVG)' {
    # Load the profile into a child pwsh, run d2w in the background, hit the server
    $abs = 'C:\Program Files\PowerShell\7-preview\pwsh.exe'
    $exampleD2 = "$HOME\projects\personal-notes\d2\examples\hello.d2"
    if (-not (Test-Path $exampleD2)) { throw "missing example d2 file" }
    $job = Start-Job -ScriptBlock {
        param($abs, $profilePath, $exampleD2)
        & $abs -NoLogo -NoProfile -Command ". '$profilePath'; d2w '$exampleD2' -Port 8123" *>&1
    } -ArgumentList $abs, "$HOME\projects\win-dot\.config\powershell\profile.ps1", $exampleD2
    try {
        Start-Sleep -Seconds 6
        $r = Invoke-WebRequest -Uri 'http://localhost:8123' -UseBasicParsing -TimeoutSec 5
        if ($r.StatusCode -ne 200) { throw "non-200: $($r.StatusCode)" }
        if ($r.Content -notmatch 'watch\.js') { throw "no watch.js in response (not D2 watch server)" }
        "200 OK, $($r.Content.Length) bytes, watch.js present"
    } finally {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        Get-Process -Name d2 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------------------------
# 6. install-packages.ps1 syntax + content
# ---------------------------------------------------------------------------
Test-Case 'install-packages.ps1 parses as valid PowerShell' {
    $f = "$HOME\projects\win-dot\scripts\install-packages.ps1"
    $tokens = $null; $errs = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tokens, [ref]$errs) | Out-Null
    if ($errs.Count -gt 0) { throw "$($errs.Count) parse errors: $(($errs | Select-Object -First 3 | ForEach-Object { $_.Message }) -join '; ')" }
    "$($tokens.Count) tokens, 0 errors"
}

Test-Case 'install-packages.ps1 installs d2, psmux, pwsh PATH fix' {
    $c = Get-Content "$HOME\projects\win-dot\scripts\install-packages.ps1" -Raw
    if ($c -notmatch '"d2"') { throw "no d2 in scoop packages" }
    if ($c -notmatch 'marlocarlo\.psmux') { throw "no modern psmux install" }
    if ($c -notmatch 'PowerShell\\\\7-preview' -and $c -notmatch 'PowerShell\\7-preview') { throw "no pwsh PATH fix" }
    'd2 + psmux + pwsh PATH fix present'
}

# ---------------------------------------------------------------------------
# 7. Tracked-files drift check
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

Test-Case 'helix config.toml and languages.toml load (hx --health)' {
    if (-not (Get-Command hx -ErrorAction SilentlyContinue)) { throw "hx not on PATH" }
    $health = & hx --health 2>&1 | Out-String
    if ($health -notmatch 'Config file:\s+\S') { throw "hx --health missing Config file line" }
    if ($health -match 'Config file:\s+default') { throw "hx is using default config; tracked config.toml not picked up" }
    if ($health -match 'Language file:\s+default') { throw "hx is using default languages.toml" }
    'config + languages picked up'
}

Test-Case 'tracked helix config matches live AppData/Roaming/helix' {
    foreach ($name in 'config.toml','languages.toml') {
        $live = Join-Path "$HOME\AppData\Roaming\helix" $name
        $tracked = Join-Path "$HOME\projects\win-dot\AppData\Roaming\helix" $name
        if (-not (Test-Path $live)) { throw "missing live $name" }
        if (-not (Test-Path $tracked)) { throw "missing tracked $name" }
        $a = Get-FileHash $live -Algorithm SHA256
        $b = Get-FileHash $tracked -Algorithm SHA256
        if ($a.Hash -ne $b.Hash) { throw "$name hashes differ" }
    }
    'config.toml + languages.toml in sync'
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
