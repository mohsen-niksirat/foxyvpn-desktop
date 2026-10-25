//go:build windows

package desktop

import (
	"errors"
	"runtime"
	"sync"
	"unsafe"

	"golang.org/x/sys/windows"
)

// Windows tells programs that the user signs out or the computer shuts down
// only through messages to their top-level windows (WM_QUERYENDSESSION,
// then WM_ENDSESSION), and ends them soon after. The core of the desktop
// app has no window and no console of its own, so without one it would be
// ended before it restores the system proxy, which would then point every
// application at a closed port after the next sign-in. A hidden window
// receives those messages; the work runs before WM_ENDSESSION returns,
// which Windows waits for.

var (
	user32End            = windows.NewLazySystemDLL("user32.dll")
	procRegisterClassExW = user32End.NewProc("RegisterClassExW")
	procCreateWindowExW  = user32End.NewProc("CreateWindowExW")
	procDefWindowProcW   = user32End.NewProc("DefWindowProcW")
	procGetMessageW      = user32End.NewProc("GetMessageW")
	procDispatchMessageW = user32End.NewProc("DispatchMessageW")
	procPostMessageW     = user32End.NewProc("PostMessageW")
	procPostQuitMessage  = user32End.NewProc("PostQuitMessage")
)

const (
	wmDestroy         = 0x0002
	wmClose           = 0x0010
	wmQueryEndSession = 0x0011
	wmEndSession      = 0x0016
)

type wndClassExW struct {
	size       uint32
	style      uint32
	wndProc    uintptr
	clsExtra   int32
	wndExtra   int32
	instance   windows.Handle
	icon       windows.Handle
	cursor     windows.Handle
	background windows.Handle
	menuName   *uint16
	className  *uint16
	iconSm     windows.Handle
}

type msgW struct {
	hwnd    uintptr
	message uint32
	wParam  uintptr
	lParam  uintptr
	time    uint32
	pt      struct{ x, y int32 }
	private uint32
}

// endSession is the one hidden window of the process and what it calls.
var endSession struct {
	mu    sync.Mutex
	onEnd func()
	once  *sync.Once
}

var registerEndSessionClass = sync.OnceValues(func() (*uint16, error) {
	name, _ := windows.UTF16PtrFromString("FirefoxVPNCoreEndSession")
	cls := wndClassExW{
		wndProc:   windows.NewCallback(endSessionWndProc),
		className: name,
	}
	cls.size = uint32(unsafe.Sizeof(cls))
	if r, _, err := procRegisterClassExW.Call(uintptr(unsafe.Pointer(&cls))); r == 0 {
		return nil, err
	}
	return name, nil
})

func endSessionWndProc(hwnd, msg, wParam, lParam uintptr) uintptr {
	switch msg {
	case wmQueryEndSession:
		return 1 // agree: the work happens on WM_ENDSESSION
	case wmEndSession:
		if wParam != 0 {
			endSession.mu.Lock()
			onEnd, once := endSession.onEnd, endSession.once
			endSession.mu.Unlock()
			if onEnd != nil {
				once.Do(onEnd)
			}
		}
		return 0
	case wmDestroy:
		procPostQuitMessage.Call(0)
		return 0
	}
	r, _, _ := procDefWindowProcW.Call(hwnd, msg, wParam, lParam)
	return r
}

// startEndSessionWindow creates the hidden window that calls onEnd (once)
// when Windows ends the session, and returns it with a function that
// removes it.
func startEndSessionWindow(onEnd func()) (uintptr, func(), error) {
	class, err := registerEndSessionClass()
	if err != nil {
		return 0, nil, err
	}
	endSession.mu.Lock()
	endSession.onEnd, endSession.once = onEnd, new(sync.Once)
	endSession.mu.Unlock()

	created := make(chan uintptr, 1)
	failed := make(chan error, 1)
	go func() {
		// A window belongs to the thread that made it and gets its
		// messages there.
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		hwnd, _, err := procCreateWindowExW.Call(0, uintptr(unsafe.Pointer(class)), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
		if hwnd == 0 {
			failed <- err
			return
		}
		created <- hwnd
		var m msgW
		for {
			r, _, _ := procGetMessageW.Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0)
			if int32(r) <= 0 {
				return
			}
			procDispatchMessageW.Call(uintptr(unsafe.Pointer(&m)))
		}
	}()
	select {
	case hwnd := <-created:
		stop := func() {
			endSession.mu.Lock()
			endSession.onEnd = nil
			endSession.mu.Unlock()
			// DefWindowProc destroys the window on WM_CLOSE.
			procPostMessageW.Call(hwnd, wmClose, 0, 0)
		}
		return hwnd, stop, nil
	case err := <-failed:
		if err == nil {
			err = errors.New("creating the window failed")
		}
		return 0, nil, err
	}
}

// watchEndSession calls onEnd when Windows signs the user out or shuts
// down; the returned function stops watching.
func watchEndSession(onEnd func()) (func(), error) {
	_, stop, err := startEndSessionWindow(onEnd)
	if err != nil {
		return func() {}, err
	}
	return stop, nil
}
