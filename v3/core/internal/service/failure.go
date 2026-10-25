package service

import (
	"context"

	"github.com/armanlife/firefox-vpn-client/core/internal/netcheck"
	"github.com/armanlife/firefox-vpn-client/core/internal/netstate"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
)

// failureCode is proxy.FailureCode for err, made sure for failures that may
// be this device's own: no route or name (no_network), no answer
// (unreachable), or anything unknown (other). The internet is then checked
// outside the tunnel (netcheck), every time, since the network may have
// changed: without it the code is no_network; with it, a Mozilla name that
// does not resolve or a route that does not exist means a network that
// filters Mozilla (unreachable). A phone that reported no network needs no
// check.
func failureCode(err error) string {
	return checkedFailure(proxy.FailureCode(err))
}

func checkedFailure(code string) string {
	switch code {
	case proxy.FailureNoNetwork, proxy.FailureUnreachable, proxy.FailureOther:
	default:
		return code
	}
	if netstate.ReportedDown() {
		return proxy.FailureNoNetwork
	}
	switch netcheck.Check(context.Background()) {
	case netcheck.Offline:
		return proxy.FailureNoNetwork
	case netcheck.Online:
		if code == proxy.FailureNoNetwork {
			return proxy.FailureUnreachable
		}
	}
	return code
}
