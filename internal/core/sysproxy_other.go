//go:build !windows

package core

// EnableSystemProxy is a no-op on non-Windows platforms.
func EnableSystemProxy(port int) error { return nil }

// DisableSystemProxy is a no-op on non-Windows platforms.
func DisableSystemProxy() error { return nil }
