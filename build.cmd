@echo off
REM Build script for FoxyVPN Desktop (Windows, amd64)
REM Requires: Go >= 1.25

set GOOS=windows
set GOARCH=amd64
set CGO_ENABLED=0

if not exist build mkdir build
go build -trimpath -ldflags "-s -w" -o build\foxyvpn-desktop.exe .\cmd\foxyvpn-app
go build -trimpath -ldflags "-s -w -H=0x20000000" -o build\foxyvpn-desktop-silent.exe .\cmd\foxyvpn-app
go build -trimpath -ldflags "-s -w" -o build\foxyvpn-cli.exe .\cmd\foxyvpn
if errorlevel 1 (
  echo Build failed.
  exit /b 1
)
echo Built build\foxyvpn-desktop.exe
echo Built build\foxyvpn-desktop-silent.exe
echo Built build\foxyvpn-cli.exe
go build -tags desktop,production -trimpath -ldflags "-s -w -H=0x20000000" -o build\foxyvpn-desktop-app.exe .\cmd\foxyvpn-wails
