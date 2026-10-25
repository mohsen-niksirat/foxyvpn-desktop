//go:build !windows && !linux && !darwin

package desktop

func systemProxySupported() bool { return false }

func setSystemProxy(string) error { return nil }

func restoreSystemProxy(string) error { return nil }

func clearSystemProxy() error { return nil }

func systemProxyTaken(string) (bool, string) { return false, "" }
