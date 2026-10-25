package service

import (
	"context"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	xproxy "golang.org/x/net/proxy"

	"github.com/armanlife/firefox-vpn-client/core/internal/controlplane"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
)

// Local fixtures for the lazy start: a stand-in for Mozilla's CONNECT proxy
// on loopback, and a control plane that answers only the server list and
// Guardian's pass. Nothing here reaches a real endpoint.

// lazyEchoTarget is the only destination the fixture upstream connects.
const lazyEchoTarget = "echo.invalid:443"

// lazyFixture counts what the engine asked of "Mozilla".
type lazyFixture struct {
	serverLists atomic.Int32
	passes      atomic.Int32
	connects    atomic.Int32
	// guardianRefuses makes Guardian answer 451 (region unavailable),
	// which is not retried and keeps the account.
	guardianRefuses atomic.Bool
	// guardianFails makes Guardian answer 400, a failure not known to last
	// (a 5xx would first use up the pass request's own retry budget).
	guardianFails atomic.Bool
	// deadServer, when set, is listed before the fixture upstream in the
	// same city: an address where nothing listens.
	deadServer atomic.Pointer[string]
	upstream   string
	// controlPlane is the installed control-plane transport.
	controlPlane *lazyControlPlane
}

// lazyControlPlane is a comparable control-plane transport, so a test can
// check that it is still the one installed.
type lazyControlPlane struct {
	handle func(*http.Request) (*http.Response, error)
}

func (c *lazyControlPlane) RoundTrip(r *http.Request) (*http.Response, error) { return c.handle(r) }

func lazyPassToken() string {
	claims := fmt.Sprintf(`{"iat":%d,"exp":%d}`, time.Now().Truncate(time.Hour).Unix(), time.Now().Truncate(time.Hour).Add(2*time.Hour).Unix())
	return "e30." + base64.RawURLEncoding.EncodeToString([]byte(claims)) + ".local-only"
}

// newLazyFixture starts the fixture upstream (HTTP/2 CONNECT over TLS that
// the upstream sessions trust through proxy.SetUpstreamRoots) and installs
// the control plane. Call it after creating the daemon: loading the config
// resets the control-plane transport.
func newLazyFixture(t *testing.T) *lazyFixture {
	t.Helper()
	f := &lazyFixture{}
	pass := lazyPassToken()
	srv := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodConnect || r.ProtoMajor != 2 {
			http.Error(w, "CONNECT over HTTP/2 only", http.StatusBadRequest)
			return
		}
		f.connects.Add(1)
		if r.Header.Get("Proxy-Authorization") != "Bearer "+pass {
			http.Error(w, "fixture pass rejected", http.StatusProxyAuthRequired)
			return
		}
		if r.Host != lazyEchoTarget {
			// Neither a rebuild nor a failure count (not 502, 401, 403, 407).
			http.Error(w, "fixture reaches no other destination", http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
		w.(http.Flusher).Flush()
		buf := make([]byte, 4096)
		for {
			n, err := r.Body.Read(buf)
			if n > 0 {
				_, _ = w.Write(buf[:n])
				w.(http.Flusher).Flush()
			}
			if err != nil {
				return
			}
		}
	}))
	srv.EnableHTTP2 = true
	srv.StartTLS()
	t.Cleanup(srv.Close)
	roots := x509.NewCertPool()
	roots.AddCert(srv.Certificate())
	proxy.SetUpstreamRoots(roots)
	t.Cleanup(func() { proxy.SetUpstreamRoots(nil) })
	f.upstream = srv.Listener.Addr().String()
	host, port, _ := net.SplitHostPort(f.upstream)

	f.controlPlane = &lazyControlPlane{handle: func(r *http.Request) (*http.Response, error) {
		switch {
		case r.Method == http.MethodGet && r.URL.Host == "firefox.settings.services.mozilla.com" && strings.HasSuffix(r.URL.Path, "/collections/vpn-serverlist/records"):
			f.serverLists.Add(1)
			servers := fmt.Sprintf(`{"hostname":%q,"port":%s}`, host, port)
			if dead := f.deadServer.Load(); dead != nil {
				deadHost, deadPort, _ := net.SplitHostPort(*dead)
				servers = fmt.Sprintf(`{"hostname":%q,"port":%s},`, deadHost, deadPort) + servers
			}
			serverList := `{"data":[{"name":"Netherlands","code":"NL","cities":[{"name":"Amsterdam","code":"ams","servers":[` + servers + `]}]}]}`
			return coreResponse(r, http.StatusOK, serverList, nil), nil
		case r.Method == http.MethodGet && strings.HasSuffix(r.URL.Path, "/api/v1/fpn/token"):
			f.passes.Add(1)
			if f.guardianRefuses.Load() {
				return coreResponse(r, http.StatusUnavailableForLegalReasons, `{"error":"fixture refusal"}`, nil), nil
			}
			if f.guardianFails.Load() {
				return coreResponse(r, http.StatusBadRequest, `{"error":"fixture failure"}`, nil), nil
			}
			body, _ := json.Marshal(map[string]string{"token": pass})
			return coreResponse(r, http.StatusOK, string(body), quotaHeader(1)), nil
		}
		t.Errorf("unexpected control-plane request %s %s", r.Method, r.URL)
		return nil, fmt.Errorf("unexpected request %s %s", r.Method, r.URL)
	}}
	controlplane.SetTransport(f.controlPlane)
	t.Cleanup(func() { controlplane.SetTransport(nil) })
	previousDelay := proxy.GuardianRetryInitialDelay
	proxy.GuardianRetryInitialDelay = time.Millisecond
	t.Cleanup(func() { proxy.GuardianRetryInitialDelay = previousDelay })
	return f
}

