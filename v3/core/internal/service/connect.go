package service

import (
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/netstate"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
)

// A connect the user asked for in an app (the button) that never reaches
// Mozilla is given up after connectWindow: the proxy turns off again, and
// the phone's VPN with its notification, instead of staying "Connecting"
// with no end. Why it failed stays in the status (StatusView.ConnectFailure)
// for the app to say under its button. A proxy that connected once stays on
// through later failures (a network that comes and goes), and reconnects by
// itself.

// connectWindow is how long a connect may take before it is given up. Tests
// shorten it.
var connectWindow = time.Minute

// Connect turns the proxy on for the user of an app, and gives the connect
// up after connectWindow unless it reaches Mozilla.
func (d *Daemon) Connect() {
	attempt := make(chan struct{})
	started := time.Now()
	d.mu.Lock()
	d.autoConnect = nil
	d.connectAttempt, d.connectFailure = attempt, ""
	d.mu.Unlock()
	d.setOn(true)
	go d.giveUpUnlessConnected(attempt, started)
}

// markConnected records a connection that reached Mozilla.
func (d *Daemon) markConnected() {
	d.mu.Lock()
	d.lastConnected = time.Now()
	d.mu.Unlock()
}

// endConnect ends a connect attempt: the user acted.
func (d *Daemon) endConnect() {
	d.mu.Lock()
	d.connectAttempt = nil
	d.mu.Unlock()
}

func (d *Daemon) giveUpUnlessConnected(attempt chan struct{}, started time.Time) {
	select {
	case <-d.stop:
		return
	case <-time.After(connectWindow):
	}
	d.mu.Lock()
	current := d.connectAttempt == attempt && !d.off
	connected := !d.lastConnected.Before(started)
	if !current || connected {
		if d.connectAttempt == attempt {
			d.connectAttempt = nil
		}
		d.mu.Unlock()
		return
	}
	d.mu.Unlock()
	reason := d.connectFailureCode(started)
	d.mu.Lock()
	gaveUp := d.connectAttempt == attempt && !d.off && d.lastConnected.Before(started)
	if gaveUp {
		d.connectAttempt, d.connectFailure, d.off = nil, reason, true
	}
	d.mu.Unlock()
	if gaveUp {
		logx.Warn("no connection to Mozilla within %s of connecting; the proxy is off again reason=%s", connectWindow, reason)
		d.RequestRestart()
	}
}

// connectFailureCode says why a connect since started did not reach
// Mozilla: the last failure's code, else what the internet check finds.
func (d *Daemon) connectFailureCode(started time.Time) string {
	if engine := d.currentEngine(); engine != nil {
		if at, code, err := engine.wakeFailure(); err != nil && !at.Before(started) {
			return code
		}
	}
	d.mu.Lock()
	test := d.lastTest
	d.mu.Unlock()
	if test != nil && !test.OK && !test.At.Before(started) && test.ErrorCode != "" {
		return test.ErrorCode
	}
	if netstate.ReportedDown() {
		return proxy.FailureNoNetwork
	}
	return checkedFailure(proxy.FailureOther)
}

// RetryNow drops the waits that failures left before the next attempt, for
// a user who is looking (the app came to the front): the next connection
// tries at once. Failures that retrying cannot fix (a spent quota, an
// account that must sign in again) keep theirs.
func (d *Daemon) RetryNow() {
	engine := d.currentEngine()
	if engine == nil {
		return
	}
	engine.retryNow()
	if controller := engine.currentController(); controller != nil {
		controller.RetryNow()
	}
}
