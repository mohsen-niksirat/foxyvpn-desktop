//go:build windows || linux

package desktop

import (
	"context"
	"sync"
	"time"
	"unicode/utf16"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/service"
	"github.com/armanlife/firefox-vpn-client/core/internal/version"

	"fyne.io/systray"
)

const trayPollInterval = 3 * time.Second

// trayErrorShown is how long the tooltip shows a menu action's error.
const trayErrorShown = 2 * time.Minute

// trayApp is the notification-area icon. Its color and tooltip show the
// service state; its menu is kept short on purpose (dashboard, system
// proxy, restart, exit). Status details and accounts live in the dashboard
// and the terminal status screen. When no service is reachable it runs the
// service in its own process; when another copy already serves the data
// folder, it only talks to it through the local API.
type trayApp struct {
	paths   service.DataPaths
	verbose bool
	client  *service.Client

	mu  sync.Mutex
	own *service.Daemon // in-process service; nil when another process serves
	// Windows shows no notifications, so the tooltip carries the errors
	// that would have been one (all are logged too): why the service
	// could not start or stopped, until it answers again, and the last
	// menu action's error for trayErrorShown.
	startErr    string
	actionErr   string
	actionErrAt time.Time
	// newerVersion is set once a newer version of the program served the
	// data folder; this icon then never runs the service itself, so older
	// code does not take over a folder a newer version wrote, and it quits
	// when that copy stops, so a newer tray or app can take the folder.
	newerVersion string

	// Last observed state, for notifications on changes.
	seen        bool
	lastPhase   string
	lastMessage string
	lastAccount string
	lastReauth  int

	failures     int       // consecutive failed polls
	lastOwnStart time.Time // last attempt to run the service in-process
	sysproxy     systemProxySync
	// folderRequest is the last open-folder count seen in the status.
	folderRequest     uint64
	folderRequestSeen bool

	mOpen, mRestart, mQuit *systray.MenuItem
	// mModes are the system proxy modes, one checked (Windows).
	mModes                             map[string]*systray.MenuItem
	iconOK, iconWait, iconErr, iconOff []byte
	iconSet                            []byte
	// Faded running icons while the proxy sleeps (proxy.idle_sleep).
	iconOKAsleep, iconSetAsleep []byte
}

// RunTray shows the tray icon until the user quits.
func RunTray(paths service.DataPaths, verbose bool) error {
	release, ok := acquireSingleInstance(paths)
	if !ok {
		// A tray already runs for this data folder (two copies started at
		// once); this copy leaves.
		logx.Debug("tray: another tray serves this data folder; exiting")
		return nil
	}
	defer release()
	app := &trayApp{paths: paths, verbose: verbose, client: service.NewClient(paths)}
	app.iconOK = trayIcon(iconRunning)
	app.iconWait = trayIcon(iconWaiting)
	app.iconErr = trayIcon(iconError)
	app.iconOff = trayIcon(iconOff)
	app.iconSet = trayIcon(iconSet)
	app.iconOKAsleep = trayIcon(iconRunningAsleep)
	app.iconSetAsleep = trayIcon(iconSetAsleep)
	systray.Run(app.onReady, app.onExit)
	return nil
}

func (a *trayApp) onReady() {
	systray.SetIcon(a.iconOff)
	systray.SetTitle("Firefox VPN")
	systray.SetTooltip("Firefox VPN")

	// The layout follows v2rayN's tray menu.
	a.mOpen = systray.AddMenuItem("Open dashboard", "Open the web dashboard")
	if systemProxySupported() {
		systray.AddSeparator()
		a.mModes = map[string]*systray.MenuItem{}
		for _, m := range systemProxyModes {
			a.mModes[m.mode] = systray.AddMenuItemCheckbox(m.label, m.tip, false)
		}
	}
	systray.AddSeparator()
	a.mRestart = systray.AddMenuItem("Restart proxy", "Restart the proxy engine")
	systray.AddSeparator()
	a.mQuit = systray.AddMenuItem("Quit", "")
	systray.SetOnTapped(a.openDashboard)

	go a.handleClicks()
	go a.start()
}

func (a *trayApp) onExit() {
	a.sysproxy.clear()
	a.stopOwn()
}

// start decides whether to run the service in this process, then keeps the
// menu current.
func (a *trayApp) start() {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	_, err := a.client.Status(ctx)
	cancel()
	if err != nil {
		a.startOwn()
	} else {
		logx.Info("tray: using the running service")
	}
	a.refresh()
	ticker := time.NewTicker(trayPollInterval)
	defer ticker.Stop()
	for range ticker.C {
		a.refresh()
	}
}

