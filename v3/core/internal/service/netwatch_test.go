package service

import (
	"sync"
	"testing"
	"time"
)

// A computer's network changing counts as a change, as the phone's report
// does; the same reading does not.
func TestWatchNetworkSeesAChange(t *testing.T) {
	var mu sync.Mutex
	reading := "Wi-Fi=192.168.1.100,gw 192.168.1.1"
	oldNow, oldInterval := networkNow, networkWatchInterval
	networkNow = func() (string, bool) {
		mu.Lock()
		defer mu.Unlock()
		return reading, true
	}
	networkWatchInterval = 10 * time.Millisecond
	t.Cleanup(func() { networkNow, networkWatchInterval = oldNow, oldInterval })

	d := newTestDaemon(t)
	go d.watchNetwork()
	t.Cleanup(func() { d.stopOnce.Do(func() { close(d.stop) }) })

	time.Sleep(60 * time.Millisecond)
	if n := d.networkChanges.Load(); n != 0 {
		t.Fatalf("%d changes without one", n)
	}
	mu.Lock()
	reading = "Ethernet=10.0.0.5,gw 10.0.0.1"
	mu.Unlock()
	waitForCondition(t, 2*time.Second, func() bool { return d.networkChanges.Load() == 1 })
	view, err := d.StatusView()
	if err != nil || view.NetworkChangedAt.IsZero() {
		t.Fatalf("the change is not in the status: %v", err)
	}
}
