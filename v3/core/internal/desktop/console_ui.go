package desktop

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode/utf8"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
	"github.com/armanlife/firefox-vpn-client/core/internal/service"
	"github.com/armanlife/firefox-vpn-client/core/internal/version"

	"golang.org/x/term"
)

// The terminal screen: a compact, colored status view with a short numbered
// list of actions (type a number and press Enter), shown instead of the raw log when the program runs in
// an interactive terminal. It deliberately offers only the basics;
// everything else is in the dashboard.
//
// When another copy already serves the data folder (the desktop app's
// core, a tray, or a systemd service), the screen only controls it, and
// closing the window leaves it running. Otherwise the proxy runs in this
// window, on every system, and closing the window stops it.

// consoleBackend is what the screen shows and controls: the daemon in this
// process, or a service in another process through the local API.
type consoleBackend interface {
	status(ctx context.Context) (service.StatusView, error)
	connectionTest(ctx context.Context) (proxy.ConnectionTestResult, error)
	restart(ctx context.Context) error
	ping(ctx context.Context) ([]proxy.LocationPing, error)
	setLocation(ctx context.Context, country string) error
	setSystemProxy(ctx context.Context, mode string) error
	resetLogin(ctx context.Context) (dashboardLogin, error)
	logsSince(ctx context.Context, after uint64) ([]logx.Entry, error)
}

type daemonBackend struct{ d *service.Daemon }

func (b daemonBackend) status(context.Context) (service.StatusView, error) { return b.d.StatusView() }
func (b daemonBackend) connectionTest(context.Context) (proxy.ConnectionTestResult, error) {
	return b.d.ConnectionTest()
}
func (b daemonBackend) restart(context.Context) error { b.d.RequestRestart(); return nil }
func (b daemonBackend) ping(ctx context.Context) ([]proxy.LocationPing, error) {
	results, _, err := b.d.PingAll(ctx, nil)
	return results, err
}
func (b daemonBackend) setLocation(_ context.Context, country string) error {
	return b.d.SetLocation(country)
}
func (b daemonBackend) setSystemProxy(_ context.Context, mode string) error {
	return b.d.SetSystemProxy(mode)
}
func (b daemonBackend) resetLogin(context.Context) (dashboardLogin, error) {
	username, password, err := b.d.ResetDashboardLogin()
	return dashboardLogin{Username: username, Password: password}, err
}
func (b daemonBackend) logsSince(_ context.Context, after uint64) ([]logx.Entry, error) {
	return logx.Logs.Since(after), nil
}

type apiBackend struct{ c *service.Client }

func (b apiBackend) status(ctx context.Context) (service.StatusView, error) {
	var view service.StatusView
	err := b.c.Do(ctx, http.MethodGet, "/api/status", nil, &view)
	return view, err
}
func (b apiBackend) connectionTest(ctx context.Context) (proxy.ConnectionTestResult, error) {
	return b.c.ConnectionTest(ctx)
}
func (b apiBackend) restart(ctx context.Context) error { return b.c.RestartProxy(ctx) }
func (b apiBackend) ping(ctx context.Context) ([]proxy.LocationPing, error) {
	var out struct {
		Locations []proxy.LocationPing `json:"locations"`
	}
	err := b.c.Do(ctx, http.MethodPost, "/api/locations/ping", nil, &out)
	return out.Locations, err
}
func (b apiBackend) setLocation(ctx context.Context, country string) error {
	return b.c.Do(ctx, http.MethodPost, "/api/location", map[string]string{"country": country}, nil)
}
func (b apiBackend) setSystemProxy(ctx context.Context, mode string) error {
	return b.c.SetSystemProxy(ctx, mode)
}
func (b apiBackend) resetLogin(ctx context.Context) (dashboardLogin, error) {
	var login dashboardLogin
	err := b.c.Do(ctx, http.MethodPost, "/api/dashboard/reset-login", map[string]any{}, &login)
	return login, err
}

// dashboardLogin is a dashboard username and password.
type dashboardLogin struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func (b apiBackend) logsSince(ctx context.Context, after uint64) ([]logx.Entry, error) {
	var out struct {
		Entries []logx.Entry `json:"entries"`
	}
	err := b.c.Do(ctx, http.MethodGet, "/api/logs?after="+strconv.FormatUint(after, 10), nil, &out)
	return out.Entries, err
}

// ANSI styles. 256-color codes work in Windows 10+ consoles, Windows
// Terminal, and common Linux terminals.
const (
	ansiReset  = "\x1b[0m"
	ansiBold   = "\x1b[1m"
	ansiDim    = "\x1b[2m"
	ansiOrange = "\x1b[38;5;208m"
	ansiPurple = "\x1b[38;5;141m"
	ansiGreen  = "\x1b[38;5;78m"
	ansiYellow = "\x1b[38;5;221m"
	ansiRed    = "\x1b[38;5;203m"
	ansiCyan   = "\x1b[38;5;117m"
	ansiGrey   = "\x1b[38;5;245m"
)