func (a *trayApp) startOwn() {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.own != nil {
		return
	}
	a.lastOwnStart = time.Now()
	// The status screen's "exit completely" ends this process.
	d, err := newHostedDaemon(a.paths, a.verbose, systray.Quit)
	if err != nil {
		logx.Error("tray: starting the service failed err=%s", logx.Err(err))
		a.startErr = "Could not start: " + err.Error()
		notify("Firefox VPN could not start", err.Error())
		return
	}
	a.own = d
	go func() {
		err := d.Run()
		if err != nil {
			logx.Error("tray: the service stopped err=%s", logx.Err(err))
			notify("Firefox VPN stopped", err.Error())
		}
		a.mu.Lock()
		if err != nil {
			a.startErr = "Stopped: " + err.Error()
		}
		if a.own == d {
			a.own = nil
		}
		a.mu.Unlock()
	}()
}

func (a *trayApp) stopOwn() {
	a.mu.Lock()
	d := a.own
	a.own = nil
	a.mu.Unlock()
	if d != nil {
		d.Shutdown()
	}
}

func (a *trayApp) ownsService() bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.own != nil
}

// servedByNewer is the newer version that served the data folder, or "".
func (a *trayApp) servedByNewer() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return a.newerVersion
}

// actionFailed logs a menu action's error, keeps it for the tooltip, and
// shows it as a notification where there are notifications (Linux).
func (a *trayApp) actionFailed(title string, err error) {
	logx.Warn("tray: %s err=%s", title, logx.Err(err))
	a.mu.Lock()
	a.actionErr, a.actionErrAt = title+": "+err.Error(), time.Now()
	a.mu.Unlock()
	notify(title, err.Error())
}

// actionDone forgets the last menu action's error.
func (a *trayApp) actionDone() {
	a.mu.Lock()
	a.actionErr = ""
	a.mu.Unlock()
}

// problem is the error the tooltip shows, if any.
func (a *trayApp) problem() string {
	a.mu.Lock()
	defer a.mu.Unlock()
	switch {
	case a.startErr != "":
		return a.startErr
	case a.actionErr != "" && time.Since(a.actionErrAt) < trayErrorShown:
		return a.actionErr
	}
	return ""
}

// setTooltip shows text as the icon's hover text, followed by the error
// to show, if any.
func (a *trayApp) setTooltip(text string) {
	if problem := a.problem(); problem != "" {
		text += " · " + problem
	}
	systray.SetTooltip(capTooltip("Firefox VPN: " + text))
}

// maxTooltipUnits is the longest tooltip in UTF-16 units: Windows keeps it
// in 128 units, and the tray library copies it there without making room
// for the terminating zero.
const maxTooltipUnits = 127

// capTooltip shortens s to maxTooltipUnits, ending in "…" when it cuts.
func capTooltip(s string) string {
	if len(utf16.Encode([]rune(s))) <= maxTooltipUnits {
		return s
	}
	units := 0
	for i, r := range s {
		n := utf16.RuneLen(r)
		if units+n > maxTooltipUnits-1 { // room for the "…"
			return s[:i] + "…"
		}
		units += n
	}
	return s
}

// refresh polls the service and updates the icon, menu, and notifications.
func (a *trayApp) refresh() {
	st, err := pollStatus(a.client)
	if a.ownsService() {
		a.mQuit.SetTitle("Exit Firefox VPN (stops the proxy)")
	} else {
		a.mQuit.SetTitle("Close icon (the service keeps running)")
	}
	newer := a.servedByNewer()
	if err != nil {
		// Take over when the copy we were talking to has gone away. When it
		// was a newer version, this older icon quits instead and frees the
		// single-instance lock (onExit restores the system proxy).
		a.failures++
		if a.failures >= 2 && newer != "" && !a.ownsService() {
			logx.Info("tray: version %s no longer serves the data folder; this %s icon exits", newer, version.Current)
			systray.Quit()
			return
		}
		if a.failures >= 2 && newer == "" && !a.ownsService() && time.Since(a.lastOwnStart) > time.Minute {
			a.startOwn()
		}
		systray.SetIcon(a.iconOff)
		text := "Service not reachable"
		if a.ownsService() {
			text = "Starting…"
		}
		a.setTooltip(text)
		a.mRestart.Disable()
		a.sysproxy.update(nil)
		return
	}
	a.failures = 0
	a.mu.Lock()
	a.startErr = ""
	a.mu.Unlock()
	// A newer copy of the program serves the data folder (one in a
	// terminal, after an update). The icon keeps controlling it, but this
	// older code never runs the service on that folder again; it quits
	// once that copy stops.
	if !a.ownsService() && st.Version != "" && version.Newer(st.Version, version.Current) && newer != st.Version {
		logx.Info("tray: version %s serves the data folder; this %s icon no longer starts the service itself", st.Version, version.Current)
		a.mu.Lock()
		a.newerVersion = st.Version
		a.mu.Unlock()
		newer = st.Version
	}
	a.mRestart.Enable()
	// A copy that applies the mode itself keeps the setting; this icon only
	// shows it. For one that does not (the plain log mode), the tray does.
	hostApplies := !a.ownsService() && st.SystemProxyByHost
	if hostApplies {
		a.sysproxy.handOver(&st)
	} else {
		a.sysproxy.update(&st)
	}
	// A copy that runs without a desktop of its own (the plain log mode)
	// cannot open a window here; the dashboard's "Open folder" asks the
	// tray through the status.
	if a.folderRequestSeen && st.OpenFolderRequest > a.folderRequest {
		if err := openBrowser(a.paths.Dir); err != nil {
			a.actionFailed("Cannot open the folder", err)
		}
	}
	a.folderRequest, a.folderRequestSeen = st.OpenFolderRequest, true
	for mode, item := range a.mModes {
		if mode == st.SystemProxy {
			item.Check()
		} else {
			item.Uncheck()
		}
	}
	_, want := wantedSystemProxy(&st)
	active := a.sysproxy.active() || hostApplies && want != ""
	tip := st.Summary()
	if st.Accounts["reauth_required"] > 0 {
		// Windows shows no notifications, so the tooltip says it.
		tip += " · sign-in needed"
	}
	if newer != "" {
		tip += " · served by version " + newer
	}
	a.setTooltip(tip)
	switch st.State.Phase {
	case "running":
		asleep := st.Proxy != nil && !st.Proxy.SleepingSince.IsZero()
		switch {
		case active && asleep:
			systray.SetIcon(a.iconSetAsleep)
		case active:
			systray.SetIcon(a.iconSet)
		case asleep:
			systray.SetIcon(a.iconOKAsleep)
		default:
			systray.SetIcon(a.iconOK)
		}
	case "error":
		systray.SetIcon(a.iconErr)
	default:
		systray.SetIcon(a.iconWait)
	}
	a.notifyChanges(st)
}

