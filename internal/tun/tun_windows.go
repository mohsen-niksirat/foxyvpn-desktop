//go:build windows

// Package tun runs hev-socks5-tunnel to route system traffic through the
// local SOCKS5 proxy (TUN Mode). Requires administrator rights for wintun.
package tun

import (
	"context"
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"syscall"
	"time"
)

//go:embed bin/*
var binFS embed.FS

const (
	tunName    = "FoxyTun"
	tunGUID    = "7f3c2a1e-5b9d-4c8a-9e21-6d4f0a8b3c71"
	tunAddress = "198.18.0.1"
	mtu        = 1500
)

// SHA-256 digests of the binaries shipped in bin/ (hev-socks5-tunnel 2.18.0 win64 release).
var expectedHashes = map[string]string{
	"hev-socks5-tunnel.exe": "bd78baca0619a7a7dafd15aae0443b78be8a8152e7aa35752914b5b181e4ee9e",
	"wintun.dll":            "e5da8447dc2c320edc0fc52fa01885c103de8c118481f683643cacc3220dafce",
	"msys-2.0.dll":          "1410599ee2efcede0869abec8910398d688755952e59cf7983b15cac6de78201",
}

type Runner struct {
	dir      string
	cmd      *exec.Cmd
	cancel   context.CancelFunc
	edgeIP   string
	gateway  string
	routesOn bool

	ipv6DefaultSet bool
}

// config renders the YAML accepted by hev-socks5-tunnel 2.18.x.
func config(socksHost, socksPort, logPath string) string {
	return fmt.Sprintf(`tunnel:
  name: %s
  guid: %s
  mtu: %d
  ipv4: %s
socks5:
  port: %s
  address: %s
  udp: 'udp'
misc:
  log-file: %s
  log-level: warn
  udp-read-write-timeout: 5000
`, tunName, tunGUID, mtu, tunAddress, socksPort, socksHost, logPath)
}

// runHidden executes a command without flashing a console window.
func runHiddenOut(name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
	return cmd.Output()
}

func runHidden(name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000} // CREATE_NO_WINDOW
	return cmd.CombinedOutput()
}

// Start extracts the embedded binaries into a temp dir, launches the tunnel
// over the given local SOCKS5 address (e.g. "127.0.0.1:1080"), and routes all
// system traffic through it except traffic to the upstream edge itself.
func Start(socksAddr, edgeAddr string) (*Runner, error) {
	host, port, err := net.SplitHostPort(socksAddr)
	if err != nil {
		return nil, err
	}
	edgeHost, _, err := net.SplitHostPort(edgeAddr)
	if err != nil {
		return nil, fmt.Errorf("invalid edge address: %w", err)
	}
	edgeIP, err := resolveIPv4(edgeHost)
	if err != nil {
		return nil, err
	}
	clearStaleRoutes()
	gateway, err := defaultGateway()
	if err != nil {
		return nil, err
	}

	dir, err := os.MkdirTemp("", "foxyvpn-tun")
	if err != nil {
		return nil, err
	}
	r := &Runner{dir: dir, edgeIP: edgeIP, gateway: gateway}

	for name, want := range expectedHashes {
		data, err := binFS.ReadFile("bin/" + name)
		if err != nil {
			r.cleanup()
			return nil, fmt.Errorf("embedded asset %s missing: %w", name, err)
		}
		sum := sha256.Sum256(data)
		if hex.EncodeToString(sum[:]) != want {
			r.cleanup()
			return nil, fmt.Errorf("embedded asset %s failed integrity check", name)
		}
		if err := os.WriteFile(filepath.Join(dir, name), data, 0o755); err != nil {
			r.cleanup()
			return nil, err
		}
	}

	logPath := filepath.Join(dir, "tunnel.log")
	cfgPath := filepath.Join(dir, "config.yml")
	if err := os.WriteFile(cfgPath, []byte(config(host, port, logPath)), 0o644); err != nil {
		r.cleanup()
		return nil, err
	}

	ctx, cancel := context.WithCancel(context.Background())
	r.cancel = cancel
	cmd := exec.CommandContext(ctx, filepath.Join(dir, "hev-socks5-tunnel.exe"), cfgPath)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
	cmd.Dir = dir
	r.cmd = cmd
	if err := cmd.Start(); err != nil {
		r.Stop()
		return nil, fmt.Errorf("starting hev-socks5-tunnel: %w", err)
	}

	// Detect an immediate exit (e.g. missing admin rights) before reporting success.
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case err := <-done:
		r.cancel()
		r.cleanup()
		return nil, fmt.Errorf("tunnel exited immediately: %v (log: %s)", err, logPath)
	case <-time.After(3 * time.Second):
	}

	if err := r.setRoutes(); err != nil {
		r.Stop()
		return nil, err
	}
	r.preferIPv4()
	return r, nil
}

// setRoutes pins the edge IP to the physical gateway so the tunnel's own
// connection to the edge does not loop back into TUN, then sends the default
// route through the FoxyTun adapter.
// preferIPv4 raises the precedence of IPv4-mapped addresses so apps choose
// IPv4 (which the tunnel carries) instead of unroutable IPv6 while TUN is up.
func (r *Runner) preferIPv4() {
	_, err := runHidden("netsh", "interface", "ipv6", "set", "prefixpolicies", "::ffff:0:0/96", "46", "4")
	r.ipv6DefaultSet = err == nil
}

func (r *Runner) restoreIPv4() {
	if r.ipv6DefaultSet {
		exec.Command("netsh", "interface", "ipv6", "set", "prefixpolicies", "::ffff:0:0/96", "3", "4").Run()
		r.ipv6DefaultSet = false
	}
}

