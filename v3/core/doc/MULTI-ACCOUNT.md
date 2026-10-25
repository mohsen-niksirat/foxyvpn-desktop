# Multi-Account Mode

The service runs from a configuration file and a set of stored Firefox Accounts. One account supplies the ProxyPass at a time; when it reaches its quota threshold, the next account in priority order takes over without restarting the upstream session.

Accounts are managed in the [dashboard](DASHBOARD.md) (add, sign in again, reorder, enable/disable, use now, remove). Use only accounts you are authorized to use and respect Mozilla's service terms.

## Commands

| Command | Effect |
| --- | --- |
| `firefox-vpn-core` | Run the service: dashboard and proxy |
| `firefox-vpn-core -add-account` | Sign in on the terminal (email, password, emailed code) and store the account at the end of the priority order |
| `firefox-vpn-core -list-accounts` | Print accounts in priority order with status, usage, and the active account |
| `firefox-vpn-core -set-dashboard-login` | Set or remove the dashboard login |
| `-data-dir PATH` | Use another data folder (with any of the above) |
| `-verbose` | Force verbose logs regardless of the config |

Accounts added from the dashboard take effect immediately. After `-add-account` or `-set-dashboard-login` on the terminal, restart a running service.

## Portable data folder

All data lives in a `user-data` folder **next to the executable**. A core in the Windows desktop app's `core` folder (or beside `firefox-vpn.exe`) uses the app's `user-data` instead, so the core shares the app's accounts and settings. The one exception is a core beside the macOS or Linux app (`firefox_vpn` in the same folder, without a `portable` file): it uses the app's data folder (`~/Library/Application Support/Firefox VPN Client`, or `$XDG_DATA_HOME/firefox-vpn-client`). (Not `data`: Flutter keeps its own files in a `data` folder beside the app.) Moving the program's folder moves its data. If the folder is read-only (for example under `Program Files`), startup fails with a message; move the program or pass `-data-dir`.

```text
<program folder>/
├── firefox-vpn-core(.exe)
└── user-data/
    ├── config.json            settings (may contain the dashboard password hash)
    ├── state.json             active account id
    ├── status.json            runtime status snapshot (no secrets)
    ├── selection.json         persisted upstream location
    ├── servers.json           last server list fetched (used offline)
    ├── flags/                 country flags downloaded on demand
    └── accounts/<id>/
        ├── account.json       email, status, last known usage (no secrets)
        └── credentials.json   OAuth access and refresh tokens (secret)
```

Files are written atomically with owner-only permissions on POSIX systems. On Windows they inherit the folder's ACL and are stored as plaintext. **The data folder contains account credentials: do not copy, zip, or share the program folder with it.**


## Configuration

`config.json` is created with defaults on first use. Omitted fields keep their defaults; invalid values stop startup with an error naming the field; unknown fields are dropped with a warning. Durations are strings such as `"10s"` or `"5m"`.

