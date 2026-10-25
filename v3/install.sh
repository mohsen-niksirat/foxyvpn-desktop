#!/usr/bin/env bash
# Installs or updates Firefox VPN from the newest release on GitHub:
#
#   curl -fsSL https://raw.githubusercontent.com/armanlife/firefox-vpn-client/main/install.sh | bash
#
# Without an argument it decides by itself:
#   - macOS, or Linux with a graphical session: the app, for the current
#     user (no sudo);
#   - Linux without a graphical session, or run as root: the core alone as
#     a systemd service with the web dashboard (it asks sudo for that);
#   - a Linux SSH session could be either, so it asks;
#   - when Firefox VPN is already installed, it asks: update (the default)
#     or remove, and on remove whether to delete the accounts too.
# Questions are read from the terminal; without one (automation) the
# default answer is taken, so a rerun updates. Accounts and settings stay.
#
# Arguments, for scripts: desktop, server, remove-desktop, remove-server
# (PURGE=1 with a remove also deletes the accounts and settings).
#
# Environment:
#   VERSION=v1.1.1   a given release instead of the newest
#   BASE_URL=url     a mirror that serves the release files
#   INSTALL_DIR, SERVICE_NAME, SERVICE_USER: the service's, as in
#   core/scripts/install-systemd.sh
set -euo pipefail

REPO="armanlife/firefox-vpn-client"
RAW="https://raw.githubusercontent.com/$REPO/main/install.sh"
VERSION="${VERSION:-latest}"
if [ "$VERSION" = "latest" ]; then
  BASE_URL="${BASE_URL:-https://github.com/$REPO/releases/latest/download}"
else
  BASE_URL="${BASE_URL:-https://github.com/$REPO/releases/download/$VERSION}"
fi
COMMAND=/usr/local/bin/firefox-vpn
OS="$(uname -s)"
PURGE="${PURGE:-0}"

# The service's unit, and its settings to pass through sudo, which clears
# the environment.
SERVICE_UNIT="/etc/systemd/system/${SERVICE_NAME:-firefox-vpn}.service"
SERVICE_ENV=()
[ -z "${INSTALL_DIR:-}" ] || SERVICE_ENV+=("INSTALL_DIR=$INSTALL_DIR")
[ -z "${SERVICE_NAME:-}" ] || SERVICE_ENV+=("SERVICE_NAME=$SERVICE_NAME")
[ -z "${SERVICE_USER:-}" ] || SERVICE_ENV+=("SERVICE_USER=$SERVICE_USER")

# The Linux app's places, for the current user.
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$HOME/.local/opt/firefox-vpn-client"
DESKTOP_FILE="$DATA_HOME/applications/com.arman.firefoxvpn.desktop"
AUTOSTART_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/firefox-vpn-client.desktop"
APP_DATA="$DATA_HOME/firefox-vpn-client"

# The macOS app's.
MAC_APP="Firefox VPN.app"
MAC_AGENT="$HOME/Library/LaunchAgents/com.arman.firefoxvpn.plist"
MAC_DATA="$HOME/Library/Application Support/Firefox VPN Client"

# Colors and symbols when the output is a terminal (and NO_COLOR is not
# set); plain text otherwise, for logs and automation.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
  BOLD=$'\e[1m' DIM=$'\e[2m' OFF=$'\e[0m'
  RED=$'\e[31m' GREEN=$'\e[32m' YELLOW=$'\e[33m' BLUE=$'\e[34m' CYAN=$'\e[36m'
  FOX=$'\e[38;5;208m'
else
  BOLD="" DIM="" OFF="" RED="" GREEN="" YELLOW="" BLUE="" CYAN="" FOX=""
fi
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8* | *utf-8* | *UTF8* | *utf8*) TICK="✓" BANG="!" CROSS="✗" ARROW="➜" PROMPT="›" LINE="─" ;;
  *) TICK="+" BANG="!" CROSS="x" ARROW=">" PROMPT=">" LINE="-" ;;
esac

# rule <n>: a horizontal line n characters long.
rule() { local i; for ((i = 0; i < $1; i++)); do printf '%s' "$LINE"; done; }