type screenMode int

const (
	screenHome screenMode = iota
	screenLogs
	screenPing
	screenResetLogin
)

type consoleUI struct {
	paths   service.DataPaths
	verbose bool
	out     io.Writer

	mu       sync.Mutex
	backend  consoleBackend
	own      *service.Daemon // the daemon in this process, nil in client mode
	mode     screenMode
	status   *service.StatusView
	statusAt time.Time
	lastErr  string
	message  string
	msgColor string
	busy     bool
	pings    []proxy.LocationPing
	logLines []logx.Entry
	// newLogin is the dashboard login just reset, shown until the reset
	// screen is left.
	newLogin *dashboardLogin
	lastLog  uint64
	quitting bool
	input    string // the number typed at the prompt

	// sysproxy applies system_proxy.mode for the daemon in this process,
	// as the tray and the app mode do; stopSync ends that and restores the
	// previous setting.
	sysproxy systemProxySync
	stopSync func()
}

// RunConsole shows the terminal screen until the user quits. It returns
// false when the terminal cannot show it, so the caller can fall back to
// the plain log.
func RunConsole(paths service.DataPaths, verbose bool) (bool, error) {
	if !term.IsTerminal(int(os.Stdin.Fd())) || !term.IsTerminal(int(os.Stdout.Fd())) {
		return false, nil
	}
	if !enableTerminalColors() {
		return false, nil
	}
	if !logx.EnableFile(paths.LogDir, false) {
		logx.SetOutput(io.Discard)
	}
	ui := &consoleUI{paths: paths, verbose: verbose, out: os.Stdout}
	if err := ui.connect(); err != nil {
		return true, err
	}

	oldState, err := term.MakeRaw(int(os.Stdin.Fd()))
	if err != nil {
		ui.stopOwn()
		return false, nil
	}
	fmt.Fprint(ui.out, "\x1b[?1049h\x1b[?25l") // alternate screen, hide cursor
	restore := func() {
		fmt.Fprint(ui.out, "\x1b[?25h\x1b[?1049l")
		_ = term.Restore(int(os.Stdin.Fd()), oldState)
	}
	defer restore()

	keys := make(chan rune, 16)
	go func() {
		reader := bufio.NewReader(os.Stdin)
		for {
			r, _, err := reader.ReadRune()
			if err != nil {
				close(keys)
				return
			}
			keys <- r
		}
	}()
	// Closing the terminal window sends SIGHUP on Linux and macOS (SIGTERM
	// on Windows); caught, it stops the proxy and restores the system proxy
	// like 0 does.
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM, syscall.SIGHUP)
	defer signal.Stop(signals)

	ui.poll()
	ui.render()
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for !ui.isQuitting() {
		select {
		case <-ticker.C:
			go ui.poll()
		case <-signals:
			ui.quit()
		case key, ok := <-keys:
			if !ok {
				ui.quit()
				break
			}
			ui.handleKey(key)
		}
		ui.render()
	}
	if ui.ownsDaemon() {
		ui.setMessage("Stopping…", ansiYellow)
		ui.render()
		ui.stopOwn()
	}
	return true, nil
}

// connect uses the copy that already serves the data folder (the desktop
// app's core, a tray, or a systemd service on Linux). Otherwise it runs the
// proxy in this window.
func (ui *consoleUI) connect() error {
	client := service.NewClient(ui.paths)
	ui.backend = apiBackend{c: client}
	if reachable(client, 2*time.Second) {
		return nil
	}
	return ui.startOwn()
}

// startOwn runs the proxy in this process. Like the app mode, it applies
// system_proxy.mode while the proxy runs; stopOwn restores the previous
// setting before the proxy stops.
func (ui *consoleUI) startOwn() error {
	d, err := service.NewDaemon(ui.paths, ui.verbose)
	if err != nil {
		return err
	}
	d.OpenFolder = openBrowser
	d.SystemProxySupported = systemProxySupported()
	runDone := make(chan struct{})
	ctx, cancel := context.WithCancel(context.Background())
	syncDone := make(chan struct{})
	ui.mu.Lock()
	ui.own = d
	ui.backend = daemonBackend{d: d}
	ui.status = nil
	// No sync runs before the goroutine below starts it.
	ui.sysproxy.report = d.SetSystemProxyTaken
	ui.stopSync = func() {
		cancel()
		<-syncDone
		ui.sysproxy.clear()
	}
	ui.mu.Unlock()
	go func() {
		defer close(runDone)
		if err := d.Run(); err != nil {
			logx.Error("%s", logx.Err(err))
			ui.setMessage(err.Error(), ansiRed)
		}
	}()
	go func() {
		defer close(syncDone)
		ui.sysproxy.follow(ctx, func() (service.TrayStatus, error) {
			select {
			case <-runDone:
				// A daemon that stopped counts as unreachable, so the
				// setting is removed.
				return service.TrayStatus{}, errors.New("the proxy stopped")
			default:
				return daemonTrayStatus(d)
			}
		}, appPollInterval)
	}()
	return nil
}

