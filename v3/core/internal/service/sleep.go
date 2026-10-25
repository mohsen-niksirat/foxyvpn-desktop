package service

import (
	"context"
	"errors"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/accounts"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
)

// Sleep: an engine without a controller listens on proxy.listen but holds
// no upstream session and no pass, renews nothing, and checks no quota.
// Every engine starts asleep, so starting the program sends nothing to
// Mozilla. After proxy.idle_sleep without a connection through Mozilla it
// falls asleep again: the engine closes its controller.
//
// The next connection that needs Mozilla, a connection test, or a
// real-delay test wakes it and waits for the wake: the first wake selects
// the server and connects (server list, pass, "fastest" measurement,
// session; then the automatic connection test and the device
// registration), later wakes build a controller for the same server (a
// new pass and session). Direct connections (routing) never wake it.

// idleCheckInterval is how often the engine checks whether it may sleep.
const idleCheckInterval = 30 * time.Second

// wakeReason says what needs the upstream of a sleeping engine.
type wakeReason int

const (
	// wakeForClient: a client connection; after a failed wake it gets the
	// failure until wakeRetryAt.
	wakeForClient wakeReason = iota
	// wakeForTest: the connection test, which records its own result, so
	// no automatic test follows the first wake.
	wakeForTest
	// wakeForPing: the real-delay test.
	wakeForPing
)

// idleState is an engine's use of its controller. mu also guards
// proxyEngine.controller, so a connection that has taken the controller
// (inUse) is never left with a closed one.
type idleState struct {
	mu       sync.Mutex
	inUse    int       // connections and tests using the controller
	lastUsed time.Time // when inUse last changed
	sleeping time.Time // when the engine fell asleep, zero while awake
	stopped  bool      // the engine stopped; a late wake closes its controller
	// wakeErr is why the last wake failed, at wakeFailedAt, and its
	// failure code after the internet check (failureCode); cleared by a
	// successful wake.
	wakeErr      error
	wakeCode     string
	wakeFailedAt time.Time
	// wakeRetryAt is when client connections may wake the engine again
	// (proxy.WakeRetryDelay after wakeFailures failures in a row), so a
	// browser opening many connections cannot turn failures into a stream
	// of Guardian requests. Tests and real-delay measurements try again
	// at once, unless the failure is lasting (wakeLasting).
	wakeRetryAt  time.Time
	wakeFailures int
	wakeLasting  bool
	// wakeMu serializes wakes; it also guards proxyEngine.upstream and
	// proxyEngine.connected.
	wakeMu sync.Mutex
}

func (s *idleState) touch() {
	s.mu.Lock()
	s.lastUsed = time.Now()
	s.mu.Unlock()
}

// currentController returns the controller, or nil while asleep.
func (e *proxyEngine) currentController() *proxy.Controller {
	e.idle.mu.Lock()
	defer e.idle.mu.Unlock()
	return e.controller
}

// asleepSince reports when the engine fell asleep, or zero.
func (e *proxyEngine) asleepSince() time.Time {
	e.idle.mu.Lock()
	defer e.idle.mu.Unlock()
	return e.idle.sleeping
}

// wakeFailure reports why the last wake failed, when, and its failure
// code; empty after a successful wake.
func (e *proxyEngine) wakeFailure() (time.Time, string, error) {
	e.idle.mu.Lock()
	defer e.idle.mu.Unlock()
	return e.idle.wakeFailedAt, e.idle.wakeCode, e.idle.wakeErr
}

// wakeWait returns the last wake failure while the next wake must wait
// for why, and how long it waits.
func (e *proxyEngine) wakeWait(why wakeReason, now time.Time) (error, time.Duration) {
	e.idle.mu.Lock()
	defer e.idle.mu.Unlock()
	if e.idle.wakeErr == nil || !now.Before(e.idle.wakeRetryAt) {
		return nil, 0
	}
	if why != wakeForClient && !e.idle.wakeLasting {
		return nil, 0
	}
	return e.idle.wakeErr, e.idle.wakeRetryAt.Sub(now)
}

