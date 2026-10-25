//go:build windows

package desktop

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"strings"
	"unsafe"

	"github.com/armanlife/firefox-vpn-client/core/internal/service"

	"golang.org/x/sys/windows"
)

var (
	kernel32                  = windows.NewLazySystemDLL("kernel32.dll")
	procGetConsoleProcessList = kernel32.NewProc("GetConsoleProcessList")
	procFreeConsole           = kernel32.NewProc("FreeConsole")
)

// StartedWithOwnConsole reports whether this process is alone on its
// console, which is the case when it was started from Explorer rather than
// from a terminal.
func StartedWithOwnConsole() bool {
	var pids [4]uint32
	n, _, _ := procGetConsoleProcessList.Call(uintptr(unsafe.Pointer(&pids[0])), uintptr(len(pids)))
	return n == 1
}

// DetachConsole closes the console window of a process started from
// Explorer; the tray icon replaces it.
func DetachConsole() {
	_, _, _ = procFreeConsole.Call()
}

// acquireSingleInstance makes sure only one desktop host (the tray icon or
// the app mode) runs per data folder. The returned release function is a
// no-op when another instance owns it.
func acquireSingleInstance(paths service.DataPaths) (release func(), ok bool) {
	name := trayMutexName(paths)
	h, err := windows.CreateMutex(nil, false, name)
	if errors.Is(err, windows.ERROR_ALREADY_EXISTS) {
		if h != 0 {
			_ = windows.CloseHandle(h)
		}
		return func() {}, false
	}
	if err != nil {
		// Without a mutex, prefer running over refusing to start.
		return func() {}, true
	}
	return func() { _ = windows.CloseHandle(h) }, true
}

func trayMutexName(paths service.DataPaths) *uint16 {
	sum := sha256.Sum256([]byte(strings.ToLower(paths.Dir)))
	name, _ := windows.UTF16PtrFromString(`Local\FirefoxVPN-tray-` + hex.EncodeToString(sum[:8]))
	return name
}

// notify does nothing on Windows. A toast needs a WinRT binding or a
// hidden script host, and antivirus heuristics flag the latter; the tray
// shows the state in its icon and tooltip, and the desktop app shows its
// own notifications.
func notify(title, body string) {}

// browserAvailable reports whether openBrowser can show a page: always on
// Windows.
func browserAvailable() bool { return true }

// openBrowser opens url in the default browser.
func openBrowser(url string) error {
	verb, _ := windows.UTF16PtrFromString("open")
	target, err := windows.UTF16PtrFromString(url)
	if err != nil {
		return err
	}
	return windows.ShellExecute(0, verb, target, nil, nil, windows.SW_SHOWNORMAL)
}

// enableTerminalColors turns on ANSI escape processing for the console
// (Windows 10 1511 and later) and sets the window title.
func enableTerminalColors() bool {
	h := windows.Handle(os.Stdout.Fd())
	var mode uint32
	if err := windows.GetConsoleMode(h, &mode); err != nil {
		return false
	}
	if err := windows.SetConsoleMode(h, mode|windows.ENABLE_VIRTUAL_TERMINAL_PROCESSING|windows.ENABLE_PROCESSED_OUTPUT); err != nil {
		return false
	}
	os.Stdout.WriteString("\x1b]0;Firefox VPN\x07")
	return true
}