func (ui *consoleUI) stopOwn() {
	ui.mu.Lock()
	d, stopSync := ui.own, ui.stopSync
	ui.own, ui.stopSync = nil, nil
	ui.mu.Unlock()
	// The system proxy goes back first, so applications are never left
	// pointed at a closed port.
	if stopSync != nil {
		stopSync()
	}
	if d != nil {
		d.Shutdown()
	}
}

func (ui *consoleUI) ownsDaemon() bool {
	ui.mu.Lock()
	defer ui.mu.Unlock()
	return ui.own != nil
}

func (ui *consoleUI) isQuitting() bool {
	ui.mu.Lock()
	defer ui.mu.Unlock()
	return ui.quitting
}

func (ui *consoleUI) quit() {
	ui.mu.Lock()
	ui.quitting = true
	ui.mu.Unlock()
}

func (ui *consoleUI) setMessage(text, color string) {
	ui.mu.Lock()
	ui.message, ui.msgColor = text, color
	ui.mu.Unlock()
}

// poll refreshes the status and new log lines.
func (ui *consoleUI) poll() {
	ui.mu.Lock()
	backend, after := ui.backend, ui.lastLog
	ui.mu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	view, err := backend.status(ctx)
	entries, _ := backend.logsSince(ctx, after)

	ui.mu.Lock()
	defer ui.mu.Unlock()
	if err != nil {
		ui.lastErr = err.Error()
	} else {
		ui.lastErr = ""
		ui.status = &view
		ui.statusAt = time.Now()
	}
	if len(entries) > 0 {
		ui.logLines = append(ui.logLines, entries...)
		if len(ui.logLines) > 300 {
			ui.logLines = ui.logLines[len(ui.logLines)-300:]
		}
		ui.lastLog = entries[len(entries)-1].ID
	}
}

// run performs a slow action in the background with a busy message.
func (ui *consoleUI) run(busyText string, action func(ctx context.Context) (string, error)) {
	ui.mu.Lock()
	if ui.busy {
		// One task at a time; say so rather than ignoring the choice.
		ui.mu.Unlock()
		ui.setMessage("Please wait until the current task finishes, then try again.", ansiYellow)
		return
	}
	ui.busy = true
	ui.message, ui.msgColor = busyText, ansiYellow
	ui.mu.Unlock()
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
		defer cancel()
		text, err := action(ctx)
		ui.mu.Lock()
		ui.busy = false
		ui.mu.Unlock()
		if err != nil {
			ui.setMessage(err.Error(), ansiRed)
		} else {
			ui.setMessage(text, ansiGreen)
		}
		ui.poll()
	}()
}

// digitAliases maps Persian and Arabic-Indic digits to ASCII digits, so
// numbers can be typed without switching the keyboard layout.
var digitAliases = map[rune]rune{
	'۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4', '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
	'٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4', '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
}

func normalizeKey(r rune) rune {
	if alias, ok := digitAliases[r]; ok {
		return alias
	}
	return r
}

const maxInputDigits = 3

// handleKey edits the number at the prompt; Enter runs it, Esc clears it
// or goes back, Ctrl+C closes the window.
func (ui *consoleUI) handleKey(r rune) {
	r = normalizeKey(r)
	ui.mu.Lock()
	switch {
	case r == 3: // Ctrl+C
		ui.mu.Unlock()
		ui.quit()
		return
	case r == '\r' || r == '\n':
		input := ui.input
		ui.input = ""
		ui.mu.Unlock()
		ui.submit(input)
		return
	case r == 8 || r == 127: // Backspace
		if n := len(ui.input); n > 0 {
			ui.input = ui.input[:n-1]
		}
	case r == 27: // Esc
		if ui.input != "" {
			ui.input = ""
		} else {
			ui.switchModeLocked(screenHome)
		}
	case r >= '0' && r <= '9' && len(ui.input) < maxInputDigits:
		ui.input += string(r)
	}
	ui.mu.Unlock()
}

// Actions of the main menu.
const (
	actDashboard = "dashboard"
	actLocation  = "location"
	actTest      = "test"
	actRestart   = "restart"
	actStart     = "start"
	actLog       = "log"
	actSysProxy  = "system-proxy"
	actReset     = "reset-login"
	actExit      = "exit"
)

// Fixed entries at the top of the location screen.
const (
	locFastest = iota + 1
	locRecommended
	locMeasure
	locFirst // the first measured location
)