| Field | Default | Meaning |
| --- | --- | --- |
| `proxy.listen` | `127.0.0.1:10810` | Local SOCKS5 address |
| `proxy.username`, `proxy.password` | empty | When set (both), SOCKS5 clients must log in with them (RFC 1929); set them whenever the proxy listens on the network |
| `proxy.country` | empty | Country code or name; empty is Auto (recommended, the `REC` location); `fastest` is Auto (fastest), the lowest real delay at each start |
| `proxy.server` | empty | Exact upstream `host:port`; mutually exclusive with `country` |
| `proxy.transport` | `h2` | `h2` (HTTP/2 over TCP) or `h3` (HTTP/3 over QUIC) |
| `proxy.upstream_connections` | `1` | Upstream sessions; client-IP affinity above 1 |
| `proxy.max_connections` | `256` | Concurrent SOCKS clients; `0` disables the limit |
| (fixed) `config.ConnectTimeout` | `20s` | Upstream dial/handshake and CONNECT opening budget; not in `config.json` |
| (fixed) `config.HandshakeTimeout` / `IdleTimeout` | `10s` / `0` | SOCKS/HTTP handshake limit / established-tunnel idle limit (`0`: never); not in `config.json`. The fixed settings are together in [config.go](../internal/config/config.go), with `ExitCheckTimeout` (20 s, the public IP check) |
| `proxy.idle_sleep` | `15m` | The proxy starts asleep and connects on first use whatever this value. After this long without a connection through Mozilla, the proxy sleeps again: its upstream session closes and the account renews no pass and checks no quota; the next connection, a connection test, or a real-delay test wakes it. `0s` or at least `1m` |
| `proxy.allow_locked` | absent | Ignored: every location is offered, including those Mozilla's server list marks locked. Still accepted so that older files load; not written back |
| `accounts.switch_threshold_percent` | `95` | Used share of an account's quota at which the next account takes over (47.5 GB of 50 GB); with no other account to take over, the active one goes on to the end of its quota |
| `accounts.order` | `[]` | Priority order: `{"id": "...", "enabled": true}` entries |
| `dashboard.enabled` / `listen` | `true` / `127.0.0.1:10820` | Web dashboard; `enabled` can only be changed in the file |
| `dashboard.username` / `password_hash` | empty | Dashboard login; set from Settings or `-set-dashboard-login` (bcrypt hash) |
| `network.api_relay` | empty | The user's own relay (an `https://` URL; a Cloudflare Worker or a PHP file, [scripts/relay](../scripts/relay)) for the FxA, Guardian, Remote Settings, geo-file, and flag requests; see [OPERATOR.md](OPERATOR.md#guardian-returns-http-451-region_unavailable) |
| `network.guardian_endpoint` | `https://vpn.mozilla.org` | Guardian API endpoint |
| `dns.servers` | DNS over HTTPS to 1.1.1.1, 8.8.8.8, and 9.9.9.9 ("Automatic") | DNS servers for the names this program resolves itself (Mozilla's and Firefox Accounts' servers), queried together (first answer wins): `https://…/dns-query` (DNS over HTTPS), `tls://host` (DNS over TLS), or an IP address (plain DNS). Empty uses the system resolver. Connections routed directly use the system resolver whatever this says: they go to the local country's sites, which its DNS answers best. See [OPERATOR.md](OPERATOR.md#dns-and-filtering) |
| `dns.fallback_to_system` | `true` | Use the system resolver when every configured server fails |
| `routing.enabled` | `false` | Send the region's destinations and those named by `routing.direct` directly, refuse `routing.block`; the rest through Mozilla ([CONFIGURATION.md](CONFIGURATION.md#routing)) |
| `routing.region` | `ir` | `ir`, `cn`, `ru`, `af`, `tr`, `id`, `br`, or `""` (none): its preset Direct rules, plus `geoip:private`, are written into `routing.direct`; another region swaps them |
| `routing.direct` / `block` | Iran's presets / empty | Rules, editable: geosite:TAG, geoip:TAG, ext:FILE:TAG, domain:, full:, keyword:, regexp:, IP, CIDR |
| `routing.resolve_domains` | `false` | Look names up to apply IP rules (DNS over HTTPS through Mozilla, never the local DNS) |
| `routing.geosite_url` / `geoip_url` / `update_interval` | Iran-v2ray-rules `geosite.dat` / Iran-v2ray-rules `geoip.dat` / `240h` | List sources and how often they are downloaded again |
| `system_proxy.mode` | `clear` | Windows, applied by the tray, the app mode, or the status screen running the proxy; the user's choice is kept here, so the next start uses it: `set` (Windows' proxy setting points at the local proxy while it runs) or `clear` (system proxy off, once); any other value is refused |
| `logging.verbose` | `false` | Log CONNECT destinations (privacy sensitive) |

New accounts are appended to `accounts.order` automatically. Entries for deleted accounts are dropped. Set `enabled` to `false` to keep an account stored but out of rotation.

## Account selection and failover

