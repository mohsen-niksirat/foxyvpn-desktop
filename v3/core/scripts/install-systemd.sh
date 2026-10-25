#!/usr/bin/env bash
# Installs firefox-vpn-core as a systemd service on Linux, from the source
# tree or from a prebuilt binary. The release's install.sh (at the repository
# root) runs it with the downloaded binary and keeps it as the firefox-vpn
# command.
#
# The program and its data folder live together in INSTALL_DIR (portable
# layout): INSTALL_DIR/firefox-vpn-core and INSTALL_DIR/user-data. Settings and
# accounts are managed from the web dashboard (default 127.0.0.1:10820) or
# with the subcommands below.
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-firefox-vpn}"
SERVICE_USER="${SERVICE_USER:-firefox-vpn}"
INSTALL_DIR="${INSTALL_DIR:-/opt/firefox-vpn}"
BINARY="${BINARY:-}"
PURGE="${PURGE:-0}"
# How the help and the messages name this script (install.sh: firefox-vpn).
SELF="${SELF:-$0}"
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
BIN_PATH="$INSTALL_DIR/firefox-vpn-core"
DATA_DIR="$INSTALL_DIR/user-data"

# The command being run, for the messages.
COMMAND_NAME="${1:-}"
# The name people type (firefox-vpn), not the path.
NAME="$(basename "$SELF")"
# Colors on a terminal (unless NO_COLOR is set): errors in red, the menu.
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
  RED=$'\e[1;31m' OFF=$'\e[0m' BOLD=$'\e[1m' DIM=$'\e[2m' CYAN=$'\e[36m' FOX=$'\e[38;5;208m' GREEN=$'\e[32m'
else
  RED="" OFF="" BOLD="" DIM="" CYAN="" FOX="" GREEN=""
fi

# done_ok, done_fail: what a command did, in green or red.
done_ok() { printf '  %s✓%s %s\n' "$GREEN" "$OFF" "$*"; }
done_fail() { printf '  %s✗ %s%s\n' "$RED" "$*" "$OFF" >&2; return 1; }

log() { printf '[%s] %s\n' "$SERVICE_NAME" "$*"; }
die() { printf '[%s] error: %s\n' "$SERVICE_NAME" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: sudo $NAME [command]

Without a command, on a terminal, a menu offers them by number.

Commands:
  install              Install or update the binary and the service, then start it
  uninstall            Stop and remove the service (PURGE=1 also deletes $INSTALL_DIR)
  status               Show the service state and the runtime status file
  start                Start the service
  stop                 Stop the service (until start, or the next boot when enabled)
  restart              Restart the service
  enable               Start the service with the server
  disable              Do not start the service with the server
  logs                 Show the service log
  add-account          Sign in to a Firefox Account on this terminal
  list-accounts        List accounts, status, and quota
  set-dashboard-login  Set or remove the dashboard username and password
  setup-server [user]  Open the dashboard and the proxy to the network: the dashboard
                       login for user (a random one without it) and a random proxy
                       login, each with a random password; print the logins

Environment:
  BINARY=path          Install this prebuilt binary instead of building from the source tree
  INSTALL_DIR=dir      Program and data folder (default /opt/firefox-vpn)
  SERVICE_NAME, SERVICE_USER

The dashboard is at http://<address>:10820/app/. It opens to other devices only
with a login (set-dashboard-login, or setup-server, which install.sh runs on a
new server); without one it answers this machine only, and an SSH tunnel
(ssh -L 10820:127.0.0.1:10820 host) reaches it.
EOF
}

# need_root: stops, in red, when the command needs root and was run
# without it.
need_root() {
  [ "$(id -u)" -ne 0 ] || return 0
  printf '%sPermission denied: this needs root. Run it with sudo:%s\n  sudo %s %s\n' \
    "$RED" "$OFF" "$(basename "$SELF")" "$COMMAND_NAME" >&2
  exit 1
}

repo_root() { cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd; }

