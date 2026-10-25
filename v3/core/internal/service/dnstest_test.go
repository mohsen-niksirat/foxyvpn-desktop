package service

import (
	"context"
	"encoding/json"
	"errors"
	"net"
	"net/http"
	"net/netip"
	"strings"
	"testing"

	"golang.org/x/net/dns/dnsmessage"

	"github.com/armanlife/firefox-vpn-client/core/internal/resolver"
)

// startTestDNS answers every A query with ip.
func startTestDNS(t *testing.T, ip [4]byte) string {
	t.Helper()
	pc, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { pc.Close() })
	go func() {
		buf := make([]byte, 1500)
		for {
			n, addr, err := pc.ReadFrom(buf)
			if err != nil {
				return
			}
			var msg dnsmessage.Message
			if msg.Unpack(buf[:n]) != nil || len(msg.Questions) == 0 {
				continue
			}
			reply := dnsmessage.Message{Header: dnsmessage.Header{ID: msg.Header.ID, Response: true}, Questions: msg.Questions}
			if q := msg.Questions[0]; q.Type == dnsmessage.TypeA {
				reply.Answers = []dnsmessage.Resource{{
					Header: dnsmessage.ResourceHeader{Name: q.Name, Type: dnsmessage.TypeA, Class: dnsmessage.ClassINET, TTL: 60},
					Body:   &dnsmessage.AResource{A: ip},
				}}
			}
			packed, _ := reply.Pack()
			_, _ = pc.WriteTo(packed, addr)
		}
	}()
	return pc.LocalAddr().String()
}

func TestSettingsApplyDNS(t *testing.T) {
	t.Cleanup(func() { resolver.Set(nil) })
	d := newTestDaemon(t)
	cfg := d.config()
	cfg.DNS.Servers = []string{"https://1.1.1.1/dns-query", "tls://9.9.9.9"}
	if _, err := d.updateSettings(cfg, nil); err != nil {
		t.Fatal(err)
	}
	if got := resolver.Current().String(); !strings.Contains(got, "https://1.1.1.1/dns-query") || !strings.Contains(got, "tls://9.9.9.9:853") {
		t.Fatalf("installed resolver = %s", got)
	}
	if view, _ := d.StatusView(); !strings.Contains(view.DNS, "1.1.1.1") {
		t.Fatalf("status DNS = %q", view.DNS)
	}
	cfg.DNS.Servers = []string{"dns.google"}
	if _, err := d.updateSettings(cfg, nil); err == nil {
		t.Fatal("a host name without a scheme must be rejected")
	}
	cfg.DNS.Servers = []string{}
	if _, err := d.updateSettings(cfg, nil); err != nil {
		t.Fatal(err)
	}
	if !resolver.Current().System() {
		t.Fatal("an empty list must restore the system resolver")
	}
}

func TestDNSTestEndpointComparesWithSystem(t *testing.T) {
	addr := startTestDNS(t, [4]byte{23, 235, 42, 9})
	old := systemDNS
	systemDNS = func(_ context.Context, host string) (resolver.Result, error) {
		if host == "vpn.mozilla.org" {
			return resolver.Result{}, errors.New("blocked")
		}
		return resolver.Result{Addrs: []netip.Addr{netip.MustParseAddr("10.10.34.35")}, Source: "system"}, nil
	}
	t.Cleanup(func() { systemDNS = old })

	d := newTestDaemon(t)
	rec := newDashboardClient(t, d).do(http.MethodPost, "/api/dns/test", map[string]any{"servers": []string{"udp://" + addr}})
	if rec.Code != http.StatusOK {
		t.Fatalf("got %d %s", rec.Code, rec.Body.String())
	}
	var out struct {
		Results []dnsTestHost `json:"results"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	if len(out.Results) != 4 {
		t.Fatalf("expected 4 names, got %+v", out.Results)
	}
	for _, r := range out.Results {
		if len(r.Addrs) != 1 || r.Addrs[0] != "23.235.42.9" || r.Error != "" {
			t.Errorf("%s: configured answer %+v", r.Host, r)
		}
		switch r.Host {
		case "vpn.mozilla.org":
			if r.SystemError != "blocked" || r.Differs || r.Filtered {
				t.Errorf("guardian system answer %+v", r)
			}
		default:
			if !r.Differs || !r.Filtered {
				t.Errorf("%s: a block-page system answer must be flagged: %+v", r.Host, r)
			}
		}
	}
	bad := newDashboardClient(t, d).do(http.MethodPost, "/api/dns/test", map[string]any{"servers": []string{"quic://1.1.1.1"}})
	if bad.Code != http.StatusBadRequest {
		t.Fatalf("an invalid server must be rejected, got %d", bad.Code)
	}
}
