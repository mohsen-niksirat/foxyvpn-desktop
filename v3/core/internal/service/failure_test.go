package service

import (
	"context"
	"testing"

	"github.com/armanlife/firefox-vpn-client/core/internal/netcheck"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
)

// A failure that may be the device's own is checked against the internet:
// without it, it is no_network; with it, a name or route that fails is
// Mozilla's servers filtered. The account's problems need no check.
func TestCheckedFailure(t *testing.T) {
	old := netcheck.Check
	t.Cleanup(func() { netcheck.Check = old })
	cases := []struct {
		code  string
		check netcheck.Result
		want  string
	}{
		{proxy.FailureUnreachable, netcheck.Offline, proxy.FailureNoNetwork},
		{proxy.FailureOther, netcheck.Offline, proxy.FailureNoNetwork},
		{proxy.FailureNoNetwork, netcheck.Online, proxy.FailureUnreachable},
		{proxy.FailureUnreachable, netcheck.Online, proxy.FailureUnreachable},
		{proxy.FailureOther, netcheck.Online, proxy.FailureOther},
		{proxy.FailureNoNetwork, netcheck.Unknown, proxy.FailureNoNetwork},
		{proxy.FailureQuota, netcheck.Offline, proxy.FailureQuota},
	}
	for _, tc := range cases {
		calls := 0
		netcheck.Check = func(context.Context) netcheck.Result { calls++; return tc.check }
		if got := checkedFailure(tc.code); got != tc.want {
			t.Errorf("%s with %v: %q, want %q", tc.code, tc.check, got, tc.want)
		}
		if tc.code == proxy.FailureQuota && calls != 0 {
			t.Errorf("the account's problem was checked against the internet")
		}
	}
}
