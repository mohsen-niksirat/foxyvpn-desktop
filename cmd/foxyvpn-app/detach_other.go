//go:build !windows

package main

import "syscall"

func detachAttr() *syscall.SysProcAttr { return nil }
