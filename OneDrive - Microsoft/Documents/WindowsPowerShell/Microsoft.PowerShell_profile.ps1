# Load local profile (not synced to OneDrive)
$localProfile = "$HOME\.config\powershell\profile.ps1"
if (Test-Path $localProfile) {
    . $localProfile
}
