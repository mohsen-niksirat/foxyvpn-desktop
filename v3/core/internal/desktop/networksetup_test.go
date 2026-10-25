package desktop

import (
	"fmt"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

// fakeNetworkSetup answers like networksetup for Wi-Fi (the user's own web
// proxy and a PAC file, turned off) and Ethernet, with a disabled
// Bluetooth PAN that must stay untouched.
type fakeNetworkSetup struct {
	state map[string]*macServiceProxy
	calls []string
}

func newFakeNetworkSetup(t *testing.T) (*fakeNetworkSetup, networkSetup) {
	f := &fakeNetworkSetup{state: map[string]*macServiceProxy{}}
	for _, s := range []string{"Wi-Fi", "Ethernet", "Bluetooth PAN"} {
		p := &macServiceProxy{Proxies: map[string]macProxy{}}
		for _, kind := range proxyKinds {
			p.Proxies[kind] = macProxy{}
		}
		f.state[s] = p
	}
	f.state["Wi-Fi"].Proxies["webproxy"] = macProxy{Enabled: true, Server: "proxy.example", Port: 3128}
	f.state["Wi-Fi"].Bypass = []string{"*.corp"}
	f.state["Wi-Fi"].AutoURL = "http://pac.example/proxy.pac"
	backup := filepath.Join(t.TempDir(), "previous-proxy.json")
	return f, networkSetup{run: f.run, backup: func() (string, error) { return backup, nil }}
}

func (f *fakeNetworkSetup) run(args ...string) (string, error) {
	f.calls = append(f.calls, strings.Join(args, " "))
	if args[0] == "-listallnetworkservices" {
		return "An asterisk (*) denotes that a network service is disabled.\nWi-Fi\nEthernet\n*Bluetooth PAN", nil
	}
	p, ok := f.state[args[1]]
	if !ok {
		return "", fmt.Errorf("%s is not a recognized network service", args[1])
	}
	cmd := args[0]
	switch {
	case cmd == "-getproxybypassdomains":
		if len(p.Bypass) == 0 {
			return "There aren't any bypass domains set on " + args[1] + ".", nil
		}
		return strings.Join(p.Bypass, "\n"), nil
	case cmd == "-setproxybypassdomains":
		p.Bypass = nil
		if args[2] != "Empty" {
			p.Bypass = append([]string(nil), args[2:]...)
		}
	case cmd == "-getautoproxyurl":
		url := p.AutoURL
		if url == "" {
			url = "(null)"
		}
		return fmt.Sprintf("URL: %s\nEnabled: %s", url, yesNo(p.AutoEnabled)), nil
	case cmd == "-setautoproxyurl":
		p.AutoURL, p.AutoEnabled = args[2], true
	case cmd == "-setautoproxystate":
		p.AutoEnabled = args[2] == "on"
	case strings.HasPrefix(cmd, "-get"):
		x := p.Proxies[strings.TrimPrefix(cmd, "-get")]
		return fmt.Sprintf("Enabled: %s\nServer: %s\nPort: %d\nAuthenticated Proxy Enabled: 0", yesNo(x.Enabled), x.Server, x.Port), nil
	case strings.HasSuffix(cmd, "state"):
		kind := strings.TrimSuffix(strings.TrimPrefix(cmd, "-set"), "state")
		x := p.Proxies[kind]
		x.Enabled = args[2] == "on"
		p.Proxies[kind] = x
	case strings.HasPrefix(cmd, "-set"):
		kind := strings.TrimPrefix(cmd, "-set")
		port, _ := strconv.Atoi(args[3])
		// networksetup turns a proxy on when it sets its server.
		p.Proxies[kind] = macProxy{Enabled: true, Server: args[2], Port: port}
	default:
		return "", fmt.Errorf("unexpected %v", args)
	}
	return "", nil
}

func yesNo(b bool) string {
	if b {
		return "Yes"
	}
	return "No"
}

func TestNetworkSetupSetAndRestore(t *testing.T) {
	f, n := newFakeNetworkSetup(t)
	f.state["Wi-Fi"].AutoEnabled = true
	if err := n.set("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	for _, s := range []string{"Wi-Fi", "Ethernet"} {
		for _, kind := range proxyKinds {
			if got := f.state[s].Proxies[kind]; got != (macProxy{Enabled: true, Server: "127.0.0.1", Port: 10810}) {
				t.Fatalf("%s %s = %+v", s, kind, got)
			}
		}
		if f.state[s].AutoEnabled {
			t.Fatalf("%s: the PAC file is still on", s)
		}
	}
	if f.state["Bluetooth PAN"].Proxies["webproxy"].Enabled {
		t.Fatal("a disabled service was changed")
	}
	// Setting it again keeps the user's setting as the one to restore.
	if err := n.set("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	if err := n.restore("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	wifi := f.state["Wi-Fi"]
	if got := wifi.Proxies["webproxy"]; got != (macProxy{Enabled: true, Server: "proxy.example", Port: 3128}) {
		t.Fatalf("Wi-Fi web proxy = %+v", got)
	}
	if wifi.Proxies["socksfirewallproxy"].Enabled || !wifi.AutoEnabled || strings.Join(wifi.Bypass, ",") != "*.corp" {
		t.Fatalf("Wi-Fi did not come back: %+v", wifi)
	}
	if eth := f.state["Ethernet"]; eth.Proxies["webproxy"].Enabled || eth.Proxies["socksfirewallproxy"].Enabled {
		t.Fatalf("Ethernet keeps the proxy: %+v", eth)
	}
}

func TestNetworkSetupRestoreLeavesTheUsersChoice(t *testing.T) {
	f, n := newFakeNetworkSetup(t)
	if err := n.set("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	f.state["Ethernet"].Proxies["webproxy"] = macProxy{Enabled: true, Server: "other.example", Port: 8080}
	if err := n.restore("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	if got := f.state["Ethernet"].Proxies["webproxy"]; got.Server != "other.example" || !got.Enabled {
		t.Fatalf("a proxy set meanwhile was replaced: %+v", got)
	}
}

func TestNetworkSetupClear(t *testing.T) {
	f, n := newFakeNetworkSetup(t)
	f.state["Wi-Fi"].AutoEnabled = true
	if err := n.clear(); err != nil {
		t.Fatal(err)
	}
	for _, s := range []string{"Wi-Fi", "Ethernet"} {
		for _, kind := range proxyKinds {
			if f.state[s].Proxies[kind].Enabled {
				t.Fatalf("%s %s is still on", s, kind)
			}
		}
		if f.state[s].AutoEnabled {
			t.Fatalf("%s: the PAC file is still on", s)
		}
	}
	// The user's server stays filled in, only turned off.
	if f.state["Wi-Fi"].Proxies["webproxy"].Server != "proxy.example" {
		t.Fatal("clearing removed the user's server")
	}
}
