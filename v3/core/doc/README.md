# Developer Documentation

This directory is the maintained English reference for developers. Start with the [development workflow](DEVELOPMENT.md), then read the documents relevant to the task. Run all command examples from the project root containing `go.mod`.

The current source and nearby tests are authoritative. These guides explain existing behavior and change boundaries; they do not replace inspecting the implementation.

## Reading paths

| Task | Read first | Then inspect |
| --- | --- | --- |
| First development task | [Development workflow](DEVELOPMENT.md), [architecture](ARCHITECTURE.md) | `go.mod` and the affected source file |
| Login, OAuth, Guardian, quota | [Authentication](AUTHENTICATION.md) | `internal/fxa`, `internal/guardian`, `internal/proxy/proxypass.go` |
| Multi-account mode, config.json, data folder | [Multi-account mode](MULTI-ACCOUNT.md) | `internal/accounts`, `internal/config`, `internal/proxy/accounts.go`, `internal/service/daemon.go` |
| Web dashboard, API, sign-in steps | [Dashboard](DASHBOARD.md) | `cmd/firefox-vpn-core`: `dashboard.go`, `dashboard_api.go`, `signin_flow.go`, `web/` |
| SOCKS, H2/H3, renewal, pool, concurrency | [Sessions and transports](SESSIONS.md) | `cmd/firefox-vpn-core`: `socks.go`, `upstream_h2.go`, `pool.go`, `controller.go`, `renewal.go` |
| Settings, server selection, data-folder files | [Configuration and state](CONFIGURATION.md) | `internal/config`, `proxy.ResolveWithStateAndCountry`, state helpers |
| Implement a behavior change | [Change guide](CHANGE-GUIDE.md) | The matching source/test row |
| Choose or run tests | [Testing](TESTING.md) | Existing tests for the affected behavior |
| Operate or troubleshoot the proxy | [Operator guide](OPERATOR.md) | Dashboard, `-help`, installer as applicable |
| Tray icon, status screen, notifications | [Operator guide](OPERATOR.md), [change guide](CHANGE-GUIDE.md) | `internal/desktop`: `tray.go`, `console_ui.go`, `platform_*.go`; `internal/service/client.go` |

## Documentation map

| File | Owns |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Package/file map, service lifecycle, data/control boundaries, key interfaces |
| [MULTI-ACCOUNT.md](MULTI-ACCOUNT.md) | Accounts, failover rules, config field reference, data folder |
| [DASHBOARD.md](DASHBOARD.md) | Dashboard pages, API, login, and request security |
| [AUTHENTICATION.md](AUTHENTICATION.md) | Credential lifetimes, sign-in flow, renewal, quota and challenge handling |
| [SESSIONS.md](SESSIONS.md) | Session admission/draining, locks, pooling, failure handling, stream forwarding |
| [CONFIGURATION.md](CONFIGURATION.md) | Data-folder files, selection rules, status and persisted-state contracts |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Local setup, edit loop, builds, completion expectations |
| [TESTING.md](TESTING.md) | Verification tiers, focused test commands, isolation and live opt-ins |
| [CHANGE-GUIDE.md](CHANGE-GUIDE.md) | Concrete change recipes, review checks, documentation maintenance |
| [OPERATOR.md](OPERATOR.md) | Running on Windows and Linux, tray icon, systemd service, commands, troubleshooting |

The root [README.md](../README.md) is the user entry point.

## Fast orientation

- Module: `github.com/armanlife/firefox-vpn-client/core`; executable: `./cmd/firefox-vpn-core` (service, dashboard, proxy); internal packages: `fxa`, `guardian`, `serverlist`, `accounts`, `config`, `controlplane`, `securefile`, `resolver`.
- Data: SOCKS5 CONNECT -> controller/pool -> H2 over TLS/TCP or H3 over QUIC/UDP -> Fastly -> target TCP.
- Control: per-account FxA OAuth -> Guardian ProxyPass -> bearer token for CONNECT; the account manager picks the account.
- Settings and accounts: `user-data/` next to the executable (the desktop app's data folder when the core sits beside `firefox-vpn.exe`), edited through the dashboard (`127.0.0.1:10820`).
- Default SOCKS5 listener: `127.0.0.1:10810`; dashboard: `127.0.0.1:10820`.
- Run modes: status screen in an interactive terminal (also a double-click), plain log (`-plain` or non-interactive), tray (`-tray`), desktop app core process (`-app`, started by the Flutter app), systemd on Linux (plain log mode).
- The proxy has no direct-target fallback, TUN, or SOCKS UDP support; connections go directly only by the opt-in routing rules.
- Ordinary development uses isolated local tests. Real-account tests have explicit side effects and opt-in requirements.

Use symbol names rather than historical line numbers when navigating. Keep each behavior documented in its owning guide and link to it from other documents.
