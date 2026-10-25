//go:build !windows

package service

import "syscall"

// errAddressInUse is the system's error for a taken address.
var errAddressInUse error = syscall.EADDRINUSE
