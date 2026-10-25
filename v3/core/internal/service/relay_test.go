package service

import (
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/controlplane"
)

type fixtureTransport struct{}

func (fixtureTransport) RoundTrip(*http.Request) (*http.Response, error) {
	return nil, http.ErrNotSupported
}

// The relay setting installs its transport and takes away only that one:
// a transport set by someone else (a test's fixture) stays when no relay
// is configured.
func TestAPIRelayKeepsOtherTransports(t *testing.T) {
	t.Cleanup(func() { controlplane.SetTransport(nil); apiRelayTransport = nil })
	fixture := fixtureTransport{}
	controlplane.SetTransport(fixture)

	if err := configureAPIRelay(""); err != nil {
		t.Fatal(err)
	}
	if controlplane.Transport() != (http.RoundTripper)(fixture) {
		t.Fatal("no relay must leave the fixture in place")
	}

	if err := configureAPIRelay("https://relay.example/?key=k"); err != nil {
		t.Fatal(err)
	}
	if controlplane.Transport() == (http.RoundTripper)(fixture) || controlplane.Transport() != apiRelayTransport {
		t.Fatal("the relay is installed")
	}
	if err := configureAPIRelay(""); err != nil {
		t.Fatal(err)
	}
	if controlplane.Transport() == apiRelayTransport && apiRelayTransport != nil {
		t.Fatal("clearing the relay takes it away")
	}
	if apiRelayTransport != nil {
		t.Fatal("no relay is recorded")
	}
	if err := configureAPIRelay("http://relay.example/"); err == nil {
		t.Fatal("a plain-http relay must be refused")
	}
}

// A request goes to the relay with the target in its url parameter, next
// to the relay's own key, with the method, headers, and body; the answer
// keeps the original request.
func TestRelayTransportForwardsToTarget(t *testing.T) {
	var got struct {
		target, key, method, header, body string
	}
	relay := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		got.target, got.key = r.URL.Query().Get("url"), r.URL.Query().Get("key")
		got.method, got.header = r.Method, r.Header.Get("Authorization")
		body, _ := io.ReadAll(r.Body)
		got.body = string(body)
		w.Header().Set("Set-Cookie", "challenge=1; Path=/")
		w.WriteHeader(http.StatusCreated)
		io.WriteString(w, "from the target")
	}))
	defer relay.Close()
	base, _ := url.Parse(relay.URL + "/relay.php?key=secret")
	rt := &relayTransport{relay: base, base: relay.Client().Transport}

	req, _ := http.NewRequest(http.MethodPost, "https://vpn.mozilla.org/api/v1/fpn/token?a=1&b=2", strings.NewReader(`{"x":1}`))
	req.Header.Set("Authorization", "Bearer test")
	resp, err := rt.RoundTrip(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if got.target != "https://vpn.mozilla.org/api/v1/fpn/token?a=1&b=2" || got.key != "secret" {
		t.Fatalf("relay got target %q key %q", got.target, got.key)
	}
	if got.method != http.MethodPost || got.header != "Bearer test" || got.body != `{"x":1}` {
		t.Fatalf("relay got %+v", got)
	}
	if resp.StatusCode != http.StatusCreated || string(body) != "from the target" {
		t.Fatalf("answer %d %q", resp.StatusCode, body)
	}
	if resp.Request != req {
		t.Fatal("the answer must keep the original request, for cookies and redirects")
	}
}

// A relay that refuses (X-Relay-Error) is an error that names the relay.
func TestRelayTransportReportsRefusal(t *testing.T) {
	relay := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Relay-Error", "host not allowed")
		w.WriteHeader(http.StatusForbidden)
	}))
	defer relay.Close()
	base, _ := url.Parse(relay.URL)
	rt := &relayTransport{relay: base, base: relay.Client().Transport}
	req, _ := http.NewRequest(http.MethodGet, "https://example.com/", nil)
	_, err := rt.RoundTrip(req)
	if err == nil || !strings.Contains(err.Error(), "host not allowed") || !strings.Contains(err.Error(), base.Host) {
		t.Fatalf("got %v", err)
	}
}

func TestValidateRelay(t *testing.T) {
	for raw, ok := range map[string]bool{
		"":                                    true,
		"https://relay.example.workers.dev":   true,
		"https://example.com/relay.php?key=k": true,
		"http://example.com/relay.php":        false,
		"relay.example":                       false,
	} {
		if err := config.ValidateRelay(raw); (err == nil) != ok {
			t.Errorf("%q: %v", raw, err)
		}
	}
}
