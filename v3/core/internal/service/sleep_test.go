package service

import (
	"net"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
)

// sleepyEngine is an engine whose wake only installs a new (empty)
// controller, counting wakes.
func sleepyEngine(t *testing.T, idleSleep time.Duration) (*Daemon, *proxyEngine, *atomic.Int32) {
	t.Helper()
	d := newTestDaemon(t)
	cfg := d.config()
	cfg.Proxy.IdleSleep = config.Duration(idleSleep)
	if _, err := d.updateSettings(cfg, nil); err != nil {
		t.Fatal(err)
	}
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	e := &proxyEngine{controller: &proxy.Controller{}, listener: ln}
	e.routed = proxy.NewRoutedOpener(&engineUpstream{d: d, engine: e})
	t.Cleanup(func() { _ = ln.Close(); e.routed.Close() })
	e.idle.touch()
	d.mu.Lock()
	d.engine = e
	d.mu.Unlock()
	var wakes atomic.Int32
	d.wakeHook = func(e *proxyEngine) error {
		time.Sleep(20 * time.Millisecond) // a pass and a session take a while
		wakes.Add(1)
		e.idle.mu.Lock()
		e.controller, e.idle.sleeping = &proxy.Controller{}, time.Time{}
		e.idle.mu.Unlock()
		return nil
	}
	return d, e, &wakes
}

func idleFor(e *proxyEngine, d time.Duration) {
	e.idle.mu.Lock()
	e.idle.lastUsed = time.Now().Add(-d)
	e.idle.mu.Unlock()
}

// The proxy sleeps only after the idle time without use, and wakes once
// for many connections arriving together.
func TestIdleSleepAndWake(t *testing.T) {
	d, e, wakes := sleepyEngine(t, 15*time.Minute)

	idleFor(e, 10*time.Minute)
	if d.sleepIfIdle(e) {
		t.Fatal("not idle long enough")
	}
	idleFor(e, 16*time.Minute)
	if !d.sleepIfIdle(e) || e.currentController() != nil || e.asleepSince().IsZero() {
		t.Fatal("idle for 16 minutes: asleep")
	}
	if view, _ := d.StatusView(); view.Pass != nil || view.Proxy == nil || view.Proxy.SleepingSince.IsZero() {
		t.Fatal("a sleeping proxy reports no pass and since when it sleeps")
	}

	// Connections arriving together wake it once.
	var wg sync.WaitGroup
	releases := make(chan func(), 5)
	for i := 0; i < 5; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			c, release, err := d.useController(e, wakeForClient)
			if err != nil || c == nil {
				t.Error(err)
				return
			}
			releases <- release
		}()
	}
	wg.Wait()
	close(releases)
	if wakes.Load() != 1 || !e.asleepSince().IsZero() {
		t.Fatalf("woken %d times", wakes.Load())
	}

	// An open connection keeps it awake however long it lasts.
	idleFor(e, time.Hour)
	if d.sleepIfIdle(e) {
		t.Fatal("asleep while connections are open")
	}
	for release := range releases {
		release()
		release() // releasing twice counts once
	}
	if d.sleepIfIdle(e) {
		t.Fatal("asleep right after the last connection closed")
	}
	idleFor(e, 16*time.Minute)
	if !d.sleepIfIdle(e) {
		t.Fatal("idle again: asleep")
	}
}

func TestIdleSleepOff(t *testing.T) {
	d, e, _ := sleepyEngine(t, 0)
	idleFor(e, 24*time.Hour)
	if d.sleepIfIdle(e) || e.currentController() == nil {
		t.Fatal("idle_sleep 0 never sleeps")
	}
}

// A tunnel keeps the controller in use until it is closed.
func TestReleasingConnKeepsHalfClose(t *testing.T) {
	released := 0
	tcp, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer tcp.Close()
	go func() {
		if c, err := tcp.Accept(); err == nil {
			c.Close()
		}
	}()
	raw, err := net.Dial("tcp", tcp.Addr().String())
	if err != nil {
		t.Fatal(err)
	}
	conn := releasingConn(raw, func() { released++ })
	if _, ok := conn.(interface{ CloseWrite() error }); !ok {
		t.Fatal("half-close must be kept")
	}
	_ = conn.Close()
	if released != 1 {
		t.Fatalf("released %d", released)
	}
}