// runLazyDaemon runs a daemon with one synthetic account and the fixtures
// until the test ends, and waits for its engine to run.
func runLazyDaemon(t *testing.T) (*Daemon, *lazyFixture) {
	t.Helper()
	d := newTestDaemon(t)
	f := newLazyFixture(t)
	addTestAccount(t, d, "user")
	select { // the account change asked for a start; Run starts anyway
	case <-d.restart:
	default:
	}
	noExitCheck(t)
	d.mu.Lock()
	d.cfg.Dashboard.Listen = "127.0.0.1:0"
	d.mu.Unlock()
	if controlplane.Transport() != f.controlPlane {
		t.Fatal("the fixture control plane is not installed; requests could reach real endpoints")
	}
	done := make(chan error, 1)
	go func() { done <- d.Run() }()
	t.Cleanup(func() {
		d.Shutdown()
		<-done
	})
	waitMessage(t, d, PhaseRunning, "Proxy running")
	return d, f
}

func lazyEcho(t *testing.T, listen, value string) error {
	t.Helper()
	dialer, err := xproxy.SOCKS5("tcp", listen, nil, &net.Dialer{Timeout: 5 * time.Second})
	if err != nil {
		t.Fatal(err)
	}
	conn, err := dialer.Dial("tcp", lazyEchoTarget)
	if err != nil {
		return err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(10 * time.Second))
	if _, err := io.WriteString(conn, value); err != nil {
		return err
	}
	got := make([]byte, len(value))
	if _, err := io.ReadFull(conn, got); err != nil {
		return err
	}
	if string(got) != value {
		return fmt.Errorf("echo %q, want %q", got, value)
	}
	return nil
}