// wakeAgainNow lets the next connection wake the engine at once: the
// network came back or the accounts changed, so the last failure says
// little about the next attempt.
func (e *proxyEngine) wakeAgainNow() {
	e.idle.mu.Lock()
	e.idle.wakeRetryAt, e.idle.wakeFailures, e.idle.wakeLasting = time.Time{}, 0, false
	e.idle.mu.Unlock()
}

// retryNow lets the next connection wake the engine at once, unless the
// last failure is one that retrying cannot fix (wakeLasting).
func (e *proxyEngine) retryNow() {
	e.idle.mu.Lock()
	if !e.idle.wakeLasting {
		e.idle.wakeRetryAt, e.idle.wakeFailures = time.Time{}, 0
	}
	e.idle.mu.Unlock()
}

// useController returns the engine's controller, waking the engine when
// it sleeps, and marks it in use until release is called.
func (d *Daemon) useController(e *proxyEngine, why wakeReason) (c *proxy.Controller, release func(), err error) {
	if c := e.reserve(); c != nil {
		return c, e.releaseFunc(), nil
	}
	e.idle.wakeMu.Lock()
	defer e.idle.wakeMu.Unlock()
	if c := e.reserve(); c != nil { // woken by another connection meanwhile
		return c, e.releaseFunc(), nil
	}
	if err, wait := e.wakeWait(why, time.Now()); err != nil {
		at, _, _ := e.wakeFailure()
		return nil, nil, fmt.Errorf("connecting to Mozilla failed %s ago; trying again in %s: %w", time.Since(at).Round(time.Second), wait.Round(time.Second), err)
	}
	wake := func(e *proxyEngine) error { return d.wake(e, why) }
	if d.wakeHook != nil {
		wake = d.wakeHook
	}
	if err := wake(e); err != nil {
		return nil, nil, err
	}
	if c := e.reserve(); c != nil {
		return c, e.releaseFunc(), nil
	}
	return nil, nil, errProxyNotRunning
}

func (e *proxyEngine) reserve() *proxy.Controller {
	e.idle.mu.Lock()
	defer e.idle.mu.Unlock()
	if e.controller != nil {
		e.idle.inUse++
		e.idle.lastUsed = time.Now()
	}
	return e.controller
}

func (e *proxyEngine) releaseFunc() func() {
	var once sync.Once
	return func() {
		once.Do(func() {
			e.idle.mu.Lock()
			e.idle.inUse--
			e.idle.lastUsed = time.Now()
			e.idle.mu.Unlock()
		})
	}
}

// wake connects a sleeping engine to Mozilla: the first time it selects
// the server (connectEngine), later it reuses it (reconnectEngine).
// idle.wakeMu is held.
func (d *Daemon) wake(e *proxyEngine, why wakeReason) error {
	if d.currentEngine() != e {
		return errProxyNotRunning
	}
	started := time.Now()
	first := !e.connected
	server, _ := e.selection()
	var controller *proxy.Controller
	var err error
	if first {
		controller, err = d.connectEngine(e)
	} else {
		controller, err = d.reconnectEngine(e)
	}
	if err != nil {
		code := failureCode(err)
		now := time.Now()
		e.idle.mu.Lock()
		e.idle.wakeFailures++
		wait := proxy.WakeRetryDelay(err, e.idle.wakeFailures, now)
		if e.selected.Addr != server.Addr {
			// The failover moved to another server of the location (only
			// the server's own failures do): the next wake tries it at once.
			e.idle.wakeFailures, wait = 0, 0
		}
		e.idle.wakeErr, e.idle.wakeCode, e.idle.wakeFailedAt = err, code, now
		e.idle.wakeRetryAt, e.idle.wakeLasting = now.Add(wait), proxy.LastingWakeFailure(err, now)
		e.idle.mu.Unlock()
		logx.Warn("connecting to Mozilla failed; the proxy stays idle and connections wait before trying again retry_in=%s err=%s", wait, logx.Err(err))
		if errors.Is(err, accounts.ErrNoUsableAccount) {
			// The restarted engine reports the wait for an account.
			d.RequestRestart()
		}
		return fmt.Errorf("connecting to Mozilla: %w", err)
	}
	if !d.runController(e, controller) {
		return errProxyNotRunning
	}
	d.markConnected()
	if !first {
		logx.Info("proxy woke up for a connection account=%s took=%s", logx.Email(d.pool.ActiveName()), time.Since(started).Round(time.Millisecond))
		return nil
	}
	logx.Info("proxy connected for its first use account=%s took=%s", logx.Email(d.pool.ActiveName()), time.Since(started).Round(time.Millisecond))
	if why != wakeForTest {
		go d.autoTest(e, "proxy connected")
	}
	d.registerDevices()
	return nil
}