// submit runs the number typed at the prompt.
func (ui *consoleUI) submit(text string) {
	if text == "" {
		return
	}
	n, err := strconv.Atoi(text)
	if err != nil {
		return
	}
	ui.mu.Lock()
	mode, items := ui.mode, ui.menuItems()
	ui.mu.Unlock()
	switch mode {
	case screenLogs:
		ui.setMode(screenHome)
	case screenPing:
		ui.submitLocation(n)
	case screenResetLogin:
		ui.submitResetLogin(n)
	default:
		switch {
		case n == 0:
			ui.quit()
		case n >= 1 && n <= len(items):
			ui.do(items[n-1].action)
		default:
			ui.setMessage(fmt.Sprintf("Enter a number from 0 to %d", len(items)), ansiYellow)
		}
	}
}

func (ui *consoleUI) submitLocation(n int) {
	ui.mu.Lock()
	backend, pings := ui.backend, ui.pings
	ui.mu.Unlock()
	switch {
	case n == 0:
		ui.setMode(screenHome)
	case n == locFastest:
		ui.chooseLocation(backend, proxy.FastestCountry, "Auto (fastest)")
	case n == locRecommended:
		ui.chooseLocation(backend, "", "Auto (recommended)")
	case n == locMeasure:
		ui.measure(backend)
	case n >= locFirst && n-locFirst < len(pings):
		p := pings[n-locFirst]
		if !p.OK() {
			ui.setMessage(p.Name+" did not answer the real-delay test: "+p.Error, ansiYellow)
			return
		}
		ui.chooseLocation(backend, p.Code, p.Name)
	default:
		ui.setMessage("Enter a number from the list", ansiYellow)
	}
}

// do runs a main-menu action.
func (ui *consoleUI) do(action string) {
	ui.mu.Lock()
	backend, own, status, pings := ui.backend, ui.own != nil, ui.status, ui.pings
	ui.mu.Unlock()
	switch action {
	case actDashboard:
		url, err := service.NewClient(ui.paths).DashboardPageURL()
		if err != nil {
			ui.setMessage(err.Error(), ansiRed)
			break
		}
		if browserAvailable() {
			if err := openBrowser(url); err == nil {
				ui.setMessage("Opened "+url+" in the browser", ansiGreen)
				break
			}
		}
		// No browser here (a server): how to reach it instead.
		listen := ""
		if cfg, _, err := config.Load(ui.paths.Config); err == nil {
			listen = cfg.Dashboard.Listen
		}
		ui.setMessage(dashboardHowTo(listen, localAddresses()), ansiCyan)
	case actLocation:
		ui.setMode(screenPing)
		if len(pings) == 0 {
			ui.measure(backend)
		}
	case actTest:
		ui.run("Testing the connection through the tunnel…", func(ctx context.Context) (string, error) {
			result, err := backend.connectionTest(ctx)
			if err != nil {
				return "", err
			}
			if !result.OK {
				return "", fmt.Errorf("connection test failed: %s", result.Error)
			}
			text := fmt.Sprintf("Connection works: %d ms", result.TotalMS)
			if exit := result.Exit(); exit.IP() != "" {
				text += fmt.Sprintf(", public IP %s (%s)", exit.IP(), exit.Place())
			}
			return text, nil
		})
	case actRestart:
		ui.run("Restarting the proxy…", func(ctx context.Context) (string, error) {
			return "Proxy restarting", backend.restart(ctx)
		})
	case actStart:
		ui.run("Starting the proxy…", func(context.Context) (string, error) {
			return "Started", ui.startOwn()
		})
	case actLog:
		ui.setMode(screenLogs)
	case actReset:
		ui.setMode(screenResetLogin)
	case actSysProxy:
		mode, done := config.SystemProxySet, "System proxy on: browsers and apps that use the system's proxy setting now go through the VPN"
		if status != nil && status.SystemProxy == config.SystemProxySet {
			mode, done = config.SystemProxyClear, "System proxy off: browsers and apps connect directly again"
		}
		ui.run("Changing the system proxy…", func(ctx context.Context) (string, error) {
			return done, backend.setSystemProxy(ctx, mode)
		})
	case actExit:
		ui.exitCompletely(own, status)
	}
}

// exitCompletely stops the proxy and closes the window. A copy that no
// tray or desktop app hosts (another terminal, systemd) cannot be ended
// from here.
func (ui *consoleUI) exitCompletely(own bool, status *service.StatusView) {
	if own {
		ui.quit()
		return
	}
	if status == nil || !status.CanExit {
		ui.setMessage("This copy cannot be exited from here; stop it where it runs (its terminal, or systemd).", ansiYellow)
		return
	}
	// Exiting never waits for another task (such as a latency measurement).
	ui.setMessage("Exiting Firefox VPN…", ansiYellow)
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		if err := service.NewClient(ui.paths).ExitApp(ctx); err != nil {
			ui.setMessage(err.Error(), ansiRed)
			return
		}
		ui.quit()
	}()
}

func (ui *consoleUI) setMode(mode screenMode) {
	ui.mu.Lock()
	ui.switchModeLocked(mode)
	ui.mu.Unlock()
}

