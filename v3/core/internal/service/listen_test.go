package service

import (
	"errors"
	"net"
	"net/http"
	"testing"
	"time"
)

// occupyLoopbackPort holds a loopback port, as another program would, for
// the length of the test, and returns its address.
func occupyLoopbackPort(t *testing.T) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = ln.Close() })
	return ln.Addr().String()
}

// A taken address is the system's "address in use" error, reported as an
// *AddressInUseError naming the listener and the address; other failures
// are not.
func TestListenTCPReportsAddressInUse(t *testing.T) {
	addr := occupyLoopbackPort(t)
	_, err := listenTCP(ListenerProxy, addr)
	var inUse *AddressInUseError
	if !errors.As(err, &inUse) || inUse.Listener != ListenerProxy || inUse.Address != addr || !IsAddressInUse(err) {
		t.Fatalf("got %v, want an address-in-use error for %s", err, addr)
	}
	if err := probeListen(ListenerProxy, addr); !errors.As(err, &inUse) {
		t.Fatalf("probe: got %v", err)
	}

	_, err = listenTCP(ListenerDashboard, "127.0.0.1:not-a-port")
	if err == nil || errors.As(err, &inUse) || IsAddressInUse(err) {
		t.Fatalf("a bad address is not in use: %v", err)
	}
	free, err := listenTCP(ListenerDashboard, "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	_ = free.Close()
}

// statusState reads state from GET /api/status as a client would.
func statusState(t *testing.T, c *dashboardClient) map[string]any {
	t.Helper()
	body := decodeBody[map[string]any](t, c.do(http.MethodGet, "/api/status", nil))
	state, ok := body["state"].(map[string]any)
	if !ok {
		t.Fatalf("status without a state: %v", body)
	}
	return state
}

// While the proxy address is taken, /api/status says so with a stable code
// and the address, before any account is needed; a new proxy.listen
// restarts the engine at once on the new address and clears the code.
func TestProxyPortInUseInStatus(t *testing.T) {
	taken := occupyLoopbackPort(t)
	d := newTestDaemon(t)
	d.mu.Lock()
	d.cfg.Dashboard.Listen = "127.0.0.1:0"
	d.cfg.Proxy.Listen = taken
	d.mu.Unlock()
	done := make(chan error, 1)
	go func() { done <- d.Run() }()
	defer func() {
		d.Shutdown()
		<-done
	}()
	c := newDashboardClient(t, d)

	waitForCondition(t, 5*time.Second, func() bool { return statusState(t, c)["code"] == CodeProxyPortInUse })
	state := statusState(t, c)
	if state["phase"] != PhaseError || state["address"] != taken || state["message"] == "" || state["retry_at"] == nil {
		t.Fatalf("state %v, want phase error with the address %s, a message, and a retry time", state, taken)
	}

	settings := decodeBody[settingsView](t, c.do(http.MethodGet, "/api/settings", nil))
	next := settings.Config
	next.Proxy.Listen = "127.0.0.1:0"
	if rec := c.do(http.MethodPut, "/api/settings", map[string]any{"config": next}); rec.Code != http.StatusOK {
		t.Fatalf("saving proxy.listen: %d %s", rec.Code, rec.Body)
	}
	// Without an account the restarted start ends in "add an account",
	// which shows it got past the address check well before the retry.
	waitMessage(t, d, PhaseWaiting, "Add an account in the dashboard to start the proxy")
	if state := statusState(t, c); state["code"] != CodeNoAccounts || state["address"] != nil {
		t.Fatalf("the code must give way to the next state's: %v", state)
	}
}

// The dashboard's own address in use is returned from Run as an
// *AddressInUseError, which the desktop app mode reports to the app.
func TestDashboardPortInUseFailsRun(t *testing.T) {
	taken := occupyLoopbackPort(t)
	d := newTestDaemon(t)
	d.mu.Lock()
	d.cfg.Dashboard.Listen = taken
	d.mu.Unlock()
	d.RequireDashboard = true
	err := d.Run()
	var inUse *AddressInUseError
	if !errors.As(err, &inUse) || inUse.Listener != ListenerDashboard || inUse.Address != taken {
		t.Fatalf("got %v, want the dashboard address %s in use", err, taken)
	}
}
