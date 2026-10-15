# TUN mode fix (Windows)

status: in-progress
branch: fix-tun-404
base: 342b36e

## Problem

Starting TUN mode failed with `downloading hev-socks5-tunnel: HTTP 404 Not Found`.
The code downloaded `hev-socks5-tunnel.exe` from a release URL that does not exist.
The real Windows asset is `hev-socks5-tunnel-win64.zip`.

After the download was fixed, two more problems showed up:

- Adapter lookup by name failed. A leftover Wintun adapter already existed and the
  new one was not identified reliably.
- System DNS may not resolve while TUN is on, because the local SOCKS5 server only
  implements CONNECT and the tunnel only carries TCP streams.

## Design

- Binaries are embedded with `go:embed` from `internal/tun/bin/`. Each one is checked
  against a pinned SHA-256 before it runs.
- hev is started with a fixed adapter GUID (`tunnel.guid`). The app finds the
  adapter's interface index by that GUID through `Get-NetAdapter`, then adds the
  two half-default routes (`0.0.0.0/1` and `128.0.0.0/1`) through it.
- The edge IP is pinned to the physical default gateway (lowest metric, ignoring
  the tunnel address) so the tunnel's own connection does not loop into TUN.
- Stop removes both routes and the edge pin, kills hev, and removes the temp dir.

## Out of scope

- DNS over the tunnel. The tunnel is TCP CONNECT only, and UDP support needs a new
  transport whose edge support is unverified. Blocked until the user decides.
- IPv6 routing through the tunnel.
- Changes to the non-Windows stub beyond matching signatures.

## Tasks

1. Embed hev, wintun.dll, and msys-2.0.dll with SHA-256 checks.
   Acceptance: a modified binary fails with an integrity error. (done)
2. Pin the adapter GUID and resolve its index by GUID.
   Acceptance: TUN starts without a name or index-diff lookup. (done in code;
   needs an elevated run to confirm)
3. Pin the edge route and add the default routes.
   Acceptance: YouTube and Gemini load with TUN on. (confirmed by the user)
4. Clean up duplicated route-delete code.
   Acceptance: `go vet`, `go test ./internal/...`, and Windows and Linux builds pass. (done)
5. Support DNS over the tunnel.
   Acceptance: a name resolves with TUN on. (blocked, see Out of scope)

## Verification

- `go vet ./...`: pass
- `go test ./internal/...`: pass (only `socks` has tests)
- `GOOS=windows go build ./cmd/foxyvpn-app`: pass
- `GOOS=linux go build ./cmd/foxyvpn-app`: pass
- Manual: connect, start the local proxies, start TUN as administrator, and load
  YouTube and Gemini. Result: pass (user report).
- Manual DNS check: not run.

## Review

Pending. An independent reviewer is to be spawned after the DNS decision.
