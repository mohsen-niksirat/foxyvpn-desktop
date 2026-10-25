//go:build windows

package desktop

import (
	"errors"
	"os"
	"strings"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

// systemProxySupported: Windows always has the setting.
func systemProxySupported() bool { return true }

// The user's proxy setting (what "Use a proxy server" and "Use setup
// script" in Windows settings, and most browsers, read). A ProxyServer
// without a scheme is an HTTP proxy for every protocol, which the local
// proxy serves on its SOCKS5 port. This program never sets AutoConfigURL
// (a setup script), but removes the user's while its own setting is in
// place, since Windows would use the script first. The previous setting
// is kept under backupKey and restored when this program's setting is
// removed. Tests replace the key names.
var (
	internetSettingsKey = `Software\Microsoft\Windows\CurrentVersion\Internet Settings`
	backupKey           = `Software\FirefoxVPN\PreviousProxy`
)

// systemProxyBypass keeps local and private addresses off the proxy.
const systemProxyBypass = "localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.20.*;172.21.*;172.22.*;172.23.*;172.24.*;172.25.*;172.26.*;172.27.*;172.28.*;172.29.*;172.30.*;172.31.*;192.168.*;<local>"

var (
	wininet               = windows.NewLazySystemDLL("wininet.dll")
	procInternetSetOption = wininet.NewProc("InternetSetOptionW")
)

const (
	internetOptionSettingsChanged = 39
	internetOptionRefresh         = 37
)

// proxySetting is the part of the user's Internet Settings this program
// changes.
type proxySetting struct {
	enabled  bool   // ProxyEnable: use ProxyServer
	server   string // ProxyServer
	override string // ProxyOverride
	script   string // AutoConfigURL (the user's setup script), "" when unset
}

func readProxySetting(k registry.Key) proxySetting {
	on, _, _ := k.GetIntegerValue("ProxyEnable")
	server, _, _ := k.GetStringValue("ProxyServer")
	override, _, _ := k.GetStringValue("ProxyOverride")
	script, _, _ := k.GetStringValue("AutoConfigURL")
	return proxySetting{enabled: on == 1, server: server, override: override, script: script}
}

func writeProxySetting(k registry.Key, p proxySetting) error {
	enabled := uint32(0)
	if p.enabled {
		enabled = 1
	}
	if err := k.SetStringValue("ProxyServer", p.server); err != nil {
		return err
	}
	if err := k.SetStringValue("ProxyOverride", p.override); err != nil {
		return err
	}
	if p.script == "" {
		if err := k.DeleteValue("AutoConfigURL"); err != nil && !errors.Is(err, registry.ErrNotExist) {
			return err
		}
	} else if err := k.SetStringValue("AutoConfigURL", p.script); err != nil {
		return err
	}
	return k.SetDWordValue("ProxyEnable", enabled)
}

// isOurs reports whether p is the setting this program makes for the
// proxy at server.
func (p proxySetting) isOurs(server string) bool {
	return server != "" && p.enabled && p.server == server
}

// setSystemProxy points the user's proxy at server, keeping the previous
// setting unless it is already this program's.
func setSystemProxy(server string) error {
	next := proxySetting{enabled: true, server: server, override: systemProxyBypass}
	k, err := registry.OpenKey(registry.CURRENT_USER, internetSettingsKey, registry.QUERY_VALUE|registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer k.Close()
	current := readProxySetting(k)
	if current == next {
		return nil
	}
	if !current.isOurs(server) {
		backup, _, err := registry.CreateKey(registry.CURRENT_USER, backupKey, registry.SET_VALUE)
		if err != nil {
			return err
		}
		err = writeProxySetting(backup, current)
		backup.Close()
		if err != nil {
			return err
		}
	}
	if err := writeProxySetting(k, next); err != nil {
		return err
	}
	if envKey, err := registry.OpenKey(registry.CURRENT_USER, `Environment`, registry.SET_VALUE); err == nil {
		_ = envKey.SetStringValue("HTTP_PROXY", "http://"+server)
		_ = envKey.SetStringValue("HTTPS_PROXY", "http://"+server)
		envKey.Close()
	}
	_ = os.Setenv("HTTP_PROXY", "http://"+server)
	_ = os.Setenv("HTTPS_PROXY", "http://"+server)
	announceProxyChange()
	return nil
}

// restoreSystemProxy brings back the setting from before this program's,
// but only while the user's setting is still this program's (the proxy at
// server): a proxy the user chose meanwhile stays.
func restoreSystemProxy(server string) error {
	k, err := registry.OpenKey(registry.CURRENT_USER, internetSettingsKey, registry.QUERY_VALUE|registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer k.Close()
	if !readProxySetting(k).isOurs(server) {
		return nil
	}
	var previous proxySetting
	if backup, err := registry.OpenKey(registry.CURRENT_USER, backupKey, registry.QUERY_VALUE); err == nil {
		previous = readProxySetting(backup)
		backup.Close()
	}
	if previous.isOurs(server) {
		previous = proxySetting{}
	}
	if err := writeProxySetting(k, previous); err != nil {
		return err
	}
	deleteBackup()
	if envKey, err := registry.OpenKey(registry.CURRENT_USER, `Environment`, registry.SET_VALUE); err == nil {
		_ = envKey.DeleteValue("HTTP_PROXY")
		_ = envKey.DeleteValue("HTTPS_PROXY")
		envKey.Close()
	}
	_ = os.Unsetenv("HTTP_PROXY")
	_ = os.Unsetenv("HTTPS_PROXY")
	announceProxyChange()
	return nil
}

// systemProxyTaken reports whether another program replaced this
// program's setting for the proxy at server, and what the setting points
// at now: a setup script (which Windows uses first), another proxy, or ""
// when it turned the proxy off.
func systemProxyTaken(server string) (bool, string) {
	k, err := registry.OpenKey(registry.CURRENT_USER, internetSettingsKey, registry.QUERY_VALUE)
	if err != nil {
		return false, ""
	}
	defer k.Close()
	p := readProxySetting(k)
	switch {
	case p.script != "":
		return true, p.script
	case p.isOurs(server):
		return false, ""
	case p.enabled:
		return true, p.server
	}
	return true, ""
}

// clearSystemProxy turns the user's system proxy off: no proxy server and
// no setup script, whoever set them (v2rayN's "Clear system proxy").
func clearSystemProxy() error {
	k, err := registry.OpenKey(registry.CURRENT_USER, internetSettingsKey, registry.QUERY_VALUE|registry.SET_VALUE)
	if err != nil {
		return err
	}
	defer k.Close()
	current := readProxySetting(k)
	if !current.enabled && current.script == "" {
		return nil
	}
	current.enabled, current.script = false, ""
	if err := writeProxySetting(k, current); err != nil {
		return err
	}
	deleteBackup()
	if envKey, err := registry.OpenKey(registry.CURRENT_USER, `Environment`, registry.SET_VALUE); err == nil {
		_ = envKey.DeleteValue("HTTP_PROXY")
		_ = envKey.DeleteValue("HTTPS_PROXY")
		envKey.Close()
	}
	_ = os.Unsetenv("HTTP_PROXY")
	_ = os.Unsetenv("HTTPS_PROXY")
	announceProxyChange()
	return nil
}

func deleteBackup() {
	_ = registry.DeleteKey(registry.CURRENT_USER, backupKey)
	if parent := backupKey[:strings.LastIndex(backupKey, `\`)]; parent != "Software" {
		_ = registry.DeleteKey(registry.CURRENT_USER, parent) // only when empty
	}
}

// announceProxyChange tells running applications to read the setting
// again; tests replace it.
var announceProxyChange = func() {
	_, _, _ = procInternetSetOption.Call(0, internetOptionSettingsChanged, 0, 0)
	_, _, _ = procInternetSetOption.Call(0, internetOptionRefresh, 0, 0)
}
