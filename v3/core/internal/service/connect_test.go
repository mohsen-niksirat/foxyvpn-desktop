package service

import (
	"net/http"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
)

func shortConnectWindow(t *testing.T) {
	t.Helper()
	old := connectWindow
	connectWindow = 100 * time.Millisecond
	t.Cleanup(func() { connectWindow = old })
}

func connectFailure(t *testing.T, d *Daemon) string {
	t.Helper()
	view, err := d.StatusView()
	if err != nil {
		t.Fatal(err)
	}
	return view.ConnectFailure
}

// A connect that never reaches Mozilla is given up: the proxy goes off,
// and the status says why.
func TestConnectGivesUpWithoutAConnection(t *testing.T) {
	shortConnectWindow(t)
	d := runOffDaemon(t, "clear")
	d.Connect()
	waitMessage(t, d, PhaseRunning, "Proxy running")
	waitMessage(t, d, PhaseOff, "Proxy off")
	if got := connectFailure(t, d); got != proxy.FailureOther {
		t.Fatalf("reason %q, want %q", got, proxy.FailureOther)
	}
	// The next connect starts without the old reason.
	d.Connect()
	if got := connectFailure(t, d); got != "" {
		t.Fatalf("the old reason stays: %q", got)
	}
}

// One connection to Mozilla is enough; the proxy stays on after.
func TestConnectThatReachedMozillaStaysOn(t *testing.T) {
	shortConnectWindow(t)
	d := runOffDaemon(t, "clear")
	d.Connect()
	d.markConnected()
	time.Sleep(300 * time.Millisecond)
	if !d.IsOn() || connectFailure(t, d) != "" {
		t.Fatalf("on %t, reason %q", d.IsOn(), connectFailure(t, d))
	}
}

// The app's button gives up; a browser's (a server's dashboard) does not.
func TestPowerFromABrowserIsNotGivenUp(t *testing.T) {
	shortConnectWindow(t)
	d := runOffDaemon(t, "clear")
	if rec := newDashboardClient(t, d).do(http.MethodPost, "/api/power", map[string]bool{"on": true}); rec.Code != http.StatusOK {
		t.Fatalf("on: %d", rec.Code)
	}
	waitMessage(t, d, PhaseRunning, "Proxy running")
	time.Sleep(300 * time.Millisecond)
	if !d.IsOn() {
		t.Fatal("a browser's connect was given up")
	}
}
