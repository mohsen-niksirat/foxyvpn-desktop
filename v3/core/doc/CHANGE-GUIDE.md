# Change Guide

Use this guide after the [development workflow](DEVELOPMENT.md). It maps common requests to a complete edit surface. Check the current implementation before applying a recipe; these steps are guidance, not a request to implement unrelated features.

## Start a change

1. Translate the request into an observable before/after behavior.
2. Find the owning source and nearest tests with the [architecture map](ARCHITECTURE.md).
3. Read the relevant [authentication](AUTHENTICATION.md), [session](SESSIONS.md), [multi-account](MULTI-ACCOUNT.md), [dashboard](DASHBOARD.md), or [configuration](CONFIGURATION.md) contract.
4. Identify which resources, callers, stored fields, and dashboard views can be affected.
5. Implement the scoped behavior and verify it using [TESTING.md](TESTING.md).
6. Update the owning document and report the result with its limits.

Prefer symbol searches to hardcoded line ranges:

```powershell
rg -n 'ResolveWithStateAndCountry|ServerFailover' internal/proxy internal/service
rg -n 'UpdateToken|updateCurrentSessionToken|adoptPass' cmd/firefox-vpn-core
rg -n '^func Test' -g '*_test.go' .
```

## Add or change a setting

Settings live in `config.Config` ([internal/config](../internal/config/config.go)).

| Surface | Check |
| --- | --- |
| Schema | Field with JSON name, default in `Default()`, validation in `Validate()`; omitted fields must keep their defaults |
| Apply | `Daemon.updateSettings`: live (like the threshold or log level) or engine restart (compare in `settingsChange`) |
| Use | `startEngine` or the component that reads it |
| Dashboard | An input in `web/index.html` with `name="section.field"`; durations, integers, and floats are listed in `app.js` |
| Documentation | Field table in [MULTI-ACCOUNT.md](MULTI-ACCOUNT.md), [CONFIGURATION.md](CONFIGURATION.md) when it changes a contract |
| Tests | `config_test.go` for defaults/validation, `TestDashboardSettingsValidateAndApply` for apply behavior |

Do not add command-line flags for settings; flags are reserved for the data folder and one-shot commands.

## Change server selection or persisted choice

Start with `serverlist.Fetch`, `serverlist.Filter`, and the record models in [internal/serverlist](../internal/serverlist/serverlist.go), then inspect `ConnectCandidates`, `ResolveWithStateAndCountry`, `selectProxyCandidate`, `locationMatcher`, `LocationCandidates`, the selection load/save helpers ([internal/proxy/selection.go](../internal/proxy/selection.go)), the server failover ([internal/proxy/failover.go](../internal/proxy/failover.go); `failOver` and `dialSession` in the controller), and `connectEngine` and `reconnectEngine` ([internal/service/engine.go](../internal/service/engine.go)). The dashboard's location list comes from `handleLocations`.

