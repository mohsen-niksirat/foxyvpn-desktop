package main

import (
	"strings"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/accounts"
)

func TestAccountList(t *testing.T) {
	now := time.Date(2026, 10, 19, 12, 0, 0, 0, time.UTC)
	reset := time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC)
	list := []accounts.Account{
		{ID: "a", Email: "hamid@yahoo.com", Status: accounts.StatusReady, Usage: &accounts.Usage{LimitBytes: 50 << 30, RemainingBytes: 36 << 30, ResetAt: reset}},
		{ID: "b", Email: "ali@gmail.com", Status: accounts.StatusReserved, Reason: "reached its switch point", Usage: &accounts.Usage{LimitBytes: 50 << 30, RemainingBytes: 4 << 30, ResetAt: reset}},
		{ID: "c", Email: "x@example.com", Status: accounts.StatusReauthRequired, Reason: "sign in again"},
	}
	var b strings.Builder
	writeAccountList(&b, paint{}, list, "a", map[string]bool{"a": true, "b": true, "c": false}, 90, now)
	got := b.String()
	t.Log("\n" + got)
	for _, want := range []string{
		" 1  ● hamid@yahoo.com  ready           14.0 GB of 50.0 GB used   resets Nov 1",
		" 2    ali@gmail.com    used up         46.0 GB of 50.0 GB used   resets Nov 1   reached its switch point",
		" 3    x@example.com    disabled",
		"the next account takes over at 90% of its data",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("missing %q", want)
		}
	}
	if strings.Contains(got, "INFO") {
		t.Error("log lines in the list")
	}

	b.Reset()
	writeAccountList(&b, paint{}, nil, "", nil, 90, now)
	if !strings.Contains(b.String(), "No accounts yet. Add one: firefox-vpn add-account") {
		t.Errorf("empty list:\n%s", b.String())
	}
}
