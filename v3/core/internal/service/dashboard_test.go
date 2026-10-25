package service

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/fxa"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
)

// All credentials in this file are local fixtures; the control plane
// transport rejects every request it does not recognise.

func newTestDaemon(t *testing.T) *Daemon {
	t.Helper()
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("USERPROFILE", home)
	paths, err := ResolveDataPaths(filepath.Join(t.TempDir(), "data"))
	if err != nil {
		t.Fatal(err)
	}
	d, err := NewDaemon(paths, false)
	if err != nil {
		t.Fatal(err)
	}
	// Every engine start checks the proxy address first; a copy of the
	// program running on the default port must not change a test.
	d.cfg.Proxy.Listen = "127.0.0.1:0"
	return d
}

func addTestAccount(t *testing.T, d *Daemon, name string) string {
	t.Helper()
	acc, _, err := d.store.Add(name+"@example.com", &fxa.SavedTokens{AccessToken: "access-" + name, RefreshToken: "refresh-" + name, ObtainedAt: time.Now(), ExpiresIn: 3600}, time.Now())
	if err != nil {
		t.Fatal(err)
	}
	if err := d.accountsChanged(); err != nil {
		t.Fatal(err)
	}
	return acc.ID
}

type dashboardClient struct {
	t       *testing.T
	handler http.Handler
	host    string
	cookie  *http.Cookie
}

func newDashboardClient(t *testing.T, d *Daemon) *dashboardClient {
	return &dashboardClient{t: t, handler: newDashboardServer(d).handler(), host: "127.0.0.1:10820"}
}

