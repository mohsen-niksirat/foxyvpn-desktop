package service

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/routing"
)

// The phone's VPN refuses at once what Mozilla would refuse, unless the
// routing sends it directly.
func TestTunnelAllowsMozillaPortsAndDirectDestinations(t *testing.T) {
	d := newTestDaemon(t)
	for port, want := range map[string]bool{"443": true, "80": true, "8443": true, "5222": false, "22": false} {
		if got := d.TunnelAllows("chat.example", port); got != want {
			t.Errorf("port %s: %t", port, got)
		}
	}
	writeTestGeoIP(t, d, map[string][]string{"private": {"10.0.0.0/8"}})
	d.applyRouting(config.Routing{Enabled: true, Direct: []string{"domain:bank.test"}})
	if d.currentRouter() == nil {
		t.Fatal("the routing did not load")
	}
	if !d.TunnelAllows("www.bank.test", "8081") {
		t.Fatal("a direct destination may use any port")
	}
	if d.TunnelAllows("chat.example", "5222") {
		t.Fatal("a proxied destination keeps Mozilla's ports")
	}
}

// The region's app list is read only while routing is on.
func TestDirectAppsFollowTheRouting(t *testing.T) {
	d := newTestDaemon(t)
	if err := writeTestFile(d.paths.RoutingDir, routing.AppListFile("ir"), "cab.snapp.passenger\ncom.digikala\n"); err != nil {
		t.Fatal(err)
	}
	d.mu.Lock()
	d.cfg.Routing.Enabled, d.cfg.Routing.Region = true, "ir"
	d.mu.Unlock()
	if got := d.DirectApps(); len(got) != 2 {
		t.Fatalf("apps %v", got)
	}
	d.mu.Lock()
	d.cfg.Routing.Enabled = false
	d.mu.Unlock()
	if got := d.DirectApps(); got != nil {
		t.Fatalf("routing off, apps %v", got)
	}
}

// A network change voids the last test and, connected, reconnects.
func TestNetworkChangeReconnects(t *testing.T) {
	d, f := runLazyDaemon(t)
	view, _ := d.StatusView()
	if err := lazyEcho(t, view.Proxy.Listen, "before"); err != nil {
		t.Fatal(err)
	}
	before := f.connects.Load()
	d.NetworkChanged(true)
	view, _ = d.StatusView()
	if view.NetworkChangedAt.IsZero() || time.Since(view.NetworkChangedAt) > time.Minute {
		t.Fatalf("network change time %v", view.NetworkChangedAt)
	}
	if err := lazyEcho(t, view.Proxy.Listen, "after"); err != nil {
		t.Fatalf("after the change: %v", err)
	}
	if f.passes.Load() != 1 {
		t.Fatalf("passes %d; a reconnect keeps the pass", f.passes.Load())
	}
	if f.connects.Load() <= before {
		t.Fatal("no connection after the change")
	}
	if view.NoNetwork {
		t.Fatal("a network is connected")
	}

	// No network: the status says so at once.
	t.Cleanup(func() { d.NetworkChanged(true) })
	d.NetworkChanged(false)
	if view, _ = d.StatusView(); !view.NoNetwork {
		t.Fatal("no_network not reported")
	}
}

func writeTestFile(dir, name, content string) error {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, name), []byte(content), 0o600)
}
