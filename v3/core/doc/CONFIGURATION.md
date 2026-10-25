# Configuration and State Contracts

All settings and state live in the `user-data` folder next to the executable, in the desktop app's data folder when the core sits beside `firefox-vpn.exe`, or in `-data-dir`. This guide lists every file in it and the selection rules that read them. The full `config.json` field table is in [MULTI-ACCOUNT.md](MULTI-ACCOUNT.md#configuration); dashboard behavior is in [DASHBOARD.md](DASHBOARD.md).

## Entry points

| Entry point | Source | Behavior |
| --- | --- | --- |
| Executable flags | [main.go](../cmd/firefox-vpn-core/main.go), [commands.go](../cmd/firefox-vpn-core/commands.go) | Data folder, the one-shot commands, `-verbose` |
| `config.json` | [internal/config](../internal/config/config.go) | Every runtime setting; created with defaults on first use |
| Dashboard Settings | `PUT /api/settings` -> `Daemon.updateSettings` | Validates, saves `config.json`, applies live or restarts the proxy |
| Linux service | [install-systemd.sh](../scripts/install-systemd.sh) | Installs to `/opt/firefox-vpn`; no settings of its own |
| API relay | `network.api_relay` -> `configureAPIRelay` -> `controlplane.SetTransport(relayTransport)` | Sends control-plane requests through the user's relay (`?url=<target>`, [scripts/relay](../scripts/relay)), independently of the Fastly data plane |

| Listener | Default |
| --- | --- |
| SOCKS5 (`proxy.listen`) | `127.0.0.1:10810` |
| Dashboard (`dashboard.listen`) | `127.0.0.1:10820` |

## Server selection

`serverlist.Fetch` reads Remote Settings. `serverlist.Filter` applies each record's `filter_expression`, as Firefox's Remote Settings client does: the supported JEXL subset is a conjunction (`&&`) of `env.version|versionCompare("X") <op> N` and `env.country ==/!= "XX"` terms. `env.version` is the newest Firefox version, read from Mozilla's product details (`serverlist.LatestFirefoxVersion`: Nightly, else the release) and refreshed every 12 hours (`daemon.firefoxVersion`); without it the last value or `serverlist.DefaultFirefoxVersion` is used. Versions compare with Mozilla version-comparator semantics and `env.country` is unknown (empty). Unsupported expressions fail closed. The live collection uses this to serve two different `US` records depending on the Firefox version.

`proxy.ConnectCandidates` converts non-quarantined CONNECT metadata into `proxy.Candidate` entries. A missing server port defaults to 443, a missing protocol list means CONNECT on the server itself, and a `connect` protocol inherits a missing host/port from its server. `masque` entries and non-`https` CONNECT schemes are skipped.

Selection lives in `proxy.ResolveWithStateAndCountry` and `selectProxyCandidate` ([internal/proxy/selection.go](../internal/proxy/selection.go)), called by the engine's first wake (`connectEngine`; the engine starts without contacting Mozilla):

1. `proxy.country` and `proxy.server` are mutually exclusive. `proxy.country = "fastest"` first obtains the pass, measures the locations through the tunnel (`resolveFastestCountry`, reusing a measurement younger than 30 minutes), and continues with the fastest country code among every location (a location that failed the measurement is not picked), or the recommended location when none answered.
2. An exact server can be used even when no server-list metadata matches; its geography may be unknown.
3. Whenever a location is selected automatically, the server list is fetched on every engine's first wake (like Firefox at a connection) so a saved selection is revalidated; it is fetched while the pass is requested, and the latest Firefox version while the list downloads.
4. A saved selection (`selection.json`) is reused when it matches the configured country and is still a list entry. When no countries could be fetched, matching saved metadata is used directly. Changing the country or server in Settings deletes the saved selection.
5. Every location is eligible, including those the server list marks `locked` (Firefox shows them only under preconditions): Mozilla's proxy servers accept an ordinary account's pass on all of them (verified 2026-10-23 on all 34 locations, with exits in the expected countries). `proxy.allow_locked` is ignored; a file that still has it loads, and it is not written back.
6. Without a country, the recommended location (`REC`, the anycast entry) is used when present. `REC` or `recommended` selects it explicitly; other country filters never match it.
7. A country selects the first matching city in deterministic list order, and one of its servers at random. Without `REC` and with several countries, an explicit choice is required.
8. A server that fails three times in a row (to connect, or by breaking its sessions) is avoided for 15 minutes and replaced by another server of the same location: another server of its city, else of the location's next city; for the recommended location and `fastest`, the next server of the location the selection works on. The new server is saved as the selection, so a restart does not go back to the failed one; while a saved server is avoided, the next first wake selects another. Failures of the network, the account, or its pass do not count, and the country never changes; when every server of the location failed recently, the upstream stays and retries as before ([SESSIONS.md](SESSIONS.md#server-failover)).