func (c *dashboardClient) do(method, path string, body any) *httptest.ResponseRecorder {
	c.t.Helper()
	var reader io.Reader
	if body != nil {
		data, _ := json.Marshal(body)
		reader = bytes.NewReader(data)
	}
	req := httptest.NewRequest(method, path, reader)
	req.Host = c.host
	if method != http.MethodGet {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.cookie != nil {
		req.AddCookie(c.cookie)
	}
	rec := httptest.NewRecorder()
	c.handler.ServeHTTP(rec, req)
	return rec
}

func decodeBody[T any](t *testing.T, rec *httptest.ResponseRecorder) T {
	t.Helper()
	var v T
	if err := json.Unmarshal(rec.Body.Bytes(), &v); err != nil {
		t.Fatalf("decoding %q: %v", rec.Body.String(), err)
	}
	return v
}

func TestDashboardRejectsDNSRebindingAndCrossSiteRequests(t *testing.T) {
	d := newTestDaemon(t)
	c := newDashboardClient(t, d)

	c.host = "attacker.example:10820"
	if rec := c.do(http.MethodGet, "/api/status", nil); rec.Code != http.StatusForbidden {
		t.Fatalf("expected a DNS-name host to be refused without a login, got %d", rec.Code)
	}
	c.host = "localhost:10820"
	if rec := c.do(http.MethodGet, "/api/status", nil); rec.Code != http.StatusOK {
		t.Fatalf("expected localhost to be served, got %d %s", rec.Code, rec.Body)
	}

	req := httptest.NewRequest(http.MethodPost, "/api/proxy/restart", strings.NewReader("x=1"))
	req.Host = "127.0.0.1:10820"
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	rec := httptest.NewRecorder()
	c.handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusUnsupportedMediaType {
		t.Fatalf("expected a form post to be refused, got %d", rec.Code)
	}

	req = httptest.NewRequest(http.MethodPost, "/api/proxy/restart", strings.NewReader("{}"))
	req.Host = "127.0.0.1:10820"
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Origin", "http://attacker.example")
	rec = httptest.NewRecorder()
	c.handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusForbidden {
		t.Fatalf("expected a cross-origin request to be refused, got %d", rec.Code)
	}
}

func TestDashboardLoginProtectsAPI(t *testing.T) {
	d := newTestDaemon(t)
	cfg := d.config()
	cfg.Dashboard.Username = "admin"
	password := "correct horse"
	if _, err := d.updateSettings(cfg, &password); err != nil {
		t.Fatal(err)
	}
	c := newDashboardClient(t, d)
	c.host = "vpn.lan:10820" // names are allowed once a login is required

	if rec := c.do(http.MethodGet, "/api/status", nil); rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected a login to be required, got %d", rec.Code)
	}
	if rec := c.do(http.MethodGet, "/app/", nil); rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "Firefox VPN") {
		t.Fatalf("expected the page itself to load without a login, got %d", rec.Code)
	}
	if rec := c.do(http.MethodGet, "/app", nil); rec.Code/100 != 3 || rec.Header().Get("Location") != "/app/" {
		t.Fatalf("expected /app to redirect to /app/, got %d %q", rec.Code, rec.Header().Get("Location"))
	}
	if rec := c.do(http.MethodGet, "/", nil); rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "Up and running") || strings.Contains(rec.Body.String(), "Firefox") {
		t.Fatalf("expected the site root's running page, without the program's name, got %d", rec.Code)
	}
	for _, path := range []string{"/app/app.js", "/app/flags/de.svg", "/flags/de.svg"} {
		if rec := c.do(http.MethodGet, path, nil); rec.Code != http.StatusOK {
			t.Fatalf("expected %s to load, got %d", path, rec.Code)
		}
	}
	if rec := c.do(http.MethodPost, "/api/session", map[string]string{"username": "admin", "password": "wrong"}); rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected a wrong password to fail, got %d", rec.Code)
	}
	rec := c.do(http.MethodPost, "/api/session", map[string]string{"username": "admin", "password": password})
	if rec.Code != http.StatusOK {
		t.Fatalf("expected the login to succeed, got %d %s", rec.Code, rec.Body)
	}
	for _, cookie := range rec.Result().Cookies() {
		if cookie.Name == sessionCookieName {
			c.cookie = cookie
			if !cookie.HttpOnly || cookie.SameSite != http.SameSiteStrictMode {
				t.Fatal("the session cookie must be HttpOnly and SameSite=Strict")
			}
		}
	}
	if rec := c.do(http.MethodGet, "/api/status", nil); rec.Code != http.StatusOK {
		t.Fatalf("expected the session to authorize the API, got %d", rec.Code)
	}
	settings := decodeBody[settingsView](t, c.do(http.MethodGet, "/api/settings", nil))
	if settings.Config.Dashboard.PasswordHash != "" || !settings.LoginRequired {
		t.Fatal("the settings API must not reveal the password hash")
	}
}

func TestDashboardSettingsValidateAndApply(t *testing.T) {
	d := newTestDaemon(t)
	c := newDashboardClient(t, d)

	settings := decodeBody[settingsView](t, c.do(http.MethodGet, "/api/settings", nil))
	bad := settings.Config
	bad.Proxy.Country, bad.Proxy.Server = "US", "us.example:443"
	if rec := c.do(http.MethodPut, "/api/settings", map[string]any{"config": bad}); rec.Code != http.StatusBadRequest {
		t.Fatalf("expected country+server to be rejected, got %d", rec.Code)
	}
	noPassword := settings.Config
	noPassword.Dashboard.Username = "admin"
	if rec := c.do(http.MethodPut, "/api/settings", map[string]any{"config": noPassword}); rec.Code != http.StatusBadRequest {
		t.Fatalf("expected a username without password to be rejected, got %d", rec.Code)
	}

	good := settings.Config
	good.Accounts.SwitchThresholdPercent = 80
	good.Logging.Verbose = true
	rec := c.do(http.MethodPut, "/api/settings", map[string]any{"config": good})
	if rec.Code != http.StatusOK {
		t.Fatalf("expected the settings to save, got %d %s", rec.Code, rec.Body)
	}
	t.Cleanup(func() { logx.Verbose.Store(false) })
	if d.mgr.Policy().ThresholdPercent != 80 || !logx.Verbose.Load() {
		t.Fatal("expected the threshold and log level to apply immediately")
	}
	saved, _, err := config.Load(d.paths.Config)
	if err != nil || saved.Accounts.SwitchThresholdPercent != 80 {
		t.Fatalf("expected the threshold to be saved, got %v %v", saved.Accounts, err)
	}
}

