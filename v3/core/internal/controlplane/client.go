// Package controlplane owns the shared HTTP client for every control-plane
// API request (Firefox Accounts, Guardian, Remote Settings). It is kept
// separate from the data-plane CONNECT sessions and from http.DefaultClient.
package controlplane

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/resolver"
)

const (
	clientTimeout     = 30 * time.Second
	dialTimeout       = 30 * time.Second
	errorBodyLogLimit = 16 * 1024
)

// defaultTransport is Go's default transport with its connections resolved
// through the configured DNS servers (package resolver).
var defaultTransport = func() *http.Transport {
	t := http.DefaultTransport.(*http.Transport).Clone()
	t.DialContext = DialContext
	return t
}()

// DialContext connects through the configured resolver with a timeout; a
// custom transport (the API proxy) uses it to reach its proxy.
func DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	ctx, cancel := context.WithTimeout(ctx, dialTimeout)
	defer cancel()
	return resolver.Dial(ctx, network, address)
}

// client carries an explicit timeout so requests can never hang
// indefinitely; SetTransport may replace its Transport. Its cookie jar holds
// the Fastly anti-bot challenge cookies earned by the FxA challenge solver.
var client = func() *http.Client {
	jar, err := cookiejar.New(nil)
	if err != nil {
		panic(fmt.Sprintf("creating control plane cookie jar: %v", err))
	}
	return &http.Client{
		Timeout:   clientTimeout,
		Jar:       jar,
		Transport: defaultTransport,
	}
}()

// SetTransport routes Firefox Accounts, Guardian, and Remote Settings
// requests through transport (nil restores the default transport). It must
// be called before any control plane request is issued, because the client
// is shared process-wide.
func SetTransport(transport http.RoundTripper) {
	if transport == nil {
		transport = defaultTransport
	}
	client.Transport = transport
}

// Transport returns the configured transport.
func Transport() http.RoundTripper {
	return client.Transport
}

// Do sends req with the shared control plane client.
func Do(req *http.Request) (*http.Response, error) {
	return client.Do(req)
}

// SetCookies stores cookies for u in the shared client's cookie jar.
func SetCookies(u *url.URL, cookies []*http.Cookie) {
	client.Jar.SetCookies(u, cookies)
}

// ReadErrorBody reads a bounded prefix of an error response body for
// diagnostics.
func ReadErrorBody(r io.Reader) string {
	body, err := io.ReadAll(io.LimitReader(r, errorBodyLogLimit))
	if err != nil {
		return "reading error body failed: " + err.Error()
	}
	return string(body)
}
