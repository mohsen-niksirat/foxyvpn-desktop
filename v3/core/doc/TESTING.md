# Testing and Verification

Run commands from the module root. This guide describes what each verification tier can establish.

## Tiers and side effects

| Tier | Establishes | Side effects / limits |
| --- | --- | --- |
| Documentation checks | Links, symbols, English text, alignment with source | No proxy/account needed |
| Ordinary Go tests | Local behavior and regression cases | Loopback sockets and isolated temporary files; no live account needed |
| Local transport integration | Production SOCKS/controller/H2/H3 path with fixtures | curl-dependent transfers; local TLS/QUIC and synthetic credentials |
| `go vet` and build | Static diagnostics and compilation | Do not establish real CONNECT or race freedom |
| Race detector | Races observed on exercised paths | Requires CGO/C compiler; not a proof for all schedules |
| External challenge test | Current account-API challenge handling | Real external invalid test login; opt-in |
| Live account/proxy tests | Actual service acceptance and data path | Real credentials, account/cache changes, network use; run when they help, briefly (quota) |

Do not enable external tiers merely because a token file exists or an old report recorded a successful account test.

## Normal Go checks

```powershell
go test -count=1 -timeout=120s ./...
go vet ./...
```

Use focused tests during development, then broader checks appropriate to the change. Format touched Go files first. A documentation-only edit does not justify running account tests or restarting the proxy.

### Test routing

