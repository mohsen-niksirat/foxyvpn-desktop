# Firefox VPN app

The Flutter app: the shared UI for Windows, Linux, macOS, and Android. It holds no
VPN logic; it is a client of the core's dashboard API on loopback
(`core/doc/DASHBOARD.md`), authorized by the `X-Local-Token` header from
`local-api.token` in the data folder.

## Desktop model (Windows)

- The app starts the core as a child process, `core\firefox-vpn-core.exe -app -data-dir
  <data>` (in a `core` folder, so the app is the only program beside it), and stops it on quit (`POST /api/app/exit`, then closing its
  stdin). The core also exits when its stdin closes, so it never outlives
  the app, even after a crash. When a core already answers for the data
  folder, the app uses it and leaves it running.
- The close button asks whether to minimize to the tray or quit, with
  "Remember my choice"; Settings changes the choice later.
- One copy per data folder: launching the app again brings the running
  window up, also from the tray (a named mutex and a broadcast message in
  `windows/runner/main.cpp`).
- Start with Windows (Settings > General) is on by default: the app writes
  the current user's Run key to start itself with `--autostart`, which
  keeps the window in the tray. Each version that runs points the entry at
  itself. Copies started with `--data-dir` (development, tests) leave the
  Run key alone.
- The window opens centered, 820×680, without a maximize button.
- The tray icon and the close button are native code in
  `windows/runner/desktop_bridge.cpp` (method channel `app/desktop`), so the
  app needs no plugins.
- App preferences (language, theme, close button) are in
  `<data>/app-settings.json`; VPN settings belong to the core.

## Desktop model (Linux)

The same as on Windows, with the Linux names: the app is `firefox-vpn`
with `core/firefox-vpn-core`, and `linux/runner/desktop_bridge.cc` is the
native side of the same channel.

- The tray icon is an AppIndicator, loaded at run time
  (`libayatana-appindicator3` or `libappindicator3`); without it the app
  still runs, and minimizing to the tray minimizes the window instead. An
  AppIndicator has only a menu: its first entry (Open) also answers a middle
  click.
- Notifications go to the desktop's notification service over D-Bus; a
  click opens the window.
- Start at sign-in writes `~/.config/autostart/firefox-vpn-client.desktop`.
- One copy per user (GtkApplication `com.arman.firefoxvpn`); copies started
  with `--data-dir` run beside it.
- The core sets GNOME's proxy setting (gsettings `org.gnome.system.proxy`),
  which GNOME-based desktops and most browsers read.

## Desktop model (macOS)

The same again: `Firefox VPN.app` holds `firefox-vpn-core` beside its
executable in `Contents/MacOS`, and `DesktopBridge` in
`macos/Runner/MainFlutterWindow.swift` is the native side of the channel.

- The tray icon is a menu bar icon; a click opens its menu. While the window
  is hidden the app has no Dock icon. Opening the app again (Finder, Dock,
  Spotlight) brings the window up.
- Start at sign-in writes the LaunchAgent
  `~/Library/LaunchAgents/com.arman.firefoxvpn.plist`.
- No App Sandbox: the app starts its core and changes the proxy setting.
  It is signed ad hoc, not with an Apple Developer ID.
- The core sets the web, secure web, and SOCKS proxies of every enabled
  network service with `networksetup`, keeping each service's previous
  setting to restore.

