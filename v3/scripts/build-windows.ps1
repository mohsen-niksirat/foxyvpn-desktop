# Builds the Windows app with its core into dist\:
# - Firefox-VPN-<version>\: firefox-vpn.exe (the Flutter app) and
#   core\firefox-vpn-core.exe (the Go core, which the app starts with -app),
#   to run here;
# - Firefox-VPN-<version>-Windows-x64.zip: the portable app, a "Firefox VPN"
#   folder to unpack anywhere (or over an older one);
# - Firefox-VPN-<version>-Windows-Setup-x64.exe: the installer
#   (app\windows\installer\firefox-vpn.iss, Inno Setup 6).
# The app keeps its data (accounts, settings, logs) in user-data beside it.
# The zip and the installer are made from a clean copy, never with a
# user-data folder. The version is "major.minor.patch" from app\pubspec.yaml;
# a folder that already exists is refused, because a running build locks its
# files.
# PowerShell 7: Windows PowerShell 5.1 writes zip paths with backslashes.
#Requires -Version 7
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$match = Select-String -Path "$root\app\pubspec.yaml" -Pattern '^version:\s*(\d+\.\d+\.\d+)'
if (-not $match) { throw 'No version in app\pubspec.yaml' }
$version = $match.Matches[0].Groups[1].Value
$out = "$root\dist\Firefox-VPN-$version"
if (Test-Path $out) { throw "$out already exists; bump the version in app\pubspec.yaml" }

# Inno Setup's compiler: ISCC on the PATH, else its usual places.
$iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
if (-not $iscc) {
    $iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $iscc) { throw 'Inno Setup 6 is needed for the installer (winget install JRSoftware.InnoSetup)' }

Push-Location "$root\app"
try {
    # Flutter copies the assets into the build folder but never removes the
    # ones taken out of the app; start from empty copies so old files (such
    # as earlier PNG flags) do not ship.
    foreach ($stale in "build\flutter_assets", "build\windows\x64\runner\Release\data\flutter_assets") {
        if (Test-Path $stale) { Remove-Item -LiteralPath $stale -Recurse -Force }
    }
    # The packages from the local cache when it has them; from pub.dev
    # otherwise (a new machine). pub.dev refuses some requests from some
    # countries (its security advisories), which an offline get avoids.
    flutter pub get --offline
    if ($LASTEXITCODE -ne 0) { flutter pub get }
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
    flutter build windows --release --no-pub --dart-define=APP_VERSION=$version
    if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
} finally { Pop-Location }

New-Item -ItemType Directory -Force "$root\dist" | Out-Null
Copy-Item "$root\app\build\windows\x64\runner\Release" $out -Recurse

Push-Location "$root\core"
try {
    # The executable's icon and version information (Windows resources).
    $env:APP_VERSION = $version
    go generate ./cmd/firefox-vpn-core
    if ($LASTEXITCODE -ne 0) { throw 'go generate failed' }
    go build -trimpath -ldflags "-s -w -X github.com/armanlife/firefox-vpn-client/core/internal/version.Current=$version" -o "$out\core\firefox-vpn-core.exe" ./cmd/firefox-vpn-core
    if ($LASTEXITCODE -ne 0) { throw 'go build failed' }
} finally { Pop-Location }

# A clean copy named as the user sees it, for the zip and the installer.
$stage = "$root\dist\.stage-$version"
$app = "$stage\Firefox VPN"
Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $app | Out-Null
Get-ChildItem $out -Force | Where-Object { $_.Name -notin 'user-data', 'portable' } | Copy-Item -Destination $app -Recurse
try {
    $zip = "$root\dist\Firefox-VPN-$version-Windows-x64.zip"
    Compress-Archive -Path $app -DestinationPath $zip -CompressionLevel Optimal -Force

    $setupName = "Firefox-VPN-$version-Windows-Setup-x64"
    & $iscc /Q "/DAppVersion=$version" "/DSourceDir=$app" "/DOutputDir=$root\dist" "/DOutputName=$setupName" "$root\app\windows\installer\firefox-vpn.iss"
    if ($LASTEXITCODE -ne 0) { throw 'the installer did not build' }
} finally { Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue }

Write-Host "Built $out"
foreach ($f in $zip, "$root\dist\$setupName.exe") {
    Write-Host ("Built {0} ({1:N1} MB)" -f $f, ((Get-Item $f).Length / 1MB))
}