| Changed behavior | Package / test file | Existing tests to start with |
| --- | --- | --- |
| FxA API errors and sign-in classification | `internal/fxa`, `fxa_test.go` | `TestNewFxaAPIErrorParsesErrno`, `TestFxaAPIErrorClassifiesReauthRequired` |
| Challenge parser / PoW | `internal/fxa`, `challenge_test.go` | `TestParseChallengeInitExtractsToken`, `TestParseChallengeInitPowData`, `TestSolvePowFindsSuffix` |
| Private file writes | `internal/securefile`, `securefile_test.go` | `TestWritePrivateReplacesContentAndTightensPermissions` |
| Local token, shutdown, API client, daily log files and their retention, tray icons | `internal/service`: `localtoken_test.go`, `client_test.go`; `internal/logx`, `file_test.go`; `internal/desktop`, `trayicon_test.go` | `TestLocalTokenBypassesHostCheckAndLogin`, `TestDaemonShutdownStopsDashboardAndPublishesToken`, `TestLocalClientReadsStatusThroughToken`, `TestDailyLogFiles`, `TestLogsKeptForOneWeek`, `TestDailyFileSharedByTwoWriters`, `TestDailyLogSizeLimit`, `TestDefaultLogLimits`, `TestDeletedLogFileIsCreatedAgain`, `TestTrayIcons` |
| Location latency, fastest location, location endpoint, status-screen keys | `internal/proxy`, `ping_test.go`; `internal/service`, `ping_test.go`; `internal/desktop`, `console_ui_test.go` | `TestPingLocationsSortsByLatencyAndReportsFailures`, `TestTunnelMeterTimesConnectThroughEachLocation`, `TestLocationPingNeedsRunningProxy`, `TestSetLocationEndpoint`, `TestConsoleKeysAndWidth` |
| DNS resolver, DNS setting, DNS test | `internal/resolver`, `resolver_test.go`; `internal/service`, `dnstest_test.go` | `TestParseServerSpecs`, `TestDoHLookupAndCache`, `TestUDPLookupAndDial`, `TestRaceUsesWorkingServerAndReportsFailures`, `TestSettingsApplyDNS`, `TestDNSTestEndpointComparesWithSystem` (local DoH/UDP servers; system DNS replaced) |
| Stored password, automatic sign-in, connected-services device | `internal/accounts`, `password_test.go`; `internal/fxa`, `device_test.go`; `internal/service`, `relogin_test.go` | `TestPasswordIsEncryptedAndSurvivesTokenUpdates`, `TestRegisterDeviceUsesRefreshTokenAndName`, `TestReloginWithStoredPassword`, `TestReloginNeedsConfirmation` (both also check that the sign-in session is ended), `TestSignInAgainUsesStoredPassword`, `TestDestroySessionSignsWithTheSessionToken`, `TestReloginWhenGuardianKeepsRefusingTokens`, `TestReloginNetworkFailureIsRetried`, `TestReloginWrongPasswordNeedsSignIn` (`internal/proxy/relogin_test.go`) (mock FxA; `deviceRegistration` is off in every other test) |
| SOCKS5 login | `internal/proxy`, `socks_auth_test.go` | `TestSOCKSUsernamePassword` |
| Latest Firefox version, config clean-up | `internal/serverlist/version_test.go`, `internal/config/config_test.go` | `TestLatestFirefoxVersionPrefersNightly`, `TestLoadDropsRemovedSettingsAndNormalizesRecommended` (tests never fetch the version: `latestFirefoxVersion` is replaced in `internal/service/helpers_test.go`) |
| Real-delay test per tab | `internal/proxy`, `ping_test.go` | `TestPingSubsetIsMergedIntoEarlierResults` |
| VPN on/off switch | `internal/service`, `vpnswitch_test.go` | `TestVPNSwitchKeepsServiceRunning`, `TestOldConfigKeepsVPNOn` |
| Version, app exit, status-screen menu and number prompt | `internal/version`, `version_test.go`; `internal/service`, `localtoken_test.go`; `internal/desktop`, `console_ui_test.go` | `TestVersionFormatAndOrder`, `TestAppExitNeedsLocalTokenAndHost`, `TestConsoleMenuItems`, `TestConsoleNumberPrompt`, `TestLogScreenKeepsThePromptVisible`, `TestScreenChangeClearsTheMessage` |
| Guardian claim times | `internal/guardian`, `pass_test.go` | `TestAnchorProxyPassClaims*`, `TestAudienceAcceptsStringAndArray` |
| Guardian status classes / quota | `internal/guardian`, `errors_test.go`, `usage_test.go`, `guardian_test.go` | `TestHTTPErrorClassifiesStatus`, `TestParseProxyUsage`, `TestFetchProxyPassSendsNoCacheAndAnchorsExpiry` |
| Server-list filters and versions | `internal/serverlist`, `filter_test.go` | `TestEvaluateFilterExpression`, `TestFilterSelectsVersionGatedRecord`, `TestCompareVersions` |
| Guardian retry and recovery policy | `internal/proxy`, `proxypass_test.go` | `TestFetchProxyPass*`, `TestAcquireUsablePass*`, `TestIsQuotaExhausted` |
| Selection and persistence | `internal/proxy`, `selection_test.go` | `TestSelectProxyCandidate*`, `TestResolveProxy*`, `TestConnectProxy*` |
| Server failover | `internal/proxy`, `failover_test.go`; `internal/service`, `lazy_test.go` | `TestServerFailingThreeTimesSwitchesToAnotherServerOfItsCity` (three failures on A: B of the same city at once, A avoided, `selection.json` and a restart's selection on B), `TestServerFailoverCountsTheDialsOfNewPasses` (requests one by one, rebuilding with new passes from a local Guardian stand-in), `TestBrokenSessionsMoveTheServer` (sessions that open and break; a tunnel that opens resets the count), `TestFailuresThatAreNotTheServersDoNotSwitch` (no network, Guardian and account errors, CONNECT 401/403/407/429, a refused port, a cancellation), `TestEveryServerFailingKeepsTheLocation` (the city, then the next city, then staying; never another country), `TestAvoidedServerIsSkippedUntilItsTimeIsUp` (by the failover and by selection, with a test clock), `TestRecommendedLocationFailsOverWithinItself`, `TestWakeMovesToAnotherServerOfTheLocation` (failed wakes on a persisted dead server move to the fixture server, saved, and the next connection uses it at once) |
| Exit response parsing (Cloudflare, ip.sb), IPv4 and IPv6 with fallback, cancellation | `internal/proxy`, `exitprobe_test.go` | `TestParseExitProbeResponse*`, `TestParseIPSBGeoIP`, `TestVerifyExitFindsBothFamilies`, `TestVerifyExitTakesTheCountryFromCloudflare`, `TestOpenTunnelContextClosesConnectionThatArrivesAfterCancellation` |
| SOCKS and limits, refused ports | `internal/proxy`, `socks_test.go`, `session_test.go` | `TestHandshakeSOCKS5*`, `TestSocksServer*` (including `TestSocksServerReportsRefusedPort`, `TestSocksServerNotesUDPRequest`), `TestRefusedPortDoesNotRetireSession`, `TestNoticesCountNewestFirstAndBounded` |
| Half-close forwarding | `internal/proxy`, `relay_test.go` | `TestProxyBidirectionalClosesBothSidesOnCopyError`, `TestTunnelWrappersForwardHalfCloseAndReleaseOnClose` |
| Failure classes / open timeout | `internal/proxy`, `session_test.go` | `TestShouldRebuildProxySession`, `TestSessionFailureTrackerRequiresDistinctTargets`, `TestRoundTripWithOpenTimeout` |
| Buffer/deadline contracts | `internal/proxy`, `tunnel_test.go` | `TestTunnelWriteBuffer*`, `TestTunnelConn*` |
| Upstream bearer update | `internal/proxy`, `upstream_test.go` | `TestProxySessionsUpdateBearerToken` |
| HTTP/2 session at its stream limit (busy, not dead; no rebuild, no new pass) | `internal/proxy`, `saturation_test.go` | `TestSaturatedSessionIsBusyNotDead`, `TestControllerDoesNotRebuildSaturatedSession` |
| Sign-in links, the phone's token-only API | `internal/service`, `loginlink_test.go` | `TestLoginLink`, `TestTokenOnlyAPI` |
| Fastly challenge: a waiter gives up with its context | `internal/fxa`, `challenge_test.go` | `TestChallengeSlotWaiterGivesUp` |
| Pool affinity / failure / tokens | `internal/proxy`, `pool_test.go` | `TestProxySessionPool*` |
| Controller admission / replacement | `internal/proxy`, `controller_test.go` | `TestProxyController*` |
| Renewal timing, watchdog, retry policy | `internal/proxy`, `renewal_test.go` | `TestProxyControllerRenewWithTimeout*`, `TestRenewalRetryDelayBacksOffTerminalFailures`, `TestProxyControllerRebuildCooldownAvoidsGuardianStorm` |
| Rebuild kinds and spacing | `internal/proxy`, `rebuild_test.go` | `TestDeadConnectionRedialsWithThePass` (no Guardian request), `TestExpiringPassIsNotRedialed`, `TestNewPassRebuildsBackOff` (10 s, then 30 s; a tunnel resets), `TestRefusalAfterANewPassPassesThrough` (one new pass for a 403, then the 403 goes to the client and the session keeps serving), `TestRefusedChosenLocationIsLocationRefused` (a chosen location refused with 403 or 407 after a new pass is `location_refused`; otherwise `refused`), `TestNewPassWaitsForTheRenewalLoop`, `TestWakeRetryDelay` |
| Status file | `internal/proxy`, `status_test.go` | `TestProxyControllerWritesStatusFile`, `TestProxyControllerStatusReportsQuotaAndFailure` |
| Log redaction | `internal/proxy`, `redact_test.go` | `TestLogErrRedactsConnectHTTPBodyUnlessVerbose` |
| Routing rules, geo lists, downloads | `internal/routing`, `routing_test.go`; `internal/proxy`, `route_test.go`; `internal/service`, `routing_test.go` | `TestRouterDecides`, `TestRouterResolvesNamesWhenAsked`, `TestRouterRejectsBadRulesAndTags`, `TestDownloadKeepsOldListOnFailure`, `TestRegionRules`, `TestRegionRoutesDirectly`, `TestRoutedOpenerFollowsRules`, `TestRoutingSettingsApplyLive` (geo lists encoded in the test), `TestRoutingRegionDefaultsAndValues`, `TestDirectRouteRefusesThisMachineForOtherDevices` |
| Desktop app mode (`-app`) | `internal/desktop`, `app_test.go`, `endsession_windows_test.go`; `cmd/firefox-vpn-core`, `main_test.go`; `internal/service`, `localtoken_test.go` | `TestWatchParentStopsAtEndOfInput`, `TestWatchParentStopsOnReadError`, `TestStdinIsPipe`, `TestRunHostedStopsInOrder` (status loop, then system proxy restore, then shutdown), `TestRunHostedReportsServiceFailure`, `TestEndSessionWindow` (Windows: agrees to `WM_QUERYENDSESSION`, runs the stop once on `WM_ENDSESSION`, not on a cancelled end), `TestReportAppError` (the `app-error:` line, codes, and exit statuses), `TestAppDashboardPortInUse` (a loopback listener holds the dashboard port), `TestAppModeIsExclusive`, `TestRequireDashboardRefusesDisabledDashboard`, `TestAppExitNeedsLocalTokenAndHost` |
| Listen address in use | `internal/service`, `listen_test.go` | `TestListenTCPReportsAddressInUse`, `TestProxyPortInUseInStatus` (a loopback listener holds `proxy.listen`: `state.code` `proxy_port_in_use` with the address, replaced by the next state's code after a new `proxy.listen`), `TestDashboardPortInUseFailsRun` |
| State codes | `internal/service`, `statecode_test.go` | `TestWaitingStatesHaveCodes` (`waiting_for_network`, then `no_accounts`, then `no_usable_account` for an account that must sign in again, each beside the English message), `TestStartFailureHasCode` (`start_failed` for a `proxy.listen` that cannot be used, with `retry_at`) |
| HTTP proxy on the SOCKS5 port | `internal/proxy`, `http_proxy_test.go` | `TestHTTPProxyConnectTunnel`, `TestHTTPProxyForwardsPlainRequests`, `TestHTTPProxyExplainsRefusedPort`, `TestBasicCredentials` |
| Windows system proxy modes (set, clear) | `internal/desktop`, `sysproxy_windows_test.go`; `internal/config`, `config_test.go`; `internal/service`, `systemproxy_test.go` | `TestSystemProxySetAndRestore`, `TestSystemProxyModes` (set only while running, restored when stopped, gone, or closed; clear once when switched to, while a start in clear keeps another program's proxy; repeated refreshes keep the setting; temporary keys under `HKCU\Software`, never the real Internet Settings), `TestSystemProxyTakenByAnotherProgram` (another program's setting is reported, never taken back by itself; the user's request takes it back), `TestSystemProxyModes` in `config` (default `clear`, other values refused), `TestSystemProxyEndpointAcceptsSetAndClear`, `TestNoVPNSwitch` |
| Dashboard sessions, login reset, open folder | `internal/service`: `dashboard_test.go`, `localtoken_test.go`; `internal/desktop`, `console_ui_test.go` | `TestDashboardSessionsLastAndEnd`, `TestResetDashboardLogin`, `TestOpenFolder`, `TestResetLoginScreen` |
| Revoked tokens, device record | `internal/proxy`, `revoked_test.go`; `internal/accounts`, `store_test.go` | `TestRevokedRefreshTokenSignsInAgainAtOnce`, `TestRevokedRefreshTokenNeedingCode`, `TestQuotaCheckRefusedTokenRenewsNow`, `TestManagerKeepsDeviceRecord` |
| Waiting for a network | `internal/service`, `netwait_test.go`; `internal/netstate` | `TestEngineWaitsForNetwork` (no start and no request while offline; a restart request ends the wait and the next start waits again; starts once online), `TestEngineIgnoresNetworkWhenOff`, `TestLinuxDefaultRoutes`; `TestWindowsAdapters` only logs this computer's adapters. The service tests replace `networkConnected` so they never depend on the machine's network |
| Sleeping when unused | `internal/service`, `sleep_test.go` | `TestIdleSleepAndWake` (sleeps only after the idle time and with nothing open; many connections wake it once), `TestIdleSleepOff`, `TestReleasingConnKeepsHalfClose` |
| Lazy start (first wake) | `internal/service`, `lazy_test.go` | `TestEngineStartsAsleepAndConnectsOnFirstUse` (a started daemon listens asleep, counts as running for the system proxy, writes `status.json` reason `sleeping`, and sends no server-list, Guardian, or upstream request; the first SOCKS5 connection gets the list and one pass, connects, and its data goes through; the automatic test follows), `TestConnectionTestWakesProxy`, `TestFailedWakeWaitsBeforeRetrying` (`wake_error` and its code; a refused region holds for a requested test too until the network comes back), `TestTransientWakeFailureLetsTestsRetry` (after a failure not known to last, connections wait and a requested test retries). They run the real wake against local fixtures: a control-plane transport that answers only the server list and Guardian's pass (installed after the daemon is created, because loading the config resets the transport; the test checks it is installed before `Run`), and an HTTP/2 CONNECT server on loopback trusted through `proxy.SetUpstreamRoots` with hostname and chain validation on |
| Speed, destination test | `internal/proxy`, `route_test.go`; `internal/service`, `routing_test.go` | `TestTrafficCountsBytesAndSpeed`, `TestDestinationTest` |
| Automatic connection test | `internal/proxy`, `renewal_test.go` | `TestSessionRebuildIsReported` |
| Failure codes | `internal/proxy`, `failure_test.go`; `internal/service`, `dashboard_test.go`; app `test/failure_text_test.dart` | `TestFailureCode` (account, Guardian, CONNECT, DNS, socket, and timeout errors), `TestConnectionTestMeasuresTunnelRequest` (`unreachable` before the tunnel opens, `test_site` after); the app names the newer failure and asks to check the internet only for `no_network` |
| Config schema and data folder | `internal/config`, `config_test.go` | `TestLoad*`, `TestDefaultDataDirIsNextToExecutable` |
| Account store and failover policy | `internal/accounts`, `accounts_test.go` | `TestManager*`, `TestPolicyThresholdReached`, `TestStoreAdd*` |
| FxA sign-in steps (unblock, TOTP, CAPTCHA) | `internal/fxa`, `signin_test.go` | `TestLoginWithUnblockCodeSendsCode`, `TestVerifyTOTPReportsRejectedCode`, `TestAnswerChallengeAsksCaptchaSolver` |
| Dashboard API, login, request policy, sign-in flow | `internal/service`, `dashboard_test.go` | `TestDashboard*`, `TestConnectionTestMeasuresTunnelRequest` |
| Account failover against Guardian, order reconciliation | `internal/proxy`, `accounts_test.go`; `internal/service`, `paths_test.go` | `TestAccountPool*`, `TestControllerQuotaCheck*`, `TestNoteTraffic*`, `TestReconcileAccountOrder` |
| End-to-end local transport and renewal | `internal/proxy`, `audit_integration_test.go` | `TestAuditSOCKSConnectAndRenewal` |

Wildcard names in this table denote existing test families, not literal `-run` arguments. Inspect the matching functions before selecting a subset.

Focused commands:

```powershell
go test -count=1 -timeout=120s -run '^(TestSelectProxyCandidate|TestResolveProxy|TestServerFail|TestBrokenSessions|TestFailuresThatAreNotTheServers|TestEveryServerFailing|TestAvoidedServer|TestRecommendedLocationFailsOver)' ./internal/proxy
go test -count=1 -timeout=120s -run '^TestAccountPool' ./internal/proxy
go test -count=1 -timeout=120s -run '^TestDashboard' ./internal/service
go test -count=1 -timeout=120s -run '^(TestProxyController|TestProxySessionPool|TestProxySessionsUpdateBearerToken)' ./internal/proxy
go test -count=1 -timeout=120s -run '^TestAudit' ./internal/proxy
go test -count=1 -timeout=120s ./internal/...
```

Check the output for actual executed tests and skips. A successful command with no matching tests does not verify the intended behavior.

## Local integration and isolation

[audit_integration_test.go](../internal/proxy/audit_integration_test.go) uses production SOCKS, controller, and H2/H3 session implementations with controlled upstream/auth responses.

- Two batches of six concurrent curl transfers per protocol reach a local origin through mock CONNECT, with no direct-target fallback.
- A persistent echo stream crosses automatic expired-access refresh and ProxyPass renewal while retaining session identity.
- Synthetic bearer values are accepted only by local fixtures. The mock control-plane transport rejects unrecognized URLs.
- HOME and USERPROFILE are temporary, and the shared transport is restored during cleanup.
- The redaction regression covers short and long token values.

H2 uses in-process TLS over `net.Pipe` because the audit host's HTTP Debugger intercepted loopback TLS. SOCKS/origin sockets are real loopback TCP. H3 uses real loopback QUIC/UDP with test-only certificate trust. Preserve production certificate validation.

The curl-dependent transfer helper skips when curl is absent. Record the missing coverage. These results establish local behavior, not current Mozilla eligibility, live H3, or a stable public exit.

Tests that replace `controlplane.SetTransport`, mutate the shared HTTP client, capture stdout, or change process home must remain serial unless those conflicts are removed. Do not introduce `t.Parallel()` into them casually. Close sockets, servers, response bodies, and controllers on failure paths.

## Dashboard checks

The dashboard's API, request policy, and sign-in flow are covered by Go tests with local fixtures (`internal/service/dashboard_test.go`). The browser code has no automated tests; after changing `internal/service/web`, check the JavaScript syntax (`node --check internal/service/web/app.js` when Node.js is available) and load every page, in the dark and light themes, against a running instance with an isolated data folder (see [DASHBOARD.md](DASHBOARD.md)). Headless browser screenshots taken with `--virtual-time-budget` hang on the live log stream and plain `--screenshot` captures before scripts and transitions finish; drive the browser over the DevTools protocol with a real delay instead. Use synthetic accounts and a local fake Guardian for screenshots; a test instance may use real credentials when that helps.

## Tray checks

`TestTrayIcons` covers the tray icons. The tray menu and the notifications (Linux `notify-send`; Windows shows none) have no automated tests. Check them by hand with a separate copy of the executable, an isolated data folder, and ports other than the defaults (`proxy.listen`, `dashboard.listen` in that folder's `config.json`):

- A start from Explorer or a new console shows the status screen; check the number keys (also Persian digits), Backspace, Esc, **0** stopping the proxy that runs in the window (and restoring a system proxy it set), and, against a copy a tray hosts, **Exit Firefox VPN completely**.
- `-tray` (no console window remains; the dashboard answers with the token from `local-api.token`).
- `-app` started with a redirected standard input: `GET /api/status` reports `can_exit: true`; a second `-app` copy exits with status 3 and a line on the standard error; closing the standard input, `POST /api/app/exit`, or (Windows) `SendMessage` of `WM_ENDSESSION` with wParam 1 to the window of class `FirefoxVPNCoreEndSession` ends the process with status 0, the last only after the stop finished; with a standard input that is not a pipe it keeps running and logs a warning.
- The menu actions, the icon colors, and the tooltip against a fake Guardian or an account you are authorized to use; an invalid `config.json` value shows "Could not start: …" in the tooltip and in the log; with a status screen running the proxy and Set system proxy, a `-tray` started for the same folder and then closed (**Close icon**) leaves the system proxy set.

Stop test copies by PID or path, never by image name.

## Race and build checks

The recorded Windows audit could not run the race detector because GCC was absent. To run it on a suitable Windows development host, use a compatible C compiler and CGO:

```powershell
$env:CGO_ENABLED = '1'
go test -race -count=1 -timeout=180s ./...
```

Use a fresh shell or restore build environment variables when switching targets. A distribution build with CGO disabled does not establish race safety. Build commands and separate development output are in [DEVELOPMENT.md](DEVELOPMENT.md).

## External challenge test

`TestSolveFastlyChallengeE2E` in [challenge_e2e_test.go](../internal/fxa/challenge_e2e_test.go) skips unless `FXA_E2E=1` is set. It sends an invalid test login to the real account API. It is separate from proxy health and does not belong in ordinary local checks.

## Explicit live OAuth test

[live_oauth_test.go](../internal/fxa/live_oauth_test.go) has build tag `live` and an environment guard. After local interactive sign-in:

```powershell
$env:VPN_LIVE_AUTH_TEST = '1'
$env:FXA_LIVE_CREDENTIALS = 'dist\user-data\accounts\<id>\credentials.json'
try {
    go test -tags=live -v -count=1 -timeout=110s -run '^TestLiveOAuthRefresh$' ./internal/fxa
} finally {
    Remove-Item Env:\VPN_LIVE_AUTH_TEST, Env:\FXA_LIVE_CREDENTIALS -ErrorAction SilentlyContinue
}
```

It loads the current user's real refresh token, invokes `fxa.RefreshToken`, saves a successful response with `SaveTokens`, then checks Guardian acceptance. The credential-cache write occurs before Guardian verification. A Guardian failure therefore does not imply the cache was untouched.

The test logs only non-secret metadata. It refreshes explicitly; it does not wait for natural access-token expiry or prove automatic expiry timing against the real service.

`go vet -tags=live ./...` can check the opt-in source without executing the test or changing credentials.

## Live traffic and natural pass renewal

Real traffic needs an account and uses its quota; keep runs short. Attribute success using the listener, the Fastly socket, the response, and the exit observation together; a changed IP alone is not proof.

The location latency measurement uses the active account's pass and opens one session per location. With a synthetic account it reports every location as rejected, which still exercises the code path.

## Documentation-only verification

For documentation edits:

1. Resolve all local Markdown links relative to their containing file.
2. Check referenced source symbols and test names against current code.
3. Compare changed default/schema descriptions with flag declarations and JSON tags.
4. Check balanced fences and English text, including moved files.
5. Confirm no production source, scripts, credentials, or executable were changed accidentally.

Keep test results scoped to what was actually run. A source/link check is not a new runtime verification.