// switchModeLocked shows another screen. The message under the prompt
// belongs to the screen it was shown on, so it goes, unless it reports a
// task that is still running.
func (ui *consoleUI) switchModeLocked(mode screenMode) {
	if mode != ui.mode && !ui.busy {
		ui.message = ""
	}
	if mode != screenResetLogin {
		ui.newLogin = nil // the password is shown only once
	}
	ui.mode = mode
}

// submitResetLogin handles the reset screen: 1 confirms, 0 goes back.
func (ui *consoleUI) submitResetLogin(n int) {
	ui.mu.Lock()
	backend, done := ui.backend, ui.newLogin != nil
	ui.mu.Unlock()
	switch {
	case n == 0:
		ui.setMode(screenHome)
	case n == 1 && !done:
		ui.run("Creating a new dashboard login…", func(ctx context.Context) (string, error) {
			login, err := backend.resetLogin(ctx)
			if err != nil {
				return "", err
			}
			ui.mu.Lock()
			ui.newLogin = &login
			ui.mu.Unlock()
			return "New dashboard login created; write it down", nil
		})
	default:
		ui.setMessage("Enter 1 to reset or 0 to go back", ansiYellow)
	}
}

func (ui *consoleUI) measure(backend consoleBackend) {
	ui.run("Testing the real delay of every location through the tunnel (up to a minute on slow networks)…", func(ctx context.Context) (string, error) {
		results, err := backend.ping(ctx)
		if err != nil {
			return "", err
		}
		ui.mu.Lock()
		ui.pings = results
		ui.mu.Unlock()
		reachable := 0
		for _, r := range results {
			if r.OK() {
				reachable++
			}
		}
		return fmt.Sprintf("%d of %d locations answered", reachable, len(results)), nil
	})
}

func (ui *consoleUI) chooseLocation(backend consoleBackend, country, label string) {
	ui.run("Saving the location…", func(ctx context.Context) (string, error) {
		if err := backend.setLocation(ctx, country); err != nil {
			return "", err
		}
		return "Server set: " + label + "; the proxy restarts", nil
	})
}

// ---------------------------------------------------------------- render

func (ui *consoleUI) render() {
	width, height, err := term.GetSize(int(os.Stdout.Fd()))
	if err != nil || width <= 0 {
		width, height = 80, 25
	}
	width = min(width, 110)
	ui.mu.Lock()
	var lines []string
	switch ui.mode {
	case screenLogs:
		lines = ui.logsScreen(width, height)
	case screenPing:
		lines = ui.pingScreen(width, height)
	case screenResetLogin:
		lines = ui.resetLoginScreen(width, height)
	default:
		lines = ui.homeScreen(width, height)
	}
	ui.mu.Unlock()

	var b strings.Builder
	b.WriteString("\x1b[H")
	for i, line := range lines {
		if i >= height {
			break
		}
		b.WriteString(fitWidth(line, width))
		b.WriteString(ansiReset + "\x1b[K")
		if i < len(lines)-1 && i < height-1 {
			b.WriteString("\r\n")
		}
	}
	b.WriteString("\x1b[J")
	fmt.Fprint(ui.out, b.String())
}

func (ui *consoleUI) header(width int) []string {
	title := ansiBold + ansiOrange + "  ◆ FIREFOX VPN" + ansiReset + ansiGrey + "  version " + version.Current + ansiReset
	return []string{"", title, ansiGrey + "  " + strings.Repeat("─", max(10, min(width-4, 64))) + ansiReset}
}