build_binary() {
  local out="$1"
  if [ -n "$BINARY" ]; then
    [ -f "$BINARY" ] || die "BINARY=$BINARY does not exist"
    cp "$BINARY" "$out"
    return
  fi
  # Installed as the firefox-vpn command (install.sh), with no source tree.
  [ -d "$(repo_root)/cmd/firefox-vpn-core" ] ||
    die "to update, run the install command again: curl -fsSL https://raw.githubusercontent.com/armanlife/firefox-vpn-client/main/install.sh | bash"
  command -v go >/dev/null 2>&1 || die "Go is not installed; install Go or pass BINARY=path/to/firefox-vpn-core"
  log "building from $(repo_root)"
  (cd "$(repo_root)" && CGO_ENABLED=0 go build -trimpath -o "$out" ./cmd/firefox-vpn-core)
}

ensure_user() {
  if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    log "creating system user $SERVICE_USER"
    useradd --system --home-dir "$DATA_DIR" --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"
  fi
}


write_unit() {
  cat >"$UNIT_FILE" <<EOF
[Unit]
Description=Firefox VPN SOCKS5 proxy and dashboard
After=network-online.target
Wants=network-online.target

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$BIN_PATH
Restart=on-failure
RestartSec=10
UMask=0077
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$DATA_DIR

[Install]
WantedBy=multi-user.target
EOF
}

run_as_service_user() {
  [ -x "$BIN_PATH" ] || die "not installed; run: sudo $SELF install"
  runuser -u "$SERVICE_USER" -- "$BIN_PATH" "$@"
}

cmd_install() {
  need_root
  command -v systemctl >/dev/null 2>&1 || die "systemd is required"
  local tmp
  tmp="$(mktemp)"
  # The value now: the local variable is gone when the script exits.
  trap "rm -f -- '$tmp'" EXIT
  build_binary "$tmp"
  ensure_user
  install -d -m 0755 -o root -g root "$INSTALL_DIR"
  install -d -m 0700 -o "$SERVICE_USER" -g "$SERVICE_USER" "$DATA_DIR"
  install -m 0755 -o root -g root "$tmp" "$BIN_PATH"
  write_unit
  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}.service" >/dev/null
  systemctl restart "${SERVICE_NAME}.service"
  log "installed $BIN_PATH; data in $DATA_DIR"
  log "dashboard: http://127.0.0.1:10820/app/ (add accounts there, or: sudo $SELF add-account)"
}

cmd_uninstall() {
  need_root
  systemctl disable --now "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
  rm -f "$UNIT_FILE"
  systemctl daemon-reload
  if [ "$PURGE" = "1" ]; then
    log "deleting $INSTALL_DIR including accounts and settings"
    rm -rf "$INSTALL_DIR"
    userdel "$SERVICE_USER" >/dev/null 2>&1 || true
  else
    log "service removed; $INSTALL_DIR kept (PURGE=1 deletes it)"
  fi
}

# cmd_status: a few lines: the service and its autostart from systemd, then
# the core's own (proxy, account, data left). systemctl status
# firefox-vpn has every detail.
cmd_status() {
  local active since auto=off
  active="$(systemctl is-active "${SERVICE_NAME}.service" 2>/dev/null || true)"
  [ "$(systemctl is-enabled "${SERVICE_NAME}.service" 2>/dev/null || true)" != enabled ] || auto=on
  printf '\n  %s%sFirefox VPN%s\n' "$BOLD" "$FOX" "$OFF"
  printf '  %s──────────────────────────────────────────────────────%s\n' "$DIM" "$OFF"
  if [ "$active" = active ]; then
    since="$(systemctl show -p ActiveEnterTimestamp --value "${SERVICE_NAME}.service" 2>/dev/null || true)"
    since="$(date -d "$since" '+%b %-d %H:%M' 2>/dev/null || true)"
    printf '    %-11s %s●%s %srunning%s       %s\n' "Service" "$GREEN" "$OFF" "$BOLD" "$OFF" "${since:+since $since}"
  else
    printf '    %-11s %s●%s %sstopped%s       start it: %s start\n' "Service" "$RED" "$OFF" "$BOLD" "$OFF" "$NAME"
  fi
  printf '    %-11s %s\n' "Autostart" "$auto"
  if [ "$active" = active ]; then
    if [ "$(id -u)" -eq 0 ] && [ -x "$BIN_PATH" ]; then
      run_as_service_user -status 2>/dev/null || true
    else
      printf '    %s(the account and data left need root: sudo %s status)%s\n' "$DIM" "$NAME" "$OFF"
    fi
  fi
}