func TestDashboardManagesAccounts(t *testing.T) {
	d := newTestDaemon(t)
	a := addTestAccount(t, d, "a")
	b := addTestAccount(t, d, "b")
	c := newDashboardClient(t, d)

	type accountsBody struct {
		Accounts []AccountView `json:"accounts"`
	}
	list := decodeBody[accountsBody](t, c.do(http.MethodGet, "/api/accounts", nil)).Accounts
	if len(list) != 2 || list[0].ID != a || list[1].ID != b {
		t.Fatalf("unexpected account list %+v", list)
	}

	if rec := c.do(http.MethodPost, "/api/accounts/order", map[string][]string{"ids": {b, a}}); rec.Code != http.StatusOK {
		t.Fatalf("reorder failed: %d %s", rec.Code, rec.Body)
	}
	if rec := c.do(http.MethodPost, "/api/accounts/order", map[string][]string{"ids": {b}}); rec.Code != http.StatusBadRequest {
		t.Fatalf("an incomplete order must be rejected, got %d", rec.Code)
	}
	if rec := c.do(http.MethodPost, "/api/accounts/"+a+"/enabled", map[string]bool{"enabled": false}); rec.Code != http.StatusOK {
		t.Fatalf("disable failed: %d %s", rec.Code, rec.Body)
	}
	list = decodeBody[accountsBody](t, c.do(http.MethodGet, "/api/accounts", nil)).Accounts
	if list[0].ID != b || list[1].ID != a || list[1].Enabled || d.mgr.Len() != 1 {
		t.Fatalf("expected b first and a disabled, got %+v (managed %d)", list, d.mgr.Len())
	}
	if rec := c.do(http.MethodPost, "/api/accounts/"+a+"/activate", nil); rec.Code != http.StatusBadRequest {
		t.Fatalf("a disabled account must not be activated, got %d", rec.Code)
	}

	if rec := c.do(http.MethodDelete, "/api/accounts/"+a, nil); rec.Code != http.StatusOK {
		t.Fatalf("remove failed: %d %s", rec.Code, rec.Body)
	}
	if _, err := d.store.Get(a); err == nil {
		t.Fatal("expected the account files to be removed")
	}
	saved, _, _ := config.Load(d.paths.Config)
	if len(saved.Accounts.Order) != 1 || saved.Accounts.Order[0].ID != b {
		t.Fatalf("expected only b in the saved order, got %+v", saved.Accounts.Order)
	}
}

// An email without a Firefox Account fails with a code the app explains.
func TestDashboardSignInWithoutAnAccount(t *testing.T) {
	d := newTestDaemon(t)
	setCoreControlPlane(t, func(r *http.Request) (*http.Response, error) {
		if r.URL.Path == "/v1/account/login" {
			return coreResponse(r, http.StatusBadRequest, `{"errno":102,"message":"Unknown account"}`, nil), nil
		}
		return nil, fmt.Errorf("unexpected request %s %s", r.Method, r.URL)
	})
	c := newDashboardClient(t, d)
	rec := c.do(http.MethodPost, "/api/signin", map[string]string{"email": "nobody@example.com", "password": "pw"})
	if rec.Code != http.StatusAccepted {
		t.Fatalf("sign-in start failed: %d %s", rec.Code, rec.Body)
	}
	id := decodeBody[signInView](t, rec).ID
	var view signInView
	waitForCondition(t, 5*time.Second, func() bool {
		view = decodeBody[signInView](t, c.do(http.MethodGet, "/api/signin/"+id, nil))
		return view.Step == stepFailed
	})
	if view.ErrorCode != signInNoAccount || !strings.Contains(view.Error, "No Firefox Account") || view.PasswordAccepted {
		t.Fatalf("want the no-account code and text, got %+v", view)
	}
}

