// Package netcheck tells whether this device reaches the internet at all,
// outside the tunnel, so a failed connection to Mozilla can be told apart
// from a device without internet: a network that filters Mozilla answers
// these checks, one without internet does not.
//
// It asks the connectivity checks of Google, Microsoft, and Apple, which
// operating systems use for the same question, and Baidu, which answers in
// China where Google's does not, all at once over plain HTTP; any expected
// answer means online. A captive portal's redirect or page is not one. Each
// call checks anew: the network may have changed since the last one.
package netcheck

import (
	"bytes"
	"context"
	"io"
	"net"
	"net/http"
	"sync"
	"time"
)

// Result is what a check found.
type Result int

const (
	// Unknown: no check was made (tests, or a check replaced).
	Unknown Result = iota
	// Online: at least one check site answered as expected.
	Online
	// Offline: none did within the timeout.
	Offline
)

// Timeout bounds one check.
const Timeout = 5 * time.Second

// site is a check URL and the answer it gives on a working internet.
type site struct {
	url string
	ok  func(status int, body []byte) bool
}

var sites = []site{
	{"http://connectivitycheck.gstatic.com/generate_204", func(status int, _ []byte) bool { return status == http.StatusNoContent }},
	{"http://www.msftconnecttest.com/connecttest.txt", func(status int, body []byte) bool {
		return status == http.StatusOK && bytes.HasPrefix(body, []byte("Microsoft Connect Test"))
	}},
	{"http://captive.apple.com/hotspot-detect.html", func(status int, body []byte) bool {
		return status == http.StatusOK && bytes.Contains(body, []byte("Success"))
	}},
	{"http://www.baidu.com/", func(status int, body []byte) bool {
		return status == http.StatusOK && bytes.Contains(body, []byte("baidu"))
	}},
}

// Check reports whether the internet is reachable; tests replace it.
var Check = check

var (
	mu      sync.Mutex
	running chan struct{}
	last    Result
)

// check runs one check; callers that arrive while one runs share its
// result.
func check(ctx context.Context) Result {
	mu.Lock()
	if running != nil {
		wait := running
		mu.Unlock()
		select {
		case <-wait:
		case <-ctx.Done():
			return Unknown
		}
		mu.Lock()
		defer mu.Unlock()
		return last
	}
	done := make(chan struct{})
	running = done
	mu.Unlock()

	result := probe(ctx, sites)

	mu.Lock()
	last, running = result, nil
	mu.Unlock()
	close(done)
	return result
}

// probe asks every site at once, directly (never through a proxy), and
// returns Online at the first expected answer.
func probe(ctx context.Context, list []site) Result {
	ctx, cancel := context.WithTimeout(ctx, Timeout)
	defer cancel()
	client := &http.Client{
		Transport: &http.Transport{
			Proxy:             nil,
			DialContext:       (&net.Dialer{Timeout: Timeout}).DialContext,
			DisableKeepAlives: true,
		},
		// A redirect is a captive portal's, not the expected answer.
		CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse },
	}
	answers := make(chan bool, len(list))
	for _, s := range list {
		go func(s site) {
			req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.url, nil)
			if err != nil {
				answers <- false
				return
			}
			resp, err := client.Do(req)
			if err != nil {
				answers <- false
				return
			}
			defer resp.Body.Close()
			body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
			answers <- s.ok(resp.StatusCode, body)
		}(s)
	}
	for range list {
		if <-answers {
			return Online
		}
	}
	return Offline
}
