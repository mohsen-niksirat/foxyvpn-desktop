package desktop

import (
	"encoding/json"
	"errors"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/armanlife/firefox-vpn-client/core/internal/securefile"
)

// The macOS proxy setting, per network service (Wi-Fi, Ethernet, ...), read
// and written with networksetup; sysproxy_darwin.go uses it. This program
// sets the web (HTTP), secure web (HTTPS), and SOCKS proxies of every
// enabled service to the local proxy, which serves all three on one port,
// and turns off a proxy configuration URL (PAC) while its setting is in
// place. The previous setting of each service is kept in a backup file and
// restored when this program's setting is removed. It is plain code without
// a build tag, so its tests run everywhere.

// networkSetup runs networksetup; tests replace run and backup.
type networkSetup struct {
	run    func(args ...string) (string, error)
	backup func() (string, error)
}

// macProxyBypass keeps local and private addresses off the proxy.
var macProxyBypass = []string{"localhost", "127.0.0.1", "::1", "*.local", "169.254/16", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"}

// proxyKinds are networksetup's names for the three proxies it sets:
// web is HTTP, securewebproxy HTTPS, socksfirewallproxy SOCKS.
var proxyKinds = []string{"webproxy", "securewebproxy", "socksfirewallproxy"}

// macProxy is one proxy of a service.
type macProxy struct {
	Enabled bool   `json:"enabled"`
	Server  string `json:"server"`
	Port    int    `json:"port"`
}

// macServiceProxy is a service's whole setting this program changes.
type macServiceProxy struct {
	Proxies     map[string]macProxy `json:"proxies"` // by proxyKinds
	Bypass      []string            `json:"bypass"`
	AutoURL     string              `json:"auto_url"`
	AutoEnabled bool                `json:"auto_enabled"`
}

// services lists the enabled network services.
func (n networkSetup) services() ([]string, error) {
	out, err := n.run("-listallnetworkservices")
	if err != nil {
		return nil, err
	}
	var names []string
	for i, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		// The first line explains the asterisk, which marks a disabled
		// service.
		if line == "" || strings.HasPrefix(line, "*") || (i == 0 && strings.Contains(line, "asterisk")) {
			continue
		}
		names = append(names, line)
	}
	if len(names) == 0 {
		return nil, errors.New("no enabled network service")
	}
	return names, nil
}

// fields reads networksetup's "Key: value" lines.
func fields(out string) map[string]string {
	m := map[string]string{}
	for _, line := range strings.Split(out, "\n") {
		if k, v, ok := strings.Cut(line, ":"); ok {
			m[strings.TrimSpace(k)] = strings.TrimSpace(v)
		}
	}
	return m
}

func (n networkSetup) read(service string) (macServiceProxy, error) {
	p := macServiceProxy{Proxies: map[string]macProxy{}}
	for _, kind := range proxyKinds {
		out, err := n.run("-get"+kind, service)
		if err != nil {
			return p, err
		}
		f := fields(out)
		port, _ := strconv.Atoi(f["Port"])
		p.Proxies[kind] = macProxy{Enabled: f["Enabled"] == "Yes", Server: f["Server"], Port: port}
	}
	out, err := n.run("-getproxybypassdomains", service)
	if err != nil {
		return p, err
	}
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		// "There aren't any bypass domains set on Wi-Fi."
		if line != "" && !strings.Contains(line, " ") {
			p.Bypass = append(p.Bypass, line)
		}
	}
	out, err = n.run("-getautoproxyurl", service)
	if err != nil {
		return p, err
	}
	f := fields(out)
	if url := f["URL"]; url != "(null)" {
		p.AutoURL = url
	}
	p.AutoEnabled = f["Enabled"] == "Yes"
	return p, nil
}

func (n networkSetup) write(service string, p macServiceProxy) error {
	for _, kind := range proxyKinds {
		x := p.Proxies[kind]
		if x.Server != "" {
			if _, err := n.run("-set"+kind, service, x.Server, strconv.Itoa(x.Port)); err != nil {
				return err
			}
		}
		state := "off"
		if x.Enabled {
			state = "on"
		}
		if _, err := n.run("-set"+kind+"state", service, state); err != nil {
			return err
		}
	}
	bypass := p.Bypass
	if len(bypass) == 0 {
		bypass = []string{"Empty"}
	}
	if _, err := n.run(append([]string{"-setproxybypassdomains", service}, bypass...)...); err != nil {
		return err
	}
	if p.AutoEnabled && p.AutoURL != "" {
		_, err := n.run("-setautoproxyurl", service, p.AutoURL)
		return err
	}
	_, err := n.run("-setautoproxystate", service, "off")
	return err
}