banner() {
  printf '\n  %s%sFirefox VPN%s %sinstaller%s\n' "$BOLD" "$FOX" "$OFF" "$DIM" "$OFF"
  printf '  %s%s%s\n' "$DIM" "$(rule 34)" "$OFF"
  field "System" "$(os_name)"
  field "Processor" "$(uname -m)"
}

# os_name: this system's name and version, such as "Ubuntu 24.04.1 LTS".
os_name() {
  if [ "$OS" = "Darwin" ]; then
    printf '%s %s\n' "$(sw_vers -productName 2>/dev/null || echo macOS)" "$(sw_vers -productVersion 2>/dev/null)"
  elif [ -r /etc/os-release ]; then
    (. /etc/os-release && echo "${PRETTY_NAME:-${NAME:-Linux}}")
  else
    uname -sr
  fi
}

# step: a stage of the work; ok, warn: its outcome; log: a detail.
step() { printf '\n%s%s%s %s%s%s\n' "$BLUE" "$BOLD" "$ARROW" "$BOLD" "$*" "$OFF"; }
ok() { printf '  %s%s%s %s\n' "$GREEN" "$TICK" "$OFF" "$*"; }
warn() { printf '  %s%s%s %s\n' "$YELLOW" "$BANG" "$OFF" "$*"; }
log() { printf '  %s%s%s\n' "$DIM" "$*" "$OFF"; }
die() { printf '\n  %s%s error:%s %s\n\n' "$RED$BOLD" "$CROSS" "$OFF" "$*" >&2; exit 1; }

# section <title>, field <label> <value> [color]: the final summary.
section() { printf '\n  %s%s%s\n' "$BOLD" "$*" "$OFF"; }
field() { printf '    %s%-10s%s %s%s%s\n' "$DIM" "$1" "$OFF" "${3:-}" "$2" "$OFF"; }

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    die "curl or wget is required"
  fi
}

sha256_check() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c --quiet -
  else
    shasum -a 256 -c --quiet -
  fi
}

# download <file>: the release file into $tmp, checked against the release's
# checksums when it has them.
download() {
  local file="$1"
  step "Downloading $file ${DIM}($VERSION)"
  fetch "$BASE_URL/$file" "$tmp/$file" || die "could not download $BASE_URL/$file"
  if fetch "$BASE_URL/SHA256SUMS.txt" "$tmp/SHA256SUMS.txt" 2>/dev/null; then
    local line
    line="$(awk -v f="$file" '{ n = $2; sub(/^\*/, "", n) } n == f' "$tmp/SHA256SUMS.txt")"
    [ -n "$line" ] || die "$file is missing from SHA256SUMS.txt"
    (cd "$tmp" && printf '%s\n' "$line" | sha256_check) || die "$file does not match its checksum"
    ok "downloaded and checked (SHA-256)"
  else
    warn "no SHA256SUMS.txt in the release; the checksum is skipped"
  fi
}

# The Go and file name of this machine's processor.
arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo amd64 ;;
    aarch64 | arm64) echo arm64 ;;
    *) die "no build for $(uname -m)" ;;
  esac
}

# have_tty: a terminal to ask on. Under curl | bash the standard input is
# the script itself, so answers are read from /dev/tty; without a terminal
# (automation) nothing is asked and the default is taken.
have_tty() { (exec </dev/tty) 2>/dev/null; }

