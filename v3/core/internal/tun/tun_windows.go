//go:build windows

// Package tun runs hev-socks5-tunnel to route system traffic through the
// local SOCKS5 proxy (TUN Mode). Requires administrator rights for wintun.
package tun

import (
	"context"
	"crypto/sha256"
	"embed"
	"encoding/binary"
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
	"unsafe"

	"golang.org/x/sys/windows"
)

//go:embed bin/*
var binFS embed.FS

const (
	tunName    = "FoxyTun"
	tunGUID    = "7f3c2a1e-5b9d-4c8a-9e21-6d4f0a8b3c71"
	tunAddress = "198.18.0.1"
	mtu        = 1500
)

var (
	modiphlpapi      = syscall.NewLazyDLL("iphlpapi.dll")
	procGetBestRoute = modiphlpapi.NewProc("GetBestRoute")
)

type mibIPForwardRow struct {
	ForwardDest      uint32
	ForwardMask      uint32
	ForwardPolicy    uint32
	ForwardNextHop   uint32
	ForwardIfIndex   uint32
	ForwardType      uint32
	ForwardProto     uint32
	ForwardAge       uint32
	ForwardNextHopAS uint32
	ForwardMetric1   uint32
	ForwardMetric2   uint32
	ForwardMetric3   uint32
	ForwardMetric4   uint32
	ForwardMetric5   uint32
}

func getBestRoute(destIP net.IP) (string, string, error) {
	ip4 := destIP.To4()
	if ip4 == nil {
		return "", "", fmt.Errorf("not an ipv4 address")
	}
	dest := binary.LittleEndian.Uint32(ip4)
	var row mibIPForwardRow
	r1, _, err := procGetBestRoute.Call(uintptr(dest), 0, uintptr(unsafe.Pointer(&row)))
	if r1 != 0 {
		return "", "", fmt.Errorf("GetBestRoute failed: %v", err)
	}

	var nextHopBytes [4]byte
	binary.LittleEndian.PutUint32(nextHopBytes[:], row.ForwardNextHop)
	nextHopIP := net.IP(nextHopBytes[:])

	hopStr := nextHopIP.String()
	if hopStr == "0.0.0.0" {
		if iface, err := net.InterfaceByIndex(int(row.ForwardIfIndex)); err == nil {
			if addrs, err := iface.Addrs(); err == nil {
				for _, a := range addrs {
					if ipNet, ok := a.(*net.IPNet); ok && ipNet.IP.To4() != nil {
						hopStr = ipNet.IP.To4().String()
						break
					}
				}
			}
		}
	}

	return hopStr, fmt.Sprint(row.ForwardIfIndex), nil
}

// SHA-256 digests of the binaries shipped in bin/ (hev-socks5-tunnel 2.18.0 win64 release).
var expectedHashes = map[string]string{
	"hev-socks5-tunnel.exe": "bd78baca0619a7a7dafd15aae0443b78be8a8152e7aa35752914b5b181e4ee9e",
	"wintun.dll":            "e5da8447dc2c320edc0fc52fa01885c103de8c118481f683643cacc3220dafce",
	"msys-2.0.dll":          "1410599ee2efcede0869abec8910398d688755952e59cf7983b15cac6de78201",
}

// IsSupported reports whether TUN mode is supported on this platform.
func IsSupported() bool {
	return true
}

// IsAdmin checks if the current process runs with elevated administrator rights.
func IsAdmin() bool {
	var token windows.Token
	err := windows.OpenProcessToken(windows.CurrentProcess(), windows.TOKEN_QUERY, &token)
	if err != nil {
		return false
	}
	defer token.Close()

	var elevation uint32
	var retLen uint32
	err = windows.GetTokenInformation(
		token,
		windows.TokenElevation,
		(*byte)(unsafe.Pointer(&elevation)),
		uint32(unsafe.Sizeof(elevation)),
		&retLen,
	)
	if err != nil {
		return false
	}
	return elevation != 0
}

