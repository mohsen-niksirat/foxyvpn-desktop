# Builds the Windows app and its core and puts them over the installed copy
# (the Setup's per-user install, in the folder chosen at install time; by
# default %LOCALAPPDATA%\Programs\Firefox VPN Client), to try a change
# without making and running an installer:
# - a running copy is closed first: the app by its process id, after which
#   its core restores the system proxy and exits, as when the app quits;
# - user-data in the install folder (accounts, settings, logs) is never
#   touched;
# - a copy that was running is started again, and connected again if it
#   was connected.
# The version is "major.minor.patch" from app\pubspec.yaml, or -AppVersion: an
# older one makes the app find the latest release as an update, to try the
# update notices. Nothing is written to dist\; scripts\build-windows.ps1
# makes the release files.
#Requires -Version 7
param([string]$AppVersion)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$match = Select-String -Path "$root\app\pubspec.yaml" -Pattern '^version:\s*(\d+\.\d+\.\d+)'
if (-not $match) { throw 'No version in app\pubspec.yaml' }
$version = $match.Matches[0].Groups[1].Value
if ($AppVersion) { $version = $AppVersion }

# The install folder, from the Setup's uninstall entry (AppId in
# app\windows\installer\firefox-vpn.iss).
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{6F3A2C1E-9B4D-4E7A-8C21-5D0F7B9E4A63}_is1'
$dir = (Get-ItemProperty $uninstallKey -ErrorAction SilentlyContinue).InstallLocation
if (-not $dir) { throw 'Firefox VPN is not installed for this user; run the Setup once' }
$dir = $dir.TrimEnd('\')
$appExe = "$dir\firefox-vpn.exe"
$dataDir = "$dir\user-data"

# The same build as scripts\build-windows.ps1, the core into app\build.
Push-Location "$root\app"
try {
    foreach ($stale in "build\flutter_assets", "build\windows\x64\runner\Release\data\flutter_assets") {
        if (Test-Path $stale) { Remove-Item -LiteralPath $stale -Recurse -Force }
    }
    flutter pub get --offline
    if ($LASTEXITCODE -ne 0) { flutter pub get }
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
    flutter build windows --release --no-pub --dart-define=APP_VERSION=$version
    if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
} finally { Pop-Location }
$release = "$root\app\build\windows\x64\runner\Release"
$coreOut = "$root\app\build\installed-core"
Push-Location "$root\core"
try {
    $env:APP_VERSION = $version
    go generate ./cmd/firefox-vpn-core
    if ($LASTEXITCODE -ne 0) { throw 'go generate failed' }
    go build -trimpath -ldflags "-s -w -X github.com/armanlife/firefox-vpn-client/core/internal/version.Current=$version" -o "$coreOut\firefox-vpn-core.exe" ./cmd/firefox-vpn-core
    if ($LASTEXITCODE -ne 0) { throw 'go build failed' }
} finally {
    Remove-Item Env:APP_VERSION -ErrorAction SilentlyContinue
    Pop-Location
}

# The core's API, as the app reaches it: the address from config.json and
# the local token. The token is only sent, never shown.
function Invoke-Core([string]$Method, [string]$Path, [hashtable]$Body) {
    $listen = '127.0.0.1:10820'
    try {
        $config = Get-Content "$dataDir\config.json" -Raw | ConvertFrom-Json
        if ($config.dashboard.listen) { $listen = $config.dashboard.listen }
    } catch {}
    $port = $listen.Substring($listen.LastIndexOf(':') + 1)
    $token = (Get-Content "$dataDir\local-api.token" -Raw).Trim()
    $request = @{
        Method = $Method; Uri = "http://127.0.0.1:$port/api$Path"; TimeoutSec = 5
        Headers = @{ 'X-Local-Token' = $token }
    }
    if ($Body) { $request.Body = $Body | ConvertTo-Json; $request.ContentType = 'application/json' }
    Invoke-RestMethod @request
}

function Get-Installed {
    # Path is read once: it is looked up on each read, and a process that
    # exits in between has none.
    Get-Process | Where-Object { $path = $_.Path; $path -and $path.StartsWith("$dir\", [StringComparison]::OrdinalIgnoreCase) }
}

$running = @(Get-Installed)
$appWasRunning = [bool]($running | Where-Object { $_.Path -ieq $appExe })
$wasOn = $false
if ($running) {
    try { $wasOn = (Invoke-Core GET /status).state.phase -notin 'off', '' } catch {}
    # The app first: its core sees the end of its standard input, restores
    # the system proxy, and exits.
    $running | Where-Object { $_.Path -ieq $appExe } | ForEach-Object { Stop-Process -Id $_.Id -Force }
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Installed) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
    $left = @(Get-Installed)
    if ($left) {
        Write-Warning "Still running after 10 s, stopped by id: $($left.Id -join ', ')"
        $left | ForEach-Object { Stop-Process -Id $_.Id -Force }
        Start-Sleep -Milliseconds 500
    }
}

# Files replaced; extra files and user-data stay. Robocopy retries a file
# that a scanner holds open for a moment.
robocopy $release $dir /E /XD user-data data /XF portable /R:10 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "copying the app failed (robocopy $LASTEXITCODE)" }
# The app's assets exactly as built: an asset removed from the build (an
# old icon, say) must not stay behind and be used.
robocopy "$release\data" "$dir\data" /MIR /R:10 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "copying the app's assets failed (robocopy $LASTEXITCODE)" }
robocopy $coreOut "$dir\core" firefox-vpn-core.exe /R:10 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "copying the core failed (robocopy $LASTEXITCODE)" }
Set-ItemProperty $uninstallKey -Name DisplayVersion -Value $version
Write-Host "Installed $version in $dir"

if ($appWasRunning) {
    # Without the proxy variables a build may have needed: the app's core
    # would inherit them and send its own requests to Mozilla through them.
    # They come back afterwards, for the terminal this script runs in.
    $saved = @{}
    foreach ($name in 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY') {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name)
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
    try {
        Start-Process -FilePath $appExe -WorkingDirectory $dir
        Write-Host 'Started the app again'
        if ($wasOn) {
            # The app's core starts with the proxy off.
            $deadline = (Get-Date).AddSeconds(30)
            $done = $false
            while (-not $done -and (Get-Date) -lt $deadline) {
                Start-Sleep -Seconds 1
                try { Invoke-Core POST /power @{ on = $true } | Out-Null; $done = $true } catch {}
            }
            if ($done) { Write-Host 'Connected again' } else { Write-Warning 'The app did not answer; connect by hand' }
        }
    } finally {
        foreach ($name in $saved.Keys) {
            if ($null -ne $saved[$name]) { Set-Item "Env:$name" $saved[$name] }
        }
    }
}
# Not robocopy's code, where 1 means "files copied".
exit 0
