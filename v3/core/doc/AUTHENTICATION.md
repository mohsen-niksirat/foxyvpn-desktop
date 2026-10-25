# Authentication, Credentials, and Renewal

Read [architecture](ARCHITECTURE.md) for call boundaries and [sessions](SESSIONS.md) for the effect of renewal on open streams.

## Credential types

| Credential | Used by | Source and storage |
| --- | --- | --- |
| Firefox Account password | Sign-in only | Typed in the dashboard or on the terminal; never stored |
| FxA session token | HAWK-authenticated sign-in steps and OAuth issuance | Created by sign-in; process memory only |
| OAuth access token | Guardian API requests | FxA response; `user-data/accounts/<id>/credentials.json` |
| OAuth refresh token | FxA refresh grant | Issued with offline access; stored with the access token |
| Guardian ProxyPass | Fastly CONNECT `Proxy-Authorization` | Guardian response; process memory |
| Fastly challenge cookies | Challenged account-API calls | Shared control-plane cookie jar, process memory |
| Dashboard password | Dashboard login | bcrypt hash in `config.json`; sessions in memory |

These values are not interchangeable. A ProxyPass update does not imply an OAuth refresh, and successful OAuth refresh does not prove a target CONNECT succeeded.

## Sign-in and account flow

Accounts are added from the dashboard ([DASHBOARD.md](DASHBOARD.md)) or with `-add-account` on the terminal. The dashboard sign-in (`signin_flow.go`) runs in the background and asks the person for input when FxA needs it:

| FxA situation | Step | API used |
| --- | --- | --- |
| Password accepted, session unverified (default) | `need_email_code` | `POST /session/verify_code` |
| Account with two-step authentication | `need_totp` | `POST /session/verify/totp` |
| Confirmation by link (legacy servers) | `need_email_link` | none; the person confirms they opened it |
| Sign-in blocked as unusual (errno 125) | `need_unblock_code` | `POST /account/login/send_unblock_code`, then login with `unblockCode` |
| Fastly image CAPTCHA during any call | `need_captcha` | answered inside the challenge solver through `fxa.WithCaptchaSolver` |
| Email typed in another letter case than the account's (errno 120) | none | login again with the email the error names, and the typed one as `originalLoginEmail` |

The password's key stretching uses the email exactly as the account has it, so FxA refuses another letter case and names the account's own spelling; `fxa.Login` repeats the sign-in once with it, as Firefox does, and the account is stored under that spelling (`fxa.SignedInEmail`). Wrong codes can be retried up to five times. The terminal `-add-account` supports email codes and confirmation links only.

After verification, `fxa.OAuthToken` issues offline OAuth credentials, the account is stored (an existing account with the same email is updated and becomes ready), its quota is read, and the account manager reloads. The session token and password are discarded.

Each account's credentials are loaded by `AccountPool.AuthFor` and refreshed by `FreshRuntimeAuth`/`refreshRuntimeAuth` (`internal/proxy`); refreshed credentials are written back to that account's own file through `runtimeAuth.persist`.

[internal/fxa](../internal/fxa/fxa.go) owns password derivation and HAWK signing (`hawk.go`), `fxa.Login`, `fxa.LoginWithUnblockCode`, `fxa.SendUnblockCode`, `fxa.VerifySession`, `fxa.VerifyTOTP`, `fxa.OAuthToken`, `fxa.RefreshToken`, and `fxa.RegisterDevice`. OAuth issuance uses the FxA credentials grant with `access_type=offline`; refresh uses `grant_type=refresh_token`. When refresh returns no replacement refresh token, the existing one is preserved.

Defaults and relevant paths:

| Service | Endpoint / path |
| --- | --- |
| FxA base | `https://api.accounts.firefox.com/v1` |
| OAuth | `/oauth/token` relative to that base |
| Guardian base | `https://vpn.mozilla.org`, `network.guardian_endpoint` in `config.json` |
| Guardian pass | `GET /api/v1/fpn/token` |
| Guardian quota | `HEAD /api/v1/fpn/token` (headers only, no pass minted) |
| Guardian status | `GET /api/v1/fpn/status` |
| Guardian activation | `POST /api/v1/fpn/activate` |