type Runner struct {
	dir            string
	cmd            *exec.Cmd
	cancel         context.CancelFunc
	edgeIP         string
	gateway        string
	routesOn       bool
	ipv6DefaultSet bool
	adapterName    string
	pinnedIPs      []string
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
// over the given local SOCKS5 address (e.g. "127.0.0.1:10810"), and routes all
// system traffic through it except traffic to the upstream edge itself.
func Start(socksAddr, edgeAddr string) (*Runner, error) {
	if !IsAdmin() {
		return nil, fmt.Errorf("TUN mode requires running as Administrator (to configure Wintun and routing table)")
	}

	host, port, err := net.SplitHostPort(socksAddr)
	if err != nil {
		return nil, fmt.Errorf("invalid socks address %s: %w", socksAddr, err)
	}

	var edgeIP string
	if edgeAddr != "" {
		edgeHost := edgeAddr
		if h, _, err := net.SplitHostPort(edgeAddr); err == nil {
			edgeHost = h
		}
		if ip, err := resolveIPv4(edgeHost); err == nil {
			edgeIP = ip
		}
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

	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case err := <-done:
		r.cancel()
		r.cleanup()
		return nil, fmt.Errorf("tunnel exited immediately: %v (log: %s)", err, logPath)
	case <-time.After(2 * time.Second):
	}

	if err := r.setRoutes(); err != nil {
		r.Stop()
		return nil, err
	}
	r.preferIPv4()
	return r, nil
}

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

func (r *Runner) pinIP(ipStr string) {
	ip := net.ParseIP(ipStr)
	if ip == nil || ip.To4() == nil {
		return
	}
	if ip.String() == tunAddress || strings.HasPrefix(ip.String(), "127.") {
		return
	}
	for _, pinned := range r.pinnedIPs {
		if pinned == ipStr {
			return
		}
	}
	hop, ifIdx, err := getBestRoute(ip)
	if err != nil || hop == "" || hop == tunAddress {
		hop = r.gateway
	}
	if hop != "" {
		if ifIdx != "" {
			_, _ = runHidden("route", "add", ipStr, "mask", "255.255.255.255", hop, "metric", "1", "if", ifIdx)
		} else {
			_, _ = runHidden("route", "add", ipStr, "mask", "255.255.255.255", hop, "metric", "1")
		}
		r.pinnedIPs = append(r.pinnedIPs, ipStr)
	}
}

func (r *Runner) setRoutes() error {
	// Pin current edge IP
	if r.edgeIP != "" {
		r.pinIP(r.edgeIP)
	}

	// Pin Mozilla serverlist and Guardian auth endpoints to bypass TUN
	bypassHosts := []string{
		"firefox.settings.services.mozilla.com",
		"api.guardianapp.com",
		"api.stage.guardianapp.com",
	}
	for _, host := range bypassHosts {
		if ips, err := net.LookupIP(host); err == nil {
			for _, ip := range ips {
				if ip4 := ip.To4(); ip4 != nil {
					r.pinIP(ip4.String())
				}
			}
		}
	}

	r.routesOn = true

	info, err := findAdapter(tunGUID)
	if err != nil {
		return err
	}
	r.adapterName = info.Name

	if out, err := runHidden("route", "add", "0.0.0.0", "mask", "128.0.0.0", tunAddress, "metric", "1", "if", info.Index); err != nil {
		return fmt.Errorf("adding default route (low half): %w (%s)", err, out)
	}
	if out, err := runHidden("route", "add", "128.0.0.0", "mask", "128.0.0.0", tunAddress, "metric", "1", "if", info.Index); err != nil {
		return fmt.Errorf("adding default route (high half): %w (%s)", err, out)
	}

	dnsName := r.adapterName
	if dnsName == "" {
		dnsName = tunName
	}
	_, _ = runHidden("netsh", "interface", "ip", "set", "dns", "name="+dnsName, "static", "1.1.1.1")
	_, _ = runHidden("netsh", "interface", "ip", "add", "dns", "name="+dnsName, "8.8.8.8", "index=2")
	return nil
}

func (r *Runner) clearRoutes() {
	r.restoreIPv4()
	if !r.routesOn {
		return
	}
	deleteDefaultRoutes()
	for _, ip := range r.pinnedIPs {
		_, _ = runHidden("route", "delete", ip)
	}
	r.pinnedIPs = nil
	dnsName := r.adapterName
	if dnsName == "" {
		dnsName = tunName
	}
	_, _ = runHidden("netsh", "interface", "ip", "set", "dns", "name="+dnsName, "dhcp")
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

func defaultGateway() (string, error) {
	// Try GetBestRoute to a public address first
	if hop, _, err := getBestRoute(net.ParseIP("1.1.1.1")); err == nil && hop != "" && hop != tunAddress && hop != "0.0.0.0" {
		return hop, nil
	}

	out, err := runHidden("route", "print", "-4", "0.0.0.0")
	if err != nil {
		return "", fmt.Errorf("reading routing table: %w", err)
	}
	best, bestMetric := "", -1
	for _, line := range strings.Split(string(out), "\n") {
		f := strings.Fields(line)
		if len(f) < 5 || f[0] != "0.0.0.0" || (f[1] != "0.0.0.0" && f[1] != "128.0.0.0") || net.ParseIP(f[2]) == nil || f[2] == tunAddress {
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

func clearStaleRoutes() {
	deleteDefaultRoutes()
}

func deleteDefaultRoutes() {
	_, _ = runHidden("route", "delete", "0.0.0.0", "mask", "128.0.0.0", tunAddress)
	_, _ = runHidden("route", "delete", "128.0.0.0", "mask", "128.0.0.0", tunAddress)
}

type tunAdapterInfo struct {
	Index string
	Name  string
}

func findAdapter(guid string) (tunAdapterInfo, error) {
	deadline := time.Now().Add(10 * time.Second)
	for {
		// 1. Direct check via net.Interfaces for assigned IP 198.18.0.1 or name FoxyTun
		if ifaces, err := net.Interfaces(); err == nil {
			for _, iface := range ifaces {
				if strings.EqualFold(iface.Name, tunName) {
					return tunAdapterInfo{Index: fmt.Sprint(iface.Index), Name: iface.Name}, nil
				}
				if addrs, err := iface.Addrs(); err == nil {
					for _, addr := range addrs {
						if strings.HasPrefix(addr.String(), tunAddress) {
							return tunAdapterInfo{Index: fmt.Sprint(iface.Index), Name: iface.Name}, nil
						}
					}
				}
			}
		}

		// 2. PowerShell query for Wintun description, GUID, or name
		script := fmt.Sprintf(`Get-NetAdapter -IncludeHidden | Where-Object { $_.InterfaceGuid -eq '{%s}' -or $_.InterfaceDescription -like '*Wintun*' -or $_.Name -eq '%s' } | Select-Object -First 1 | ForEach-Object { "$($_.ifIndex)|$($_.Name)" }`, guid, tunName)
		out, err := runHiddenOut("powershell", "-NoProfile", "-NonInteractive", "-Command", script)
		if err == nil {
			line := strings.TrimSpace(string(out))
			if line != "" {
				parts := strings.SplitN(line, "|", 2)
				if len(parts) == 2 && parts[0] != "" {
					return tunAdapterInfo{Index: parts[0], Name: parts[1]}, nil
				} else if len(parts) == 1 && parts[0] != "" {
					return tunAdapterInfo{Index: parts[0], Name: tunName}, nil
				}
			}
		}

		if time.Now().After(deadline) {
			return tunAdapterInfo{}, fmt.Errorf("FoxyTun Wintun adapter did not appear; please ensure you are running as Administrator")
		}
		time.Sleep(500 * time.Millisecond)
	}
}

func (r *Runner) cleanup() {
	os.RemoveAll(r.dir)
}

var (
	global   *Runner
	globalMu sync.Mutex
)

// PinEdge ensures that the given upstream edge address is pinned in the routing table.
func PinEdge(edgeAddr string) {
	globalMu.Lock()
	defer globalMu.Unlock()
	if global == nil || !global.routesOn {
		return
	}
	host := edgeAddr
	if h, _, err := net.SplitHostPort(edgeAddr); err == nil {
		host = h
	}
	if ip := net.ParseIP(host); ip != nil {
		if ip4 := ip.To4(); ip4 != nil {
			global.pinIP(ip4.String())
		}
		return
	}
	if ips, err := net.LookupIP(host); err == nil {
		for _, ip := range ips {
			if ip4 := ip.To4(); ip4 != nil {
				global.pinIP(ip4.String())
			}
		}
	}
}

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

// IsActive reports whether the system-wide tunnel is currently running.
func IsActive() bool {
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
func StopAll() {
	StopGlobal()
}