Preserve exact-server versus country exclusivity, deterministic city order, best-effort saved hostname reuse, country mismatch handling, and the failover's limits: only the server's own failures count, a failover stays in the location, and a server set by hand never moves ([SESSIONS.md](SESSIONS.md#server-failover)). Use `TestResolveProxy*`, `TestSelectProxyCandidate*`, `TestFilter*`, the failover tests in `failover_test.go`, and `TestWakeMovesToAnotherServerOfTheLocation`.

## Change account failover

Policy (statuses, threshold, priority, stickiness) belongs in [internal/accounts/manager.go](../internal/accounts/manager.go); interpretation of Guardian and FxA outcomes belongs in `AccountPool.Record` ([accounts.go](../internal/proxy/accounts.go)). Keep shared failures (network, Guardian 5xx, HTTP 451) from switching accounts, keep the active account sticky, and keep the switch in place (`adoptPass`). Use `TestManager*`, `TestAccountPool*`, and `TestControllerQuotaCheckSwitchesAccountWithoutNewSession`. Update [MULTI-ACCOUNT.md](MULTI-ACCOUNT.md).

## Change OAuth, sign-in, or Guardian recovery

Inspect `internal/fxa`, `internal/guardian`, `recoverGuardianRejection`, `AccountPool.passFor`, and the dashboard sign-in steps in `internal/service/signin_flow.go`.

- Preserve typed errors (`errors.Is` on `fxa.ErrReauthRequired`, `guardian.ErrQuotaExceeded`, and the others) and recovery bounds.
- Preserve the acquisition time of loaded credentials and the old refresh token when a response omits a new one; refreshed credentials go back to the account's own file through `runtimeAuth.persist`.
- A new sign-in step needs a `need_*` step constant, its prompt in `app.js` (`STEP_INPUT` or a dedicated branch), and a test with mocked FxA responses.
- Keep synthetic credentials inside a rejecting local mock transport.
- Update [AUTHENTICATION.md](AUTHENTICATION.md).

Real account acceptance needs a live test; local success cannot substitute for it.

## Change renewal, retries, or session replacement

Trace `RunRenewalLoop` -> `renewWithTimeout` -> `acquireUsablePass` -> `adoptPass`. Include `rebuildSession`, `checkQuota`, and `SwitchAccountNow` when analyzing concurrency.

Keep in-place token adoption as the normal path. Verify old-stream lifetime, new-stream admission, expiry, serialized rebuilds, and reference release when replacement is needed. Start with the controller and renewal test families and `TestAuditSOCKSConnectAndRenewal`. Update [SESSIONS.md](SESSIONS.md) and [AUTHENTICATION.md](AUTHENTICATION.md).

## Change pooling or failure classification

Inspect `proxySessionPool`, `pooledProxySession`, `sessionFailureTracker.observe`, and `shouldRebuildProxySession`. Keep account selection and upstream-session pooling separate. Preserve sticky client affinity, partial startup, slot retirement/draining, and fresh-token propagation. Use `TestProxySessionPool*`, `TestSessionFailureTrackerRequiresDistinctTargets`, and `TestShouldRebuildProxySession`. Update [SESSIONS.md](SESSIONS.md).

## Add or change a transport

Start with `proxySession` and its optional token-update, affinity, and liveness interfaces. Trace constructor selection in `proxy.NewController` and lifecycle cleanup in `proxyEngine.stop`. Preserve CONNECT semantics, validated TLS, bounded opening attempts, bearer redaction, and the distinction between stream and session closure. Run the protocol subtests of `TestAuditSOCKSConnectAndRenewal`. Update [ARCHITECTURE.md](ARCHITECTURE.md), [SESSIONS.md](SESSIONS.md), and the `proxy.transport` setting.

## Change SOCKS or forwarding

Inspect `ServeSOCKS`, `SOCKSServer`, `handshakeSOCKS5`, `proxyBidirectional`, `copyConn`, `tunnelConn`, `tunnelWriteBuffer`, and `managedTunnelConn` (which also counts traffic). Trace every exit path for slot/reference release; keep no direct-target fallback, bounded buffering, cancellation cleanup, and half-close semantics.

## Change the dashboard

Server code in `internal/service`: `dashboard.go` (routes and `guard`), `dashboard_api.go` (views and handlers), `daemon.go` (operations). Browser code: `internal/service/web/index.html`, `app.css`, `app.js`.

- Every state-changing endpoint must go through `guard` (JSON content type, same origin, session when a login is configured).
- Never return credentials, tokens, password hashes, or FxA response bodies from the API.
- Render server data with `textContent`; keep the Content-Security-Policy free of inline scripts and styles.
- Keep handlers working while the engine is stopped.
- Add or extend `internal/service/dashboard_test.go`; check the page in a browser against an isolated data folder.
- Update [DASHBOARD.md](DASHBOARD.md).

## Change the tray, the status screen, or notifications

Sources: `internal/desktop`: `tray.go` (menu, polling, notifications), `console_ui.go` (status screen), `platform_windows.go` / `platform_other.go` (console, notifications, single instance), `trayicon.go`; `internal/service/client.go` (API calls with the local token).

- The tray talks to the daemon only through the dashboard API with `X-Local-Token`; add an API endpoint rather than reaching into the daemon.
- The plain log mode (the systemd service on Linux) runs without a desktop, a console, or a user profile; code it runs must not depend on them.
- On Windows, do not start a script host or system tool (PowerShell, `icacls`, `sc`), ask for elevation, or install a service: antivirus heuristics flag the program for them. `notify` does nothing on Windows for that reason; the tray icon and its tooltip show the state.
- Pass notification text as separate arguments, never through a shell or script (`notify-send` takes it after `--`), and never include tokens or account secrets.
- Keep Linux and macOS builds CGO-free: check `GOOS=linux CGO_ENABLED=0 go vet ./...` and `GOOS=darwin CGO_ENABLED=0 go vet ./cmd/...`.
- Update [OPERATOR.md](OPERATOR.md) and, for files in the data folder, [CONFIGURATION.md](CONFIGURATION.md).

## Compatibility

During development there is no backward compatibility: change file formats, settings, flags, and APIs directly and remove the old code instead of migrating. Old data folders may need a fresh sign-in; that is acceptable until a release is published.

## Release a new version

The version is `version` in `app/pubspec.yaml`, `major.minor.patch`: the patch number for fixes, the minor number for new features, the major number for large changes; the number after `+` (the Android build number) only rises. The build scripts pass it to the app and the core (`version.Current`). A tray stops starting the service itself once a newer version served its data folder (and quits when that copy stops), and the status screen and dashboard show the version, so every build given to users needs a new number.

## Change the status screen or location latency

Sources: `console_ui.go` (screen, keys, backends), `ping.go` (measurement, fastest location), `engine.go` (`fastest` at start).

- The screen reads and acts through `consoleBackend`; give the daemon and the API backends the same behavior, and add an API endpoint for anything the client mode needs.
- Never print to stderr while the screen is shown; logs go to the file and the screen's log view.
- Keep every key reachable on the Persian layout (`keyAliases`).
- Latency must be measured through the tunnel: the servers share an anycast range, and local tunnels accept TCP at once. Keep refused locations unretried and the whole measurement bounded (`pingTotalLimit`).
- Update [OPERATOR.md](OPERATOR.md) (keys, latency) and [DASHBOARD.md](DASHBOARD.md) (API).

## Change DNS resolution

Sources: `internal/resolver` (servers, racing, cache), `internal/service/network.go` (`configureDNS`, `resolverDialer`), `internal/service/dnstest.go`, the controlplane default transport.

- Every connection the program opens to a host name must go through `resolver.Dial` or `resolver.LookupNetIP`; never `net.Dial` with a name or `net.DefaultResolver` directly.
- Never resolve SOCKS target names locally; they belong to the exit.
- Tests use local DoH or UDP servers and replace `systemDNS`; they must not query public resolvers.

## Change status, persistence, or logs

Find the writer and every reader before changing a field: `status.json` is read by external health checks; the dashboard uses `/api/status`. Account files, `config.json`, `state.json`, and `selection.json` have separate owners ([CONFIGURATION.md](CONFIGURATION.md)). Preserve existing-file compatibility and non-secret output. Log messages reach the dashboard; keep tokens and passwords out of them.

## Maintain the documentation

| Change | Owning document |
| --- | --- |
| Packages, interfaces, lifecycle | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Credential flow, sign-in, timing, API recovery | [AUTHENTICATION.md](AUTHENTICATION.md) |
| Accounts, failover, config fields | [MULTI-ACCOUNT.md](MULTI-ACCOUNT.md) |
| Dashboard pages, API, security | [DASHBOARD.md](DASHBOARD.md) |
| Tray icon, status screen | [OPERATOR.md](OPERATOR.md) |
| Locks, admission/draining, transport/pool behavior | [SESSIONS.md](SESSIONS.md) |
| Data-folder files, selection rules, status contract | [CONFIGURATION.md](CONFIGURATION.md) |
| Running, systemd install, troubleshooting | [OPERATOR.md](OPERATOR.md) |
| Toolchain or build procedure | [DEVELOPMENT.md](DEVELOPMENT.md) |
| Test names, commands, isolation, side effects | [TESTING.md](TESTING.md) |

Keep [README.md](README.md) as the directory index. Link to the owning guide instead of duplicating tables. For documentation-only work, validate links, referenced symbols and test families, English text, and changed source contracts.
