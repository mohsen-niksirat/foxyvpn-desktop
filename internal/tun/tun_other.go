//go:build !windows

// Package tun: no-op stub for non-Windows builds (TUN Mode is Windows-only
// in this project; Linux/macOS users can run hev-socks5-tunnel manually).
package tun

import "fmt"

type Runner struct{}

func Start(socksAddr, edgeAddr string) (*Runner, error) {
	return nil, fmt.Errorf("TUN mode is only supported on Windows builds")
}

func (r *Runner) Stop() {}

func StopGlobal() {}

func Active() bool { return false }

func StartGlobal(socksAddr, edgeAddr string) error {
	return fmt.Errorf("TUN mode is only supported on Windows builds")
}

// StopAll stops TUN if running (no-op stub on this platform).
func StopAll() {}
