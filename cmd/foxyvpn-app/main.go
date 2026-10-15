// foxyvpn-desktop app — Stage 2: web UI + core manager + local proxies.
//
// Run: foxyvpn-app [-ui 127.0.0.1:8080] [-country NL] [-no-browser]
package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"strconv"
	"time"

	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/core"
	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/proxy"
	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/tun"
	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/ui"
)

type stdLogger struct{}

func (stdLogger) Logf(format string, args ...interface{}) {
	log.Printf(format, args...)
}

var logFile *os.File

func dlog(format string, args ...interface{}) {
	msg := fmt.Sprintf("%s "+format+"\n", append([]interface{}{time.Now().Format("15:04:05")}, args...)...)
	fmt.Print(msg)
	if logFile != nil {
		logFile.WriteString(msg)
	}
}

func main() {
	// File log next to the exe (or home) for diagnosing silent/short-lived runs.
	dir := exeDir()
	f, err := os.OpenFile(filepath.Join(dir, "foxyvpn-debug.log"),
		os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err == nil {
		logFile = f
		log.SetOutput(f)
	}
	defer func() {
		if r := recover(); r != nil {
			dlog("PANIC: %v\n%s", r, debug.Stack())
		}
	}()

	uiAddr := flag.String("ui", "127.0.0.1:8080", "web UI listen address")
	country := flag.String("country", "", "preferred upstream country code")
	noBrowser := flag.Bool("no-browser", false, "do not open the UI in a browser")
	flag.Parse()

	dlog("starting (os=%s arch=%s pid=%d)", runtime.GOOS, runtime.GOARCH, os.Getpid())

	home, _ := os.UserHomeDir()
	cred := &core.FileCredentialStore{Path: filepath.Join(home, ".foxyvpn-desktop-token.json")}
	mgr := core.NewManager(stdLogger{}, cred)
	if *country != "" {
		mgr.SetCountry(*country)
	} else if last := ui.LoadLastCountry(); last != "" {
		mgr.SetCountry(last)
		dlog("restored last country: %s", last)
	}

	proxies := proxy.NewServers(mgr, mgr.AddTraffic,
		func(f string, a ...interface{}) { dlog("[proxy] "+f, a...) },
		nil)

	srv := ui.New(mgr, proxies)
	srv.SetQuit(func() {
		dlog("quit requested; exiting")
		core.DisableSystemProxy()
		tun.StopAll()
		os.Exit(0)
	})
	port, err := srv.Listen(portOf(*uiAddr))
	if err != nil {
		dlog("FATAL: UI listen failed: %v", err)
		holdOpen()
		return
	}
	url := fmt.Sprintf("http://127.0.0.1:%d", port)
	dlog("UI ready: %s", url)

	if !*noBrowser {
		go func() {
			time.Sleep(400 * time.Millisecond) // let the server settle
			dlog("opening browser: %s", url)
			var cmd *exec.Cmd
			switch runtime.GOOS {
			case "windows":
				// Use cmd /c start to fully detach; rundll32 direct spawn has
				// been implicated in premature exits when double-clicked.
				cmd = exec.Command("cmd", "/c", "start", "", url)
			case "darwin":
				cmd = exec.Command("open", url)
			default:
				cmd = exec.Command("xdg-open", url)
			}
			cmd.SysProcAttr = detachAttr()
			if err := cmd.Start(); err != nil {
				dlog("browser open failed: %v", err)
			} else {
				go cmd.Wait()
				dlog("browser spawn ok")
			}
		}()
	}

	dlog("entering keep-alive loop")
	select {}
}

func holdOpen() {
	dlog("press Enter to exit")
	fmt.Scanln()
}

func exeDir() string {
	exe, err := os.Executable()
	if err != nil {
		home, _ := os.UserHomeDir()
		return home
	}
	return filepath.Dir(exe)
}

func portOf(addr string) int {
	_, portStr, err := net.SplitHostPort(addr)
	if err != nil {
		return 8080
	}
	p, err := strconv.Atoi(portStr)
	if err != nil || p == 0 {
		return 8080
	}
	return p
}
