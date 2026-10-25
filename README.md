# FoxyVPN Desktop

Unofficial Windows desktop client for the **Firefox VPN free proxy** (the
50 GB/month allowance that ships with a Firefox account), ported from the
Android app [FoxyVPN](https://github.com/Vauth/FoxyVPN) and the Go reference
client [firefox-vpn-client](https://github.com/UjuiUjuMandan/firefox-vpn-client).

> ⚠️ For personal and educational use only. This tool does not bypass any
> payment: it uses exactly the free 50 GB monthly quota Mozilla grants every
> Firefox account, subject to the same limits and reset schedule.

---

# FoxyVPN Desktop (نسخه فارسی)

کلاینت دسکتاپ ویندوزی غیررسمی برای **پروکسی رایگان Firefox VPN** (سهمیه ۵۰
گیگابایت ماهانه‌ای که با هر اکانت فایرفاکس ارائه می‌شود)، پورت‌شده از اپ
اندرویدی [FoxyVPN](https://github.com/Vauth/FoxyVPN) و کلاینت مرجع Go
[firefox-vpn-client](https://github.com/UjuiUjuMandan/firefox-vpn-client).

> ⚠️ فقط برای استفاده شخصی و آموزشی. این ابزار هیچ پرداختی را دور نمی‌زند:
> از همان سهمیه رایگان ۵۰ گیگابایت ماهانه موزیلا استفاده می‌کند، با همان
> محدودیت‌ها و بازنشانی ماهانه.

## How it works / نحوه کار

1. **Sign in with a Firefox Account** (FxA protocol: PBKDF2+HKDF `authPW`,
   HAWK-signed session requests, OAuth token).
2. **Guardian** (`vpn.mozilla.org`) issues a **proxy pass** (a short-lived
   JWT). On first use the app calls `/api/v1/fpn/activate` to enable the
   free entitlement.
3. The app dials the selected edge server (`*.fastly-masque.net`) over TLS
   with ALPN `h2` and opens **HTTP/2 CONNECT** streams authenticated with
   `Proxy-Authorization: Bearer <proxy pass>`.
4. A local **SOCKS5 proxy** (and HTTP proxy in stage 2) on `127.0.0.1`
   forwards browser traffic — e.g. Chrome with `--proxy-server` — through
   the tunnel. Stage 3 adds a full system TUN via `hev-socks5-tunnel`.

Server endpoints come from Mozilla Remote Settings
(`vpn-serverlist`) — nothing is hard-coded.

## Stage status / وضعیت مراحل

| Stage | Scope | Status |
|---|---|---|
| 1 | Login → proxy pass → H2 tunnel → exit-IP probe → test SOCKS5 | ✅ working |
| 2 | Web UI (Connect/Settings/About tabs), HTTP+SOCKS5 proxies, auto pass renewal, traffic stats, token cache | ✅ working |
| 3 | TUN Mode (system-wide VPN via hev-socks5-tunnel + wintun, embedded) | ✅ working (v3.0 Release) |
| 4 | Multi-Account Rotation, HTTP/3 QUIC, Modern Web UI | ✅ working (v3.0 Release) |

## Build

Requirements: Go ≥ 1.25, and the `firefox-vpn-client` library checked out
as a sibling directory (`../firefox-vpn-client`), per `go.mod`.

```bash
# Windows (cross-compile from any OS)
GOOS=windows GOARCH=amd64 go build -o build/foxyvpn-desktop.exe ./cmd/foxyvpn

# Linux / macOS
go build -o build/foxyvpn-desktop ./cmd/foxyvpn
```

## Run — Stage 2 App

```bash
./build/foxyvpn-desktop.exe -ui 127.0.0.1:8080 -country NL
# open http://127.0.0.1:8080 → tabs: Connect / Settings / About
# Sign in once; afterwards Connect uses the cached refresh token.
# "Start local proxies" serves SOCKS5 :1080 and HTTP :8888 on 127.0.0.1.
```

## Run — Stage 1 CLI

```bash
# one-shot test: login, fetch pass, probe exit IP
./build/foxyvpn-desktop -country NL <email> <password>

# keep a SOCKS5 proxy running on 127.0.0.1:1080
./build/foxyvpn-desktop -country NL -listen 127.0.0.1:1080 <email> <password>
```

- First run (or a fresh session) may email you a verification code; enter it
  when prompted.
- The refresh token is cached in `~/.foxyvpn-desktop-token.json` (mode 0600)
  so repeat runs avoid the FxA login rate limit. **Stage 2** moves this to
  the Windows Credential Manager.
- FxA rate-limits repeated logins (HTTP 429, ~15 min cooldown) — prefer the
  cached-token path.

## TUN Mode / حالت TUN

In the UI press **TUN Mode (system VPN)**: the app extracts the embedded
`hev-socks5-tunnel.exe` + `wintun.dll`, creates a `FoxyTun` adapter and
routes **all** system traffic through the VPN. Requirements:

- Run `foxyvpn-desktop.exe` **as Administrator** (wintun adapter creation).
- Stop TUN mode before closing the app (button toggles off automatically
  when pressed; killing the process removes the temp adapter files).

در رابط کاربری دکمه **TUN Mode** را بزنید تا تمام ترافیک سیستم از تونل رد شود.
حتماً برنامه را با دسترسی Administrator اجرا کنید.

## Use with Chrome / استفاده با کروم

```bash
chrome.exe --proxy-server="socks5://127.0.0.1:1080"
```

Or use the SwitchyOmega extension (SOCKS5, `127.0.0.1:1080`).

## Troubleshooting / عیب‌یابی

- **`429 Too Many Requests` at login** — FxA cooldown; wait ~15 min or let
  the cached refresh token path run.
- **`token invalid (HTTP 403)` at Guardian** — the app auto-calls
  `/api/v1/fpn/activate` and retries; a persistent 403 means the account's
  entitlement cannot be enabled.
- **`429` at Guardian** — monthly 50 GB quota exhausted; resets monthly.
- **`CONNECT rejected: 400 parsing JWT failed`** — the proxy pass expired;
  stage 2 renews it automatically 2 minutes before expiry.
- **`EOF` at upstream dial** — transient edge issue; retry or pick another
  `-country`.

## Credits

- [FoxyVPN](https://github.com/Vauth/FoxyVPN) (MIT) — Android reference
- [firefox-vpn-client](https://github.com/UjuiUjuMandan/firefox-vpn-client) (MIT) — Go protocol library used here
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) — tun2socks for stage 3

License: MIT.
