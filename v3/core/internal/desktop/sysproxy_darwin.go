//go:build darwin

package desktop

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// The macOS proxy setting of every enabled network service, through
// networksetup (networksetup.go).
var macNetworkSetup = networkSetup{
	run: func(args ...string) (string, error) {
		out, err := exec.Command("/usr/sbin/networksetup", args...).CombinedOutput()
		return strings.TrimSpace(string(out)), err
	},
	backup: func() (string, error) {
		dir, err := os.UserConfigDir()
		if err != nil {
			return "", err
		}
		return filepath.Join(dir, "Firefox VPN Client", "previous-proxy.json"), nil
	},
}

func systemProxySupported() bool {
	_, err := os.Stat("/usr/sbin/networksetup")
	return err == nil
}

func setSystemProxy(server string) error { return macNetworkSetup.set(server) }

func restoreSystemProxy(server string) error { return macNetworkSetup.restore(server) }

func clearSystemProxy() error { return macNetworkSetup.clear() }

// systemProxyTaken: another program's setting is not looked for on macOS,
// where each network service has its own.
func systemProxyTaken(string) (bool, string) { return false, "" }