// Starting the proxy contacts nothing; the first client connection gets
// the server list and a pass, connects, and succeeds.
func TestEngineStartsAsleepAndConnectsOnFirstUse(t *testing.T) {
	d, f := runLazyDaemon(t)

	view, err := d.StatusView()
	if err != nil {
		t.Fatal(err)
	}
	if view.Proxy == nil || view.Proxy.SleepingSince.IsZero() || view.Pass != nil {
		t.Fatalf("a started proxy listens asleep, without a pass: %+v", view.Proxy)
	}
	time.Sleep(200 * time.Millisecond)
	if n, m, c := f.serverLists.Load(), f.passes.Load(), f.connects.Load(); n != 0 || m != 0 || c != 0 {
		t.Fatalf("contacted at start: server lists %d, passes %d, upstream CONNECTs %d", n, m, c)
	}
	// What the tray and the app mode read to apply system_proxy.mode
	// "set": a running phase and the listen address.
	tray := decodeBody[TrayStatus](t, newDashboardClient(t, d).do(http.MethodGet, "/api/status", nil))
	if tray.State.Phase != PhaseRunning || tray.Proxy == nil || tray.Proxy.Listen == "" || tray.Proxy.SleepingSince.IsZero() {
		t.Fatalf("an asleep proxy counts as running for the system proxy: %+v %+v", tray.State, tray.Proxy)
	}
	if data, err := os.ReadFile(d.paths.Status); err != nil || !strings.Contains(string(data), `"reason": "sleeping"`) {
		t.Fatalf("status.json at start: %s %v", data, err)
	}

	if err := lazyEcho(t, view.Proxy.Listen, "first connection"); err != nil {
		t.Fatalf("the first connection must wait for the wake and succeed: %v", err)
	}
	if n, m := f.serverLists.Load(), f.passes.Load(); n != 1 || m != 1 {
		t.Fatalf("first use: server lists %d, passes %d; want 1 and 1", n, m)
	}
	view, _ = d.StatusView()
	if !view.Proxy.SleepingSince.IsZero() || view.Pass == nil || view.Proxy.Upstream != f.upstream || view.Proxy.CountryCode != "NL" {
		t.Fatalf("connected: %+v", view.Proxy)
	}
	if got := d.ExitCountry(); got != "NL" {
		t.Fatalf("exit country %q; want the selected location's, NL", got)
	}
	// The automatic connection test follows the first connection.
	waitForCondition(t, 5*time.Second, func() bool {
		d.mu.Lock()
		defer d.mu.Unlock()
		return d.lastTest != nil
	})
	if err := lazyEcho(t, view.Proxy.Listen, "second connection"); err != nil {
		t.Fatal(err)
	}
	if m := f.passes.Load(); m != 1 {
		t.Fatalf("an awake proxy gets no new pass per connection: %d", m)
	}
}

// The connection test wakes a sleeping proxy.
func TestConnectionTestWakesProxy(t *testing.T) {
	d, f := runLazyDaemon(t)
	rec := newDashboardClient(t, d).do(http.MethodPost, "/api/test", nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("test: %d %s", rec.Code, rec.Body)
	}
	if m, c := f.passes.Load(), f.connects.Load(); m != 1 || c == 0 {
		t.Fatalf("the test must connect: passes %d, upstream CONNECTs %d", m, c)
	}
	if view, _ := d.StatusView(); view.Proxy == nil || !view.Proxy.SleepingSince.IsZero() {
		t.Fatal("awake after the test")
	}
}

// A failed wake is reported, and client connections do not retry it for a
// while; a requested test does.
func TestFailedWakeWaitsBeforeRetrying(t *testing.T) {
	d, f := runLazyDaemon(t)
	f.guardianRefuses.Store(true)
	view, _ := d.StatusView()
	if err := lazyEcho(t, view.Proxy.Listen, "x"); err == nil {
		t.Fatal("no pass: the connection fails")
	}
	asked := f.passes.Load()
	if asked == 0 {
		t.Fatal("the connection asked for a pass")
	}
	if err := lazyEcho(t, view.Proxy.Listen, "x"); err == nil || f.passes.Load() != asked {
		t.Fatalf("a connection right after a failed wake must not ask again: %v, passes %d -> %d", err, asked, f.passes.Load())
	}
	view, _ = d.StatusView()
	if view.State.Phase != PhaseRunning || view.Proxy.WakeError == "" || view.Proxy.WakeFailedAt.IsZero() || view.Proxy.SleepingSince.IsZero() {
		t.Fatalf("a failed wake is shown on the sleeping proxy: %+v %+v", view.State, view.Proxy)
	}

	if view.Proxy.WakeErrorCode != proxy.FailureRegion {
		t.Fatalf("wake error code %q, want %q", view.Proxy.WakeErrorCode, proxy.FailureRegion)
	}

	// A refused region is lasting: a requested test waits too.
	f.guardianRefuses.Store(false)
	if rec := newDashboardClient(t, d).do(http.MethodPost, "/api/test", nil); rec.Code != http.StatusConflict || f.passes.Load() != asked {
		t.Fatalf("a test right after a lasting failure must not ask again: %d %s, passes %d -> %d", rec.Code, rec.Body, asked, f.passes.Load())
	}
	// A network that comes back ends the wait.
	d.NetworkChanged(true)
	if rec := newDashboardClient(t, d).do(http.MethodPost, "/api/test", nil); rec.Code != http.StatusOK || f.passes.Load() == asked {
		t.Fatalf("after the network came back the test tries again: %d %s", rec.Code, rec.Body)
	}
	if view, _ = d.StatusView(); view.Proxy.WakeError != "" || !view.Proxy.SleepingSince.IsZero() {
		t.Fatalf("a successful wake clears the failure: %+v", view.Proxy)
	}
}