// registerDevices shows every account as "Firefox's built-in VPN" in its
// Mozilla connected services (accounts already registered are skipped),
// once per run, after the proxy first connected: until then the program
// sends Mozilla nothing.
func (d *Daemon) registerDevices() {
	d.devicesOnce.Do(func() {
		go func() {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			go func() {
				select {
				case <-d.stop:
					cancel()
				case <-ctx.Done():
				}
			}()
			d.pool.EnsureDevices(ctx)
		}()
	})
}

// sleepWhenIdle puts the engine to sleep after proxy.idle_sleep without a
// connection through Mozilla, until the engine stops.
func (d *Daemon) sleepWhenIdle(e *proxyEngine, stopped <-chan struct{}) {
	ticker := time.NewTicker(idleCheckInterval)
	defer ticker.Stop()
	for {
		select {
		case <-stopped:
			return
		case <-ticker.C:
		}
		d.sleepIfIdle(e)
	}
}

// sleepIfIdle puts the engine to sleep when proxy.idle_sleep is on and
// nothing has used its controller for that long, and reports whether it
// did.
func (d *Daemon) sleepIfIdle(e *proxyEngine) bool {
	limit := d.config().Proxy.IdleSleep.Duration()
	if limit <= 0 {
		return false
	}
	e.idle.mu.Lock()
	var c *proxy.Controller
	if e.controller != nil && e.idle.inUse == 0 && time.Since(e.idle.lastUsed) >= limit {
		c, e.controller, e.idle.sleeping = e.controller, nil, time.Now()
	}
	e.idle.mu.Unlock()
	if c == nil {
		return false
	}
	_ = c.Close()
	if err := proxy.WriteIdleStatus(e.statusFile, proxy.StatusSleeping); err != nil {
		logx.Warn("writing status file failed path=%s err=%s", e.statusFile, logx.Err(err))
	}
	logx.Info("no connection through Mozilla for %s; the proxy sleeps and the account is not used until the next connection", limit)
	return true
}

// engineUpstream opens the engine's tunnels through its controller,
// waking it when it sleeps, and keeps it awake while a tunnel is open.
type engineUpstream struct {
	d      *Daemon
	engine *proxyEngine
}

func (u *engineUpstream) OpenTunnel(authority string) (net.Conn, error) {
	return u.OpenTunnelForClient(authority, "")
}

func (u *engineUpstream) OpenTunnelForClient(authority, clientKey string) (net.Conn, error) {
	c, release, err := u.d.useController(u.engine, wakeForClient)
	if err != nil {
		return nil, err
	}
	var conn net.Conn
	if clientKey != "" {
		conn, err = c.OpenTunnelForClient(authority, clientKey)
	} else {
		conn, err = c.OpenTunnel(authority)
	}
	if err != nil {
		release()
		return nil, err
	}
	return releasingConn(conn, release), nil
}

// releasingConn calls release when conn closes, keeping half-close.
func releasingConn(conn net.Conn, release func()) net.Conn {
	r := &releaseConn{Conn: conn, release: release}
	if _, ok := conn.(interface{ CloseWrite() error }); ok {
		return halfClosingReleaseConn{r}
	}
	return r
}

type releaseConn struct {
	net.Conn
	release func()
}

func (c *releaseConn) Close() error {
	err := c.Conn.Close()
	c.release()
	return err
}

type halfClosingReleaseConn struct{ *releaseConn }

func (c halfClosingReleaseConn) CloseWrite() error {
	return c.Conn.(interface{ CloseWrite() error }).CloseWrite()
}
