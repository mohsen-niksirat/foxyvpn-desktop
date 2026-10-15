// foxyvpn-wails: native Windows desktop shell around the same UI and core.
package wailsapp

import (
	"context"
	"embed"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/core"
	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/proxy"
	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/tun"
	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/ui"
	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	"github.com/wailsapp/wails/v2/pkg/options/windows"
	wailsruntime "github.com/wailsapp/wails/v2/pkg/runtime"
)

var wailsCtx context.Context

var _ = wailsCtx

type stdLogger struct{}

func (stdLogger) Logf(format string, args ...interface{}) { log.Printf(format, args...) }

//go:embed all:frontend/dist
var frontendFS embed.FS

func Run() {
	flag.Parse()

	// File log next to the exe for diagnosing issues.
	if exe, err := os.Executable(); err == nil {
		f, err := os.OpenFile(filepath.Join(filepath.Dir(exe), "foxyvpn-debug.log"),
			os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
		if err == nil {
			defer f.Close()
			log.SetOutput(f)
		}
	}
	log.Printf("starting wails app (os=%s)", runtime.GOOS)

	home, _ := os.UserHomeDir()
	cred := &core.FileCredentialStore{Path: filepath.Join(home, ".foxyvpn-desktop-token.json")}
	mgr := core.NewManager(stdLogger{}, cred)
	if last := ui.LoadLastCountry(); last != "" {
		mgr.SetCountry(last)
	}

	proxies := proxy.NewServers(mgr, mgr.AddTraffic,
		func(f string, a ...interface{}) { log.Printf("[proxy] "+f, a...) }, nil)

	srv := ui.New(mgr, proxies)
	srv.SetQuit(func() {
		core.DisableSystemProxy()
		tun.StopAll()
		if wailsCtx != nil {
			wailsruntime.Quit(wailsCtx) // closes the window gracefully
		}
	})

	// Real UI is embedded in frontend/dist; API routes come from srv.Handler().
	root := srv.Handler()

	sub, err := fs.Sub(frontendFS, "frontend/dist")
	if err != nil {
		sub = frontendFS
	}

	err = wails.Run(&options.App{
		Title:     "FoxyVPN Desktop",
		Width:     460,
		Height:    760,
		MinWidth:  380,
		MinHeight: 560,
		AssetServer: &assetserver.Options{
			Assets:  sub,
			Handler: root,
		},
		OnStartup: func(ctx context.Context) { wailsCtx = ctx },
		Windows: &windows.Options{
			WebviewIsTransparent: false,
			WindowIsTranslucent:  false,
		},
	})
	if err != nil {
		log.Printf("wails: %v", err)
		fmt.Println("FoxyVPN Desktop failed to start:", err)
		fmt.Scanln()
	}
	_ = time.Now
}
