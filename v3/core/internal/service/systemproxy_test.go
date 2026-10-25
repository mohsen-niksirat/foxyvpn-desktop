package service

import (
	"encoding/json"
	"net/http"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
)

func waitPhase(t *testing.T, d *Daemon, want string) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		d.mu.Lock()
		phase := d.state.Phase
		d.mu.Unlock()
		if phase == want {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("phase did not become %q", want)
}

// POST /api/system-proxy accepts only set and clear; the choice is saved
// and reported by the status.
func TestSystemProxyEndpointAcceptsSetAndClear(t *testing.T) {
	d := newTestDaemon(t)
	client := newDashboardClient(t, d)
	if view, _ := d.StatusView(); view.SystemProxy != config.SystemProxyClear {
		t.Fatalf("default system proxy mode %q", view.SystemProxy)
	}
	for _, mode := range []string{config.SystemProxySet, config.SystemProxyClear} {
		if rec := client.do(http.MethodPost, "/api/system-proxy", map[string]string{"mode": mode}); rec.Code != http.StatusOK {
			t.Fatalf("mode %s: %d %s", mode, rec.Code, rec.Body.String())
		}
		saved, _, err := config.Load(d.paths.Config)
		if err != nil || saved.SystemProxy.Mode != mode {
			t.Fatalf("mode %s must be saved: %q %v", mode, saved.SystemProxy.Mode, err)
		}
		if view, _ := d.StatusView(); view.SystemProxy != mode {
			t.Fatalf("status reports %q, want %q", view.SystemProxy, mode)
		}
	}
	for _, mode := range []string{"pac", "unchanged", ""} {
		if rec := client.do(http.MethodPost, "/api/system-proxy", map[string]string{"mode": mode}); rec.Code != http.StatusBadRequest {
			t.Fatalf("mode %q must be refused: %d %s", mode, rec.Code, rec.Body.String())
		}
	}
	if d.config().SystemProxy.Mode != config.SystemProxyClear {
		t.Fatalf("a refused mode must not change the setting: %q", d.config().SystemProxy.Mode)
	}
}

// The proxy has no on/off switch: the endpoint and the status field are
// gone, and the engine starts on its own.
func TestNoVPNSwitch(t *testing.T) {
	d := newTestDaemon(t)
	d.mu.Lock()
	d.cfg.Dashboard.Listen = "127.0.0.1:0"
	d.mu.Unlock()
	done := make(chan error, 1)
	go func() { done <- d.Run() }()
	defer func() {
		d.Shutdown()
		<-done
	}()
	waitPhase(t, d, PhaseWaiting) // no account yet

	client := newDashboardClient(t, d)
	if rec := client.do(http.MethodPost, "/api/proxy/enabled", map[string]bool{"enabled": false}); rec.Code == http.StatusOK {
		t.Fatalf("POST /api/proxy/enabled must not exist: %d", rec.Code)
	}
	rec := client.do(http.MethodGet, "/api/status", nil)
	var status map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &status); err != nil {
		t.Fatal(err)
	}
	if _, ok := status["vpn_enabled"]; ok {
		t.Fatal("the status must not report vpn_enabled")
	}
}