# choose <default> <question> <option>...: prints the number of the chosen
# option; Enter, or no terminal, takes the default.
choose() {
  local default="$1" question="$2" reply i opt
  shift 2
  if ! have_tty; then
    echo "$default"
    return
  fi
  {
    printf '\n%s%s%s %s%s%s\n' "$CYAN$BOLD" "$PROMPT" "$OFF" "$BOLD" "$question" "$OFF"
    i=1
    for opt in "$@"; do
      printf '    %s%d)%s %s\n' "$CYAN" "$i" "$OFF" "$opt"
      i=$((i + 1))
    done
  } >/dev/tty
  while :; do
    printf '  Choose %s[%s]%s: ' "$DIM" "$default" "$OFF" >/dev/tty
    read -r reply </dev/tty || reply=""
    reply="${reply:-$default}"
    if [[ "$reply" =~ ^[0-9]+$ ]] && [ "$reply" -ge 1 ] && [ "$reply" -le $# ]; then
      echo "$reply"
      return
    fi
  done
}

has_app() {
  if [ "$OS" = "Darwin" ]; then
    [ -d "/Applications/$MAC_APP" ] || [ -d "$HOME/Applications/$MAC_APP" ]
  else
    [ -x "$APP_DIR/firefox-vpn" ]
  fi
}

has_service() { [ "$OS" = "Linux" ] && [ -f "$SERVICE_UNIT" ]; }

# need_sudo: the service is installed and managed as root; anyone else is
# stopped at once, in red (SUDO stays for
# the commands that need root, empty as root).
need_sudo() {
  SUDO=""
  [ "$(id -u)" -eq 0 ] || need_root
}

need_root() {
  printf '\n  %s%s Please run this script with root privilege%s\n\n' "$RED$BOLD" "$CROSS" "$OFF" >&2
  exit 1
}

remove_server() {
  has_service || die "the service is not installed"
  [ -f "$COMMAND" ] || die "$COMMAND is missing; remove the service with core/scripts/install-systemd.sh uninstall"
  need_sudo
  step "Removing the service"
  $SUDO env ${SERVICE_ENV[@]+"${SERVICE_ENV[@]}"} PURGE="$PURGE" bash "$COMMAND" uninstall >"$tmp/service.log" 2>&1 ||
    { cat "$tmp/service.log" >&2; die "removing the service failed"; }
  $SUDO rm -f "$COMMAND"
  ok "removed the service"
}

# random_digits <n>: n random digits from 2 to 9 (no 0 or 1, which read
# like O and l).
random_digits() {
  local out="" b
  for b in $(od -An -N"$1" -tu1 /dev/urandom); do out="$out$((b % 8 + 2))"; done
  echo "$out"
}

# ask <default> <question>: a line of text without spaces or ':'; Enter,
# or no terminal, takes the default (shown in brackets unless empty).
ask() {
  local default="$1" question="$2" reply shown=""
  if ! have_tty; then
    echo "$default"
    return
  fi
  [ -z "$default" ] || shown=" $DIM[$default]$OFF"
  while :; do
    printf '\n%s%s%s %s%s%s%s: ' "$CYAN$BOLD" "$PROMPT" "$OFF" "$BOLD" "$question" "$OFF" "$shown" >/dev/tty
    read -r reply </dev/tty || reply=""
    reply="${reply:-$default}"
    case "$reply" in
      *[[:space:]:]*) printf '  %s%s%s Without spaces or ":", please.\n' "$YELLOW" "$BANG" "$OFF" >/dev/tty ;;
      *) echo "$reply"; return ;;
    esac
  done
}

# local_ip: this server's address on its network.
local_ip() {
  local ip
  ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }')"
  [ -n "$ip" ] || ip="$(hostname -I 2>/dev/null | awk '{ print $1 }')"
  echo "$ip"
}

# public_ip: the address the Internet sees, or nothing when it cannot be
# asked (a filtered network, for one).
public_ip() {
  local ip=""
  if command -v curl >/dev/null 2>&1; then
    ip="$(curl -fsS -4 --max-time 5 https://api.ipify.org 2>/dev/null || true)"
  elif command -v wget >/dev/null 2>&1; then
    ip="$(wget -qO- -T 5 https://api.ipify.org 2>/dev/null || true)"
  fi
  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && echo "$ip"
}

