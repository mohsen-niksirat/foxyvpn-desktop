//go:build linux

package desktop

import (
	"encoding/json"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"github.com/armanlife/firefox-vpn-client/core/internal/securefile"
)

// The desktop's proxy setting: GNOME's (gsettings org.gnome.system.proxy),
// which GNOME, Cinnamon, Budgie, and Unity read, and with them Chrome and
// Firefox's "Use system proxy settings". This program sets one manual
// proxy for HTTP, HTTPS, and SOCKS (the local proxy serves all three on one
// port). The previous setting is kept in backupPath and restored when this
// program's setting is removed. Tests replace gsettings and backupPath.
var (
	gsettings = func(args ...string) (string, error) {
		out, err := exec.Command("gsettings", args...).Output()
		return strings.TrimSpace(string(out)), err
	}
	backupPath = func() (string, error) {
		dir, err := os.UserConfigDir()
		if err != nil {
			return "", err
		}
		return filepath.Join(dir, "firefox-vpn-client", "previous-proxy.json"), nil
	}
)

const proxySchema = "org.gnome.system.proxy"

// proxyKeys are the keys this program changes, "schema key"; mode is
// last, so the proxy is complete before it is turned on.
var proxyKeys = []string{
	proxySchema + " autoconfig-url",
	proxySchema + " ignore-hosts",
	proxySchema + ".http host", proxySchema + ".http port",
	proxySchema + ".https host", proxySchema + ".https port",
	proxySchema + ".socks host", proxySchema + ".socks port",
	proxySchema + " mode",
}

// systemProxyBypass keeps local and private addresses off the proxy.
const systemProxyBypass = "['localhost', '127.0.0.0/8', '::1', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']"

// proxySetting maps each of proxyKeys to its value in GVariant text, as
// gsettings prints and reads it.
type proxySetting map[string]string

// systemProxySupported reports whether this session has GNOME's proxy
// setting: a desktop session (not a service) with gsettings and the schema.
var systemProxySupported = sync.OnceValue(func() bool {
	if os.Getenv("DBUS_SESSION_BUS_ADDRESS") == "" && os.Getenv("XDG_RUNTIME_DIR") == "" {
		return false
	}
	_, err := gsettings("get", proxySchema, "mode")
	return err == nil
})

func readProxySetting() (proxySetting, error) {
	p := proxySetting{}
	for _, k := range proxyKeys {
		schema, key, _ := strings.Cut(k, " ")
		v, err := gsettings("get", schema, key)
		if err != nil {
			return nil, err
		}
		p[k] = v
	}
	return p, nil
}

func writeProxySetting(p proxySetting) error {
	for _, k := range proxyKeys {
		v, ok := p[k]
		if !ok {
			continue
		}
		schema, key, _ := strings.Cut(k, " ")
		if _, err := gsettings("set", schema, key, v); err != nil {
			return err
		}
	}
	return nil
}

// ourSetting is the setting this program makes for the proxy at server.
func ourSetting(server string) (proxySetting, error) {
	host, port, err := net.SplitHostPort(server)
	if err != nil {
		return nil, err
	}
	quoted := "'" + host + "'"
	p := proxySetting{
		proxySchema + " mode":           "'manual'",
		proxySchema + " autoconfig-url": "''",
		proxySchema + " ignore-hosts":   systemProxyBypass,
	}
	for _, kind := range []string{"http", "https", "socks"} {
		p[proxySchema+"."+kind+" host"] = quoted
		p[proxySchema+"."+kind+" port"] = port
	}
	return p, nil
}

// isOurs reports whether p is this program's setting for the proxy at
// server.
func (p proxySetting) isOurs(server string) bool {
	ours, err := ourSetting(server)
	if err != nil || p[proxySchema+" mode"] != "'manual'" {
		return false
	}
	return p[proxySchema+".http host"] == ours[proxySchema+".http host"] &&
		p[proxySchema+".http port"] == ours[proxySchema+".http port"]
}

func (p proxySetting) equal(q proxySetting) bool {
	for _, k := range proxyKeys {
		if p[k] != q[k] {
			return false
		}
	}
	return true
}

// setSystemProxy points the desktop's proxy at server, keeping the
// previous setting unless it is already this program's.
func setSystemProxy(server string) error {
	next, err := ourSetting(server)
	if err != nil {
		return err
	}
	current, err := readProxySetting()
	if err != nil {
		return err
	}
	if current.equal(next) {
		return nil
	}
	if !current.isOurs(server) {
		if err := saveBackup(current); err != nil {
			return err
		}
	}
	return writeProxySetting(next)
}

// restoreSystemProxy brings back the setting from before this program's,
// but only while the desktop's setting is still this program's (the proxy
// at server): a proxy the user chose meanwhile stays.
func restoreSystemProxy(server string) error {
	current, err := readProxySetting()
	if err != nil {
		return err
	}
	if !current.isOurs(server) {
		return nil
	}
	previous := loadBackup()
	if previous == nil || previous.isOurs(server) {
		previous = proxySetting{proxySchema + " mode": "'none'"}
	}
	if err := writeProxySetting(previous); err != nil {
		return err
	}
	deleteBackup()
	return nil
}

// systemProxyTaken reports whether another program replaced this
// program's setting for the proxy at server, and what the setting points
// at now: a setup script, another proxy, or "" when it turned the proxy
// off.
func systemProxyTaken(server string) (bool, string) {
	p, err := readProxySetting()
	if err != nil || p.isOurs(server) {
		return false, ""
	}
	switch p[proxySchema+" mode"] {
	case "'auto'":
		return true, strings.Trim(p[proxySchema+" autoconfig-url"], "'")
	case "'manual'":
		return true, net.JoinHostPort(strings.Trim(p[proxySchema+".http host"], "'"), p[proxySchema+".http port"])
	}
	return true, ""
}

// clearSystemProxy turns the desktop's proxy off, whoever set it.
func clearSystemProxy() error {
	mode, err := gsettings("get", proxySchema, "mode")
	if err != nil {
		return err
	}
	if mode == "'none'" {
		return nil
	}
	if _, err := gsettings("set", proxySchema, "mode", "'none'"); err != nil {
		return err
	}
	deleteBackup()
	return nil
}

func saveBackup(p proxySetting) error {
	path, err := backupPath()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.Marshal(p)
	if err != nil {
		return err
	}
	return securefile.WritePrivate(path, data)
}

func loadBackup() proxySetting {
	path, err := backupPath()
	if err != nil {
		return nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var p proxySetting
	if json.Unmarshal(data, &p) != nil {
		return nil
	}
	return p
}

func deleteBackup() {
	if path, err := backupPath(); err == nil {
		_ = os.Remove(path)
	}
}