// After a failure not known to last, connections wait but a requested
// test tries again at once.
func TestTransientWakeFailureLetsTestsRetry(t *testing.T) {
	d, f := runLazyDaemon(t)
	f.guardianFails.Store(true)
	view, _ := d.StatusView()
	if err := lazyEcho(t, view.Proxy.Listen, "x"); err == nil {
		t.Fatal("no pass: the connection fails")
	}
	asked := f.passes.Load()
	if err := lazyEcho(t, view.Proxy.Listen, "x"); err == nil || f.passes.Load() != asked {
		t.Fatalf("a connection right after a failed wake must not ask again: %v, passes %d -> %d", err, asked, f.passes.Load())
	}
	f.guardianFails.Store(false)
	if rec := newDashboardClient(t, d).do(http.MethodPost, "/api/test", nil); rec.Code != http.StatusOK || f.passes.Load() == asked {
		t.Fatalf("a requested test tries again at once: %d %s", rec.Code, rec.Body)
	}
}

// Turning the proxy off closes its port without contacting anything, and
// keeps the API; turning it on listens again.
func TestProxyOffClosesThePortAndOnReopensIt(t *testing.T) {
	d, f := runLazyDaemon(t)
	view, err := d.StatusView()
	if err != nil {
		t.Fatal(err)
	}
	listen := view.Proxy.Listen

	d.SetOn(false)
	waitMessage(t, d, PhaseOff, "Proxy off")
	if got := d.ExitCountry(); got != "" {
		t.Fatalf("exit country %q while off", got)
	}
	if conn, err := net.DialTimeout("tcp", listen, time.Second); err == nil {
		conn.Close()
		t.Fatal("the proxy's port is still open while off")
	}
	tray := decodeBody[TrayStatus](t, newDashboardClient(t, d).do(http.MethodGet, "/api/status", nil))
	if tray.State.Phase != PhaseOff {
		t.Fatalf("the API reports %q while off", tray.State.Phase)
	}

	d.SetOn(true)
	waitMessage(t, d, PhaseRunning, "Proxy running")
	// The test proxy listens on a new free port at each start.
	if view, err = d.StatusView(); err != nil || view.Proxy == nil {
		t.Fatalf("on again: %+v %v", view.Proxy, err)
	}
	if err := lazyEcho(t, view.Proxy.Listen, "on again"); err != nil {
		t.Fatal(err)
	}
	if m := f.passes.Load(); m != 1 {
		t.Fatalf("passes %d; want 1, for the connection after turning on", m)
	}
}

// With the proxy off, a latency measurement gets a pass of its own and
// keeps it for the next one.
func TestPingWhileOffUsesAPassOfItsOwn(t *testing.T) {
	d, f := runLazyDaemon(t)
	d.SetOn(false)
	waitMessage(t, d, PhaseOff, "Proxy off")
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if _, _, err := d.PingAll(ctx, nil); err != nil {
		t.Fatalf("ping while off: %v", err)
	}
	if _, _, err := d.PingAll(ctx, nil); err != nil {
		t.Fatalf("second ping while off: %v", err)
	}
	if m := f.passes.Load(); m != 1 {
		t.Fatalf("passes %d; want 1, kept for the second measurement", m)
	}
	if d.currentEngine() != nil {
		t.Fatal("measuring must not turn the proxy on")
	}
}