install_server() {
  [ "$OS" = "Linux" ] || die "the service is for Linux; on macOS, install the app: curl -fsSL $RAW | bash"
  command -v systemctl >/dev/null 2>&1 || die "systemd is required"
  # Administrator rights first: without them nothing else is asked.
  need_sudo
  # A new server gets its logins; an update keeps the ones it has.
  local fresh=0 user=""
  if ! has_service; then
    fresh=1
    # Left empty: a random one, "panel" and four digits, made here so any
    # release's core takes it.
    user="$(ask "" "Set a username for the web panel")"
    user="${user:-panel$(random_digits 4)}"
  fi
  local name dir
  name="firefox-vpn-core-linux-$(arch)"
  dir="$tmp/$name"
  download "$name.tar.gz"
  tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
  [ -f "$dir/firefox-vpn-core" ] && [ -f "$dir/install-systemd.sh" ] || die "not a firefox-vpn-core archive"

  step "Installing the service"
  # Its own lines only when it fails.
  if ! $SUDO env ${SERVICE_ENV[@]+"${SERVICE_ENV[@]}"} SELF=firefox-vpn BINARY="$dir/firefox-vpn-core" \
    bash "$dir/install-systemd.sh" install >"$tmp/service.log" 2>&1; then
    cat "$tmp/service.log" >&2
    die "installing the service failed"
  fi
  $SUDO install -m 0755 "$dir/install-systemd.sh" "$COMMAND"
  ok "the service runs, and starts with the server"

  if [ "$fresh" = 0 ]; then
    printf '\n  %s%s Firefox VPN is updated and running.%s\n' "$GREEN$BOLD" "$TICK" "$OFF"
    log "The panel and the proxy keep their addresses and logins."
    command_menu
    return
  fi

  # Open the panel and the proxy to the network, each behind a login.
  step "Opening the panel and the proxy to the network"
  local out
  out="$($SUDO env ${SERVICE_ENV[@]+"${SERVICE_ENV[@]}"} bash "$COMMAND" setup-server "$user")" ||
    die "setting up the logins failed; set them with: sudo firefox-vpn set-dashboard-login"
  value() { printf '%s\n' "$out" | sed -n "s/^$1=//p"; }
  local panel_user panel_pass panel_port proxy_user proxy_pass proxy_port lan wan
  panel_user="$(value dashboard_username)"
  panel_pass="$(value dashboard_password)"
  panel_port="$(value dashboard_port)"
  proxy_user="$(value proxy_username)"
  proxy_pass="$(value proxy_password)"
  proxy_port="$(value proxy_port)"
  lan="$(local_ip)"
  wan="$(public_ip)"
  ok "each behind its own login"
  [ "$lan" != "$wan" ] || lan=""

  printf '\n  %s%s Firefox VPN is installed and running.%s\n' "$GREEN$BOLD" "$TICK" "$OFF"
  printf '  %s%s%s\n' "$DIM" "$(rule 58)" "$OFF"
  section "Proxy ${DIM}(SOCKS5 and HTTP)${OFF}"
  [ -z "$lan" ] || field "Local" "$lan:$proxy_port" "$CYAN"
  [ -z "$wan" ] || field "Global" "$wan:$proxy_port" "$CYAN"
  field "Username" "$proxy_user" "$BOLD"
  field "Password" "$proxy_pass" "$YELLOW$BOLD"
  section "Web panel login"
  field "Username" "$panel_user" "$BOLD"
  field "Password" "$panel_pass" "$YELLOW$BOLD"
  # Where the eye lands: where to open the panel.
  section "Open the web panel"
  [ -z "$lan" ] || field "Local" "http://$lan:$panel_port/app/" "$CYAN$BOLD"
  [ -z "$wan" ] || field "Global" "http://$wan:$panel_port/app/" "$CYAN$BOLD"
  printf '\n'
  warn "An address does not open? Allow TCP ports $proxy_port and $panel_port"
  printf '    in the server'"'"'s firewall and the cloud provider'"'"'s.\n'
  command_menu
}

# command_menu: what the firefox-vpn command does on this server.
command_menu() {
  local width=58
  section "Firefox VPN commands"
  printf '  %s%s%s\n' "$DIM" "$(rule $width)" "$OFF"
  menu_line "firefox-vpn" "The menu: pick a command by its number"
  menu_line "firefox-vpn status" "The service's state"
  menu_line "firefox-vpn start" "Start the service"
  menu_line "firefox-vpn stop" "Stop the service"
  menu_line "firefox-vpn restart" "Restart the service"
  menu_line "firefox-vpn enable" "Start with the server"
  menu_line "firefox-vpn disable" "Do not start with the server"
  menu_line "firefox-vpn logs" "Show the log"
  menu_line "firefox-vpn add-account" "Add a Firefox Account"
  menu_line "firefox-vpn list-accounts" "Accounts and their quota"
  menu_line "firefox-vpn set-dashboard-login" "The panel's username and password"
  printf '  %s%s%s\n' "$DIM" "$(rule $width)" "$OFF"
  log "Update or remove: run the install command again."
  printf '\n'
}

