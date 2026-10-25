#!/usr/bin/env bash
# Builds the Linux desktop app with its core, for this machine's processor
# (amd64 or arm64), into dist/Firefox-VPN-<version>-Linux-<arch>.tar.gz: a
# firefox-vpn folder with firefox-vpn (the Flutter app), core/firefox-vpn-core
# (the Go core, which the app starts with -app), and Flutter's lib/ and
# data/. "install.sh desktop" installs it for the current user. The version
# is "major.minor.patch" from app/pubspec.yaml.
#
# Needs Flutter, GTK 3 headers, clang, cmake, ninja, and pkg-config
# (Ubuntu: clang cmake ninja-build pkg-config libgtk-3-dev), and Go for the
# core, unless CORE names a firefox-vpn-core built for this processor.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(sed -n 's/^version:[[:space:]]*\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' "$root/app/pubspec.yaml")"
[ -n "$version" ] || { echo "no version in app/pubspec.yaml" >&2; exit 1; }
# Flutter's name for the processor, and Go's (also the file's).
case "$(uname -m)" in
  x86_64 | amd64) flutter_arch=x64 arch=amd64 ;;
  aarch64 | arm64) flutter_arch=arm64 arch=arm64 ;;
  *) echo "no Flutter build for $(uname -m)" >&2; exit 1 ;;
esac

(cd "$root/app" && flutter pub get && flutter build linux --release --no-pub --dart-define=APP_VERSION="$version")

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
app="$stage/firefox-vpn"
cp -r "$root/app/build/linux/$flutter_arch/release/bundle" "$app"
if [ -n "${CORE:-}" ]; then
  install -D -m 0755 "$CORE" "$app/core/firefox-vpn-core"
else
  (cd "$root/core" && CGO_ENABLED=0 GOOS=linux GOARCH="$arch" go build -trimpath \
    -ldflags "-s -w -X github.com/armanlife/firefox-vpn-client/core/internal/version.Current=$version" \
    -o "$app/core/firefox-vpn-core" ./cmd/firefox-vpn-core)
fi
install -m 0644 "$root/LICENSE" "$app/LICENSE"

mkdir -p "$root/dist"
out="$root/dist/Firefox-VPN-$version-Linux-$arch.tar.gz"
tar -czf "$out" -C "$stage" --owner=0 --group=0 firefox-vpn
echo "Built $out ($(du -h "$out" | cut -f1))"
