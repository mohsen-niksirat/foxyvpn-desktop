// Package resolver resolves the host names this program connects to itself
// (Mozilla's Fastly proxy servers and the account, Guardian, and server-list
// APIs) through configurable DNS servers: DNS over HTTPS, DNS over TLS, or
// plain DNS. On filtered networks the system resolver may return wrong
// answers; encrypted DNS avoids that.
//
// Names that SOCKS clients send are not resolved here: they travel inside
// the CONNECT request and Mozilla's exit resolves them.
package resolver

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"net/url"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const (
	queryTimeout = 5 * time.Second
	minCacheTTL  = 30 * time.Second
	maxCacheTTL  = 10 * time.Minute
	// defaultTTL applies to answers whose TTL is unknown (DoT and plain DNS
	// through Go's resolver).
	defaultTTL = 5 * time.Minute
)

// server answers queries for one configured DNS server.
type server interface {
	lookup(ctx context.Context, host string) ([]netip.Addr, time.Duration, error)
	String() string
}

// Resolver looks names up through its servers concurrently, uses the first
// answer, caches it, and optionally falls back to the system resolver.
type Resolver struct {
	servers  []server
	fallback bool

	mu    sync.Mutex
	cache map[string]cacheEntry
}

type cacheEntry struct {
	addrs   []netip.Addr
	source  string
	expires time.Time
}

// New builds a resolver from server specifications:
//
//	https://1.1.1.1/dns-query   DNS over HTTPS
//	tls://1.1.1.1               DNS over TLS (port 853 unless given)
//	udp://8.8.8.8, 8.8.8.8:53   plain DNS (TCP when an answer is truncated)
//
// No servers means the system resolver.
func New(specs []string, fallbackToSystem bool) (*Resolver, error) {
	r := &Resolver{fallback: fallbackToSystem, cache: make(map[string]cacheEntry)}
	for _, spec := range specs {
		spec = strings.TrimSpace(spec)
		if spec == "" {
			continue
		}
		s, err := parseServer(spec)
		if err != nil {
			return nil, err
		}
		r.servers = append(r.servers, s)
	}
	return r, nil
}

// Validate reports whether every specification can be parsed.
func Validate(specs []string) error {
	_, err := New(specs, true)
	return err
}

func parseServer(spec string) (server, error) {
	lower := strings.ToLower(spec)
	switch {
	case strings.HasPrefix(lower, "https://"):
		u, err := url.Parse(spec)
		if err != nil || u.Host == "" {
			return nil, fmt.Errorf("invalid DNS-over-HTTPS URL %q", spec)
		}
		if u.Path == "" || u.Path == "/" {
			u.Path = "/dns-query"
		}
		return newDoHServer(u.String()), nil
	case strings.HasPrefix(lower, "tls://"):
		host, port, err := hostPort(spec[len("tls://"):], "853")
		if err != nil {
			return nil, fmt.Errorf("invalid DNS-over-TLS server %q: %w", spec, err)
		}
		return newStreamServer("tls", host, port), nil
	case strings.HasPrefix(lower, "udp://"), strings.HasPrefix(lower, "tcp://"):
		host, port, err := hostPort(spec[len("udp://"):], "53")
		if err != nil {
			return nil, fmt.Errorf("invalid DNS server %q: %w", spec, err)
		}
		if _, err := netip.ParseAddr(host); err != nil {
			return nil, fmt.Errorf("DNS server %q must be an IP address", spec)
		}
		return newStreamServer(lower[:3], host, port), nil
	case strings.Contains(spec, "://"):
		return nil, fmt.Errorf("unsupported DNS server %q (use https://, tls://, udp://, or an IP address)", spec)
	}
	host, port, err := hostPort(spec, "53")
	if err != nil {
		return nil, fmt.Errorf("invalid DNS server %q: %w", spec, err)
	}
	if _, err := netip.ParseAddr(host); err != nil {
		return nil, fmt.Errorf("DNS server %q must be an IP address or a URL", spec)
	}
	return newStreamServer("udp", host, port), nil
}

