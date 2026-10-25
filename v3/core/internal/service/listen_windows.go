package service

import "golang.org/x/sys/windows"

// errAddressInUse is what Winsock returns for a taken address; Go's
// syscall.EADDRINUSE on Windows is an invented value that never matches.
var errAddressInUse error = windows.WSAEADDRINUSE