// ours is this program's setting for the proxy at server.
func ours(server string) (macServiceProxy, error) {
	host, portText, err := net.SplitHostPort(server)
	if err != nil {
		return macServiceProxy{}, err
	}
	port, err := strconv.Atoi(portText)
	if err != nil {
		return macServiceProxy{}, err
	}
	p := macServiceProxy{Proxies: map[string]macProxy{}, Bypass: macProxyBypass}
	for _, kind := range proxyKinds {
		p.Proxies[kind] = macProxy{Enabled: true, Server: host, Port: port}
	}
	return p, nil
}

// isOurs reports whether p is this program's setting for server.
func (p macServiceProxy) isOurs(server string) bool {
	want, err := ours(server)
	if err != nil {
		return false
	}
	return p.Proxies["webproxy"] == want.Proxies["webproxy"]
}

func (p macServiceProxy) equal(q macServiceProxy) bool {
	for _, kind := range proxyKinds {
		if p.Proxies[kind] != q.Proxies[kind] {
			return false
		}
	}
	return strings.Join(p.Bypass, ",") == strings.Join(q.Bypass, ",") &&
		p.AutoURL == q.AutoURL && p.AutoEnabled == q.AutoEnabled
}

func (n networkSetup) set(server string) error {
	next, err := ours(server)
	if err != nil {
		return err
	}
	services, err := n.services()
	if err != nil {
		return err
	}
	backup := n.loadBackup()
	saved := false
	for _, s := range services {
		current, err := n.read(s)
		if err != nil {
			return err
		}
		if current.equal(next) {
			continue
		}
		if !current.isOurs(server) {
			backup[s] = current
			saved = true
		}
	}
	if saved {
		if err := n.saveBackup(backup); err != nil {
			return err
		}
	}
	for _, s := range services {
		if err := n.write(s, next); err != nil {
			return err
		}
	}
	return nil
}

func (n networkSetup) restore(server string) error {
	services, err := n.services()
	if err != nil {
		return err
	}
	backup := n.loadBackup()
	for _, s := range services {
		current, err := n.read(s)
		if err != nil {
			return err
		}
		// A proxy the user chose meanwhile stays.
		if !current.isOurs(server) {
			continue
		}
		previous, ok := backup[s]
		if !ok || previous.isOurs(server) {
			previous = current
			for kind, x := range previous.Proxies {
				x.Enabled = false
				previous.Proxies[kind] = x
			}
			previous.AutoEnabled = false
		}
		if err := n.write(s, previous); err != nil {
			return err
		}
	}
	n.deleteBackup()
	return nil
}

// clear turns every proxy of every service off, whoever set it.
func (n networkSetup) clear() error {
	services, err := n.services()
	if err != nil {
		return err
	}
	for _, s := range services {
		current, err := n.read(s)
		if err != nil {
			return err
		}
		for _, kind := range proxyKinds {
			if current.Proxies[kind].Enabled {
				if _, err := n.run("-set"+kind+"state", s, "off"); err != nil {
					return err
				}
			}
		}
		if current.AutoEnabled {
			if _, err := n.run("-setautoproxystate", s, "off"); err != nil {
				return err
			}
		}
	}
	n.deleteBackup()
	return nil
}

func (n networkSetup) loadBackup() map[string]macServiceProxy {
	backup := map[string]macServiceProxy{}
	path, err := n.backup()
	if err != nil {
		return backup
	}
	if data, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(data, &backup)
	}
	return backup
}

func (n networkSetup) saveBackup(backup map[string]macServiceProxy) error {
	path, err := n.backup()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.Marshal(backup)
	if err != nil {
		return err
	}
	return securefile.WritePrivate(path, data)
}

func (n networkSetup) deleteBackup() {
	if path, err := n.backup(); err == nil {
		_ = os.Remove(path)
	}
}