// hostPort splits "host", "host:port", "[v6]", or "[v6]:port".
func hostPort(s, defaultPort string) (string, string, error) {
	s = strings.TrimSuffix(strings.TrimSpace(s), "/")
	if s == "" {
		return "", "", errors.New("empty address")
	}
	if host, port, err := net.SplitHostPort(s); err == nil {
		return strings.Trim(host, "[]"), port, nil
	}
	if _, err := netip.ParseAddr(s); err == nil {
		return s, defaultPort, nil
	}
	if strings.HasPrefix(s, "[") && strings.HasSuffix(s, "]") {
		return strings.Trim(s, "[]"), defaultPort, nil
	}
	if strings.Contains(s, ":") {
		return "", "", errors.New("bad host:port")
	}
	return s, defaultPort, nil
}

// System reports whether the resolver only uses the system resolver.
func (r *Resolver) System() bool { return r == nil || len(r.servers) == 0 }

// String describes the configuration for logs.
func (r *Resolver) String() string {
	if r.System() {
		return "system"
	}
	names := make([]string, len(r.servers))
	for i, s := range r.servers {
		names[i] = s.String()
	}
	text := strings.Join(names, ", ")
	if r.fallback {
		text += " (system fallback)"
	}
	return text
}

// Result is a lookup outcome with the server that answered.
type Result struct {
	Addrs  []netip.Addr
	Source string
	Cached bool
}

// Lookup resolves host to IP addresses.
func (r *Resolver) Lookup(ctx context.Context, host string) (Result, error) {
	host = strings.TrimSuffix(strings.ToLower(strings.TrimSpace(host)), ".")
	if addr, err := netip.ParseAddr(strings.Trim(host, "[]")); err == nil {
		return Result{Addrs: []netip.Addr{addr}, Source: "literal"}, nil
	}
	if r.System() || host == "localhost" {
		return systemLookup(ctx, host)
	}
	r.mu.Lock()
	if entry, ok := r.cache[host]; ok && time.Now().Before(entry.expires) {
		r.mu.Unlock()
		return Result{Addrs: entry.addrs, Source: entry.source, Cached: true}, nil
	}
	r.mu.Unlock()

	result, ttl, err := r.race(ctx, host)
	if err == nil {
		r.mu.Lock()
		r.cache[host] = cacheEntry{addrs: result.Addrs, source: result.Source, expires: time.Now().Add(clampTTL(ttl))}
		r.mu.Unlock()
		return result, nil
	}
	if r.fallback && ctx.Err() == nil {
		if sys, sysErr := systemLookup(ctx, host); sysErr == nil {
			sys.Source = "system (fallback)"
			return sys, nil
		}
	}
	return Result{}, err
}

// race queries every server at once and returns the first answer.
func (r *Resolver) race(ctx context.Context, host string) (Result, time.Duration, error) {
	ctx, cancel := context.WithTimeout(ctx, queryTimeout)
	defer cancel()
	type answer struct {
		addrs  []netip.Addr
		ttl    time.Duration
		source string
		err    error
	}
	answers := make(chan answer, len(r.servers))
	for _, s := range r.servers {
		go func(s server) {
			addrs, ttl, err := s.lookup(ctx, host)
			if err == nil && len(addrs) == 0 {
				err = fmt.Errorf("no addresses for %s", host)
			}
			answers <- answer{addrs, ttl, s.String(), err}
		}(s)
	}
	var errs serverErrors
	for range r.servers {
		a := <-answers
		if a.err == nil {
			return Result{Addrs: a.addrs, Source: a.source}, a.ttl, nil
		}
		errs = append(errs, fmt.Errorf("%s: %w", a.source, a.err))
	}
	return Result{}, 0, fmt.Errorf("resolving %s failed: %w", host, errs)
}

// serverErrors are every server's failure, kept as errors so that callers
// can still tell why (proxy.FailureCode: no route is "no network").
type serverErrors []error

func (e serverErrors) Error() string {
	texts := make([]string, len(e))
	for i, err := range e {
		texts[i] = err.Error()
	}
	return strings.Join(texts, "; ")
}

func (e serverErrors) Unwrap() []error { return e }

func clampTTL(ttl time.Duration) time.Duration {
	if ttl <= 0 {
		return defaultTTL
	}
	return min(maxCacheTTL, max(minCacheTTL, ttl))
}