menu_line() { printf '  %s%-33s%s %s\n' "$CYAN" "$1" "$OFF" "$2"; }

install_linux_app() {
  local file
  file="Firefox-VPN-Linux-$(arch).tar.gz"
  download "$file"
  tar -xzf "$tmp/$file" -C "$tmp"
  [ -f "$tmp/firefox-vpn/firefox-vpn" ] || die "not a Firefox VPN archive"
  chmod 0755 "$tmp/firefox-vpn/firefox-vpn" "$tmp/firefox-vpn/core/firefox-vpn-core"

  # A running copy keeps its open files; the new one replaces the folder.
  mkdir -p "$(dirname "$APP_DIR")"
  rm -rf "$APP_DIR.old"
  if [ -d "$APP_DIR" ]; then mv "$APP_DIR" "$APP_DIR.old"; fi
  mv "$tmp/firefox-vpn" "$APP_DIR"
  rm -rf "$APP_DIR.old"

  mkdir -p "$(dirname "$DESKTOP_FILE")"
  cat >"$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Firefox VPN
Comment=Mozilla's VPN servers through your Firefox Accounts
Exec="$APP_DIR/firefox-vpn"
Icon=$APP_DIR/data/app_icon.png
Terminal=false
Categories=Network;
StartupWMClass=com.arman.firefoxvpn
EOF
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q "$(dirname "$DESKTOP_FILE")" || true
  fi

  ok "installed in $APP_DIR"
  if ! { ldconfig -p 2>/dev/null | grep -qE 'lib(ayatana-)?appindicator3\.so'; }; then
    warn "no tray icon library: install libayatana-appindicator3-1 (Debian, Ubuntu) or libappindicator-gtk3 (Fedora, Arch) for the tray icon"
  fi
  printf '\n  %s%s Firefox VPN is installed.%s\n' "$GREEN$BOLD" "$TICK" "$OFF"
  section "Open it"
  field "Menu" "Firefox VPN in the applications menu"
  field "Command" "$APP_DIR/firefox-vpn" "$CYAN"
  field "Update" "run the same install command again (it also removes)"
  printf '\n'
}

# macOS: the app into /Applications (or ~/Applications when that is not
# writable). Downloaded this way it carries no quarantine flag, so macOS
# opens it without asking.
install_mac_app() {
  local file="Firefox-VPN-macOS.dmg" dest=/Applications
  [ -w "$dest" ] || dest="$HOME/Applications"
  mkdir -p "$dest"
  download "$file"
  mkdir "$tmp/mnt"
  hdiutil attach -nobrowse -readonly -quiet -mountpoint "$tmp/mnt" "$tmp/$file" || die "could not open $file"
  mounted="$tmp/mnt"
  [ -d "$tmp/mnt/$MAC_APP" ] || die "not a Firefox VPN disk image"
  # A running copy quits first, so the new one replaces it.
  osascript -e 'quit app "Firefox VPN"' >/dev/null 2>&1 || true
  rm -rf "$dest/$MAC_APP"
  ditto "$tmp/mnt/$MAC_APP" "$dest/$MAC_APP"
  hdiutil detach -quiet "$tmp/mnt" || true
  mounted=""
  ok "installed in $dest/$MAC_APP"
  printf '\n  %s%s Firefox VPN is installed.%s\n' "$GREEN$BOLD" "$TICK" "$OFF"
  section "Open it"
  field "Launchpad" "Firefox VPN in Launchpad or Applications"
  field "Command" "open \"$dest/$MAC_APP\"" "$CYAN"
  field "Update" "run the same install command again (it also removes)"
  printf '\n'
}

