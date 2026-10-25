package service

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/accounts"
	"github.com/armanlife/firefox-vpn-client/core/internal/controlplane"
	"github.com/armanlife/firefox-vpn-client/core/internal/fxa"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
)

// mockFxA answers the FxA requests of an automatic sign-in and device
// registration; anything else fails. destroyed counts ended sessions.
var destroyed atomic.Int32

func mockFxA(t *testing.T, verified bool, logins *atomic.Int32, devices *atomic.Int32) {
	destroyed.Store(0)
	t.Helper()
	previous := controlplane.Transport()
	t.Cleanup(func() { controlplane.SetTransport(previous) })
	controlplane.SetTransport(auditRoundTripper(func(r *http.Request) (*http.Response, error) {
		reply := func(status int, body string) (*http.Response, error) {
			return &http.Response{StatusCode: status, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(body)), Request: r}, nil
		}
		var body map[string]any
		if r.Body != nil {
			_ = json.NewDecoder(r.Body).Decode(&body)
		}
		switch {
		case r.URL.Host == "api.accounts.firefox.com" && r.URL.Path == "/v1/account/login":
			logins.Add(1)
			if body["email"] != "user@example.com" {
				return reply(400, `{"errno":102}`)
			}
			return reply(200, `{"uid":"u1","sessionToken":"`+strings.Repeat("ab", 32)+`","verified":`+map[bool]string{true: "true", false: "false"}[verified]+`,"verificationMethod":"email-otp"}`)
		case r.URL.Host == "api.accounts.firefox.com" && r.URL.Path == "/v1/session/destroy":
			destroyed.Add(1)
			return reply(200, `{}`)
		case r.URL.Host == "api.accounts.firefox.com" && r.URL.Path == "/v1/oauth/token":
			return reply(200, `{"access_token":"new-access","refresh_token":"new-refresh","scope":"profile","expires_in":86400,"token_type":"bearer"}`)
		case r.URL.Host == "api.accounts.firefox.com" && r.URL.Path == "/v1/account/device":
			devices.Add(1)
			if r.Header.Get("Authorization") != "Bearer new-refresh" {
				return reply(401, `{"errno":110}`)
			}
			return reply(200, `{"id":"dev01","name":"`+fxa.DeviceName+`","type":"desktop"}`)
		}
		t.Errorf("unexpected request %s %s", r.Method, r.URL)
		return reply(500, "unexpected")
	}))
}

func TestReloginWithStoredPassword(t *testing.T) {
	d := newTestDaemon(t)
	id := addTestAccount(t, d, "user")
	if err := d.store.SetPassword(id, "secret"); err != nil {
		t.Fatal(err)
	}
	var logins, devices atomic.Int32
	mockFxA(t, true, &logins, &devices)
	proxy.DeviceRegistration.Store(true)
	t.Cleanup(func() { proxy.DeviceRegistration.Store(false) })

	acc, _ := d.store.Get(id)
	auth, err := d.pool.Relogin(context.Background(), acc, fxa.ErrReauthRequired)
	if err != nil {
		t.Fatalf("relogin: %v", err)
	}
	if auth.Token.AccessToken != "new-access" {
		t.Fatalf("new token not used: %+v", auth.Token)
	}
	if creds, _ := d.store.Credentials(id); creds.RefreshToken != "new-refresh" {
		t.Fatalf("new tokens not stored: %+v", creds)
	}
	if pw, _ := d.store.Password(id); pw != "secret" {
		t.Fatal("the password must survive the new tokens")
	}
	if destroyed.Load() != 1 {
		t.Fatalf("the sign-in session must end once the tokens exist (ended %d)", destroyed.Load())
	}
	deadline := time.Now().Add(3 * time.Second)
	for time.Now().Before(deadline) {
		if acc, _ := d.store.Get(id); acc.DeviceID == "dev01" {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if acc, _ := d.store.Get(id); acc.DeviceID != "dev01" {
		t.Fatal("the device was not registered after the new sign-in")
	}
	// Registered once per refresh token.
	d.pool.EnsureDevice(context.Background(), id)
	if devices.Load() != 1 {
		t.Fatalf("device registered %d times", devices.Load())
	}

	// A second automatic sign-in within the retry window is not attempted.
	if _, err := d.pool.Relogin(context.Background(), acc, fxa.ErrReauthRequired); !errors.Is(err, fxa.ErrReauthRequired) || logins.Load() != 1 {
		t.Fatalf("relogin must wait between attempts: %v logins=%d", err, logins.Load())
	}
}

func TestReloginNeedsConfirmation(t *testing.T) {
	d := newTestDaemon(t)
	id := addTestAccount(t, d, "user")
	if err := d.store.SetPassword(id, "secret"); err != nil {
		t.Fatal(err)
	}
	var logins, devices atomic.Int32
	mockFxA(t, false, &logins, &devices)
	acc, _ := d.store.Get(id)
	_, err := d.pool.Relogin(context.Background(), acc, fxa.ErrReauthRequired)
	var relogErr *proxy.ReloginError
	if !errors.As(err, &relogErr) || !errors.Is(err, fxa.ErrReauthRequired) || !strings.Contains(relogErr.Reason, "confirm") {
		t.Fatalf("an unconfirmed sign-in must ask for Sign in again: %v", err)
	}
	if d.pool.Record(acc, nil, err) != proxy.AccountSkipped {
		t.Fatal("the account must be skipped")
	}
	if destroyed.Load() != 1 {
		t.Fatal("an unconfirmed session is ended too; Sign in again starts a new one")
	}
	if got, _ := d.store.Get(id); got.Status != accounts.StatusReauthRequired || !strings.Contains(got.Reason, "confirm") {
		t.Fatalf("status %s reason %q", got.Status, got.Reason)
	}

	// Without a stored password, nothing is attempted.
	other := addTestAccount(t, d, "other")
	acc2, _ := d.store.Get(other)
	if _, err := d.pool.Relogin(context.Background(), acc2, fxa.ErrReauthRequired); !errors.Is(err, fxa.ErrReauthRequired) || logins.Load() != 1 {
		t.Fatalf("no password: %v logins=%d", err, logins.Load())
	}
}

func TestSignInAgainUsesStoredPassword(t *testing.T) {
	d := newTestDaemon(t)
	id := addTestAccount(t, d, "user")
	client := newDashboardClient(t, d)
	if rec := client.do(http.MethodPost, "/api/signin", map[string]string{"account_id": id}); rec.Code != http.StatusConflict {
		t.Fatalf("without a stored password: got %d", rec.Code)
	}
	if err := d.store.SetPassword(id, "secret"); err != nil {
		t.Fatal(err)
	}
	rec := client.do(http.MethodGet, "/api/accounts", nil)
	if !strings.Contains(rec.Body.String(), `"has_password":true`) || strings.Contains(rec.Body.String(), "secret") {
		t.Fatalf("accounts view: %s", rec.Body.String())
	}
}