# menu: the everyday commands by number, for the command without
# arguments on a terminal; it runs the one picked.
menu() {
  local reply
  local -a cmds=(status start stop restart enable disable logs add-account list-accounts set-dashboard-login)
  local -a labels=(
    "Status"
    "Start"
    "Stop"
    "Restart"
    "Start with the server"
    "Do not start with the server"
    "Show the log"
    "Add a Firefox Account"
    "List the accounts and their quota"
    "Set the panel's username and password"
  )
  local i
  # Back to the menu after each command, until 0.
  while :; do
    printf '\n  %s%sFirefox VPN%s\n' "$BOLD" "$FOX" "$OFF"
    printf '  %s────────────────────────────────────────────────────────────────────────────%s\n' "$DIM" "$OFF"
    for i in "${!cmds[@]}"; do
      printf '  %s%2d)%s %-40s %s%s %s%s\n' "$CYAN" $((i + 1)) "$OFF" "${labels[$i]}" "$DIM" "$NAME" "${cmds[$i]}" "$OFF"
    done
    printf '  %s 0)%s Exit\n' "$CYAN" "$OFF"
    printf '  %s────────────────────────────────────────────────────────────────────────────%s\n' "$DIM" "$OFF"
    while :; do
      printf '  Enter a number [0-%d]: ' "${#cmds[@]}"
      read -r reply || exit 0
      case "$reply" in
        0 | "") exit 0 ;;
        *[!0-9]*) ;;
        *) if [ "$reply" -ge 1 ] && [ "$reply" -le "${#cmds[@]}" ]; then break; fi ;;
      esac
      printf '  %sNo such choice: %s%s\n' "$RED" "$reply" "$OFF"
    done
    COMMAND_NAME="${cmds[$((reply - 1))]}"
    printf '\n'
    # Ctrl+C ends the command (the log, for one), not the menu.
    trap ':' INT
    ( main "$COMMAND_NAME" ) || true
    trap - INT
    # A blank line below the prompt too, so it never sits on the window's
    # bottom edge: print it, then move the cursor back up onto the prompt.
    printf '\n\n\033[1A  %s↵  Press Enter to return to the menu%s ' "$CYAN" "$OFF"
    read -r reply || exit 0
  done
}

main() {
case "${1:-}" in
  install) cmd_install ;;
  uninstall) cmd_uninstall ;;
  status) cmd_status ;;
  logs) journalctl -u "${SERVICE_NAME}.service" -f ;;
  start)
    need_root
    if systemctl is-active --quiet "${SERVICE_NAME}.service"; then done_ok "Already running."
    else systemctl start "${SERVICE_NAME}.service" && done_ok "Started." || done_fail "Starting failed: $NAME logs"; fi
    ;;
  stop) need_root; systemctl stop "${SERVICE_NAME}.service" && done_ok "Stopped." || done_fail "Stopping failed" ;;
  restart) need_root; systemctl restart "${SERVICE_NAME}.service" && done_ok "Restarted." || done_fail "Restarting failed: $NAME logs" ;;
  enable) need_root; systemctl enable --quiet "${SERVICE_NAME}.service" && done_ok "Starts with the server." || done_fail "Failed" ;;
  disable) need_root; systemctl disable --quiet "${SERVICE_NAME}.service" && done_ok "Does not start with the server." || done_fail "Failed" ;;
  add-account) need_root; run_as_service_user -add-account && systemctl restart "${SERVICE_NAME}.service" ;;
  list-accounts) need_root; run_as_service_user -list-accounts ;;
  set-dashboard-login) need_root; run_as_service_user -set-dashboard-login && systemctl restart "${SERVICE_NAME}.service" ;;
  setup-server) need_root; run_as_service_user -setup-server "${2:--}" && systemctl restart "${SERVICE_NAME}.service" ;;
  "")
    # On a terminal, the menu; otherwise (scripts, pipes) the help.
    if [ -t 0 ] && [ -t 1 ]; then menu; else usage; fi
    ;;
  -h|--help|help) usage ;;
  *) usage; exit 2 ;;
esac
}

main "$@"
