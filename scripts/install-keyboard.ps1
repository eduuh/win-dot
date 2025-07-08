# Capsicain Keyboard Setup Script

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Use ~/projects/keyboard folder
$homeDir = [Environment]::GetFolderPath('UserProfile')
$keyboardDir = Join-Path $homeDir "projects\keyboard"

Write-Host "Setting up Capsicain in $keyboardDir..."

if (-not (Test-Path $keyboardDir)) {
    New-Item -ItemType Directory -Path $keyboardDir -Force | Out-Null
    Write-Host "Created $keyboardDir"
}

# Clone Capsicain repository first
$repoUrl = "https://github.com/eduuh/capsicain.git"
$repoPath = Join-Path $keyboardDir "repo"

if (-not (Test-Path $repoPath)) {
    Write-Host "Cloning Capsicain repository..."
    git clone $repoUrl $repoPath
    Write-Host "Repository cloned to $repoPath"
}
else {
    Write-Host "Repository already exists, updating..."
    Push-Location $repoPath
    git pull
    Pop-Location
}

# Also download and extract the latest release
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$apiUrl = "https://api.github.com/repos/eduuh/capsicain/releases/latest"
$release = Invoke-RestMethod -Uri $apiUrl
$version = $release.tag_name
$asset = $release.assets | Where-Object { $_.name -like "*capsicain-release*.zip" } | Select-Object -ExpandProperty browser_download_url -First 1

if (-not $asset) {
    $version = "v0.9.13"
    $asset = "https://github.com/eduuh/capsicain/releases/download/$version/capsicain-release.zip"
    Write-Host "Fallback to $version"
}
else {
    Write-Host "Latest Capsicain version: $version"
}

$releasePath = Join-Path $keyboardDir "release"
if (-not (Test-Path $releasePath)) {
    New-Item -ItemType Directory -Path $releasePath -Force | Out-Null
}

$zipPath = Join-Path $releasePath "capsicain-release.zip"
Write-Host "Downloading release $version to $zipPath..."
Invoke-WebRequest -Uri $asset -OutFile $zipPath
Write-Host "Extracting to $releasePath..."
Expand-Archive -Path $zipPath -DestinationPath $releasePath -Force
Remove-Item $zipPath -Force
Write-Host "Capsicain $version installed to $releasePath"

# Set Capsicain to run at Windows startup
Write-Host "Setting up Capsicain to run at Windows startup..."
$RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$AppName = "Capsicain"
$AppPath = Join-Path $releasePath "capsicain.exe"

# Ensure the exe exists
if (Test-Path $AppPath) {
    # Set the registry key to run Capsicain at startup
    Set-ItemProperty -Path $RegPath -Name $AppName -Value "`"$AppPath`""
    Write-Host "✅ Capsicain has been set to run at Windows startup"
}
else {
    Write-Host "❌ Warning: Could not find capsicain.exe at $AppPath"
    Write-Host "   Please set up startup manually after installation"
}

Write-Host "✅ Capsicain setup complete."
