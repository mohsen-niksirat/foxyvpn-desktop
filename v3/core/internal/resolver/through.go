package resolver

import (
	"context"
	"crypto/tls"
	"net"
	"net/http"
	"time"
)

// ThroughServers are the DNS-over-HTTPS servers NewThrough asks, by IP
// address so no lookup is needed to reach them; their certificates name
// these addresses.
var ThroughServers = []string{"https://1.1.1.1/dns-query", "https://8.8.8.8/dns-query"}

// DialFunc opens a connection, such as a tunnel through Mozilla's proxy.
type DialFunc func(ctx context.Context, network, address string) (net.Conn, error)

// throughClient builds the HTTP client of NewThrough; tests replace it to
// trust a local server.
var throughClient = func(dial DialFunc) *http.Client {
	return &http.Client{
		Timeout: queryTimeout,
		Transport: &http.Transport{
			Proxy:               nil,
			DialContext:         dial,
			TLSClientConfig:     &tls.Config{MinVersion: tls.VersionTLS12},
			ForceAttemptHTTP2:   true,
			TLSHandshakeTimeout: queryTimeout,
			MaxIdleConns:        2,
			// An idle connection is a tunnel that keeps the proxy in use;
			// close it well before the proxy would sleep.
			IdleConnTimeout: time.Minute,
		},
	}
}

// NewThrough returns a resolver that asks ThroughServers over connections
// from dial. It never falls back to the system resolver: on a filtered
// network that resolver answers blocked names with the address of a block
// page. Answers are cached like those of New.
func NewThrough(dial DialFunc) *Resolver {
	client := throughClient(dial)
	r := &Resolver{cache: make(map[string]cacheEntry)}
	for _, u := range ThroughServers {
		r.servers = append(r.servers, &dohServer{url: u, client: client})
	}
	return r
}
