package service

import (
	"net/http"
	"sync/atomic"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
)

// fakeAutoConnect replaces auto-connect's test with pass (counting the
// calls) and shortens its waits to window and a millisecond.
func fakeAutoConnect(t *testing.T, window time.Duration, pass func(call int32) bool) *atomic.Int32 {
	t.Helper()
	var calls atomic.Int32
	oldProbe, oldWindow, oldRetry := autoConnectProbe, autoConnectWindow, autoConnectRetry
	autoConnectProbe = func(*Daemon) bool { return pass(calls.Add(1)) }
	autoConnectWindow = window
	autoConnectRetry = func(int) time.Duration { return time.Millisecond }
	t.Cleanup(func() { autoConnectProbe, autoConnectWindow, autoConnectRetry = oldProbe, oldWindow, oldRetry })
	return &calls
}

// runOffDaemon runs the lazy daemon with the proxy off and the system proxy
// mode set to mode, as the desktop app starts it.
func runOffDaemon(t *testing.T, mode string) *Daemon {
	t.Helper()
	d, _ := runLazyDaemon(t)
	d.SystemProxySupported = true
	if err := d.SetSystemProxy(mode); err != nil {
		t.Fatal(err)
	}
	d.SetOn(false)
	waitMessage(t, d, PhaseOff, "Proxy off")
	return d
}

func autoConnecting(t *testing.T, d *Daemon) bool {
	t.Helper()
	view, err := d.StatusView()
	if err != nil {
		t.Fatal(err)
	}
	return view.AutoConnecting
}

// With the system proxy set, the system proxy waits until a test passes;
// the proxy stays on.
func TestAutoConnectHoldsTheSystemProxyUntilATestPasses(t *testing.T) {
	calls := fakeAutoConnect(t, time.Minute, func(call int32) bool { return call >= 3 })
	d := runOffDaemon(t, config.SystemProxySet)
	client := newDashboardClient(t, d)
	if rec := client.do(http.MethodPost, "/api/power", map[string]bool{"on": true, "auto": true}); rec.Code != http.StatusOK {
		t.Fatalf("auto: %d %s", rec.Code, rec.Body)
	}
	waitMessage(t, d, PhaseRunning, "Proxy running")
	waitForCondition(t, 5*time.Second, func() bool { return !autoConnecting(t, d) })
	if n := calls.Load(); n != 3 {
		t.Fatalf("tests %d; want 3, until the first passed", n)
	}
	if d.isOff() {
		t.Fatal("the proxy must stay on after a passed test")
	}
}

// No passed test within the window: the proxy goes off again, the system
// proxy never set.
func TestAutoConnectGivesUpAndTurnsTheProxyOff(t *testing.T) {
	fakeAutoConnect(t, 50*time.Millisecond, func(int32) bool { return false })
	d := runOffDaemon(t, config.SystemProxySet)
	d.AutoConnect()
	if !autoConnecting(t, d) {
		t.Fatal("the system proxy must wait for the test")
	}
	// The phase was off before the attempt too, so wait for the attempt to
	// end first, then for the proxy to be off again.
	waitForCondition(t, 5*time.Second, func() bool { return !autoConnecting(t, d) })
	waitMessage(t, d, PhaseOff, "Proxy off")
	if !d.isOff() {
		t.Fatal("the proxy must be off again when the attempt gives up")
	}
}

// The window counts from when a network connected.
func TestAutoConnectWaitsForTheNetwork(t *testing.T) {
	calls := fakeAutoConnect(t, time.Minute, func(int32) bool { return true })
	d := runOffDaemon(t, config.SystemProxySet)
	online := setNetwork(t)
	d.AutoConnect()
	time.Sleep(50 * time.Millisecond)
	if n := calls.Load(); n != 0 || !autoConnecting(t, d) {
		t.Fatalf("tested %d times without a network", n)
	}
	online.Store(true)
	waitForCondition(t, 5*time.Second, func() bool { return !autoConnecting(t, d) })
}

// The user's own switch ends the attempt; the proxy stays as they set it.
func TestAutoConnectEndsWhenTheUserActs(t *testing.T) {
	fakeAutoConnect(t, time.Minute, func(int32) bool { return false })
	d := runOffDaemon(t, config.SystemProxySet)
	d.AutoConnect()
	waitMessage(t, d, PhaseRunning, "Proxy running")
	if err := d.SetSystemProxy(config.SystemProxyClear); err != nil {
		t.Fatal(err)
	}
	if autoConnecting(t, d) {
		t.Fatal("a mode change must end the attempt")
	}
	time.Sleep(50 * time.Millisecond)
	if d.isOff() {
		t.Fatal("an ended attempt must not turn the proxy off")
	}
}

// Proxy only: auto-connect only turns the proxy on, with no test.
func TestAutoConnectProxyOnly(t *testing.T) {
	calls := fakeAutoConnect(t, time.Minute, func(int32) bool { return false })
	d := runOffDaemon(t, config.SystemProxyClear)
	d.AutoConnect()
	waitMessage(t, d, PhaseRunning, "Proxy running")
	time.Sleep(50 * time.Millisecond)
	if n := calls.Load(); n != 0 || autoConnecting(t, d) {
		t.Fatalf("tests %d, waiting %t; want neither", n, autoConnecting(t, d))
	}
}
