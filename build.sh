#!/bin/bash
# Build script for FoxyVPN Desktop (cross-platform)
# Requires: Go >= 1.25 and internet access to fetch dependencies

set -e

BINARY_NAME="foxyvpn-desktop"
CLI_NAME="foxyvpn-cli"

echo "Building FoxyVPN Desktop..."

# Build the GUI app (Stage 2)
GOOS=windows GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o "build/${BINARY_NAME}.exe" ./cmd/foxyvpn-app
echo "Built build/${BINARY_NAME}.exe"

# Build the silent GUI app (no console)
GOOS=windows GOARCH=amd64 go build -trimpath -ldflags "-s -w -H=0x20000000" -o "build/${BINARY_NAME}-silent.exe" ./cmd/foxyvpn-app
echo "Built build/${BINARY_NAME}-silent.exe"

# Build the CLI tool (Stage 1)
GOOS=windows GOARCH=amd64 go build -trimpath -ldflags "-s -w" -o "build/${CLI_NAME}.exe" ./cmd/foxyvpn
echo "Built build/${CLI_NAME}.exe"

echo "All builds completed successfully."