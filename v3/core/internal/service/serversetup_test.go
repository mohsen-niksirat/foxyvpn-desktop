package service

import (
	"regexp"
	"strings"
	"testing"

	"golang.org/x/crypto/bcrypt"
)

// A new server's dashboard and proxy open to the network, each behind its
// own random password; the ports stay.
func TestSetupServer(t *testing.T) {
	cfg := newTestDaemon(t).config()
	cfg.Dashboard.Listen, cfg.Proxy.Listen = "127.0.0.1:9898", "127.0.0.1:9899"
	login, err := SetupServer(&cfg, " ops ")
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Dashboard.Listen != "0.0.0.0:9898" || cfg.Proxy.Listen != "0.0.0.0:9899" {
		t.Fatalf("listen addresses: dashboard %q, proxy %q", cfg.Dashboard.Listen, cfg.Proxy.Listen)
	}
	if login.DashboardPort != "9898" || login.ProxyPort != "9899" {
		t.Fatalf("ports: %+v", login)
	}
	if login.DashboardUsername != "ops" || cfg.Dashboard.Username != "ops" || !regexp.MustCompile(`^proxy[2-9]{4}$`).MatchString(login.ProxyUsername) || cfg.Proxy.Username != login.ProxyUsername {
		t.Fatalf("usernames: %+v", login)
	}
	if len(login.DashboardPassword) != 16 || len(login.ProxyPassword) != 16 || login.DashboardPassword == login.ProxyPassword {
		t.Fatalf("passwords must be 16 characters and differ: %+v", login)
	}
	if bcrypt.CompareHashAndPassword([]byte(cfg.Dashboard.PasswordHash), []byte(login.DashboardPassword)) != nil {
		t.Fatal("the stored hash does not match the dashboard password")
	}
	if cfg.Proxy.Password != login.ProxyPassword {
		t.Fatal("the proxy password was not stored")
	}

	empty := newTestDaemon(t).config()
	if login, err := SetupServer(&empty, "-"); err != nil || !regexp.MustCompile(`^panel[2-9]{4}$`).MatchString(login.DashboardUsername) {
		t.Fatalf("an empty username becomes admin: %+v, %v", login, err)
	}
	for _, bad := range []string{"a b", "a:b", strings.Repeat("x", 65)} {
		cfg := newTestDaemon(t).config()
		if _, err := SetupServer(&cfg, bad); err == nil {
			t.Fatalf("username %q accepted", bad)
		}
	}
}

// The dashboard never opens to other devices without a login: settings
// that would do it are refused.
func TestDashboardNeedsLoginToOpen(t *testing.T) {
	d := newTestDaemon(t)
	cfg := d.config()
	cfg.Dashboard.Listen = "0.0.0.0:10820"
	if _, err := d.updateSettings(cfg, nil); err == nil || !strings.Contains(err.Error(), "username and password") {
		t.Fatalf("opening the dashboard without a login must be refused, got %v", err)
	}
	cfg.Dashboard.Username = "admin"
	password := "a long password"
	if _, err := d.updateSettings(cfg, &password); err != nil {
		t.Fatalf("with a login it may open: %v", err)
	}
}