func (ui *consoleUI) homeScreen(width, height int) []string {
	lines := ui.header(width)
	row := func(label, value string) {
		lines = append(lines, "    "+ansiGrey+padRight(label, 11)+ansiReset+value)
	}
	st := ui.status

	// State line.
	label, text, color := "connecting", "Connecting…", ansiGrey
	switch {
	case st == nil && ui.lastErr != "":
		label, text, color = "stopped", "Firefox VPN is not running", ansiRed
	case st != nil && ui.lastErr != "":
		label, text = "unreachable", "Firefox VPN does not answer"
	case st != nil:
		label, text = phaseLabel(st.State.Phase), st.State.Message
		switch st.State.Phase {
		case service.PhaseRunning:
			color, text = ansiGreen, locationText(st)
			if st.Proxy != nil && !st.Proxy.SleepingSince.IsZero() {
				label, color = "sleeping", ansiGrey
				text += ansiGrey + "  (no connection since " + st.Proxy.SleepingSince.Local().Format("15:04") + "; the next one wakes it)" + ansiReset
			}
		case service.PhaseError:
			color = ansiRed
		default:
			color = ansiYellow
		}
	}
	lines = append(lines, "", "  "+color+"● "+ansiBold+strings.ToUpper(label)+ansiReset+"  "+text, "")

	if st != nil && st.Proxy != nil {
		row("Proxy", ansiCyan+st.Proxy.Listen+ansiReset+ansiGrey+"  "+proxyAccess(st.Proxy.Listen, st.Proxy.LoginRequired)+ansiReset)
	}
	if url, err := service.NewClient(ui.paths).DashboardPageURL(); err == nil {
		where := ""
		if cfg, _, err := config.Load(ui.paths.Config); err == nil && isLoopbackListen(cfg.Dashboard.Listen) {
			where = ansiGrey + "  this computer only" + ansiReset
		}
		row("Dashboard", ansiCyan+url+ansiReset+where)
	}
	if st != nil {
		if a := st.ActiveAccount; a != nil {
			name := a.Name
			if name == "" {
				name = a.Email
			}
			row("Account", name+"  "+usageBar(a, st.Threshold))
		} else if st.Accounts["total"] == 0 {
			row("Account", ansiYellow+"none yet: add one in the dashboard (D)"+ansiReset)
		}
	}

	lines = append(lines, "", ansiBold+"  What would you like to do?"+ansiReset, "")
	for i, item := range ui.menuItems() {
		lines = append(lines, menuLine(i+1, item.label))
	}
	closeLabel := "Close this window (Firefox VPN keeps running)"
	if ui.own != nil {
		closeLabel = "Quit (stops the proxy)"
	}
	lines = append(lines, menuLine(0, closeLabel))
	return append(lines, "", ui.promptLine(), "  "+ui.messageLine())
}

func menuLine(n int, label string) string {
	return "    " + ansiOrange + ansiBold + padLeft(strconv.Itoa(n), 2) + ansiReset + "  " + label
}

func (ui *consoleUI) promptLine() string {
	return "  " + ansiBold + "Enter a number and press Enter: " + ansiReset + ansiCyan + ui.input + "▌" + ansiReset
}

type menuItem struct {
	action, label string
}

// menuItems lists the main-menu actions numbered from 1; 0 always closes
// the window.
func (ui *consoleUI) menuItems() []menuItem {
	st, own := ui.status, ui.own != nil
	online := st != nil && ui.lastErr == ""
	dashboard := "Open the dashboard in the browser"
	if !browserAvailable() {
		dashboard = "How to open the dashboard (no browser on this machine)"
	}
	items := []menuItem{{action: actDashboard, label: dashboard}}
	if online {
		items = append(items,
			menuItem{action: actLocation, label: "Choose a server (test the real delay)"},
			menuItem{action: actTest, label: "Test the connection"},
			menuItem{action: actRestart, label: "Restart the proxy"})
		if systemProxySupported() {
			label := "Turn on system proxy"
			if st.SystemProxy == config.SystemProxySet {
				label = "Turn off system proxy"
			}
			items = append(items, menuItem{action: actSysProxy, label: label})
		}
	} else if !own {
		items = append(items, menuItem{action: actStart, label: "Start Firefox VPN"})
	}
	if online {
		label := "Reset the dashboard login (forgotten password: new random username and password)"
		if on, _ := st.Dashboard["login_required"].(bool); !on {
			label = "Create a dashboard login (random username and password)"
		}
		items = append(items, menuItem{action: actReset, label: label})
	}
	items = append(items, menuItem{action: actLog, label: "Show the log"})
	if !own && st != nil && st.CanExit {
		items = append(items, menuItem{action: actExit, label: "Exit Firefox VPN completely"})
	}
	return items
}

func (ui *consoleUI) messageLine() string {
	if ui.message == "" {
		return ""
	}
	prefix := "› "
	if ui.busy {
		prefix = spinnerFrame() + " "
	}
	return ui.msgColor + prefix + ui.message + ansiReset
}

func (ui *consoleUI) logsScreen(width, height int) []string {
	lines := ui.header(width)
	lines = append(lines, ansiBold+"  Log"+ansiReset+ansiGrey+"  (newest last; full log: "+logx.DayFile(ui.paths.LogDir, time.Now())+")"+ansiReset)
	// The four lines below the log (Back, a gap, the prompt, the message)
	// must fit in the window, or the prompt falls off its bottom.
	const footer = 4
	room := max(1, height-len(lines)-footer)
	for _, entry := range lastEntries(ui.logLines, room, true) {
		lines = append(lines, formatLogLine(entry, width))
	}
	for len(lines) < height-footer {
		lines = append(lines, "")
	}
	return append(lines, menuLine(0, "Back"), "", ui.promptLine(), "  "+ui.messageLine())
}