// notifyChanges shows notifications for account switches, errors, and
// accounts that need signing in again.
func (a *trayApp) notifyChanges(st service.TrayStatus) {
	account := ""
	if st.ActiveAccount != nil {
		account = st.ActiveAccount.ID
	}
	reauth := st.Accounts["reauth_required"]
	if a.seen {
		if account != "" && a.lastAccount != "" && account != a.lastAccount {
			name := st.ActiveAccount.Name
			if name == "" {
				name = st.ActiveAccount.Email
			}
			notify("Switched account", "Now using "+name+".")
		}
		if st.State.Phase != a.lastPhase || st.State.Message != a.lastMessage {
			switch st.State.Phase {
			case "error":
				notify("Firefox VPN error", st.State.Message)
			case "waiting":
				// Waiting for Wi-Fi or a cable is expected, not news.
				if st.State.Code != service.CodeWaitingForNetwork {
					notify("Firefox VPN is waiting", st.State.Message)
				}
			case "running":
				if a.lastPhase == "error" || a.lastPhase == "waiting" {
					notify("Firefox VPN connected", "The proxy is running again.")
				}
			}
		}
		if reauth > a.lastReauth {
			notify("Sign-in needed", "An account must be signed in again in the dashboard.")
		}
	}
	a.seen = true
	a.lastPhase, a.lastMessage, a.lastAccount, a.lastReauth = st.State.Phase, st.State.Message, account, reauth
}

func (a *trayApp) handleClicks() {
	// A mode item's clicks are forwarded with its mode.
	modeClicks := make(chan string)
	for mode, item := range a.mModes {
		go func(mode string, clicks <-chan struct{}) {
			for range clicks {
				modeClicks <- mode
			}
		}(mode, item.ClickedCh)
	}
	for {
		select {
		case mode := <-modeClicks:
			go a.setSystemProxyMode(mode)
		case <-a.mOpen.ClickedCh:
			a.openDashboard()
		case <-a.mRestart.ClickedCh:
			go a.restartProxy()
		case <-a.mQuit.ClickedCh:
			systray.Quit()
			return
		}
	}
}

func (a *trayApp) openDashboard() {
	url, err := a.client.DashboardPageURL()
	if err == nil {
		err = openBrowser(url)
	}
	if err != nil {
		a.actionFailed("Cannot open the dashboard", err)
		return
	}
	a.actionDone()
}

// systemProxyModes are the tray's system proxy items, in v2rayN's order.
var systemProxyModes = []struct{ mode, label, tip string }{
	{config.SystemProxyClear, "Clear system proxy", "Browsers and apps connect directly again"},
	{config.SystemProxySet, "Set system proxy", "Browsers and apps that use the system's proxy setting go through the VPN while it runs"},
}

// setSystemProxyMode stores the system proxy mode; refresh applies it.
func (a *trayApp) setSystemProxyMode(mode string) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := a.client.SetSystemProxy(ctx, mode); err != nil {
		a.actionFailed("Changing the system proxy failed", err)
		a.refresh()
		return
	}
	a.actionDone()
	a.refresh()
}

func (a *trayApp) restartProxy() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := a.client.RestartProxy(ctx); err != nil {
		a.actionFailed("Restart failed", err)
		a.refresh()
		return
	}
	a.actionDone()
	a.refresh()
}
