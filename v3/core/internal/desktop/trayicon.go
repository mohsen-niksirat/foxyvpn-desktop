package desktop

import (
	"embed"
	"runtime"
)

// AppIconICO is the program's icon, the fox shield, in the sizes Windows
// uses, the small ones sharpened (made by app/tool/app_icons.py from the
// same art as the app's icons): the executable's resources (tools/winres).
//
//go:embed appicon.ico
var AppIconICO []byte

// trayFiles are the tray icons by state, made by app/tool/app_icons.py
// together with the app's tray icons: a disk in the state's color with the
// logo's shield in white. Windows takes the .ico files (several sizes), the
// other systems the 32 px .png files.
//
//go:embed tray
var trayFiles embed.FS

// Tray icon names.
const (
	iconRunning       = "running"
	iconRunningAsleep = "running-asleep" // running without a connection to Mozilla
	iconSet           = "set"            // running while Windows uses the proxy
	iconSetAsleep     = "set-asleep"
	iconWaiting       = "waiting"
	iconError         = "error"
	iconOff           = "off"
)

// trayIcon is the named tray icon in this system's format.
func trayIcon(name string) []byte {
	ext := ".png"
	if runtime.GOOS == "windows" {
		ext = ".ico"
	}
	data, _ := trayFiles.ReadFile("tray/" + name + ext)
	return data
}
