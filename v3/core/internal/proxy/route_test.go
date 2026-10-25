package proxy

import (
	"context"
	"errors"
	"io"
	"net"
	"net/netip"
	"slices"
	"sync"
	"sync/atomic"
	"testing"

	"github.com/armanlife/firefox-vpn-client/core/internal/routing"
)

// countingOpener answers every tunnel with one end of a pipe.
type countingOpener struct {
	opened atomic.Int32
}

func (o *countingOpener) OpenTunnel(string) (net.Conn, error) {
	o.opened.Add(1)
	a, b := net.Pipe()
	_ = b.Close()
	return a, nil
}

func TestRoutedOpenerFollowsRules(t *testing.T) {
	t.Parallel()

	upstream := &countingOpener{}
	routed := NewRoutedOpener(upstream)
	var dialed []string
	routed.dial = func(_ context.Context, _, address string) (net.Conn, error) {
		dialed = append(dialed, address)
		a, b := net.Pipe()
		_ = b.Close()
		return a, nil
	}
	router, err := routing.New(routing.Config{Direct: []string{"domain:shop.ir", "10.0.0.0/8"}, Block: []string{"full:ads.example"}})
	if err != nil {
		t.Fatal(err)
	}

	// Without a router everything goes through the proxy.
	if conn, err := routed.OpenTunnel("www.shop.ir:443"); err != nil {
		t.Fatal(err)
	} else {
		_ = conn.Close()
	}
	routed.SetRouter(router)
	for _, target := range []string{"www.shop.ir:443", "10.1.2.3:8080", "example.com:443"} {
		conn, err := routed.OpenTunnel(target)
		if err != nil {
			t.Fatalf("%s: %v", target, err)
		}
		_ = conn.Close()
	}
	if _, err := routed.OpenTunnel("ads.example:443"); !errors.Is(err, ErrBlockedByRule) || mapUpstreamError(err) != socksReplyNotAllow {
		t.Fatalf("a blocked target must be refused as not allowed: %v", err)
	}
	if len(dialed) != 2 || dialed[0] != "www.shop.ir:443" || dialed[1] != "10.1.2.3:8080" {
		t.Fatalf("direct dials %v", dialed)
	}
	if got := upstream.opened.Load(); got != 2 {
		t.Fatalf("tunnels through the proxy: %d, want 2", got)
	}
	if c := routed.Counts(); c.Proxy != 2 || c.Direct != 2 || c.Blocked != 1 {
		t.Fatalf("counts %+v", c)
	}
}

// Mozilla refuses port 22: git over SSH to GitHub goes through to GitHub's
// SSH server on port 443; other SSH targets, and a direct route, keep
// their address.
func TestGitHubSSHGoesThroughPort443(t *testing.T) {
	t.Parallel()

	upstream := &recordingOpener{}
	routed := NewRoutedOpener(upstream)
	var dialed []string
	routed.dial = func(_ context.Context, _, address string) (net.Conn, error) {
		dialed = append(dialed, address)
		return nil, errors.New("direct in the test")
	}
	for _, target := range []string{"github.com:22", "GitHub.com:22", "example.com:22", "github.com:443"} {
		_, _ = routed.OpenTunnel(target)
	}
	want := []string{"ssh.github.com:443", "ssh.github.com:443", "example.com:22", "github.com:443"}
	if !slices.Equal(upstream.targets, want) {
		t.Fatalf("through Mozilla %v, want %v", upstream.targets, want)
	}
	router, err := routing.New(routing.Config{Direct: []string{"domain:github.com"}})
	if err != nil {
		t.Fatal(err)
	}
	routed.SetRouter(router)
	_, _ = routed.OpenTunnel("github.com:22")
	if !slices.Equal(dialed, []string{"github.com:22"}) {
		t.Fatalf("direct dials %v; a direct route keeps port 22", dialed)
	}
}

