package service

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// A sign-in link from the app signs a browser in once, without the
// password, within its lifetime; after that it shows the expired page.
func TestLoginLink(t *testing.T) {
	d := newTestDaemon(t)
	d.localToken = "link-token"
	cfg := d.config()
	cfg.Dashboard.Username = "admin"
	password := "a long password"
	if _, err := d.updateSettings(cfg, &password); err != nil {
		t.Fatal(err)
	}
	srv := newDashboardServer(d)
	handler := srv.handler()
	get := func(path string, cookie *http.Cookie) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		req.Host = "127.0.0.1:10820"
		if cookie != nil {
			req.AddCookie(cookie)
		}
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		return rec
	}
	makeLink := func(token string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(http.MethodPost, "/api/session/link", strings.NewReader("{}"))
		req.Host = "127.0.0.1:10820"
		req.Header.Set("Content-Type", "application/json")
		if token != "" {
			req.Header.Set(localTokenHeader, token)
		}
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		return rec
	}

	if rec := makeLink(""); rec.Code == http.StatusOK {
		t.Fatal("a link must need the local token")
	}
	if rec := makeLink("wrong"); rec.Code == http.StatusOK {
		t.Fatal("a link must need the right local token")
	}
	rec := makeLink("link-token")
	var link struct {
		Path      string `json:"path"`
		ExpiresIn int    `json:"expires_in"`
	}
	if rec.Code != http.StatusOK || json.Unmarshal(rec.Body.Bytes(), &link) != nil || !strings.HasPrefix(link.Path, "/app/login/") {
		t.Fatalf("link: %d %s", rec.Code, rec.Body.String())
	}
	if link.ExpiresIn != 15*60 {
		t.Fatalf("a link lasts 15 minutes, got %d s", link.ExpiresIn)
	}

	// The password changes; the link still works.
	cfg = d.config()
	changed := "another long password"
	if _, err := d.updateSettings(cfg, &changed); err != nil {
		t.Fatal(err)
	}
	rec = get(link.Path, nil)
	if rec.Code != http.StatusSeeOther || rec.Header().Get("Location") != "/app/" {
		t.Fatalf("the link goes on to the dashboard: %d %q", rec.Code, rec.Header().Get("Location"))
	}
	var session *http.Cookie
	for _, c := range rec.Result().Cookies() {
		if c.Name == sessionCookieName {
			session = c
		}
	}
	if session == nil {
		t.Fatal("the link gives no session cookie")
	}
	if rec := get("/api/status", session); rec.Code != http.StatusOK {
		t.Fatalf("the session from the link does not open the API: %d", rec.Code)
	}

	// Once only.
	if rec := get(link.Path, nil); rec.Code != http.StatusGone || !strings.Contains(rec.Body.String(), "expired") {
		t.Fatalf("a used link shows the expired page: %d", rec.Code)
	}
	// Not after its lifetime.
	rec = makeLink("link-token")
	_ = json.Unmarshal(rec.Body.Bytes(), &link)
	code := strings.TrimPrefix(link.Path, "/app/login/")
	srv.mu.Lock()
	srv.links[code] = time.Now().Add(-time.Second)
	srv.mu.Unlock()
	if rec := get(link.Path, nil); rec.Code != http.StatusGone {
		t.Fatalf("an expired link shows the expired page: %d", rec.Code)
	}
	if rec := get("/app/login/unknown", nil); rec.Code != http.StatusGone {
		t.Fatalf("an unknown link shows the expired page: %d", rec.Code)
	}

	// Only so many wait at a time.
	for i := 0; i < maxLoginLinks+5; i++ {
		makeLink("link-token")
	}
	srv.mu.Lock()
	waiting := len(srv.links)
	srv.mu.Unlock()
	if waiting > maxLoginLinks {
		t.Fatalf("%d links wait, at most %d may", waiting, maxLoginLinks)
	}
}

// On the phone (RequireLocalToken) the API answers only the app's token or
// a browser the app signed in, also without a dashboard login.
func TestTokenOnlyAPI(t *testing.T) {
	d := newTestDaemon(t)
	d.localToken = "phone-token"
	d.RequireLocalToken()
	srv := newDashboardServer(d)
	handler := srv.handler()
	call := func(method, path, token string, cookie *http.Cookie) *httptest.ResponseRecorder {
		var body *strings.Reader
		if method != http.MethodGet {
			body = strings.NewReader("{}")
		} else {
			body = strings.NewReader("")
		}
		req := httptest.NewRequest(method, path, body)
		req.Host = "127.0.0.1:10820"
		if method != http.MethodGet {
			req.Header.Set("Content-Type", "application/json")
		}
		if token != "" {
			req.Header.Set(localTokenHeader, token)
		}
		if cookie != nil {
			req.AddCookie(cookie)
		}
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		return rec
	}

	if rec := call(http.MethodGet, "/api/accounts", "", nil); rec.Code != http.StatusUnauthorized {
		t.Fatalf("another app reached the API without the token: %d", rec.Code)
	}
	if rec := call(http.MethodGet, "/api/accounts", "phone-token", nil); rec.Code != http.StatusOK {
		t.Fatalf("the app's token must open the API: %d", rec.Code)
	}
	if rec := call(http.MethodPost, "/api/session", "", nil); rec.Code != http.StatusUnauthorized {
		t.Fatalf("without a dashboard login, a password login must not sign a browser in: %d", rec.Code)
	}
	var info struct {
		Required bool `json:"login_required"`
	}
	rec := call(http.MethodGet, "/api/session", "", nil)
	if json.Unmarshal(rec.Body.Bytes(), &info) != nil || !info.Required {
		t.Fatalf("the page must ask for a sign-in: %s", rec.Body.String())
	}

	// A sign-in link from the app opens it for the browser.
	rec = call(http.MethodPost, "/api/session/link", "phone-token", nil)
	var link struct {
		Path string `json:"path"`
	}
	_ = json.Unmarshal(rec.Body.Bytes(), &link)
	rec = call(http.MethodGet, link.Path, "", nil)
	var session *http.Cookie
	for _, c := range rec.Result().Cookies() {
		if c.Name == sessionCookieName {
			session = c
		}
	}
	if session == nil {
		t.Fatal("the link gave no session cookie")
	}
	if rec := call(http.MethodGet, "/api/accounts", "", session); rec.Code != http.StatusOK {
		t.Fatalf("the signed-in browser must reach the API: %d", rec.Code)
	}
}