// An account made with Google or Apple sign-in has no password; FxA says
// so with errno 210, which gets its own code.
func TestDashboardSignInWithoutAPassword(t *testing.T) {
	d := newTestDaemon(t)
	setCoreControlPlane(t, func(r *http.Request) (*http.Response, error) {
		if r.URL.Path == "/v1/account/login" {
			return coreResponse(r, http.StatusBadRequest, `{"errno":210,"message":"Complete account setup, please reset password to continue."}`, nil), nil
		}
		return nil, fmt.Errorf("unexpected request %s %s", r.Method, r.URL)
	})
	c := newDashboardClient(t, d)
	rec := c.do(http.MethodPost, "/api/signin", map[string]string{"email": "google@example.com", "password": "pw"})
	if rec.Code != http.StatusAccepted {
		t.Fatalf("sign-in start failed: %d %s", rec.Code, rec.Body)
	}
	id := decodeBody[signInView](t, rec).ID
	var view signInView
	waitForCondition(t, 5*time.Second, func() bool {
		view = decodeBody[signInView](t, c.do(http.MethodGet, "/api/signin/"+id, nil))
		return view.Step == stepFailed
	})
	if view.ErrorCode != signInNoPassword || !strings.Contains(view.Error, "no password") {
		t.Fatalf("want the no-password code and text, got %+v", view)
	}
}

func TestDashboardSignInWithEmailCode(t *testing.T) {
	d := newTestDaemon(t)
	session := strings.Repeat("ab", 32)
	setCoreControlPlane(t, func(r *http.Request) (*http.Response, error) {
		switch {
		case r.URL.Path == "/v1/account/login":
			return coreResponse(r, http.StatusOK, `{"sessionToken":"`+session+`","uid":"u","verified":false,"verificationMethod":"email-2fa"}`, nil), nil
		case r.URL.Path == "/v1/session/verify_code":
			body, _ := io.ReadAll(r.Body)
			if !strings.Contains(string(body), `"123456"`) {
				return coreResponse(r, http.StatusBadRequest, `{"errno":183,"message":"Invalid code"}`, nil), nil
			}
			return coreResponse(r, http.StatusOK, `{}`, nil), nil
		case r.URL.Path == "/v1/oauth/token":
			return coreResponse(r, http.StatusOK, `{"access_token":"access-new","refresh_token":"refresh-new","expires_in":3600,"scope":"profile"}`, nil), nil
		case r.Method == http.MethodHead && strings.HasSuffix(r.URL.Path, "/api/v1/fpn/token"):
			return coreResponse(r, http.StatusOK, "", quotaHeader(2)), nil
		}
		return nil, fmt.Errorf("unexpected request %s %s", r.Method, r.URL)
	})
	c := newDashboardClient(t, d)

	rec := c.do(http.MethodPost, "/api/signin", map[string]string{"email": "new@example.com", "password": "pw"})
	if rec.Code != http.StatusAccepted {
		t.Fatalf("sign-in start failed: %d %s", rec.Code, rec.Body)
	}
	id := decodeBody[signInView](t, rec).ID
	waitStep := func(step, messagePart string) signInView {
		t.Helper()
		var view signInView
		waitForCondition(t, 5*time.Second, func() bool {
			view = decodeBody[signInView](t, c.do(http.MethodGet, "/api/signin/"+id, nil))
			return view.Step == step && strings.Contains(view.Message+" "+view.Error, messagePart)
		})
		return view
	}

	if asked := waitStep(stepEmailCode, "verification code"); !asked.PasswordAccepted {
		t.Fatalf("Mozilla accepted the password before asking for the code: %+v", asked)
	}
	c.do(http.MethodPost, "/api/signin/"+id, map[string]string{"value": "000000"})
	if wrong := waitStep(stepEmailCode, "Wrong or expired code"); !strings.Contains(wrong.Message, "verification code") || wrong.ErrorCode != signInWrongCode {
		t.Fatalf("the instruction stays apart from the error, which has its code: %+v", wrong)
	}
	c.do(http.MethodPost, "/api/signin/"+id, map[string]string{"value": "123456"})
	view := waitStep(stepDone, "")

	acc, err := d.store.Get(view.AccountID)
	if err != nil || acc.Email != "new@example.com" || acc.Usage == nil {
		t.Fatalf("expected the stored account with usage, got %+v %v", acc, err)
	}
	if strings.Contains(c.do(http.MethodGet, "/api/signin/"+id, nil).Body.String(), "access-new") {
		t.Fatal("the sign-in view must never contain tokens")
	}
}

