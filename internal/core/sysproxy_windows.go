//go:build windows

// System-wide WinINET proxy management (Settings > Network > Proxy).
package core

import (
	"fmt"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows/registry"
)

const (
	internetKey                   = `Software\Microsoft\Windows\CurrentVersion\Internet Settings`
	internetOptionRefresh         = 37
	internetOptionSettingsChanged = 39
)

var (
	wininet               = syscall.NewLazyDLL("wininet.dll")
	procInternetSetOption = wininet.NewProc("InternetSetOption")
)

func setOption(opt uint32) {
	defer func() { recover() }() // never crash the app over a notify failure
	if procInternetSetOption.Find() != nil {
		return // wininet missing (rare); registry change still applies
	}
	buf := make([]byte, 4)
	procInternetSetOption.Call(
		0,
		uintptr(opt),
		uintptr(unsafe.Pointer(&buf[0])),
		uintptr(unsafe.Sizeof(buf)),
	)
}

// EnableSystemProxy sets the WinINET HTTP proxy to 127.0.0.1:port.
func EnableSystemProxy(port int) error {
	k, err := registry.OpenKey(registry.CURRENT_USER, internetKey, registry.SET_VALUE)
	if err != nil {
		return fmt.Errorf("open internet settings: %w", err)
	}
	defer k.Close()
	if err := k.SetDWordValue("ProxyEnable", 1); err != nil {
		return err
	}
	if err := k.SetStringValue("ProxyServer", fmt.Sprintf("127.0.0.1:%d", port)); err != nil {
		return err
	}
	// Bypass local addresses
	_ = k.SetStringValue("ProxyOverride", "localhost;127.*;10.*;172.16.*;192.168.*;<local>")
	setOption(internetOptionSettingsChanged)
	setOption(internetOptionRefresh)
	return nil
}

// DisableSystemProxy turns the WinINET proxy off.
func DisableSystemProxy() error {
	k, err := registry.OpenKey(registry.CURRENT_USER, internetKey, registry.SET_VALUE)
	if err != nil {
		return fmt.Errorf("open internet settings: %w", err)
	}
	defer k.Close()
	if err := k.SetDWordValue("ProxyEnable", 0); err != nil {
		return err
	}
	setOption(internetOptionSettingsChanged)
	setOption(internetOptionRefresh)
	return nil
}