Should Mozilla start enforcing the lock, the server of a chosen location refuses the CONNECT (403 or 407) even with a new pass; the connection test then reports `location_refused` ([DASHBOARD.md](DASHBOARD.md#failure-codes)). Hostname persistence does not pin a physical server, network path, public IP, or address family.

## Files in the data folder

| File | Owner | Contains | Secret |
| --- | --- | --- | --- |
| `config.json` | [internal/config](../internal/config/config.go) | All settings, account order, dashboard username and bcrypt password hash | Hash only |
| `accounts/<id>/credentials.json` | [accounts/store.go](../internal/accounts/store.go) | OAuth access and refresh tokens, and the encrypted password | Yes |
| `accounts/secret.key` | [accounts/password.go](../internal/accounts/password.go) | Random key that encrypts the stored passwords | Yes |
| `accounts/<id>/account.json` | `accounts.Store` | Email, label, status, reason, retry time, last usage | No (personal) |
| `state.json` | `accounts.Manager` | Active account id | No |
| `selection.json` | Selection helpers, `proxy.ServerFailover` | Saved upstream address and location metadata | No |
| `flags/xx.svg` | `Daemon.flag` (flags.go) | A country flag the program does not carry, downloaded once from flag-icons (jsDelivr `@main`, else GitHub; through Mozilla when the proxy is awake) when the dashboard or the app asks `GET /flags/xx.svg`. The web folder and the app carry only the flags of Mozilla's locations; a failed download is not tried again for 10 minutes | No |
| `servers.json` | `Daemon.refreshLocations` | The last server list fetched from Mozilla's Remote Settings, as fetched (filtered again on use), and when. Loaded at start, so the locations show at once; used when a fetch fails; a connection whose pass is ready before the new list uses it instead of waiting (`serverlist.SaveCache`, `LoadCache`) | No |
| `status.json` | `proxy.Controller` | Runtime status snapshot | No |
| `local-api.token` | `Daemon.Run` | Random key for local clients (the tray), replaced on every start, written only after the dashboard address is bound | Yes (local API access) |
| `logs/firefox-vpn-YYYY-MM-DD.log` | `logx` (`dailyFile`) | Log lines, one file per local day; the last seven days are kept and the oldest is deleted when the eighth day starts; a day's file stops at 10 MiB | No (redacted) |
| `routing/geosite.dat`, `routing/geoip.dat` | `routing.Download` | v2ray domain and network lists for routing, downloaded again every `routing.update_interval` | No |
| `dashboard.key` | Dashboard | Random key that signs the dashboard's session cookies; deleting it signs every browser out | Yes (dashboard access) |
| `.tray.lock` | Linux tray | Single-instance lock | No |

All files are written atomically with owner-only permissions on POSIX (`securefile.WritePrivate`); on Windows they inherit the data folder's permissions, with no special access list.

### config.json

Loaded by `config.Load`, which fills omitted fields with defaults, validates values (see `Config.Validate`), and drops unknown fields (settings this build no longer has, or typos) with a warning in the log, rewriting the file without them. `proxy.country` values `REC` and `recommended` are stored as the empty country (the recommended location). Saved by `config.Save` from the dashboard, the account commands, and order reconciliation. Durations are strings (`"10s"`). The schema `version` is 1; a newer version is refused.

`accounts.order` entries are `{"id", "enabled"}`. `service.ReconcileAccountOrder` drops entries for deleted accounts and appends stored accounts that are missing, so hand edits cannot lose accounts.

### selection.json

`proxySelectionState` defines `addr` and optional `country_name`, `country_code`, `city_name`, and `city_code`. See `loadProxySelection` and `SaveSelection`. The first wake writes it after a successful connection; `ServerFailover.Failed` rewrites it when it moves the upstream to another server of the location. The failures counted toward that and the avoided servers are kept in memory only.

### status.json

`proxy.RuntimeStatus`, written on state changes (not a heartbeat):

| Field | Meaning |
| --- | --- |
| `updated_at` | Timestamp of this snapshot |
| `pid` | Process ID |
| `proxy_pass_expires_at` | ProxyPass expiry |
| `seconds_until_expiry` | Remaining seconds at write time |
| `accepting` | Whether the current session admits new tunnels |
| `reason` | `startup`, `token_updated`, `session_swapped`, `expired`, `renewal_failed`, `quota_checked`, `closed`, or `sleeping` (the proxy listens without an upstream session or pass: from its start until first used, and after `proxy.idle_sleep`; written by `proxy.WriteIdleStatus`, with only `updated_at`, `pid`, `accepting` false, and `reason`) |
| `active_account` | Name of the account supplying the pass |
| `last_error` | Failure code of the last renewal: `reauth_required`, `region_unavailable`, `not_entitled`, `token_rejected`, `quota_exhausted`, `no_usable_account`, `guardian_server_error`, `timeout`, or `renewal_failed`; omitted after success |
| `next_attempt_at` | Next renewal attempt after a failure |
| `quota_unlimited`, `quota_limit_bytes`, `quota_remaining_bytes`, `quota_reset_at` | Last known quota of the active account |

The dashboard reads live state from the daemon instead of this file; it remains for external health checks.

## DNS

`configureDNS` builds a `resolver.Resolver` from `dns` at start and whenever the setting changes, and installs it process-wide (`resolver.Set`). The control-plane HTTP client, the API relay's own connection, H2 upstream dials, and H3 address lookups use it; DoH servers themselves are reached through the system resolver when given by name. SOCKS target names are never resolved locally for Mozilla; a connection the routing sends directly is dialled with the system resolver (`proxy.directDialer`), since it goes to the local country's sites. The default is DNS over HTTPS ("Automatic"), so a filtering network cannot hijack the names of Mozilla's servers.

## Routing

Off by default (`routing.enabled`). When on, `proxy.RoutedOpener` asks `routing.Router.Decide` for every SOCKS5 or HTTP proxy connection: **Block** rules refuse it (SOCKS reply 0x02, HTTP 403), **Direct** rules connect directly through the local network with the system's DNS (`proxy.directDialer`), and everything else goes through Mozilla. Rules: `geosite:TAG` and `geoip:TAG` (tags of `routing/geosite.dat` and `routing/geoip.dat`), `ext:FILE.dat:TAG` (a tag of another geosite file in `routing/`; its rules are left out, named in `Router.Missing`, until the file is there), `domain:NAME` (the name and names under it), `full:NAME`, `keyword:TEXT`, `regexp:EXPR`, an IP, or a CIDR; a bare name is `domain:`. Block wins over Direct.

The Direct rules are `routing.direct` as it stands. The preset rules of `routing.region` (`routing.RegionRules`) are written into that list (the default config has Iran's), where the user can change or remove them; choosing another region replaces the old region's presets in the list with the new one's and keeps the user's own rules (`routing.SwapRegionRules`, in `Daemon.updateSettings`), and the app's and the dashboard's **Restore the region's rules** puts them back. A config of version 1, which added the presets by itself, gets them written into the list once on load. The other geosite files the rules name (`ext:iran.dat:ir`) are downloaded with the lists (`routing.FilesFor`). The presets always include `geoip:private`:

| `routing.region` | Preset Direct rules |
| --- | --- |
| `ir` (default) | `geosite:ir`, `ext:iran.dat:ir`, `geoip:ir`, `geoip:private`; `iran.dat` is [bootmortis/iran-hosted-domains](https://github.com/bootmortis/iran-hosted-domains)' latest release (69,511 names in October 2026 against 57,554 in `geosite:ir`), downloaded with the two lists (`routing.RegionFiles`) |
| `cn` | `geosite:cn`, `geoip:cn`, `geoip:private` |
| `ru` | `geosite:category-ru`, `geosite:tld-ru`, `geoip:ru`, `geoip:private` |
| `af` | `domain:af`, `geoip:af`, `geoip:private` |
| `tr` | `domain:tr`, `geoip:tr`, `geoip:private` |
| `id` | `domain:id`, `geoip:id`, `geoip:private` |
| `br` | `domain:br`, `geoip:br`, `geoip:private` |
| `""` (none) | `geoip:private` |

Any other value is refused by `config.Validate` (`routing.region: unknown region …`). The default lists are both from Chocolate4U/Iran-v2ray-rules (`routing.DefaultGeoSiteURL`, `routing.DefaultGeoIPURL`). One other list set is offered as well (`routing.Sources`): Loyalsoldier/v2ray-rules-dat; both cover every country. A region change moves an offered set to the region's usual one (`routing.RegionSource`: Loyalsoldier's for China, Chocolate4U's otherwise, since only its domain list has `ir`); URLs set by hand stay. runetfreedom/russia-v2ray-rules-dat, which v2rayNG offers too, is not: 88% of its 74 MB domain list are two Russian blocklists (`ru-blocked-all`, `antifilter-download`) that no preset uses, and the core reads a list whole while it builds the rules. The routing folder records where its lists came from (`lists-source.txt`), so other URLs download them again before they are old (`routing.SourceChanged`). Checked on 2026-10-15: both network lists have all countries (260 and 278 tags); Loyalsoldier's domain list has `category-ir` but no `ir`, and both have `cn`, `geolocation-cn`, `category-ru`, and `tld-ru`. The Chocolate4U lists, despite the name, are not Iran-only: on 2026-10-15 `geoip.dat` had 278 country tags and `geosite.dat` 1,553 tags (v2fly's lists plus Iranian extras), and they carry every tag the presets name: `geosite.dat` has `ir` (57,554 domains: .ir names and Iranian names elsewhere such as digikala.com), `category-ir`, `cn`, `geolocation-cn`, `category-ru`, `tld-ru`, and `private`; `geoip.dat` has `ir`, `cn`, `ru`, `af`, `tr`, `id`, `br`, and `private`. Regions without a geosite tag in it use their country-code top-level domain. A preset naming a tag that a custom list lacks leaves routing inactive with that error, like any rule. The router built from the effective rules also drives the destination test.

Clients usually send names, so domain rules decide without DNS. IP rules apply to address targets; with `routing.resolve_domains` a name that no domain rule matched is looked up (three seconds at most, the resolver's cache) to apply them. The lookup is DNS over HTTPS to 1.1.1.1 and 8.8.8.8 (both asked, the first answer wins, cached for its TTL) inside tunnels through Mozilla (`resolver.NewThrough`, `RoutedOpener.lookup`), never the local DNS and never the system resolver as a fallback: Iran's filtering answers a blocked name with the private address of its block page (10.10.34.35), which `geoip:private` would send directly. A failed lookup sends the name through Mozilla. The lookup tunnels are not counted as client connections; a sleeping proxy wakes for them. The dashboard's destination test looks up the same way and only while the proxy runs. The lists are read once into memory (only the named tags): suffix names are map lookups per label and networks sorted, merged ranges with a binary search, so a decision takes microseconds (measured: 57,554 domains in 15 ms, 2,557 Iranian ranges in 5 ms to load).

The daemon downloads both lists when routing is on and a file is missing or older than `routing.update_interval` (checked hourly and after settings changes), through Mozilla's proxy when it runs and otherwise, or when that fails, directly with the DNS and API proxy settings; a file is replaced only by a complete, readable list. Settings changes apply live: open connections keep their route. **Update the lists now** in Settings downloads at once, also while routing is off.

## Windows system proxy

The local proxy runs from the start (as far as the accounts allow), except in the desktop app's core process, which starts it off; `POST /api/power` turns it on and off. `system_proxy.mode` is the only choice about Windows: what the tray, the desktop app's core process (`-app`), or the status screen running the proxy in its window does with the user's Windows proxy setting (`HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings`), as in v2rayN (`systemProxySync`):

| Mode | Effect |
| --- | --- |
| `set` | While the proxy runs: `ProxyServer` = the local proxy address (the HTTP proxy on the SOCKS5 port), `ProxyOverride` = local and private addresses, `ProxyEnable` = 1, and no `AutoConfigURL` (a setup script would take precedence) |
| `clear` (default) | A setting this program made is restored first; then, once when the user switches to `clear`: `ProxyEnable` = 0 and no `AutoConfigURL`, whoever set them; a proxy set by hand later stays. A tray or app mode that starts in `clear` only undoes a setting of this program's; another program's proxy (such as v2rayN's) stays |

Any other value is refused by `config.Validate` (`system_proxy.mode "…" is not supported; it must be "set" or "clear"`), and so by `POST /api/system-proxy` and the settings endpoint.

Only the tray, the app mode, and the status screen while the proxy runs in its window apply it, in the signed-in user's session (the other run modes, such as `-plain` and systemd, only store the mode); the app mode reads the mode from `GET /api/status` every two seconds, and the status screen from its own daemon (`systemProxySync.follow`). A tray that only controls a copy which applies the mode itself (`system_proxy_by_host` in `GET /api/status`) leaves the setting to that copy and does not restore it when the icon closes; for a copy that does not (`-plain`), the tray applies it. For `set`, the proxy counts as running from its start, while asleep too (its port is open); while it is not running (starting, waiting, error), when the service is unreachable, or when the tray, the app-mode process, or the status screen running the proxy ends, the previous setting (kept in `HKCU\Software\FirefoxVPN\PreviousProxy`, including a setup script the user had) comes back, unless the user chose another proxy meanwhile; a setting left by a copy that ended without restoring is restored by the next tray or app mode. Applications are told through `InternetSetOption`.

## Logs and exit probes

Logs go to the dashboard's in-memory buffer of 2000 entries and to the day's file in `user-data/logs` (`firefox-vpn-YYYY-MM-DD.log`); in a terminal or under systemd they also go to stderr (the console or the journal). The tray and the app mode (`-app`) write only the file. CONNECT destinations and response bodies are redacted unless verbose logging is enabled, and account emails show only their first letters and domain (`ha****@example.com`, `logx.Email`; a label that is no email shows as it is) unless verbose logging (Detailed logs) is enabled.

The connection test runs by itself after the proxy first connects to Mozilla (its first wake, unless that wake was a requested test) and after its upstream session was rebuilt (`Daemon.autoTest`), and from Test connection; it includes the public IP check, which always runs (each service waiting 20 seconds, `exitCheckTimeout`). Both go through the proxy controller, never directly and never through routing. Both are non-fatal. `proxy.VerifyExit` finds the public IPv4 and IPv6 address at the same time with two requests to Cloudflare's trace at its IP addresses: `https://1.1.1.1/cdn-cgi/trace` and `https://[2606:4700:4700::1111]/cdn-cgi/trace` (key=value, the address and the country). Cloudflare's country comes first: it is the one the many sites behind Cloudflare see, from a database kept current. Each host has addresses of one family only, so Mozilla's proxy reaches it over that family and it sees the exit address of that family; a dual-stack host such as `api.ip.sb` shows only the family the proxy prefers (IPv6). When the trace does not answer, ip.sb is asked for that family (`https://api-ipv4.ip.sb/geoip`, `https://api-ipv6.ip.sb/geoip`; JSON with the country, city, ISP, and ASN; the service v2rayNG uses). ip.sb is also asked alongside for the city and network, which the trace does not report; its country never replaces Cloudflare's. An answer of the wrong family is ignored. The check fails only when neither family answers; an exit without IPv6 reports only IPv4. `ipinfo.io` was not used: it has IPv4 addresses only and limits requests without a token per IP, which Mozilla's shared exit addresses would reach.