func TestDashboardLogsEndpoint(t *testing.T) {
	d := newTestDaemon(t)
	c := newDashboardClient(t, d)
	logx.Info("dashboard log endpoint marker")
	type logsBody struct {
		Entries []logx.Entry `json:"entries"`
	}
	entries := decodeBody[logsBody](t, c.do(http.MethodGet, "/api/logs", nil)).Entries
	if len(entries) == 0 || !strings.Contains(entries[len(entries)-1].Message, "marker") {
		t.Fatalf("expected the logged line, got %+v", entries)
	}
	last := entries[len(entries)-1].ID
	if newer := decodeBody[logsBody](t, c.do(http.MethodGet, fmt.Sprintf("/api/logs?after=%d", last), nil)).Entries; len(newer) != 0 {
		t.Fatalf("expected no entries after the last id, got %d", len(newer))
	}
}

// tunnelToServer opens every tunnel to one local server, standing in for
// the upstream CONNECT proxy.
type tunnelToServer struct{ addr string }

func (o tunnelToServer) OpenTunnel(string) (net.Conn, error) { return net.Dial("tcp", o.addr) }

func TestConnectionTestMeasuresTunnelRequest(t *testing.T) {
	t.Parallel()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	result := proxy.RunConnectionTest(tunnelToServer{addr: server.Listener.Addr().String()}, "http://test.invalid/generate_204", 0, 5*time.Second)
	if !result.OK || result.HTTPStatus != http.StatusNoContent || result.TotalMS < 0 {
		t.Fatalf("expected a passing test, got %+v", result)
	}
	// The stages follow each other, so together they fit in the total.
	if result.TunnelMS+result.TLSMS+result.ResponseMS > result.TotalMS+1 || result.ResponseMS > result.FirstByteMS {
		t.Fatalf("stages do not add up: %+v", result)
	}

	failed := proxy.RunConnectionTest(tunnelToServer{addr: "127.0.0.1:1"}, "http://test.invalid/", 0, 2*time.Second)
	if failed.OK || failed.Error == "" || failed.ErrorCode != proxy.FailureUnreachable {
		t.Fatalf("expected a failing test (unreachable), got %+v", failed)
	}

	// Once the tunnel is open, a failure is the test site's.
	broken := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer broken.Close()
	site := proxy.RunConnectionTest(tunnelToServer{addr: broken.Listener.Addr().String()}, "http://test.invalid/", 0, 5*time.Second)
	if site.OK || site.ErrorCode != proxy.FailureTestSite {
		t.Fatalf("expected the test site's failure, got %+v", site)
	}
}