// Bytes are counted per route, and the speed is the average of the last
// seconds.
func TestTrafficCountsBytesAndSpeed(t *testing.T) {
	t.Parallel()

	m := &trafficMeter{stop: make(chan struct{})}
	client, server := net.Pipe()
	defer server.Close()
	conn := countConn(client, &m.up, &m.down)
	go func() {
		buf := make([]byte, 100)
		_, _ = io.ReadFull(server, buf)
		_, _ = server.Write(make([]byte, 300))
	}()
	if _, err := conn.Write(make([]byte, 100)); err != nil {
		t.Fatal(err)
	}
	if _, err := io.ReadFull(conn, make([]byte, 300)); err != nil {
		t.Fatal(err)
	}
	m.directDown.Add(700)

	m.tick() // start of the window
	if got := m.traffic(); got.Up != 100 || got.Down != 300 || got.DirectDown != 700 || got.DownRate != 0 {
		t.Fatalf("one sample has no speed yet: %+v", got)
	}
	m.down.Add(2000)
	m.tick()
	m.down.Add(4000)
	m.tick()
	if got := m.traffic(); got.DownRate != 3000 || got.UpRate != 0 {
		t.Fatalf("speed over two seconds: %+v", got)
	}
}

// recordingOpener refuses every tunnel and remembers where each went.
type recordingOpener struct {
	mu      sync.Mutex
	targets []string
}

func (o *recordingOpener) OpenTunnel(authority string) (net.Conn, error) {
	o.mu.Lock()
	o.targets = append(o.targets, authority)
	o.mu.Unlock()
	return nil, errors.New("refused in the test")
}

// With resolve_domains, names are looked up through Mozilla, never with the
// local DNS: a filtered network answers a blocked name with its block
// page's private address (10.10.34.35 in Iran), which geoip:private would
// send directly. A lookup that fails sends the name through Mozilla.
func TestRoutedOpenerLooksNamesUpThroughMozilla(t *testing.T) {
	t.Parallel()

	upstream := &recordingOpener{}
	routed := NewRoutedOpener(upstream)
	defer routed.Close()
	routed.dial = func(_ context.Context, _, address string) (net.Conn, error) {
		t.Errorf("no direct connection expected, got %s", address)
		return nil, errors.New("unexpected")
	}
	router, err := routing.New(routing.Config{Direct: []string{"10.0.0.0/8"}, ResolveDomains: true})
	if err != nil {
		t.Fatal(err)
	}
	routed.SetRouter(router)

	if _, err := routed.OpenTunnel("blocked.example:443"); err == nil {
		t.Fatal("the recording upstream refuses every tunnel")
	}
	upstream.mu.Lock()
	targets := slices.Clone(upstream.targets)
	upstream.mu.Unlock()
	// The DNS-over-HTTPS servers, then the site itself, all through Mozilla.
	if !slices.Contains(targets, "1.1.1.1:443") || !slices.Contains(targets, "8.8.8.8:443") || targets[len(targets)-1] != "blocked.example:443" {
		t.Fatalf("tunnels %v", targets)
	}
	if c := routed.Counts(); c.Proxy != 1 || c.Direct != 0 {
		t.Fatalf("lookups are not client connections: %+v", c)
	}

	// An answer from the lookup decides by the IP rules.
	routed.lookup = func(context.Context, string) ([]netip.Addr, error) {
		return []netip.Addr{netip.MustParseAddr("10.20.30.40")}, nil
	}
	if d := router.Explain(context.Background(), "intranet.example", routed.Lookup); d.Action != routing.Direct || d.Resolved != "10.20.30.40" {
		t.Fatalf("decision %+v", d)
	}
}

// A direct route for another device never reaches this machine's own
// services (the dashboard among them) or link-local addresses (a cloud
// metadata service), whatever name led to the address; a client on this
// machine is not held back.
func TestDirectRouteRefusesThisMachineForOtherDevices(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			c.Close()
		}
	}()
	for _, addr := range []string{ln.Addr().String(), "[::1]:1", "0.0.0.0:1", "169.254.169.254:80", "[fe80::1]:80"} {
		conn, err := remoteDirectDialer.DialContext(context.Background(), "tcp", addr)
		if err == nil {
			conn.Close()
			t.Fatalf("a direct route for another device reached %s", addr)
		}
		if !errors.Is(err, ErrThisMachine) || !errors.Is(err, ErrBlockedByRule) {
			t.Fatalf("%s: want ErrThisMachine, got %v", addr, err)
		}
	}
	conn, err := directDialer.DialContext(context.Background(), "tcp", ln.Addr().String())
	if err != nil {
		t.Fatalf("a client on this machine may reach it: %v", err)
	}
	conn.Close()

	for key, remote := range map[string]bool{"": false, "127.0.0.1": false, "::1": false, "::ffff:127.0.0.1": false, "192.168.1.20": true, "2001:db8::1": true, "garbage": true} {
		if remoteClient(key) != remote {
			t.Fatalf("remoteClient(%q) = %v, want %v", key, !remote, remote)
		}
	}
}