Every Guardian request sends `Authorization: Bearer`, `Content-Type: application/json`, and `Cache-Control: max-age=0` (fetch's no-cache mode), as Firefox's `GuardianClient` does. Every control-plane request also carries desktop Firefox's `User-Agent` and `Accept: */*` (`controlplane.ApplyFirefoxHeaders`).

[internal/guardian/guardian.go](../internal/guardian/guardian.go) parses the pass and quota headers. A non-200 answer is a `guardian.HTTPError` whose `errors.Is` classification follows Firefox's `GuardianClient.toError`:

| Status | Sentinel(s) | Meaning / CLI handling |
| --- | --- | --- |
| 401 | `ErrTokenInvalid` | OAuth access token refused; refresh it |
| 403 | `ErrTokenInvalid`, `ErrNotEntitled` | Valid token, no proxy entitlement; activate the account |
| 429 | `ErrQuotaExceeded` | Quota spent; `RetryAfter` and quota usage are carried when sent |
| 451 | `ErrRegionUnavailable` | Guardian refuses the requesting region; not retried |
| 5xx | `ErrServer` | Transient; retried with backoff |

`guardian.IsTransient`, `guardian.RetryAfter`, and `guardian.UsageFromError` expose these properties to the CLI. FxA rejections of a stored refresh or session token (HTTP 400/401/403, except errno 107) match `ErrReauthRequired`. Preserve typed errors and `errors.Is`/`errors.As` behavior when changing API parsing.

## Stored credentials

Each account keeps its OAuth credentials in `user-data/accounts/<id>/credentials.json` (fields `access_token`, `refresh_token`, `scope`, `obtained_at`, `expires_in`, and `password`), written through `securefile.WritePrivate`: temporary file in the same folder, owner-only permissions on POSIX, write/close, rename, and a replacement fallback that can remove the old file before a retry. On Windows the file inherits the data folder's ACL.

The Firefox Account password is stored too, so revoked tokens can be replaced without the user ([password.go](../internal/accounts/password.go)): `password` is `v1:` plus base64 of an AES-256-GCM nonce and ciphertext, under a random key in `user-data/accounts/secret.key`. This keeps it out of plain sight; anyone with the whole data folder can decrypt it. Saving refreshed tokens keeps the password (`writeCredentialsLocked`). The API never returns it; `GET /accounts` only reports `has_password`.

**Auto re-login.** When an account's tokens stop working and cannot be renewed, `AccountPool.passFor` calls `AccountPool.Relogin`, which signs in with the stored password. That is the case when the stored credentials cannot be read, when the refresh token is refused (`ErrReauthRequired`), and when Guardian keeps refusing the access token after a refresh (`ErrTokenInvalid` without `ErrNotEntitled`; an account Guardian does not entitle is not helped by new tokens). The outcomes:

| Sign-in result | Account |
| --- | --- |
| Accepted without confirmation | New tokens are stored, the device record is renewed, and the account continues in the same request |
| Mozilla asks for a confirmation code, an unblock code, or a CAPTCHA | `reauth_required` with a reason saying so; **Sign in again** in the dashboard signs in with the stored password (`POST /signin {account_id}`) and only asks for the code |
| Mozilla refuses the password or the sign-in (HTTP 400/401/403) | `reauth_required` with Mozilla's message |
| Mozilla unreachable, HTTP 429 or 5xx | `unavailable` for five minutes, then tried again; the next account serves meanwhile |
| Tokens refused again within 30 minutes of an automatic sign-in | `unavailable` until 30 minutes after that sign-in, so a sign-in that Mozilla keeps confirming by email does not send a mail every minute |

Without a stored password, a refused refresh token makes the account `reauth_required` and a Guardian refusal makes it `unavailable` for 15 minutes.

### Connected services name

`AccountPool.EnsureDevice` registers a device record named "Firefox's built-in VPN" (type `desktop`) with `POST /v1/account/device`, authenticated with the account's refresh token, which is how the Mozilla account's connected services page lists this program. Firefox's own built-in VPN takes its token through the signed-in Firefox (`fxAccounts.getOAuthToken`, scope `profile` and `vpn`) with the same Firefox client ID this program uses. The record is made once per refresh token (`device_id` and a token fingerprint in `account.json`, written with `Store.SaveDevice`; the account manager saves only its own fields with `Store.SaveState`, so it never erases the record): at sign-in, after an automatic sign-in, and at startup for accounts without one. When FxA refuses the refresh token there (errno 110, for example after the entry was removed on the connected services page), `AccountPool.RecoverRevoked` signs in again at once instead of waiting for the access token to expire; if that needs the user, the account is marked for **Sign in again**, except while it is the only usable active account. Other failures are logged and change nothing else. A Guardian 401 in the quota check renews at once too.

Every sign-in (dashboard, terminal, automatic) ends its session token with `fxa.DestroySession` (`POST /v1/session/destroy`) as soon as the OAuth tokens exist, and an automatic sign-in that Mozilla wants confirmed ends it too (**Sign in again** starts a new one). The program needs only the refresh token; a session left alive appeared in connected services as a second entry named "unknown" next to "Firefox's built-in VPN". OAuth tokens are separate from the session in FxA (Firefox itself destroys its session and its OAuth tokens separately when signing out). Entries named "unknown" left by earlier versions can be signed out on the connected services page.

`runtimeAuth.accessTokenValid` applies a two-minute margin. Loading credentials keeps their acquisition time; it never resets the access-token lifetime.


Ordinary development does not need real credentials. Tests use temporary HOME/USERPROFILE and data folders with synthetic credentials. Do not include account secrets or response bodies in reports.

## ProxyPass and claim times

`ProxyPassInfo` holds the raw pass, decoded claims, raw and parsed quota metadata (`Usage`, `UsageErr`), the local receipt time, and the claim-time correction. The client decodes JWT claims for timing but does not verify their cryptographic signature; the upstream validates acceptance. `aud` may be a string or an array.

`anchorProxyPassClaims` follows Firefox (bug 2054514): when the claims disagree with the local clock by more than one minute, the pass is treated as valid from the moment it was received for its claimed lifetime (`exp - nbf`, or `exp - iat` without `nbf`). While the clocks agree, the raw claims are used, which never extends a pass beyond its signed expiry. A pass without `exp`, or whose `exp` is not after its start claim, is rejected. Use `ProxyPassInfo.ExpiresAt()` and `NotBefore()` rather than duplicating raw claim-time conversion; a change here affects both admission and renewal scheduling.

`ProxyUsage` parses quota headers like Firefox: `X-Quota-Unlimited: true` needs nothing else; otherwise `X-Quota-Limit`, `X-Quota-Remaining`, and `X-Quota-Reset` (RFC 3339, or Unix seconds) must all be present, non-negative, and consistent. Invalid headers leave `Usage` nil without rejecting the pass.

## Renewal call path

```text
RunRenewalLoop
  -> nextRenewalDelay
  -> renewWithTimeout
  -> renew / renewLocked under renewMu (context cancelled at the watchdog deadline)
  -> acquireUsablePass
       -> AccountPool.AcquirePass (account selection and failover; MULTI-ACCOUNT.md)
            -> FreshRuntimeAuth (refresh when the access token is near expiry)
            -> fetchProxyPassCtx (bounded retry) / guardian.FetchProxyPass
            -> recoverGuardianRejection: refresh on 401, activate on 403
  -> adoptPass
       -> updateCurrentSessionToken, or sessionFactory + swapSession
```

| Timing | Current constant / behavior |
| --- | --- |
| ProxyPass lead | `proxyPassRenewLead`: two minutes before expiry |
| Minimum spacing of successful renewals | `minRenewalInterval`: 10 seconds |
| Guardian pass fetch retry | 500 ms doubling backoff inside `guardianRetryBudget` (30 seconds), only for transport errors and HTTP 5xx; `Retry-After` is honored when it fits |
| Retry after a transient renewal failure | `proxyPassRetryDelay`: 30 seconds (longer when `Retry-After` asks) |
| Retry after a terminal renewal failure | `terminalRenewalRetryDelay`: 15 minutes; spent quota waits for `X-Quota-Reset` (capped at six hours) |
| Renewal watchdog | `PassRenewTimeout`: two minutes, then `proxyPassRenewAbandonGrace`: 30 seconds |
| Runtime OAuth lead | `oauthRefreshLead`: two minutes |
| Quota reading | From the quota headers of every pass request (about every 8 minutes), as Firefox does; once the last reading plus the tunnel traffic since then is within 5 GiB of the switch threshold (whether or not another account can take over), also a `HEAD` request after every 512 MiB of tunnel traffic |

OAuth refresh is reached through the authentication/pass lifecycle; there is no separate periodic OAuth refresh timer.

`renewWithTimeout` runs the renewal with a context that is cancelled at the watchdog deadline, so FxA, challenge, and Guardian calls stop. A timed-out renewal is recorded as an ordinary failure and retried; if the cancelled worker returns with a success after all, that counts. A worker that has not returned after the abandon grace is reported as stuck (status `renewal_failed`), and the loop waits for it before the next renewal: the process never exits, since on Android it carries the phone's VPN and on a desktop the system proxy points at it. The Fastly challenge solver, the usual long wait, gives up when its caller's context ends. `proxy.connect_timeout` is not this watchdog.

Terminal failures are reported, not hammered: `reauth_required` (FxA rejected the stored credential), `region_unavailable` (HTTP 451), `not_entitled`, `quota_exhausted`, and `no_usable_account` back off as listed above (the last one until the earliest quota reset). The failure code and next attempt time are written to the status file.

## Recovery and quota

Startup, renewal, quota checks, and manual account switches all obtain passes through `AccountPool.AcquirePass`; tests that build a controller without an account pool exercise the same recovery through `acquireUsablePass` with one fixed auth.

- HTTP 401 triggers an OAuth refresh; HTTP 403 (also after a refresh) triggers Guardian activation (`recoverGuardianRejection`).
- Transient network/server failures and HTTP 451 return without trying other accounts, because every account would fail the same way.
- Quota at the switch threshold, HTTP 429, a spent quota, an FxA sign-in requirement, or a persistent Guardian rejection move to the next usable account; see [MULTI-ACCOUNT.md](MULTI-ACCOUNT.md).
- The quota monitor reads usage with `HEAD` and only fetches a pass when the active account must hand over.
- A CONNECT HTTP 429 is a transport-level error observation; it does not alone trigger immediate session reconstruction.

Do not infer live quota-exhaustion behavior from parsing quota headers. The historical live run observed quota values but did not deliberately exhaust an account.

## Challenge and timeout boundaries

[internal/controlplane](../internal/controlplane/client.go) owns a shared 30-second HTTP client and cookie jar. Configure `controlplane.SetTransport` before requests start. This client is distinct from data-plane sessions.

[challenge.go](../internal/fxa/challenge.go) handles account-API HTTP 406 challenges, PoW/PAT, and challenge cookies, with at most five challenge attempts. `contextWithMinDeadline` can extend a short caller deadline to the configured minimum: FxA uses 90 seconds and challenge solving uses 60 seconds. Check the actual context path before promising a strict end-to-end timeout.

Do not disable production TLS validation to work around a challenge or local interception. Test-only certificate configurations must remain local to tests.

## Relevant tests

- `TestAccountPool*`, `TestDashboardSignInWithEmailCode`: account failover and the dashboard sign-in flow.
- `TestLoginWithUnblockCodeSendsCode`, `TestVerifyTOTPReportsRejectedCode`, `TestAnswerChallengeAsksCaptchaSolver`: unblock codes, TOTP, and CAPTCHA answers.
- `TestLoginCorrectsTheEmailCase`: an email in another letter case is signed in with the account's own spelling.
- `TestNewFxaAPIErrorParsesErrno`: typed account error parsing.
- `TestAnchorProxyPassClaims*`, `TestFetchProxyPassSendsNoCacheAndAnchorsExpiry`: Guardian claim-time anchoring.
- `TestHTTPErrorClassifiesStatus`, `TestParseProxyUsage`, `TestFxaAPIErrorClassifiesReauthRequired`: status, quota, and sign-in classification.
- `TestFetchProxyPassRetriesTransientGuardianFailure`, `TestAcquireUsablePassActivatesOnNotEntitledWithoutRefresh`, `TestRenewalRetryDelayBacksOffTerminalFailures`: retry and recovery policy.
- `TestWritePrivateReplacesContentAndTightensPermissions`: credential file replacement and permissions.
- `TestAuditSOCKSConnectAndRenewal`: controlled automatic expired-access refresh, pass renewal, saved response, and stream preservation for H2/H3.
- `TestLiveOAuthRefresh`: explicit real-account refresh and Guardian acceptance, only with authorization and opt-in.

See [TESTING.md](TESTING.md) for commands, fixture isolation, and the distinction between explicit refresh and waiting for natural OAuth expiry.