`internal/accounts.Manager` keeps each account in one of these states:

| Status | Meaning | Returns to rotation |
| --- | --- | --- |
| `ready` | Can supply a ProxyPass | — |
| `reserved` | Usage reached the switch threshold while another account could take over (reason code `quota_threshold`), or the quota is spent (`quota_exhausted`: nothing left in the quota headers, or HTTP 429) | At the quota reset (`X-Quota-Reset`); after one hour when the reset is unknown |
| `unavailable` | Guardian rejected the account after refresh and activation | After 15 minutes |
| `reauth_required` | FxA rejected the stored refresh token | After signing in again (dashboard or `-add-account`) |

Rules:

1. The active account stays active until it becomes unusable, even when a higher-priority account becomes usable again (its quota reset).
2. When the active account is unusable, the first usable account in priority order takes over. The switch updates the bearer token of the existing upstream session in place; open tunnels continue.
3. Usage is read from the quota headers of every pass request (about every 8 minutes). Between readings, the tunnel traffic since the last one is added to it; once that estimate is within 5 GiB of the threshold, a `HEAD` request reads the usage after every 512 MiB of tunnel traffic, so a large transfer cannot run far past the threshold.
4. Failures that affect every account alike (network errors, Guardian 5xx, HTTP 451) do not switch accounts.
5. When no account is usable, new tunnels stop once the current pass expires; the status file reports `last_error=no_usable_account` with `next_attempt_at`, and the daemon retries at the earliest quota reset (capped at six hours). Before that, an account set aside at the threshold with quota left is used again, so no quota goes unused. This includes an account set aside a moment before: when the account that was to take over at the threshold cannot supply a pass (it must sign in again, Guardian refuses it, or the request fails for every account alike), the account set aside goes on with the pass it supplied and is ready and active again. The same holds when a quota check set it aside: it goes on with its current pass, and the switch is tried again at the next check or renewal.

The active account id survives restarts in `user-data/state.json`. `status.json` adds `active_account` (label or email) to the fields documented in [CONFIGURATION.md](CONFIGURATION.md).

## Source map

| Concern | Source |
| --- | --- |
| Config schema, defaults, validation, data folder | [internal/config](../internal/config/config.go) |
| Account files and credentials | [internal/accounts/store.go](../internal/accounts/store.go) |
| Status, threshold, priority, active account | [internal/accounts/manager.go](../internal/accounts/manager.go) |
| Atomic owner-only writes | [internal/securefile](../internal/securefile/securefile.go) |
| Pass acquisition across accounts | [internal/proxy/accounts.go](../internal/proxy/accounts.go) |
| Supervisor, account and settings operations | [internal/service/daemon.go](../internal/service/daemon.go), [engine.go](../internal/service/engine.go) |
| Terminal commands | [cmd/firefox-vpn-core/commands.go](../cmd/firefox-vpn-core/commands.go) |
| Data folder, account store opening, order reconciliation | [internal/service/paths.go](../internal/service/paths.go) |
| Quota checks, early checks, in-place switch | `checkQuota`, `noteTraffic` in [renewal.go](../internal/proxy/renewal.go) and [controller.go](../internal/proxy/controller.go) |

Tests: `internal/config/config_test.go`, `internal/accounts/accounts_test.go`, `internal/proxy/accounts_test.go` (failover at the threshold, the account set aside going on when the next one cannot take over, HTTP 429 and revoked refresh tokens, shared failures, all accounts reserved, in-place switch during a quota check, the account a quota check set aside going on when the next one fails, early quota checks counting the traffic since the last reading), and `internal/service/paths_test.go` (order reconciliation).

## Limits

- Background token refreshes cannot show a CAPTCHA; an account blocked there eventually needs a new sign-in from the dashboard.
- The terminal `-add-account` handles email codes and confirmation links only; use the dashboard for TOTP, unblock codes, and CAPTCHAs.
- Changes made by terminal commands while the service runs are picked up after a restart.
