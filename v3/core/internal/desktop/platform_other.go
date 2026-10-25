//go:build !windows

package desktop

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"syscall"

	"github.com/armanlife/firefox-vpn-client/core/internal/service"
)

func enableTerminalColors() bool {
	return os.Getenv("TERM") != "dumb"
}

func StartedWithOwnConsole() bool { return false }

func DetachConsole() {}

// acquireSingleInstance makes sure only one desktop host (the tray icon or
// the app mode) runs per data folder, with an advisory lock that the kernel
// releases when the process exits.
func acquireSingleInstance(paths service.DataPaths) (release func(), ok bool) {
	f, err := os.OpenFile(filepath.Join(paths.Dir, ".tray.lock"), os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return func() {}, true
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		_ = f.Close()
		return func() {}, false
	}
	return func() { _ = f.Close() }, true
}

// notify shows a desktop notification when notify-send is available.
func notify(title, body string) {
	path, err := exec.LookPath("notify-send")
	if err != nil {
		return
	}
	cmd := exec.Command(path, "--app-name=Firefox VPN", "--", title, body)
	if err := cmd.Start(); err != nil {
		return
	}
	go func() { _ = cmd.Wait() }()
}

// browserAvailable reports whether openBrowser can show a page here: on
// macOS, or on a Linux desktop (a display and xdg-open). A server has
// neither; the console then gives the dashboard's address instead.
func browserAvailable() bool {
	if runtime.GOOS == "darwin" {
		return true
	}
	if os.Getenv("DISPLAY") == "" && os.Getenv("WAYLAND_DISPLAY") == "" {
		return false
	}
	_, err := exec.LookPath("xdg-open")
	return err == nil
}

// openBrowser opens url in the default browser.
func openBrowser(url string) error {
	opener := "xdg-open"
	if runtime.GOOS == "darwin" {
		opener = "open"
	}
	cmd := exec.Command(opener, url)
	if err := cmd.Start(); err != nil {
		return err
	}
	go func() { _ = cmd.Wait() }()
	return nil
}
