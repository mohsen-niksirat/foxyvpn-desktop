package resolver

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/netip"
	"strings"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"golang.org/x/net/dns/dnsmessage"
)

// answerFor builds a reply to query with the given IPv4 address.
func answerFor(t *testing.T, query []byte, ip [4]byte, ttl uint32) []byte {
	t.Helper()
	var msg dnsmessage.Message
	if err := msg.Unpack(query); err != nil {
		t.Errorf("bad query: %v", err)
		return nil
	}
	reply := dnsmessage.Message{
		Header:    dnsmessage.Header{ID: msg.Header.ID, Response: true, RecursionAvailable: true},
		Questions: msg.Questions,
	}
	q := msg.Questions[0]
	if q.Type == dnsmessage.TypeA {
		reply.Answers = append(reply.Answers, dnsmessage.Resource{
			Header: dnsmessage.ResourceHeader{Name: q.Name, Type: dnsmessage.TypeA, Class: dnsmessage.ClassINET, TTL: ttl},
			Body:   &dnsmessage.AResource{A: ip},
		})
	}
	packed, err := reply.Pack()
	if err != nil {
		t.Errorf("packing reply: %v", err)
	}
	return packed
}

func startDoH(t *testing.T, ip [4]byte, hits *atomic.Int32) string {
	t.Helper()
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.Header.Get("Content-Type") != dohContentType || r.URL.Path != "/dns-query" {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		hits.Add(1)
		body, _ := io.ReadAll(r.Body)
		w.Header().Set("Content-Type", dohContentType)
		_, _ = w.Write(answerFor(t, body, ip, 120))
	}))
	t.Cleanup(srv.Close)
	old := newDoHClient
	newDoHClient = srv.Client
	t.Cleanup(func() { newDoHClient = old })
	return srv.URL + "/dns-query"
}

func startUDPDNS(t *testing.T, ip [4]byte) string {
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
			_, _ = pc.WriteTo(answerFor(t, buf[:n], ip, 60), addr)
		}
	}()
	return pc.LocalAddr().String()
}

func TestParseServerSpecs(t *testing.T) {
	for spec, want := range map[string]string{
		"https://1.1.1.1/dns-query": "https://1.1.1.1/dns-query",
		"https://dns.google":        "https://dns.google/dns-query",
		"tls://1.1.1.1":             "tls://1.1.1.1:853",
		"tls://[2606:4700::1111]":   "tls://[2606:4700::1111]:853",
		"udp://9.9.9.9":             "9.9.9.9",
		"8.8.8.8":                   "8.8.8.8",
		"8.8.8.8:5353":              "udp://8.8.8.8:5353",
		"tcp://1.1.1.1":             "tcp://1.1.1.1:53",
	} {
		s, err := parseServer(spec)
		if err != nil {
			t.Errorf("parseServer(%q): %v", spec, err)
			continue
		}
		if s.String() != want {
			t.Errorf("parseServer(%q) = %s, want %s", spec, s, want)
		}
	}
	for _, bad := range []string{"dns.google", "quic://1.1.1.1", "udp://dns.google", "https://", "1.1.1.1:x:y"} {
		if _, err := parseServer(bad); err == nil {
			t.Errorf("parseServer(%q) should fail", bad)
		}
	}
	if err := Validate([]string{"", " 1.1.1.1 "}); err != nil {
		t.Errorf("blank entries must be ignored: %v", err)
	}
}

func TestDoHLookupAndCache(t *testing.T) {
	var hits atomic.Int32
	url := startDoH(t, [4]byte{23, 235, 42, 1}, &hits)
	r, err := New([]string{url}, false)
	if err != nil {
		t.Fatal(err)
	}
	res, err := r.Lookup(context.Background(), "US.m1.fastly-masque.net.")
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Addrs) != 1 || res.Addrs[0] != netip.MustParseAddr("23.235.42.1") || res.Source != url || res.Cached {
		t.Fatalf("unexpected result %+v", res)
	}
	res, err = r.Lookup(context.Background(), "us.m1.fastly-masque.net")
	if err != nil || !res.Cached || hits.Load() != 1 {
		t.Fatalf("second lookup should be cached: %+v %v hits=%d", res, err, hits.Load())
	}
}

func TestUDPLookupAndDial(t *testing.T) {
	addr := startUDPDNS(t, [4]byte{127, 0, 0, 1})
	r, err := New([]string{"udp://" + addr}, false)
	if err != nil {
		t.Fatal(err)
	}
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	go func() {
		if c, err := ln.Accept(); err == nil {
			c.Close()
		}
	}()
	_, port, _ := net.SplitHostPort(ln.Addr().String())
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, err := r.DialContext(ctx, "tcp", net.JoinHostPort("guardian.example", port))
	if err != nil {
		t.Fatalf("dial through the resolver: %v", err)
	}
	conn.Close()
}

func TestRaceUsesWorkingServerAndReportsFailures(t *testing.T) {
	var hits atomic.Int32
	url := startDoH(t, [4]byte{10, 0, 0, 7}, &hits)
	dead, err := net.ListenPacket("udp", "127.0.0.1:0") // never answers
	if err != nil {
		t.Fatal(err)
	}
	defer dead.Close()
	r, _ := New([]string{"udp://" + dead.LocalAddr().String(), url}, false)
	res, err := r.Lookup(context.Background(), "vpn.mozilla.org")
	if err != nil || res.Addrs[0] != netip.MustParseAddr("10.0.0.7") {
		t.Fatalf("race: %+v %v", res, err)
	}

	only, _ := New([]string{"udp://" + dead.LocalAddr().String()}, false)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if _, err := only.Lookup(ctx, "vpn.mozilla.org"); err == nil || !strings.Contains(err.Error(), "resolving vpn.mozilla.org failed") {
		t.Fatalf("expected a failure without fallback, got %v", err)
	}
}

func TestSystemAndLiterals(t *testing.T) {
	var r *Resolver
	if !r.System() || r.String() != "system" {
		t.Fatal("nil resolver is the system resolver")
	}
	empty, _ := New(nil, true)
	if !empty.System() {
		t.Fatal("no servers means the system resolver")
	}
	res, err := empty.Lookup(context.Background(), "[::1]")
	if err != nil || res.Source != "literal" || res.Addrs[0] != netip.IPv6Loopback() {
		t.Fatalf("literal: %+v %v", res, err)
	}
	ordered := orderAddrs([]netip.Addr{netip.MustParseAddr("::1"), netip.MustParseAddr("1.2.3.4")})
	if !ordered[0].Is4() {
		t.Fatal("IPv4 must come first")
	}
}

// Every server's failure stays an error, so a caller can tell a device
// without a route from other failures.
func TestServerErrorsKeepTheCause(t *testing.T) {
	err := fmt.Errorf("resolving vpn.mozilla.org failed: %w", serverErrors{
		fmt.Errorf("https://1.1.1.1/dns-query: %w", context.DeadlineExceeded),
		fmt.Errorf("https://9.9.9.9/dns-query: %w", syscall.ENETUNREACH),
	})
	var errno syscall.Errno
	if !errors.As(err, &errno) || errno != syscall.ENETUNREACH {
		t.Fatalf("the cause is lost: %v", err)
	}
	if !strings.Contains(err.Error(), "https://1.1.1.1/dns-query: context deadline exceeded; https://9.9.9.9/dns-query:") {
		t.Fatalf("text: %v", err)
	}
}
