package netcheck

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func server(t *testing.T, handler http.HandlerFunc) string {
	t.Helper()
	s := httptest.NewServer(handler)
	t.Cleanup(s.Close)
	return s.URL
}

func expect204(status int, _ []byte) bool { return status == http.StatusNoContent }

// One expected answer is enough; a captive portal's redirect or a dead
// site is not one.
func TestProbe(t *testing.T) {
	ok := server(t, func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNoContent) })
	portal := server(t, func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "http://portal.example/login", http.StatusFound)
	})
	dead := "http://127.0.0.1:1/"

	if got := probe(context.Background(), []site{{dead, expect204}, {ok, expect204}}); got != Online {
		t.Fatalf("one answer: %v, want Online", got)
	}
	if got := probe(context.Background(), []site{{dead, expect204}, {portal, expect204}}); got != Offline {
		t.Fatalf("a portal and a dead site: %v, want Offline", got)
	}
}