The data folder (accounts, settings, logs) on Windows is `user-data` next
to the app (not `data`, which holds Flutter's own files). The installer puts
the app by default in `%LOCALAPPDATA%\Programs\Firefox VPN Client`, a folder
of the user's own; the first install lets the user choose another folder they
can write to. A new version replaces the app where it is, keeping
`user-data`; the portable zip holds a `Firefox VPN` folder to unpack over the
old one. On macOS the
data is in `~/Library/Application Support/Firefox VPN Client`, on Linux in
`~/.local/share/firefox-vpn-client`; a file named `portable` next to the app keeps
it in `user-data` beside it there too.

Arguments: `--data-dir=<path>` (overrides the above) and `--core=<path>`
(default: `firefox-vpn-core.exe` next to the app).

- Ports: the core's defaults are 10810 (SOCKS5 and HTTP proxy) and 10820
  (its API). When the API port is taken (the core exits with
  `app-error: dashboard_port_in_use <address>` on stderr), Windows keeps it
  for itself, or another program answers there, the app moves the API by
  itself to a free port above it (it edits `dashboard.listen` in
  config.json, since the core is not running); only this app uses that
  port. After three moves in a run it shows the problem and offers another
  port. The proxy port never moves on its own, since the user may have set
  it up in other programs: when it is taken, the status carries
  `code: proxy_port_in_use`, and when it cannot be used otherwise (such as
  a port Windows reserves) `code: start_failed` with its `address`; the home
  page says so and offers another port through the API. Settings changes
  either port at any time.

- The core starts with the proxy off; the round button on the home page
  connects and disconnects (`POST /api/power`), and Connect on startup
  (Settings) connects when the app starts. Whether Windows uses the proxy
  is a separate choice beside it, in v2rayN's words: Set system proxy
  ("System proxy") or Clear system proxy ("Proxy"). The tray menu is
  short: Open, Proxy service only, Set system proxy, Quit. Notifications
  show while the window is in the tray.
- Developer mode (Settings > General) adds the technical details: the
  connection test's stages and total, server addresses, and the Logs tab.
- About shows the versions and checks GitHub for a newer release
  (`githubRepo` in `lib/app_info.dart`, empty until the repository exists).
- Country flags are the core's SVG flags (flag-icons, MIT), drawn with
  flutter_svg.

## Android

The core runs in the app's process: `core/mobile` built by gomobile into
`android/app/libs/core.aar` (not in Git; see `core/doc/DEVELOPMENT.md`),
started by a foreground service (`CoreService.kt`) with a lasting
notification whose Stop action ends the service and the app. Its data is in
the app's private storage (`files/core`). The UI talks to it through the
same API on loopback (`lib/core/android_core.dart`, channel `app/android`).
Android is a VPN: the core runs with the proxy off while the UI is open
(settings and accounts work), and the home button, or the Quick Settings
tile (`QuickTile.kt`), turns it on. `CoreService.kt` is then a VpnService:
it asks for the VPN permission once, leaves the app itself out of the VPN
(so the core's own connections go straight out), and hands the TUN device
to the core (`mobile.StartTun`). The core's userspace stack
(`core/internal/tun`, gVisor) sends every TCP connection through its own
SOCKS5 proxy and answers DNS (UDP and TCP port 53) with fake addresses from
198.18.0.0/15 that stand for names, so the proxy gets the name and routes
by domain. Other UDP is refused (Mozilla's proxy carries TCP only), so
apps fall back to TCP; so is TCP to a port Mozilla's proxy refuses (it
accepts 80, 443, 8080, and 8443) unless the routing sends the destination
directly: refused at once, never tried and never sent out directly.
Settings, Routing, "Apps and the VPN" chooses which apps use it: all but
the checked ones, or only the checked ones. In the first mode the apps
on the routing region's list (hiddify/Android-GFW-Apps, GPL-3.0, so the
core downloads it with the routing lists rather than the app shipping it)
are left out too unless unchecked. The service follows Android's default
network (ConnectivityManager) and tells the core (`mobile.NetworkChanged`),
which reconnects to Mozilla at once on a new network. When
the proxy is shared with the LAN the home page shows the address other
devices use. The core trusts Android's updatable root store and two
bundled GlobalSign roots (`core/mobile/roots.go`), which Android 12's
system store lacks. Every app on a phone can reach loopback, so the core's
API answers only this app (the local token) and a browser the app signs in
(About, Web dashboard). Android's backup keeps the accounts and the settings
(`files/core`, so a new phone needs no new sign-in); the logs, the routing
lists, the caches, and the per-run token are left out
(`res/xml/backup_rules.xml`, `data_extraction_rules.xml`). Copying a data
folder into the external files dir (`import/`) works in debug builds only.
The phone's home page has its own dark design
(`_PhoneHome`), and phones get a bottom navigation bar.

Build: `flutter build apk --release --split-per-abi`. From Iran, Gradle
needs a proxy for Google's Maven repository (Google answers Java clients
there with 404), for example `JAVA_TOOL_OPTIONS="-Dhttps.proxyHost=127.0.0.1
-Dhttps.proxyPort=<port> -Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=<port>"`.
`ndkVersion` names the NDK installed here.

## Languages and first run

English, Persian (right to left, Vazirmatn font under the SIL Open Font
License, `assets/fonts/OFL.txt`, dates in the Solar Hijri calendar),
Chinese, and Russian. Strings are in
`lib/l10n/app_*.arb`; `flutter gen-l10n` (or any build) generates
`lib/l10n/app_localizations*.dart`.

The first run shows a welcome page: language and country. The country is
the core's routing region (`routing.region`): Persian suggests Iran,
Chinese China, Russian Russia, and other languages the system's country.
Changing the language later offers the matching region.

## Icons

Every icon of the program comes from `tool/app_icon.png` (the fox shield,
1024 px, transparent): `python tool/app_icons.py` (Pillow) writes the
Android launcher icon (adaptive, over a blue gradient, and the older PNG),
the Windows `app_icon.ico`, the web dashboard's `icon.png`, and the core's
`appicon.ico` (its executable). The same script draws
the tray icons, which show the connection state and are not made from the
art (16 px cannot show it): a disk in the state's color with the logo's
shield in white, for the app's tray (`assets/tray`) and the core's
(`core/internal/desktop/tray`).

## Development

- Build a release folder with the core: `scripts\build-windows.ps1` from
  the repository root (output in `dist\Firefox-VPN-<version>\`); on Linux,
  `scripts/build-linux.sh` (output in `dist/Firefox-VPN-<version>-Linux-<amd64|arm64>.tar.gz`);
  on macOS, `scripts/build-macos.sh` (output in `dist/Firefox-VPN-<version>-macOS.dmg`).
- Work on the UI without a real core or accounts:

  ```
  dart run tool/fake_core.dart <data-dir> [port]
  flutter run -d windows --dart-entrypoint-args=--data-dir=<data-dir>
  ```

- Run a development core against a separate data folder whose
  `config.json` uses other ports than a core already running on this
  machine, and pass it with `--core=<path to the built core>`.
- Checks: `flutter analyze` and `flutter test`.