func (r *Runner) setRoutes() error {
	if out, err := runHidden("route", "add", r.edgeIP, "mask", "255.255.255.255", r.gateway, "metric", "1"); err != nil {
		return fmt.Errorf("pinning edge route: %w (%s)", err, out)
	}
	r.routesOn = true
	idx, err := adapterIndex(tunGUID)
	if err != nil {
		return err
	}
	if out, err := runHidden("route", "add", "0.0.0.0", "mask", "128.0.0.0", tunAddress, "metric", "1", "if", idx); err != nil {
		return fmt.Errorf("adding default route (low half): %w (%s)", err, out)
	}
	if out, err := runHidden("route", "add", "128.0.0.0", "mask", "128.0.0.0", tunAddress, "metric", "1", "if", idx); err != nil {
		return fmt.Errorf("adding default route (high half): %w (%s)", err, out)
	}
	return nil
}

func (r *Runner) clearRoutes() {
	r.restoreIPv4()
	if !r.routesOn {
		return
	}
	deleteDefaultRoutes()
	_, _ = runHidden("route", "delete", r.edgeIP)
	r.routesOn = false
}

func (r *Runner) Stop() {
	r.clearRoutes()
	if r.cancel != nil {
		r.cancel()
	}
	if r.cmd != nil && r.cmd.Process != nil {
		r.cmd.Process.Kill()
	}
	r.cleanup()
}

func resolveIPv4(host string) (string, error) {
	if ip := net.ParseIP(host); ip != nil {
		if ip4 := ip.To4(); ip4 != nil {
			return ip4.String(), nil
		}
		return "", fmt.Errorf("edge %s is not IPv4", host)
	}
	ips, err := net.LookupIP(host)
	if err != nil {
		return "", fmt.Errorf("resolving edge %s: %w", host, err)
	}
	for _, ip := range ips {
		if ip4 := ip.To4(); ip4 != nil {
			return ip4.String(), nil
		}
	}
	return "", fmt.Errorf("no IPv4 address for edge %s", host)
}

// defaultGateway returns the gateway of the active IPv4 default route: the
// 0.0.0.0/0 entry with the lowest metric, ignoring our own tunnel address.
func defaultGateway() (string, error) {
	out, err := runHidden("route", "print", "-4", "0.0.0.0")
	if err != nil {
		return "", fmt.Errorf("reading routing table: %w", err)
	}
	best, bestMetric := "", -1
	for _, line := range strings.Split(string(out), "\n") {
		f := strings.Fields(line)
		if len(f) < 5 || f[0] != "0.0.0.0" || f[1] != "0.0.0.0" || net.ParseIP(f[2]) == nil || f[2] == tunAddress {
			continue
		}
		var metric int
		if _, err := fmt.Sscanf(f[4], "%d", &metric); err != nil {
			continue
		}
		if bestMetric < 0 || metric < bestMetric {
			best, bestMetric = f[2], metric
		}
	}
	if best == "" {
		return "", fmt.Errorf("no default gateway found")
	}
	return best, nil
}

// clearStaleRoutes removes routes left behind by a previous run that was
// killed before it could clean up.
func clearStaleRoutes() {
	deleteDefaultRoutes()
}

// deleteDefaultRoutes removes the two half-default routes that send traffic
// into the tunnel. Errors are ignored because the routes may not exist.
func deleteDefaultRoutes() {
	_, _ = runHidden("route", "delete", "0.0.0.0", "mask", "128.0.0.0", tunAddress)
	_, _ = runHidden("route", "delete", "128.0.0.0", "mask", "128.0.0.0", tunAddress)
}

// adapterIndex waits for the adapter with the given GUID to appear and returns
// its interface index. The GUID is pinned in the hev config, so this does not
// depend on the friendly name or on which index Windows assigns.
func adapterIndex(guid string) (string, error) {
	script := fmt.Sprintf(`(Get-NetAdapter -IncludeHidden | Where-Object { $_.InterfaceGuid -eq '{%s}' }).ifIndex`, guid)
	deadline := time.Now().Add(10 * time.Second)
	for {
		out, err := runHiddenOut("powershell", "-NoProfile", "-NonInteractive", "-Command", script)
		if err == nil {
			if idx := strings.TrimSpace(string(out)); idx != "" {
				return idx, nil
			}
		}
		if time.Now().After(deadline) {
			return "", fmt.Errorf("FoxyTun adapter (%s) did not appear; see the tunnel log in %%TEMP%%", guid)
		}
		time.Sleep(500 * time.Millisecond)
	}
}

// cleanup removes the temp dir; it can fail while wintun is still releasing
// the adapter, which is harmless because the next Start uses a fresh dir.
func (r *Runner) cleanup() {
	os.RemoveAll(r.dir)
}

var (
	global   *Runner
	globalMu sync.Mutex
)

// StartGlobal starts the system-wide tunnel if it is not already running.
func StartGlobal(socksAddr, edgeAddr string) error {
	globalMu.Lock()
	defer globalMu.Unlock()
	if global != nil {
		return nil
	}
	r, err := Start(socksAddr, edgeAddr)
	if err != nil {
		return err
	}
	global = r
	return nil
}

// Active reports whether the system-wide tunnel is running.
func Active() bool {
	globalMu.Lock()
	defer globalMu.Unlock()
	return global != nil
}

// StopGlobal stops the system-wide tunnel if running.
func StopGlobal() {
	globalMu.Lock()
	defer globalMu.Unlock()
	if global != nil {
		global.Stop()
		global = nil
	}
}

// StopAll stops TUN if running (safe no-op otherwise).
func StopAll() { StopGlobal() }
