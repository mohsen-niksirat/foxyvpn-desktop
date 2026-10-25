@echo off
title Build FoxyVPN Desktop v3
setlocal enabledelayedexpansion

echo ========================================================
echo  Building FoxyVPN Desktop v3 (with Wintun L3 Full-Tunnel)
echo ========================================================

set GOOS=windows
set GOARCH=amd64
set CGO_ENABLED=0

if not exist build mkdir build

pushd core
echo [*] Compiling FoxyVPN Pro core and dashboard...
go build -trimpath -ldflags "-s -w -X github.com/armanlife/firefox-vpn-client/core/internal/version.Current=3.0.0" -o "..\build\foxyvpn-v3.exe" ./cmd/firefox-vpn-core
if errorlevel 1 (
    echo.
    echo [ERROR] Build failed!
    popd
    pause
    exit /b 1
)
popd

copy /y "build\foxyvpn-v3.exe" "foxyvpn-v3.exe" >nul

echo.
echo [SUCCESS] Built successfully: build\foxyvpn-v3.exe
echo ========================================================
echo.
pause
