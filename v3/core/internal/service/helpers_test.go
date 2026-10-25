package service

import (
	"context"
	"errors"
	"io"
	"net/http"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/controlplane"
	"github.com/armanlife/firefox-vpn-client/core/internal/netcheck"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
)

// All values in this file are local fixtures; the control plane transport
// rejects every request it does not recognise.

func init() {
	// Background device registration must never reach the real FxA from a
	// test; the tests that cover it enable it with a mock transport.
	proxy.DeviceRegistration.Store(false)
	// Nor may a test fetch Mozilla's Firefox versions.
	latestFirefoxVersion = func(context.Context) (string, error) { return "", errors.New("offline in tests") }
	// The network wait must not depend on the test machine's network.
	networkConnected = func() bool { return true }
	// Nor may the test machine's networks changing restart anything.
	networkNow = func() (string, bool) { return "", false }
	// Nor may a failure check the real internet.
	netcheck.Check = func(context.Context) netcheck.Result { return netcheck.Unknown }
}

type auditRoundTripper func(*http.Request) (*http.Response, error)

func (f auditRoundTripper) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func waitForCondition(t *testing.T, timeout time.Duration, ok func() bool) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if ok() {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatal("condition was not met before timeout")
}

func coreResponse(r *http.Request, status int, body string, header http.Header) *http.Response {
	if header == nil {
		header = make(http.Header)
	}
	return &http.Response{StatusCode: status, Header: header, Body: io.NopCloser(strings.NewReader(body)), Request: r}
}

func setCoreControlPlane(t *testing.T, handler func(*http.Request) (*http.Response, error)) {
	t.Helper()
	t.Setenv("USERPROFILE", t.TempDir())
	t.Setenv("HOME", t.TempDir())
	controlplane.SetTransport(auditRoundTripper(handler))
	t.Cleanup(func() { controlplane.SetTransport(nil) })
	previousDelay := proxy.GuardianRetryInitialDelay
	proxy.GuardianRetryInitialDelay = time.Millisecond
	t.Cleanup(func() { proxy.GuardianRetryInitialDelay = previousDelay })
}

const testGiB = int64(1) << 30

var quotaReset = time.Now().Add(72 * time.Hour).UTC().Truncate(time.Second)

func quotaHeader(usedGiB int64) http.Header {
	h := make(http.Header)
	h.Set("X-Quota-Limit", strconv.FormatInt(50*testGiB, 10))
	h.Set("X-Quota-Remaining", strconv.FormatInt((50-usedGiB)*testGiB, 10))
	h.Set("X-Quota-Reset", quotaReset.Format(time.RFC3339))
	return h
}