// The desktop app turns the proxy off and on through the API.
func TestPowerEndpoint(t *testing.T) {
	d, _ := runLazyDaemon(t)
	client := newDashboardClient(t, d)
	if rec := client.do(http.MethodPost, "/api/power", map[string]bool{"on": false}); rec.Code != http.StatusOK {
		t.Fatalf("off: %d %s", rec.Code, rec.Body)
	}
	waitMessage(t, d, PhaseOff, "Proxy off")
	if rec := client.do(http.MethodPost, "/api/power", map[string]bool{"on": true}); rec.Code != http.StatusOK {
		t.Fatalf("on: %d %s", rec.Code, rec.Body)
	}
	waitMessage(t, d, PhaseRunning, "Proxy running")
}

// HTTP/3 that does not connect (here: the fixture serves TCP only) falls
// back to HTTP/2 for the engine, and the status says so.
func TestHTTP3FallsBackToHTTP2(t *testing.T) {
	d := newTestDaemon(t)
	f := newLazyFixture(t)
	addTestAccount(t, d, "user")
	select {
	case <-d.restart:
	default:
	}
	noExitCheck(t)
	d.mu.Lock()
	d.cfg.Dashboard.Listen = "127.0.0.1:0"
	d.cfg.Proxy.Transport = "h3"
	d.mu.Unlock()
	oldConnect := connectTimeout
	connectTimeout = 2 * time.Second
	t.Cleanup(func() { connectTimeout = oldConnect })
	if controlplane.Transport() != f.controlPlane {
		t.Fatal("the fixture control plane is not installed")
	}
	done := make(chan error, 1)
	go func() { done <- d.Run() }()
	t.Cleanup(func() {
		d.Shutdown()
		<-done
	})
	waitMessage(t, d, PhaseRunning, "Proxy running")
	view, _ := d.StatusView()
	if err := lazyEcho(t, view.Proxy.Listen, "over h2"); err != nil {
		t.Fatalf("the fallback must connect: %v", err)
	}
	if view, _ = d.StatusView(); view.Proxy.Transport != "h2" {
		t.Fatalf("transport %q after the fallback", view.Proxy.Transport)
	}
}

// noExitCheck skips the public IP check, which would ask real services.
func noExitCheck(t *testing.T) {
	old := exitCheckTimeout
	exitCheckTimeout = 0
	t.Cleanup(func() { exitCheckTimeout = old })
}

// A wake that keeps failing on the persisted server moves to another
// server of the location after three failures, and saves it.
func TestWakeMovesToAnotherServerOfTheLocation(t *testing.T) {
	d, f := runLazyDaemon(t)
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	dead := ln.Addr().String()
	_ = ln.Close()
	f.deadServer.Store(&dead)
	if err := proxy.SaveSelection(d.paths.Selection, proxy.Candidate{Addr: dead, CountryCode: "NL", CountryName: "Netherlands", CityCode: "ams", CityName: "Amsterdam"}); err != nil {
		t.Fatal(err)
	}
	client := newDashboardClient(t, d)
	for i := 1; i <= 3; i++ {
		if rec := client.do(http.MethodPost, "/api/test", nil); rec.Code == http.StatusOK {
			t.Fatalf("test %d connected through a dead server: %s", i, rec.Body)
		}
		persisted, ok := proxy.PersistedSelection(d.paths.Selection, "")
		if want := map[bool]string{false: dead, true: f.upstream}[i == 3]; !ok || persisted.Addr != want {
			t.Fatalf("after failure %d persisted %q, want %q", i, persisted.Addr, want)
		}
	}
	if !d.failover.Avoided(dead) {
		t.Fatal("the dead server must be avoided")
	}
	// Client connections try the other server at once, without the wait
	// that failed wakes leave.
	view, _ := d.StatusView()
	if err := lazyEcho(t, view.Proxy.Listen, "next server"); err != nil {
		t.Fatalf("the next wake uses the other server: %v", err)
	}
	if view, _ = d.StatusView(); view.Proxy == nil || view.Proxy.Upstream != f.upstream || view.Proxy.CountryCode != "NL" {
		t.Fatalf("connected: %+v", view.Proxy)
	}
}