install_desktop() {
  [ "$(id -u)" -ne 0 ] || die "install the app as yourself, without sudo: curl -fsSL $RAW | bash -s -- desktop"
  case "$OS" in
    Darwin) install_mac_app ;;
    *) install_linux_app ;;
  esac
}

remove_desktop() {
  local data
  if [ "$OS" = "Darwin" ]; then
    osascript -e 'quit app "Firefox VPN"' >/dev/null 2>&1 || true
    rm -rf "/Applications/$MAC_APP" "$HOME/Applications/$MAC_APP"
    rm -f "$MAC_AGENT"
    data="$MAC_DATA"
  else
    rm -rf "$APP_DIR" "$APP_DIR.old"
    rm -f "$DESKTOP_FILE" "$AUTOSTART_FILE"
    data="$APP_DATA"
  fi
  if [ "$PURGE" = "1" ]; then
    rm -rf "$data"
    ok "removed the app, its accounts, and its settings"
  else
    ok "removed the app; accounts and settings stay in $data (PURGE=1 deletes them)"
  fi
}

# detect: what this machine most likely wants, as KIND (desktop or server)
# and CERTAIN (0 when a remote session leaves it open).
detect() {
  CERTAIN=1
  if [ "$OS" = "Darwin" ]; then
    KIND=desktop
  elif [ "$(id -u)" -eq 0 ]; then
    # The app installs for a user, never for root.
    KIND=server
  elif [ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]; then
    # A server, or a desktop computer reached over SSH.
    CERTAIN=0
    if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then KIND=desktop; else KIND=server; fi
  elif [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
    KIND=desktop
  else
    KIND=server
  fi
}

# auto: with no argument, find what to do: install what the machine needs,
# or, when Firefox VPN is already there, update it or remove it.
auto() {
  local n installed=1
  # A Linux machine without a graphical session gets the service, which
  # needs root: say so before anything is asked.
  if [ "$OS" = "Linux" ] && [ "$(id -u)" -ne 0 ] && [ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && ! has_app; then
    need_root
  fi
  if has_app && has_service; then
    n="$(choose 1 "Firefox VPN is installed both as the app and as the service. Which one?"       "the app" "the service with the web panel")"
    if [ "$n" = 1 ]; then KIND=desktop; else KIND=server; fi
  elif has_app; then
    KIND=desktop
  elif has_service; then
    KIND=server
  else
    installed=0
    detect
    if [ "$CERTAIN" = 0 ]; then
      if [ "$KIND" = desktop ]; then n=1; else n=2; fi
      n="$(choose "$n" "This is a remote (SSH) session. What should this computer get?"         "the app (a computer with a desktop)"         "the service with the web panel (a server without a desktop)")"
      if [ "$n" = 1 ]; then KIND=desktop; else KIND=server; fi
    elif [ "$KIND" = desktop ]; then
      step "Installing the app"
    else
      step "Installing the service with the web panel"
    fi
  fi

  if [ "$installed" = 1 ]; then
    local what="the app"
    [ "$KIND" = desktop ] || what="the service"
    n="$(choose 1 "Firefox VPN ($what) is already installed." "update to the newest version" "remove it")"
    if [ "$n" = 2 ]; then
      n="$(choose 1 "Delete its accounts and settings too?" "no, keep them" "yes, delete them")"
      [ "$n" = 1 ] || PURGE=1
      if [ "$KIND" = desktop ]; then remove_desktop; else remove_server; fi
      return
    fi
  fi
  if [ "$KIND" = desktop ]; then install_desktop; else install_server; fi
}

case "$OS" in
  Darwin | Linux) ;;
  *) die "this installer is for Linux and macOS" ;;
esac
command -v tar >/dev/null 2>&1 || die "tar is required"
tmp="$(mktemp -d)"
mounted=""
cleanup() {
  if [ -n "$mounted" ]; then hdiutil detach -quiet "$mounted" || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT

banner
case "${1:-}" in
  "") auto ;;
  desktop) install_desktop ;;
  server) install_server ;;
  remove-desktop) remove_desktop ;;
  remove-server) remove_server ;;
  *) die "unknown command ${1}; use desktop, server, remove-desktop, or remove-server" ;;
esac
