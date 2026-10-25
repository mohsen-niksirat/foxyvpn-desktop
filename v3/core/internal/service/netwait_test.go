package service

import (
	"net/http"
	"sync/atomic"
	"testing"
	"time"
)

func waitMessage(t *testing.T, d *Daemon, phase, message string) {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		d.mu.Lock()
		state := d.state
		d.mu.Unlock()
		if state.Phase == phase && state.Message == message {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	t.Fatalf("state %q %q, want %q %q", d.state.Phase, d.state.Message, phase, message)
}

func setNetwork(t *testing.T) *atomic.Bool {
	t.Helper()
	var online atomic.Bool
	oldConnected, oldPoll := networkConnected, networkPoll
	networkConnected, networkPoll = online.Load, 10*time.Millisecond
	t.Cleanup(func() { networkConnected, networkPoll = oldConnected, oldPoll })
	return &online
}

// Without a network the start waits and sends nothing; it starts as soon
// as a network connects. With no account, a start ends in "Add an
// account", which shows that it ran.
func TestEngineWaitsForNetwork(t *testing.T) {
	online := setNetwork(t)
	d := newTestDaemon(t)
	d.mu.Lock()
	d.cfg.Dashboard.Listen = "127.0.0.1:0"
	d.mu.Unlock()
	done := make(chan error, 1)
	go func() { done <- d.Run() }()
	defer func() {
		d.Shutdown()
		<-done
	}()
	waitMessage(t, d, PhaseWaiting, MessageWaitingForNetwork)
	time.Sleep(50 * time.Millisecond)
	waitMessage(t, d, PhaseWaiting, MessageWaitingForNetwork)

	// A restart request ends the wait, and the next start waits again.
	client := newDashboardClient(t, d)
	if rec := client.do(http.MethodPost, "/api/proxy/restart", nil); rec.Code != http.StatusOK {
		t.Fatalf("restart: %d", rec.Code)
	}
	waitMessage(t, d, PhaseWaiting, MessageWaitingForNetwork)

	online.Store(true)
	waitMessage(t, d, PhaseWaiting, "Add an account in the dashboard to start the proxy")
}
