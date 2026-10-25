//go:build windows

package desktop

import (
	"sync/atomic"
	"testing"
	"time"
)

var (
	procSendMessageW = user32End.NewProc("SendMessageW")
	procIsWindow     = user32End.NewProc("IsWindow")
)

func sendMessage(hwnd uintptr, msg, wParam uintptr) uintptr {
	r, _, _ := procSendMessageW.Call(hwnd, msg, wParam, 0)
	return r
}

// The hidden window agrees to end the session, calls onEnd once when the
// session really ends (not when it is cancelled), and goes away on stop.
func TestEndSessionWindow(t *testing.T) {
	var calls atomic.Int32
	hwnd, stop, err := startEndSessionWindow(func() { calls.Add(1) })
	if err != nil {
		t.Fatal(err)
	}
	if r := sendMessage(hwnd, wmQueryEndSession, 0); r != 1 {
		t.Fatalf("WM_QUERYENDSESSION returned %d, want 1", r)
	}
	sendMessage(hwnd, wmEndSession, 0) // another program cancelled it
	if n := calls.Load(); n != 0 {
		t.Fatalf("onEnd ran %d times for a cancelled end", n)
	}
	sendMessage(hwnd, wmEndSession, 1)
	sendMessage(hwnd, wmEndSession, 1)
	if n := calls.Load(); n != 1 {
		t.Fatalf("onEnd ran %d times, want 1", n)
	}

	stop()
	deadline := time.Now().Add(2 * time.Second)
	for {
		if r, _, _ := procIsWindow.Call(hwnd); r == 0 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("the window is still there after stop")
		}
		time.Sleep(10 * time.Millisecond)
	}

	// A second window (the class is registered once per process) works too.
	hwnd2, stop2, err := startEndSessionWindow(func() { calls.Add(1) })
	if err != nil {
		t.Fatal(err)
	}
	defer stop2()
	sendMessage(hwnd2, wmEndSession, 1)
	if n := calls.Load(); n != 2 {
		t.Fatalf("the second window's onEnd did not run (calls=%d)", n)
	}
}
