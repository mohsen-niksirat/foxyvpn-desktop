#!/usr/bin/env bash
# Builds the macOS app with its core into dist/Firefox-VPN-<version>-macOS.dmg:
# "Firefox VPN.app" (Apple silicon and Intel), with firefox-vpn-core (the Go
# core, which the app starts with -app) beside the app's executable in
# Contents/MacOS, and a link to Applications to drag it to. The version is
# "major.minor.patch" from app/pubspec.yaml.
#
# The app is signed ad hoc (no Apple Developer ID), which Apple silicon
# needs to run it at all; macOS asks once before opening a downloaded copy.
# Needs Flutter, Xcode, and Go.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(sed -n 's/^version:[[:space:]]*\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' "$root/app/pubspec.yaml")"
[ -n "$version" ] || { echo "no version in app/pubspec.yaml" >&2; exit 1; }

(cd "$root/app" && flutter pub get && flutter build macos --release --no-pub --dart-define=APP_VERSION="$version")

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
app="$stage/Firefox VPN.app"
cp -R "$root/app/build/macos/Build/Products/Release/Firefox VPN.app" "$app"

# The core for both processors, in one file.
for arch in arm64 amd64; do
  (cd "$root/core" && CGO_ENABLED=0 GOOS=darwin GOARCH="$arch" go build -trimpath \
    -ldflags "-s -w -X github.com/armanlife/firefox-vpn-client/core/internal/version.Current=$version" \
    -o "$stage/core-$arch" ./cmd/firefox-vpn-core)
done
lipo -create -output "$app/Contents/MacOS/firefox-vpn-core" "$stage/core-arm64" "$stage/core-amd64"

# The core inside the bundle changes it: sign the core, then the whole app.
codesign --force --sign - "$app/Contents/MacOS/firefox-vpn-core"
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"

dmg="$stage/dmg"
mkdir "$dmg"
mv "$app" "$dmg/"
ln -s /Applications "$dmg/Applications"
mkdir -p "$root/dist"
out="$root/dist/Firefox-VPN-$version-macOS.dmg"
rm -f "$out"
hdiutil create -volname "Firefox VPN" -srcfolder "$dmg" -ov -format UDZO "$out" >/dev/null
echo "Built $out ($(du -h "$out" | cut -f1))"
