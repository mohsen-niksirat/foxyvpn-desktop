package service

import (
	"runtime"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
)

// Auto-connect: the desktop app, started with the computer and set to
// connect, turns the proxy on by itself (POST /api/power with "auto").
//
// With system_proxy.mode=clear (proxy only) that is all: only programs set
// to use the proxy use it, and the engine connects to Mozilla when one
// does, retrying by itself after a failure.
//
// With system_proxy.mode=set, the computer must not be pointed at a proxy
// that cannot reach Mozilla, or nothing would open at all. The system proxy
// is held back (StatusView.AutoConnecting) while the core tests the
// connection: from the moment a network is connected, for
// autoConnectWindow, with growing waits between tests. A passed test lets
// the system proxy follow; at the end of the window the proxy is turned off
// again, without a notice: the computer's internet stays as it was, and the
// user finds the proxy off. Turning the proxy on or off, or changing the
// mode, ends the attempt.

// autoConnectWindow is how long auto-connect tests the connection after a
// network connected. Tests shorten it.
var autoConnectWindow = 5 * time.Minute

// autoConnectRetry is the wait after the given number of failed tests: 10
// seconds, doubling up to 80. Tests shorten it.
var autoConnectRetry = func(failures int) time.Duration {
	return 10 * time.Second << min(failures-1, 3)
}

// autoConnectProbe tests the connection through the proxy, waking it; tests
// replace it.
var autoConnectProbe = func(d *Daemon) bool {
	result, err := d.ConnectionTest()
	return err == nil && result.OK
}

// AutoConnect turns the proxy on for the desktop app started with the
// computer; with the system proxy set, the system proxy waits for a passed
// connection test (see above).
func (d *Daemon) AutoConnect() {
	cfg := d.config()
	holds := cfg.SystemProxy.Mode == config.SystemProxySet && d.systemProxyApplies()
	d.mu.Lock()
	d.autoConnect = nil
	var attempt chan struct{}
	if holds {
		attempt = make(chan struct{})
		d.autoConnect = attempt
	}
	d.mu.Unlock()
	logx.Info("auto-connect: turning the proxy on system_proxy_waits=%t", holds)
	d.setOn(true)
	if holds {
		go d.runAutoConnect(attempt)
	}
}

// systemProxyApplies reports whether this process sets the system proxy.
func (d *Daemon) systemProxyApplies() bool {
	return runtime.GOOS == "windows" || d.SystemProxySupported
}

// autoConnecting reports whether the system proxy waits for auto-connect's
// test.
func (d *Daemon) autoConnecting() bool {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.autoConnect != nil
}

// endAutoConnect ends an auto-connect attempt: the user acted.
func (d *Daemon) endAutoConnect() {
	d.mu.Lock()
	ended := d.autoConnect != nil
	d.autoConnect = nil
	d.mu.Unlock()
	if ended {
		logx.Info("auto-connect: ended by a change of the proxy or its mode")
	}
}

// runAutoConnect waits for a network, then tests the connection until a
// test passes or autoConnectWindow ends; attempt is this run's, so a run
// ended by the user changes nothing.
func (d *Daemon) runAutoConnect(attempt chan struct{}) {
	current := func() bool {
		d.mu.Lock()
		defer d.mu.Unlock()
		return d.autoConnect == attempt
	}
	for !networkConnected() {
		select {
		case <-d.stop:
			return
		case <-time.After(networkPoll):
		}
		if !current() {
			return
		}
	}
	deadline := time.Now().Add(autoConnectWindow)
	for failures := 0; ; {
		if !current() {
			return
		}
		if autoConnectProbe(d) {
			d.mu.Lock()
			if d.autoConnect == attempt {
				d.autoConnect = nil
			}
			d.mu.Unlock()
			logx.Info("auto-connect: connected; the system proxy is set")
			return
		}
		failures++
		left := time.Until(deadline)
		if left <= 0 {
			break
		}
		select {
		case <-d.stop:
			return
		case <-time.After(min(autoConnectRetry(failures), left)):
		}
	}
	d.mu.Lock()
	gaveUp := d.autoConnect == attempt
	if gaveUp {
		d.autoConnect = nil
		d.off = true
	}
	d.mu.Unlock()
	if gaveUp {
		logx.Warn("auto-connect: no connection within %s of the network connecting; the proxy is off again and the system proxy was not set", autoConnectWindow)
		d.RequestRestart()
	}
}
