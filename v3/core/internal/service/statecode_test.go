package service

import (
	"strings"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/accounts"
	"github.com/armanlife/firefox-vpn-client/core/internal/config"
)

// waitCode waits until /api/status reports the state code, and returns the
// state.
func waitCode(t *testing.T, c *dashboardClient, code string) map[string]any {
	t.Helper()
	var state map[string]any
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if state = statusState(t, c); state["code"] == code {
			return state
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("state %v, want the code %q", state, code)
	return nil
}

// The waiting states carry a stable code beside the core's English
// message, so the apps can word them: no network, no account, and no
// usable account.
func TestWaitingStatesHaveCodes(t *testing.T) {
	online := setNetwork(t)
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
	c := newDashboardClient(t, d)

	state := waitCode(t, c, CodeWaitingForNetwork)
	if state["phase"] != PhaseWaiting || state["message"] != MessageWaitingForNetwork {
		t.Fatalf("waiting for the network: %v", state)
	}

	online.Store(true)
	state = waitCode(t, c, CodeNoAccounts)
	if state["phase"] != PhaseWaiting || state["message"] == "" {
		t.Fatalf("no accounts: %v", state)
	}

	// The only account must sign in again: none can be used.
	id := addTestAccount(t, d, "signed-out")
	acc, err := d.store.Get(id)
	if err != nil {
		t.Fatal(err)
	}
	acc.Status, acc.Reason = accounts.StatusReauthRequired, "sign-in required"
	if err := d.store.SaveState(acc); err != nil {
		t.Fatal(err)
	}
	if err := d.accountsChanged(); err != nil {
		t.Fatal(err)
	}
	d.RequestRestart()
	state = waitCode(t, c, CodeNoUsableAccount)
	if state["phase"] != PhaseWaiting || !strings.HasPrefix(state["message"].(string), "No usable account") {
		t.Fatalf("no usable account: %v", state)
	}
	if _, ok := state["address"]; ok {
		t.Fatalf("only the port code has an address: %v", state)
	}
}

// Another failed start is an error with the code start_failed and the
// core's message; it is retried. A proxy address that cannot be listened
// on is named, for apps to offer another port.
func TestStartFailureHasCode(t *testing.T) {
	d := newTestDaemon(t)
	d.mu.Lock()
	d.cfg.Dashboard.Listen = "127.0.0.1:0"
	d.cfg.Proxy.Listen = "127.0.0.1:not-a-port"
	d.mu.Unlock()
	done := make(chan error, 1)
	go func() { done <- d.Run() }()
	defer func() {
		d.Shutdown()
		<-done
	}()
	c := newDashboardClient(t, d)

	state := waitCode(t, c, CodeStartFailed)
	if state["phase"] != PhaseError || state["message"] == "" || state["retry_at"] == nil {
		t.Fatalf("start failed: %v", state)
	}
	if state["address"] != "127.0.0.1:not-a-port" {
		t.Fatalf("start failed without the proxy's address: %v", state)
	}
}

// Another program's setting in place of the system proxy shows in the
// status; asking for set while set asks to take it back, and a mode change
// forgets it.
func TestSystemProxyTakenShowsInTheStatus(t *testing.T) {
	d := newTestDaemon(t)
	if err := d.SetSystemProxy(config.SystemProxySet); err != nil {
		t.Fatal(err)
	}
	d.SetSystemProxyTaken(&SystemProxyTaken{By: "127.0.0.1:7890"})
	view, err := d.StatusView()
	if err != nil {
		t.Fatal(err)
	}
	if view.SystemProxyTaken == nil || view.SystemProxyTaken.By != "127.0.0.1:7890" || view.SystemProxyRetake != 0 {
		t.Fatalf("taken %+v retake %d", view.SystemProxyTaken, view.SystemProxyRetake)
	}
	if err := d.SetSystemProxy(config.SystemProxySet); err != nil {
		t.Fatal(err)
	}
	if view, _ = d.StatusView(); view.SystemProxyRetake != 1 {
		t.Fatalf("set again: retake %d, want 1", view.SystemProxyRetake)
	}
	if err := d.SetSystemProxy(config.SystemProxyClear); err != nil {
		t.Fatal(err)
	}
	if view, _ = d.StatusView(); view.SystemProxyTaken != nil {
		t.Fatalf("still taken after clear: %+v", view.SystemProxyTaken)
	}
}