// resetLoginScreen asks before resetting the dashboard login and then
// shows the new one.
func (ui *consoleUI) resetLoginScreen(width, height int) []string {
	lines := ui.header(width)
	lines = append(lines, ansiBold+"  Reset the dashboard login"+ansiReset, "")
	if login := ui.newLogin; login != nil {
		lines = append(lines,
			"  The dashboard now asks for this login:", "",
			"    "+ansiGrey+padRight("Username", 10)+ansiReset+ansiBold+ansiCyan+login.Username+ansiReset,
			"    "+ansiGrey+padRight("Password", 10)+ansiReset+ansiBold+ansiCyan+login.Password+ansiReset, "",
			ansiYellow+"  Write it down: the password is not shown again."+ansiReset,
			ansiGrey+"  You can change both in the dashboard, Settings, Dashboard."+ansiReset, "",
			menuLine(0, "Back"))
	} else {
		lines = append(lines,
			"  This replaces the dashboard's username and password with new random",
			"  ones and shows them here. Every browser signed in to the dashboard is",
			"  signed out and must use the new login.", "",
			menuLine(1, "Reset the login now"),
			menuLine(0, "Back"))
	}
	for len(lines) < height-4 {
		lines = append(lines, "")
	}
	return append(lines, "", ui.promptLine(), "  "+ui.messageLine())
}

func (ui *consoleUI) pingScreen(width, height int) []string {
	lines := ui.header(width)
	current := ""
	if ui.status != nil && ui.status.Proxy != nil {
		current = strings.ToUpper(ui.status.Proxy.CountryCode)
	}
	lines = append(lines, ansiBold+"  Choose a server"+ansiReset, "",
		menuLine(locFastest, "Auto (fastest: tested at every start)"),
		menuLine(locRecommended, "Auto (recommended: Mozilla chooses)"),
		menuLine(locMeasure, "Test the real delay again"),
		"", ansiGrey+"  Servers, lowest real delay first (time to reach "+proxy.PingTarget+" through each)"+ansiReset)
	if len(ui.pings) == 0 {
		lines = append(lines, ansiGrey+"    No measurement yet."+ansiReset)
	}
	worst := int64(1)
	for _, p := range ui.pings {
		if p.OK() && p.PingMS > worst {
			worst = p.PingMS
		}
	}
	room := height - len(lines) - 5
	for i, p := range ui.pings {
		if i >= room {
			lines = append(lines, ansiGrey+fmt.Sprintf("    … %d more in the dashboard", len(ui.pings)-i)+ansiReset)
			break
		}
		name := p.Name
		if p.Recommended {
			name = "Recommended (anycast)"
		}
		marker := "  "
		if p.Code == current {
			marker = ansiGreen + "● " + ansiReset
		}
		value := ansiRed + padRight(p.Error, 22) + ansiReset
		if p.OK() {
			color := ansiGreen
			if p.PingMS > 150 {
				color = ansiYellow
			}
			if p.PingMS > 300 {
				color = ansiRed
			}
			barLen := int(max(1, p.PingMS*20/worst))
			value = color + padLeft(strconv.FormatInt(p.PingMS, 10)+" ms", 8) + "  " + strings.Repeat("▇", barLen) + ansiReset
		}
		number := "    " + ansiOrange + ansiBold + padLeft(strconv.Itoa(locFirst+i), 2) + ansiReset + "  "
		lines = append(lines, number+marker+ansiBold+padRight(p.Code, 4)+ansiReset+padRight(truncateRunes(name, 24), 25)+value)
	}
	return append(lines, "", menuLine(0, "Back"), "", ui.promptLine(), "  "+ui.messageLine())
}

// ---------------------------------------------------------------- helpers

func phaseLabel(phase string) string {
	switch phase {
	case service.PhaseRunning:
		return "connected"
	case service.PhaseStarting:
		return "starting"
	case service.PhaseWaiting:
		return "waiting"
	case service.PhaseError:
		return "error"
	}
	return phase
}

func locationText(st *service.StatusView) string {
	if st.Proxy == nil {
		return st.State.Message
	}
	place := st.Proxy.CountryName
	if st.Proxy.CityName != "" && st.Proxy.CityName != place {
		place += " · " + st.Proxy.CityName
	}
	if strings.EqualFold(st.Proxy.CountryCode, "REC") || place == "" {
		place = "Recommended location"
	}
	return ansiBold + place + ansiReset + ansiGrey + "  " + st.Proxy.Upstream + ansiReset
}

func transportLabel(t string) string {
	if t == "h3" {
		return "HTTP/3"
	}
	return "HTTP/2"
}

func usageBar(a *service.AccountView, threshold float64) string {
	if a.Usage == nil {
		return ansiGrey + "quota unknown until first use" + ansiReset
	}
	if a.Usage.Unlimited {
		return ansiGreen + "unlimited" + ansiReset
	}
	const cells = 20
	filled := int(a.UsedPercent / 100 * cells)
	filled = min(cells, max(0, filled))
	color := ansiGreen
	if a.UsedPercent >= threshold-10 {
		color = ansiYellow
	}
	if a.UsedPercent >= threshold {
		color = ansiRed
	}
	const gib = 1 << 30
	return color + strings.Repeat("█", filled) + ansiGrey + strings.Repeat("░", cells-filled) + ansiReset +
		fmt.Sprintf("  %.1f / %.1f GiB  %s%.0f%%%s", float64(a.Usage.UsedBytes())/gib, float64(a.Usage.LimitBytes)/gib, ansiBold, a.UsedPercent, ansiReset)
}