// A session lasts as long as a browser keeps a cookie, survives a restart
// of the dashboard, and ends with a new password, a sign-out, or tampering.
func TestDashboardSessionsLastAndEnd(t *testing.T) {
	d := newTestDaemon(t)
	cfg := d.config()
	cfg.Dashboard.Username = "admin"
	password := "correct horse"
	if _, err := d.updateSettings(cfg, &password); err != nil {
		t.Fatal(err)
	}
	login := func(c *dashboardClient) {
		t.Helper()
		rec := c.do(http.MethodPost, "/api/session", map[string]string{"username": "admin", "password": password})
		for _, cookie := range rec.Result().Cookies() {
			if cookie.Name == sessionCookieName {
				c.cookie = cookie
			}
		}
		if c.cookie == nil || c.cookie.MaxAge < 399*24*3600 {
			t.Fatalf("expected a 400-day session cookie, got %+v", c.cookie)
		}
	}
	status := func(c *dashboardClient) int { return c.do(http.MethodGet, "/api/status", nil).Code }

	c := newDashboardClient(t, d)
	login(c)
	// A new dashboard server (a restart) accepts the same cookie.
	restarted := newDashboardClient(t, d)
	restarted.cookie = c.cookie
	if status(restarted) != http.StatusOK {
		t.Fatal("the session must survive a restart")
	}
	tampered := *c.cookie
	tampered.Value = strings.Replace(tampered.Value, ".", "9.", 1)
	restarted.cookie = &tampered
	if status(restarted) != http.StatusUnauthorized {
		t.Fatal("a changed cookie must be refused")
	}

	// Signing out ends that session.
	if rec := c.do(http.MethodDelete, "/api/session", nil); rec.Code != http.StatusOK {
		t.Fatal(rec.Code)
	}
	if status(c) != http.StatusUnauthorized {
		t.Fatal("a signed-out session must be refused")
	}

	// A new password signs everyone out.
	login(c)
	password = "battery staple"
	if _, err := d.updateSettings(d.config(), &password); err != nil {
		t.Fatal(err)
	}
	if status(c) != http.StatusUnauthorized {
		t.Fatal("a new password must end old sessions")
	}
}

// The exit mismatch is reported only for a country the user chose, and
// only when the public IP's country is known and another one.
func TestExitMismatchOnlyForAChosenCountry(t *testing.T) {
	gb := proxy.Candidate{CountryCode: "GB", CountryName: "United Kingdom"}
	rec := proxy.Candidate{CountryCode: "REC", CountryName: "Recommended"}
	inDE := &exitView{CountryCode: "de", CountryName: "Germany"}
	cases := []struct {
		name     string
		cfg      config.Proxy
		selected proxy.Candidate
		exit     *exitView
		want     bool
	}{
		{"chosen country, other exit", config.Proxy{Country: "GB"}, gb, inDE, true},
		{"chosen by name", config.Proxy{Country: "United Kingdom"}, gb, inDE, true},
		{"chosen country, same exit", config.Proxy{Country: "GB"}, gb, &exitView{CountryCode: "GB"}, false},
		{"exit country unknown", config.Proxy{Country: "GB"}, gb, &exitView{IPv4: "203.0.113.1"}, false},
		{"no exit probe yet", config.Proxy{Country: "GB"}, gb, nil, false},
		{"recommended", config.Proxy{}, rec, inDE, false},
		{"fastest", config.Proxy{Country: proxy.FastestCountry}, gb, inDE, false},
		{"server set by hand", config.Proxy{Server: "gb.example:443"}, gb, inDE, false},
	}
	for _, tc := range cases {
		got := exitMismatch(tc.cfg, tc.selected, tc.exit)
		if (got != nil) != tc.want {
			t.Fatalf("%s: got %+v, want mismatch=%v", tc.name, got, tc.want)
		}
		if got != nil && (got.ChosenCountryCode != "GB" || got.ExitCountryCode != "DE" || got.ChosenCountryName != "United Kingdom" || got.ExitCountryName != "Germany") {
			t.Fatalf("%s: got %+v", tc.name, got)
		}
	}
	data, _ := json.Marshal(exitMismatch(config.Proxy{Country: "GB"}, gb, inDE))
	if string(data) != `{"chosen_country_code":"GB","chosen_country_name":"United Kingdom","exit_country_code":"DE","exit_country_name":"Germany"}` {
		t.Fatalf("JSON %s", data)
	}
}
