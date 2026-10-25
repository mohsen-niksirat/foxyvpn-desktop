package service

import (
	"errors"
	"net/http"
	"path/filepath"
	"strings"
	"testing"

	"github.com/armanlife/firefox-vpn-client/core/internal/serverlist"
)

// The server list is saved when it is fetched, shown at once on the next
// start, and used when Mozilla's settings server does not answer.
func TestServerListIsSavedAndUsedOffline(t *testing.T) {
	paths, err := ResolveDataPaths(filepath.Join(t.TempDir(), "data"))
	if err != nil {
		t.Fatal(err)
	}
	online := true
	setCoreControlPlane(t, func(r *http.Request) (*http.Response, error) {
		if online && strings.Contains(r.URL.String(), "vpn-serverlist") {
			return coreResponse(r, http.StatusOK, `{"data":[{"name":"Netherlands","code":"NL","cities":[{"name":"Amsterdam","code":"ams","servers":[{"hostname":"nl.example","port":443}]}]}]}`, nil), nil
		}
		return nil, errors.New("offline")
	})

	d, err := NewDaemon(paths, false)
	if err != nil {
		t.Fatal(err)
	}
	if len(d.countries) != 0 {
		t.Fatal("no list saved yet")
	}
	if got := d.refreshLocations(d.config()); len(got) != 1 {
		t.Fatalf("fetched %+v", got)
	}
	if _, _, err := serverlist.LoadCache(paths.ServerList); err != nil {
		t.Fatalf("the fetched list is saved: %v", err)
	}

	// Next start, no network: the saved list, at once and for connecting.
	online = false
	d, err = NewDaemon(paths, false)
	if err != nil {
		t.Fatal(err)
	}
	if len(d.countries) != 1 || d.countries[0].Code != "NL" {
		t.Fatalf("shown at start: %+v", d.countries)
	}
	if got := d.refreshLocations(d.config()); len(got) != 1 || got[0].Cities[0].Servers[0].Hostname != "nl.example" {
		t.Fatalf("offline: %+v", got)
	}
}