func systemLookup(ctx context.Context, host string) (Result, error) {
	addrs, err := net.DefaultResolver.LookupNetIP(ctx, "ip", host)
	if err != nil {
		return Result{}, err
	}
	for i := range addrs {
		addrs[i] = addrs[i].Unmap()
	}
	return Result{Addrs: addrs, Source: "system"}, nil
}

// DialContext resolves the host of address and connects to its addresses
// in turn.
func (r *Resolver) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	var d net.Dialer
	if r.System() {
		return d.DialContext(ctx, network, address)
	}
	host, port, err := net.SplitHostPort(address)
	if err != nil {
		return nil, err
	}
	result, err := r.Lookup(ctx, host)
	if err != nil {
		return nil, err
	}
	var lastErr error
	for _, addr := range orderAddrs(result.Addrs) {
		conn, err := d.DialContext(ctx, network, net.JoinHostPort(addr.String(), port))
		if err == nil {
			return conn, nil
		}
		lastErr = err
		if ctx.Err() != nil {
			break
		}
	}
	return nil, lastErr
}

// orderAddrs puts IPv4 addresses first; IPv6 is often unusable on the
// networks this program targets.
func orderAddrs(addrs []netip.Addr) []netip.Addr {
	out := make([]netip.Addr, 0, len(addrs))
	for _, a := range addrs {
		if a.Is4() {
			out = append(out, a)
		}
	}
	for _, a := range addrs {
		if !a.Is4() {
			out = append(out, a)
		}
	}
	return out
}

// The process-wide resolver; nil means the system resolver.
var current atomic.Pointer[Resolver]

// Set installs r for every dial in the process; nil restores the system
// resolver.
func Set(r *Resolver) { current.Store(r) }

// Current returns the installed resolver (nil means the system resolver).
func Current() *Resolver { return current.Load() }

// Dial connects through the installed resolver.
func Dial(ctx context.Context, network, address string) (net.Conn, error) {
	return Current().DialContext(ctx, network, address)
}

// LookupNetIP resolves host through the installed resolver, IPv4 first.
func LookupNetIP(ctx context.Context, host string) ([]netip.Addr, error) {
	result, err := Current().Lookup(ctx, host)
	if err != nil {
		return nil, err
	}
	return orderAddrs(result.Addrs), nil
}

// streamServer queries a DoT, TCP, or UDP server through Go's resolver,
// which handles truncation, retries, and the wire format.
type streamServer struct {
	kind, host, port string
	r                *net.Resolver
}

func newStreamServer(kind, host, port string) *streamServer {
	s := &streamServer{kind: kind, host: host, port: port}
	addr := net.JoinHostPort(host, port)
	s.r = &net.Resolver{PreferGo: true, Dial: func(ctx context.Context, network, _ string) (net.Conn, error) {
		var d net.Dialer
		switch kind {
		case "tls":
			// A TLS connection is a stream, so Go's resolver uses TCP
			// framing on it, which is what DNS over TLS expects.
			raw, err := d.DialContext(ctx, "tcp", addr)
			if err != nil {
				return nil, err
			}
			conn := tls.Client(raw, &tls.Config{ServerName: host, MinVersion: tls.VersionTLS12})
			if err := conn.HandshakeContext(ctx); err != nil {
				_ = raw.Close()
				return nil, err
			}
			return conn, nil
		case "tcp":
			return d.DialContext(ctx, "tcp", addr)
		}
		// Go's resolver retries over TCP for a truncated UDP answer.
		if strings.HasPrefix(network, "tcp") {
			return d.DialContext(ctx, "tcp", addr)
		}
		return d.DialContext(ctx, "udp", addr)
	}}
	return s
}

func (s *streamServer) lookup(ctx context.Context, host string) ([]netip.Addr, time.Duration, error) {
	addrs, err := s.r.LookupNetIP(ctx, "ip", host)
	for i := range addrs {
		addrs[i] = addrs[i].Unmap()
	}
	return addrs, 0, err
}

func (s *streamServer) String() string {
	if s.kind == "udp" && s.port == "53" {
		return s.host
	}
	return s.kind + "://" + net.JoinHostPort(s.host, s.port)
}
