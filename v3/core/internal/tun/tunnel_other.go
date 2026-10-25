//go:build !linux && !windows

package tun

import "errors"

// Tunnel is a running userspace stack on a TUN device.
type Tunnel struct{}

// Start is not supported on this platform.
func Start(fd int, mtu uint32, dial Dialer, allow Allow, dns *FakeDNS) (*Tunnel, error) {
	return nil, errors.New("tun: unsupported on this platform")
}

func (t *Tunnel) Stop() {}

func IsSupported() bool { return false }
func IsAdmin() bool     { return false }

func StartGlobal(socksAddr, edgeAddr string) error {
	return errors.New("TUN mode is supported on Windows only")
}

func IsActive() bool { return false }
func StopGlobal()    {}
func StopAll()       {}
