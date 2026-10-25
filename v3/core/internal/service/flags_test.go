package service

import (
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
)

// The flags of Mozilla's locations are built in; another one is downloaded
// once, kept in the data folder, and served from there; codes that are not
// two letters and answers that are not SVG images are refused.
func TestFlagsBuiltInDownloadedAndKept(t *testing.T) {
	d := newTestDaemon(t)
	const svg = `<svg xmlns="http://www.w3.org/2000/svg" id="flag-icons-ir" viewBox="0 0 640 480"></svg>`
	var requests atomic.Int32
	online := true
	setCoreControlPlane(t, func(r *http.Request) (*http.Response, error) {
		requests.Add(1)
		if !online {
			return nil, errors.New("offline")
		}
		switch {
		case strings.HasSuffix(r.URL.Path, "/ir.svg") && r.URL.Host == "cdn.jsdelivr.net":
			return coreResponse(r, http.StatusOK, svg, nil), nil
		case strings.HasSuffix(r.URL.Path, "/xk.svg"):
			return coreResponse(r, http.StatusOK, "<html>blocked</html>", nil), nil
		}
		return coreResponse(r, http.StatusNotFound, "", nil), nil
	})
	client := newDashboardClient(t, d)

	// Built in: no request.
	if rec := client.do(http.MethodGet, "/flags/nl.svg", nil); rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "<svg") {
		t.Fatalf("built-in flag: %d", rec.Code)
	}
	if requests.Load() != 0 {
		t.Fatal("a built-in flag is not downloaded")
	}

	// Missing: downloaded once and kept.
	rec := client.do(http.MethodGet, "/flags/ir.svg", nil)
	if rec.Code != http.StatusOK || rec.Body.String() != svg || rec.Header().Get("Content-Type") != "image/svg+xml" {
		t.Fatalf("downloaded flag: %d %q", rec.Code, rec.Header().Get("Content-Type"))
	}
	if data, err := os.ReadFile(filepath.Join(d.paths.Dir, "flags", "ir.svg")); err != nil || string(data) != svg {
		t.Fatalf("the flag is kept: %v", err)
	}
	online = false
	before := requests.Load()
	if rec := client.do(http.MethodGet, "/flags/ir.svg", nil); rec.Code != http.StatusOK || requests.Load() != before {
		t.Fatalf("a kept flag is served without the network: %d", rec.Code)
	}

	// Not an SVG image (a block page): refused, and not asked again soon.
	online = true
	if rec := client.do(http.MethodGet, "/flags/xk.svg", nil); rec.Code != http.StatusNotFound {
		t.Fatalf("a block page is no flag: %d", rec.Code)
	}
	before = requests.Load()
	if rec := client.do(http.MethodGet, "/flags/xk.svg", nil); rec.Code != http.StatusNotFound || requests.Load() != before {
		t.Fatal("a failed flag waits before it is asked again")
	}

	// Only two-letter codes.
	before = requests.Load()
	for _, path := range []string{"/flags/irn.svg", "/flags/1r.svg", "/flags/LICENSE"} {
		if rec := client.do(http.MethodGet, path, nil); rec.Code != http.StatusNotFound {
			t.Fatalf("%s: %d", path, rec.Code)
		}
	}
	if requests.Load() != before {
		t.Fatal("an invalid code is never downloaded")
	}
}
