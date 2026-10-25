package service

import (
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/version"
)

func TestLocalTokenBypassesHostCheckAndLogin(t *testing.T) {
	d := newTestDaemon(t)
	d.localToken = "local-token-for-test"
	d.mu.Lock()
	d.cfg.Dashboard.Username = "admin"
	d.cfg.Dashboard.PasswordHash = "unused"
	d.mu.Unlock()
	handler := newDashboardServer(d).handler()

	send := func(token, host string) int {
		req := httptest.NewRequest(http.MethodGet, "/api/status", nil)
		req.Host = host
		if token != "" {
			req.Header.Set(localTokenHeader, token)
		}
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		return rec.Code
	}
	if code := send("", "127.0.0.1:10820"); code != http.StatusUnauthorized {
		t.Fatalf("without token: got %d, want 401", code)
	}
	if code := send("wrong", "127.0.0.1:10820"); code != http.StatusUnauthorized {
		t.Fatalf("wrong token: got %d, want 401", code)
	}
	if code := send(d.localToken, "rebind.example:10820"); code != http.StatusOK {
		t.Fatalf("local token: got %d, want 200", code)
	}

	// Without a login, a wrong token must not lift the Host check.
	d.mu.Lock()
	d.cfg.Dashboard.Username = ""
	d.mu.Unlock()
	if code := send("wrong", "rebind.example:10820"); code != http.StatusForbidden {
		t.Fatalf("wrong token with a host name: got %d, want 403", code)
	}
}

func TestDaemonShutdownStopsDashboardAndPublishesToken(t *testing.T) {
	d := newTestDaemon(t)
	d.mu.Lock()
	d.cfg.Dashboard.Listen = "127.0.0.1:0"
	d.mu.Unlock()
	done := make(chan error, 1)
	go func() { done <- d.Run() }()

	deadline := time.Now().Add(5 * time.Second)
	var token string
	for time.Now().Before(deadline) {
		if data, err := os.ReadFile(d.paths.LocalToken); err == nil {
			token = string(data)
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if len(token) != 64 || token != d.localToken {
		t.Fatalf("published token %q does not match the daemon's", token)
	}
	addr := d.dashboard.listener.Addr().String()

	d.Shutdown()
	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("run returned %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("run did not return after Shutdown")
	}
	if _, err := http.Get("http://" + addr + "/api/status"); err == nil {
		t.Fatal("dashboard still answers after Shutdown")
	}
	d.Shutdown() // a second call must not block or panic
}

// The desktop app's core process (-app) needs the dashboard API: with the
// dashboard disabled it refuses to start instead of running unreachable.
func TestRequireDashboardRefusesDisabledDashboard(t *testing.T) {
	d := newTestDaemon(t)
	d.RequireDashboard = true
	d.mu.Lock()
	d.cfg.Dashboard.Enabled = false
	d.mu.Unlock()
	done := make(chan error, 1)
	go func() { done <- d.Run() }()
	select {
	case err := <-done:
		if err == nil || !strings.Contains(err.Error(), "dashboard.enabled=false") {
			t.Fatalf("run returned %v", err)
		}
	case <-time.After(5 * time.Second):
		d.Shutdown()
		t.Fatal("run must fail at once")
	}
	d.Shutdown() // returns at once after a failed Run
}

func TestAppExitNeedsLocalTokenAndHost(t *testing.T) {
	d := newTestDaemon(t)
	d.localToken = "exit-token"
	handler := newDashboardServer(d).handler()
	send := func(token string) int {
		req := httptest.NewRequest(http.MethodPost, "/api/app/exit", strings.NewReader("{}"))
		req.Host = "127.0.0.1:10820"
		req.Header.Set("Content-Type", "application/json")
		if token != "" {
			req.Header.Set(localTokenHeader, token)
		}
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		return rec.Code
	}
	if code := send(""); code != http.StatusForbidden {
		t.Fatalf("browser request: got %d, want 403", code)
	}
	if code := send(d.localToken); code != http.StatusConflict {
		t.Fatalf("service without an exit hook: got %d, want 409", code)
	}
	exited := make(chan struct{})
	d.ExitApp = func() { close(exited) }
	if code := send(d.localToken); code != http.StatusOK {
		t.Fatalf("with the exit hook: got %d, want 200", code)
	}
	select {
	case <-exited:
	case <-time.After(2 * time.Second):
		t.Fatal("exit hook not called")
	}
	if view, _ := d.StatusView(); !view.CanExit || view.Version != version.Current {
		t.Fatalf("status view: can_exit=%v version=%q", view.CanExit, view.Version)
	}
}

// Only the program on this computer can reset the dashboard login; the new
// random login works and ends the old sessions.
func TestResetDashboardLogin(t *testing.T) {
	d := newTestDaemon(t)
	d.localToken = "reset-token"
	cfg := d.config()
	cfg.Dashboard.Username = "admin"
	forgotten := "forgotten password"
	if _, err := d.updateSettings(cfg, &forgotten); err != nil {
		t.Fatal(err)
	}
	c := newDashboardClient(t, d)
	reset := func(token string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodPost, "/api/dashboard/reset-login", strings.NewReader("{}"))
		req.Host = "127.0.0.1:10820"
		req.Header.Set("Content-Type", "application/json")
		if token != "" {
			req.Header.Set(localTokenHeader, token)
		}
		rec := httptest.NewRecorder()
		c.handler.ServeHTTP(rec, req)
		return rec
	}
	if rec := reset(""); rec.Code == http.StatusOK {
		t.Fatal("a browser must not reset the login")
	}
	rec := reset(d.localToken)
	if rec.Code != http.StatusOK {
		t.Fatalf("reset: %d %s", rec.Code, rec.Body.String())
	}
	login := decodeBody[map[string]string](t, rec)
	if !strings.HasPrefix(login["username"], "admin-") || len(login["password"]) != 16 {
		t.Fatalf("new login %+v", login)
	}
	if rec := c.do(http.MethodPost, "/api/session", map[string]string{"username": login["username"], "password": login["password"]}); rec.Code != http.StatusOK {
		t.Fatalf("the new login must work: %d", rec.Code)
	}
	if rec := c.do(http.MethodPost, "/api/session", map[string]string{"username": "admin", "password": forgotten}); rec.Code != http.StatusUnauthorized {
		t.Fatalf("the old login must not: %d", rec.Code)
	}
}

// Open folder works only from a browser on this computer: directly when
// the program hosts the service, otherwise through the tray (the status).
func TestOpenFolder(t *testing.T) {
	d := newTestDaemon(t)
	handler := newDashboardServer(d).handler()
	open := func(remote string) int {
		req := httptest.NewRequest(http.MethodPost, "/api/open-folder", strings.NewReader("{}"))
		req.Host = "127.0.0.1:10820"
		req.RemoteAddr = remote
		req.Header.Set("Content-Type", "application/json")
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		return rec.Code
	}
	if code := open("192.0.2.7:4000"); code != http.StatusForbidden {
		t.Fatalf("from another device: %d", code)
	}
	if code := open("127.0.0.1:4000"); code != http.StatusOK {
		t.Fatalf("service without a desktop: %d", code)
	}
	if view, _ := d.StatusView(); view.OpenFolderRequest != 1 {
		t.Fatalf("the tray must be asked: %d", view.OpenFolderRequest)
	}
	var opened string
	d.OpenFolder = func(dir string) error { opened = dir; return nil }
	if code := open("[::1]:4000"); code != http.StatusOK || opened != d.paths.Dir {
		t.Fatalf("in-process host: %d %q", code, opened)
	}
}
