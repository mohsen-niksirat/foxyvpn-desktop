$isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isElevated) {
    Write-Host "[*] Requesting Administrator privileges for Wintun TUN mode..." -ForegroundColor Cyan
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Set-Location $PSScriptRoot

$exe = if (Test-Path "build\foxyvpn-v3.exe") { "build\foxyvpn-v3.exe" } elseif (Test-Path "foxyvpn-v3.exe") { "foxyvpn-v3.exe" } else { $null }
if (-not $exe) {
    Write-Host "[ERROR] foxyvpn-v3.exe not found! Please run build.cmd first." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$running = Get-Process -Name "foxyvpn-v3" -ErrorAction SilentlyContinue
if (-not $running) {
    Write-Host "[*] Starting FoxyVPN background engine..." -ForegroundColor Green
    Start-Process -FilePath $exe -ArgumentList "-tray -data-dir `"$PSScriptRoot\user-data`"" -WindowStyle Hidden
    Start-Sleep -Seconds 2
}

$edge = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($edge) {
    Start-Process -FilePath $edge -ArgumentList "--app=http://127.0.0.1:10820/app/"
} else {
    Start-Process "http://127.0.0.1:10820/app/"
}