func lastEntries(entries []logx.Entry, n int, debug bool) []logx.Entry {
	var out []logx.Entry
	for i := len(entries) - 1; i >= 0 && len(out) < n; i-- {
		if entries[i].Level == "DEBUG" && !debug {
			continue
		}
		out = append(out, entries[i])
	}
	for i, j := 0, len(out)-1; i < j; i, j = i+1, j-1 {
		out[i], out[j] = out[j], out[i]
	}
	return out
}

func formatLogLine(entry logx.Entry, width int) string {
	color := ansiCyan
	switch entry.Level {
	case "WARN":
		color = ansiYellow
	case "ERROR":
		color = ansiRed
	case "DEBUG":
		color = ansiGrey
	}
	prefix := "   " + ansiGrey + entry.Time.Local().Format("15:04:05") + ansiReset + " " + color + padRight(entry.Level, 5) + ansiReset + " "
	return prefix + truncateRunes(entry.Message, max(10, width-visibleLen(prefix)-1))
}

func spinnerFrame() string {
	frames := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
	return frames[(time.Now().UnixMilli()/250)%int64(len(frames))]
}

// visibleLen counts the runes of s outside ANSI escape sequences.
func visibleLen(s string) int {
	n, inEscape := 0, false
	for _, r := range s {
		switch {
		case inEscape:
			if (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') {
				inEscape = false
			}
		case r == 0x1b:
			inEscape = true
		default:
			n++
		}
	}
	return n
}

// fitWidth cuts s to width visible runes, keeping escape sequences intact.
func fitWidth(s string, width int) string {
	if visibleLen(s) <= width {
		return s
	}
	var b strings.Builder
	n, inEscape := 0, false
	for _, r := range s {
		switch {
		case inEscape:
			b.WriteRune(r)
			if (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') {
				inEscape = false
			}
		case r == 0x1b:
			inEscape = true
			b.WriteRune(r)
		case n < width-1:
			b.WriteRune(r)
			n++
		case n == width-1:
			b.WriteRune('…')
			n++
		}
	}
	return b.String()
}

func truncateRunes(s string, n int) string {
	if utf8.RuneCountInString(s) <= n {
		return s
	}
	r := []rune(s)
	return string(r[:max(0, n-1)]) + "…"
}

func padRight(s string, n int) string {
	if pad := n - utf8.RuneCountInString(s); pad > 0 {
		return s + strings.Repeat(" ", pad)
	}
	return s
}

func padLeft(s string, n int) string {
	if pad := n - utf8.RuneCountInString(s); pad > 0 {
		return strings.Repeat(" ", pad) + s
	}
	return s
}

// proxyAccess describes the proxy for the status screen: what it speaks,
// whether it asks for a login, and who can reach it.
func proxyAccess(listen string, login bool) string {
	auth := "no password"
	if login {
		auth = "username and password"
	}
	reach := "open to the network"
	if isLoopbackListen(listen) {
		reach = "this computer only"
	}
	return "SOCKS5 and HTTP · " + auth + " · " + reach
}

// isLoopbackListen reports whether a listen address takes connections
// from this computer only.
func isLoopbackListen(listen string) bool {
	host, _, err := net.SplitHostPort(listen)
	if err != nil {
		return false
	}
	if strings.EqualFold(host, "localhost") {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

// localAddresses lists this computer's IPv4 addresses other than loopback.
func localAddresses() []string {
	var out []string
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return nil
	}
	for _, a := range addrs {
		if n, ok := a.(*net.IPNet); ok && n.IP.To4() != nil && !n.IP.IsLoopback() && !n.IP.IsLinkLocalUnicast() {
			out = append(out, n.IP.String())
		}
	}
	return out
}

// dashboardHowTo tells how to open the dashboard when this computer has no
// browser (a server): from another device at one of addrs when it listens
// on the network, else through an SSH tunnel to this computer.
func dashboardHowTo(listen string, addrs []string) string {
	_, port, err := net.SplitHostPort(listen)
	if err != nil || port == "" {
		port = "10820"
	}
	if !isLoopbackListen(listen) && len(addrs) > 0 {
		urls := make([]string, len(addrs))
		for i, a := range addrs {
			urls[i] = "http://" + net.JoinHostPort(a, port) + "/app/"
		}
		return "No browser here. From another device open " + strings.Join(urls, " or ")
	}
	return "No browser here; the dashboard answers this computer only. From your own computer run " +
		"ssh -L " + port + ":127.0.0.1:" + port + " <user>@<this server>, then open http://127.0.0.1:" + port + "/app/"
}
