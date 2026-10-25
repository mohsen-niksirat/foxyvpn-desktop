# Development Workflow

Choose a reading path from the [documentation index](README.md). The deeper references are [architecture](ARCHITECTURE.md), [authentication](AUTHENTICATION.md), [sessions](SESSIONS.md), and [configuration/state](CONFIGURATION.md).

## Establish the workspace

Run commands from the directory containing [go.mod](../go.mod). Historical audit paths describe one machine; do not assume they identify the current checkout.

The module is `github.com/armanlife/firefox-vpn-client/core`. The executable is `./cmd/firefox-vpn-core`; the control-plane clients live in `internal/` (`fxa`, `guardian`, `serverlist`, `controlplane`). See [ARCHITECTURE.md](ARCHITECTURE.md) for the layout. This source was an extracted snapshot without Git metadata during the audit. Check the current directory before using Git commands or proposing a branch workflow.

Runtime code lives in `cmd/firefox-vpn-core`, one file per responsibility, with each file's tests next to it. Use symbol searches and nearby tests before considering structural changes:

```powershell
rg -n 'RunRenewalLoop|adoptPass|updateCurrentSessionToken' internal/proxy
rg -n '^func TestProxyController' cmd/firefox-vpn-core
```

There is no generated-code step and no frontend build: the dashboard's plain HTML, CSS, and JavaScript in `internal/service/web/` are embedded with `go:embed`, so any dashboard change requires rebuilding the executable. See [DASHBOARD.md](DASHBOARD.md).

## Toolchain and dependencies

`go.mod` declares Go `1.27.2` (gVisor's minimum; with `GOTOOLCHAIN=auto` an older Go downloads it). It pins `quic-go v0.59.0`, `x/crypto`, `x/net`, `x/sys` (Windows API, registry), `x/term`, `fyne.io/systray v1.12.2` (tray icon; pulls `godbus/dbus` on Linux), `gvisor.dev/gvisor` (the userspace TCP/IP stack of the Android VPN mode, [internal/tun](../internal/tun)), and `golang.org/x/mobile` at commit `8b95e45f8d3e` (2026-09-08, kept by a `tool` directive) for the Android build of [mobile/](../mobile). None of them needs CGO on Windows or Linux; the Android build uses CGO through gomobile and the NDK.

Android: `gomobile` and `gobind` are installed at the same x/mobile commit (`go install golang.org/x/mobile/cmd/gomobile@8b95e45f8d3e`, likewise `cmd/gobind`). With `ANDROID_HOME`, `ANDROID_NDK_HOME`, and a JDK (Android Studio's) set, `gomobile bind -target=android -androidapi 24 -trimpath -ldflags "-s -w" -o ../app/android/app/libs/core.aar ./mobile` builds the library the Flutter app links. Read current [go.mod](../go.mod) and [go.sum](../go.sum) before changing dependencies.

Control-plane requests and the proxy's CONNECT carry desktop Firefox's User-Agent for this system ([controlplane/headers.go](../internal/controlplane/headers.go)), with the Firefox release from Mozilla's product details; it is not this program's version.

```powershell
go version
go mod download
go mod verify
```

Do not run `go mod tidy` or upgrade dependencies for an unrelated edit. Dependency changes need an explicit compatibility review of H2/H3 behavior and the supported Go version.

## Edit and verification loop

1. Define the requested behavior and inspect its source, callers, and tests.
2. Use [CHANGE-GUIDE.md](CHANGE-GUIDE.md) to identify configuration, lifecycle, and documentation surfaces.
3. Make the smallest coherent change; preserve unrelated working configuration.
4. Format touched Go files with `gofmt -w`.
5. Run focused behavior tests. For Go changes, finish with the normal suite and vet when appropriate.
6. Build the executable when the change affects compilation or distribution.
7. Update the owning document and report passed, failed, skipped, and missing verification.

Normal checks:

```powershell
go test -count=1 -timeout=120s ./...
go vet ./...
```

See [TESTING.md](TESTING.md) for focused commands, isolation, race requirements, and live opt-ins. Documentation-only changes need link/language/source checks; they do not require a live account or proxy process.

## Windows development build

Use a separate output name while developing so the supplied/running executable is not replaced. The executable's icon and version information come from `cmd/firefox-vpn-core/rsrc_windows_*.syso`, which `go build` links in. They are build output, not in Git: `scripts/build-windows.ps1` makes them with the release version (`APP_VERSION=<version> go generate ./cmd/firefox-vpn-core`, [tools/winres](../tools/winres/main.go)); a development build without them has no icon:

```powershell
New-Item -ItemType Directory -Path dist -Force | Out-Null
$env:GOOS = 'windows'
$env:GOARCH = 'amd64'
$env:CGO_ENABLED = '0'
go build -trimpath -o dist\firefox-vpn-core-dev.exe ./cmd/firefox-vpn-core
go version -m dist\firefox-vpn-core-dev.exe
Get-FileHash -LiteralPath dist\firefox-vpn-core-dev.exe -Algorithm SHA256
```

These environment values persist in the current PowerShell process. Use a fresh shell or restore them before a different target or a race check. The application itself needs neither Go nor curl at runtime.

A development build next to the distribution executable shares its `user-data` folder (the folder next to the executable). Run test builds from a separate folder or with `-data-dir` and a temporary home so they never touch real accounts. Replacing `dist\firefox-vpn-core.exe` or restarting a running instance is a separate concrete action within the user's requested scope. Confirm listener ownership, and stop test instances by PID or path rather than image name.

## Run modes

`runCommand` in [main.go](../cmd/firefox-vpn-core/main.go) picks one: the status screen or the plain log (no mode flag, `-plain`), the tray icon (`-tray`), the desktop app's core process (`-app`, started by the Flutter app in `app/`; contract in [OPERATOR.md](OPERATOR.md#desktop-app-mode)). The mode flags and one-shot commands are mutually exclusive. On Windows, `-tray` and `-app` apply `system_proxy.mode` to the signed-in user's real Internet Settings, and there is no mode that leaves them alone: `clear` (the default) undoes a setting of this program's at start and turns the system proxy off when the user switches to it, and `set` points Windows at the test instance while its proxy runs. Run them on the real desktop only when that change is acceptable for the task. To try `-app` by hand, start a development build with an isolated `-data-dir` and non-default ports, keep its standard input as an open pipe, and stop it by closing that pipe or with `POST /api/app/exit`. A failed `-app` start writes `app-error: <code> <detail>` as the first line on the standard error (`dashboard_port_in_use` exit 4, `already_running` exit 3, `start_failed` exit 1); the codes, details, and exit statuses are the app's contract in [OPERATOR.md](OPERATOR.md#app-error-line), written by `desktop.ReportAppError`.

## Operational testing

Use [OPERATOR.md](OPERATOR.md) for login and startup commands. Local fixtures do not require Mozilla credentials. Real-account testing can send traffic, activate account access, or persist refreshed credentials; follow the explicit live-test workflow in [TESTING.md](TESTING.md).

Observe the actual listener, upstream socket, and response together when attributing live traffic. A changed IP or another proxy's success alone is insufficient.

## Completing a task

Describe the behavior changed, affected files, checks and skips, state/configuration impact, and remaining limits. Do not turn an untested possibility into a confirmed feature.
