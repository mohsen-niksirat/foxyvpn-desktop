package service

import (
	"context"
	"errors"
	"fmt"
	"net"
	"runtime"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/accounts"
	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/fxa"
	"github.com/armanlife/firefox-vpn-client/core/internal/guardian"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/netstate"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
	"github.com/armanlife/firefox-vpn-client/core/internal/routing"
	"github.com/armanlife/firefox-vpn-client/core/internal/securefile"
	"github.com/armanlife/firefox-vpn-client/core/internal/serverlist"
	"github.com/armanlife/firefox-vpn-client/core/internal/tun"
	"github.com/armanlife/firefox-vpn-client/core/internal/version"
)

// engineStartRetry spaces attempts to start the proxy after an error that
// is neither "no accounts" nor "every account reserved".
const engineStartRetry = 30 * time.Second

// MessageWaitingForNetwork is the state message while the proxy start
// waits for a network.
const MessageWaitingForNetwork = "Waiting for a network connection"

// State codes (state.code in /api/status) name the waiting and error
// states, so that apps word them in their own language; the message stays
// the core's English, for the dashboard and for codes an app does not know.
// CodeProxyPortInUse is another.
const (
	// CodeWaitingForNetwork: the start waits for a network to connect.
	CodeWaitingForNetwork = "waiting_for_network"
	// CodeNoAccounts: the start waits for an enabled account (none added, or
	// every one turned off).
	CodeNoAccounts = "no_accounts"
	// CodeNoUsableAccount: there are accounts, but none can be used now
	// (each waits for a quota reset or a new sign-in); the message counts
	// them by status.
	CodeNoUsableAccount = "no_usable_account"
	// CodeStartFailed: the start failed for another reason and is retried
	// at retry_at; the message says why. A start sends nothing to Mozilla,
	// so this is a local problem, such as a listen address that cannot be
	// used; then address is that address.
	CodeStartFailed = "start_failed"
)

// networkConnected reports a connected network; tests replace it.
var networkConnected = netstate.Connected

// networkPoll is how often a wait for the network looks again; the check
// reads the adapter list and sends nothing. Tests shorten it.
var networkPoll = 2 * time.Second

// networkSettleRetry retries a failed start soon after the network
// connected, when DNS or DHCP may still be settling.
const networkSettleRetry = 5 * time.Second

// Engine phases reported to the dashboard.
const (
	PhaseStarting = "starting"
	PhaseRunning  = "running"
	PhaseWaiting  = "waiting"
	PhaseError    = "error"
	// PhaseOff: the app turned the proxy off (SetOn); the API still runs.
	PhaseOff = "off"
)

type engineState struct {
	Phase   string `json:"phase"`
	Message string `json:"message"`
	// Code names the state for clients that word it themselves (the State
	// codes, CodeProxyPortInUse); it is empty for the ordinary states and
	// cleared by the next state. Message stays the core's English.
	Code string `json:"code,omitempty"`
	// Address is the listen address the code is about.
	Address string    `json:"address,omitempty"`
	Since   time.Time `json:"since"`
	RetryAt time.Time `json:"retry_at,omitzero"`
}

// Daemon owns the configuration, the accounts, the running proxy engine,
// and the dashboard. The dashboard keeps running while the proxy engine is
// stopped, waiting for an account, or restarting after a settings change.
type Daemon struct {
	paths DataPaths
	// notices outlives engine restarts, so the dashboard can still explain
	// a refused request after the proxy restarted.
	notices *proxy.Notices
	// sessionKey signs the dashboard's session cookies.
	sessionKey []byte
	// autoTesting is set while an automatic connection test runs.
	autoTesting atomic.Bool
	// tokenOnly makes the API answer only the local token or a signed-in
	// browser (RequireLocalToken).
	tokenOnly atomic.Bool
	routing   routingState
	// wakeHook replaces wake in tests.
	wakeHook func(*proxyEngine) error
	// devicesOnce registers the accounts' devices after the first
	// connection to Mozilla (registerDevices).
	devicesOnce  sync.Once
	forceVerbose bool
	store        *accounts.Store
	mgr          *accounts.Manager
	pool         *proxy.AccountPool
	// failover moves the upstream to another server of the location when
	// one keeps failing. It outlives engines, so a server that failed stays
	// avoided across wakes and settings changes; a new process starts from
	// the persisted choice, which the switch updated.
	failover *proxy.ServerFailover
	signins  *signInRegistry
	restart  chan struct{}
	stop     chan struct{}
	stopOnce sync.Once
	finished chan struct{}
	// LocalToken authorizes local clients (the tray) without the dashboard
	// login; it is regenerated at every start and stored in the data folder.
	localToken string
	// ExitApp ends the process that hosts this daemon (the tray or the
	// desktop app's core process); nil when the host cannot be ended that
	// way (a terminal copy: the status screen, or the plain log mode as
	// under systemd).
	ExitApp func()
	// RequireDashboard makes Run fail when the dashboard is disabled in
	// config.json: the desktop app reaches the service only through its API.
	RequireDashboard bool
	// OpenFolder, when set, shows a folder in the desktop's file manager;
	// the tray and the status screen set it when the service runs in their
	// process. The plain log mode has no desktop of its own, so it asks the
	// tray instead (folderRequests).
	OpenFolder func(dir string) error

	// SystemProxySupported: the process hosting this daemon sets the
	// system proxy (the Linux desktop app; Windows always can).
	SystemProxySupported bool
	// folderRequests counts requests to open the data folder; the tray
	// opens it when the count in the status rises.
	folderRequests atomic.Uint64
	// systemProxyRetakes counts requests to set the system proxy again
	// after another program replaced it (SetSystemProxy with the mode
	// already set); the process applying the mode does it when the count in
	// the status rises.
	systemProxyRetakes atomic.Uint64
	// systemProxyTaken is another program's setting in place of this
	// program's system proxy, nil while this program's is in place.
	systemProxyTaken atomic.Pointer[SystemProxyTaken]
	tunWanted        atomic.Bool

	mu  sync.Mutex
	cfg config.Config
	// off keeps the proxy engine stopped (SetOn); Off sets it before Run.
	off bool
	// autoConnect is set while the system proxy waits for auto-connect's
	// connection test (autoconnect.go).
	autoConnect chan struct{}
	// connectAttempt is the user's connect until it reaches Mozilla or is
	// given up; connectFailure why the last one was given up; lastConnected
	// when a connection last reached Mozilla (connect.go).
	connectAttempt chan struct{}
	connectFailure string
	lastConnected  time.Time
	engine         *proxyEngine
	state          engineState
	countries      []serverlist.Country
	exit           *proxy.ExitProbeResult
	lastTest       *proxy.ConnectionTestResult
	dashboard      *dashboardServer
	pings          []proxy.LocationPing
	pingedAt       time.Time

	// ffVersion is the Firefox version the server list is evaluated for.
	ffVersion   string
	ffVersionAt time.Time

	// networkChangedAt is when the network last changed: the phone's
	// report, or a computer's networks (watchNetwork).
	networkChangedAt time.Time
	// networkChanges counts the phone's reports, so a reconnect for an
	// older network stops (reconnectOnNewNetwork).
	networkChanges atomic.Uint64
	// flags guards downloading the flags the program does not carry
	// (flags.go).
	flags struct {
		mu     sync.Mutex
		failed map[string]time.Time
	}
	// pingMu serializes latency measurements.
	pingMu sync.Mutex
	// pingPass is the pass of measurements while the proxy is off, reused
	// until shortly before it expires; pingMu guards it.
	pingPass *guardian.ProxyPassInfo
}

func NewDaemon(paths DataPaths, forceVerbose bool) (*Daemon, error) {
	cfg, err := LoadConfig(paths, forceVerbose)
	if err != nil {
		return nil, err
	}
	store, order, err := OpenAccounts(paths, &cfg)
	if err != nil {
		return nil, err
	}
	mgr, err := accounts.NewManager(store, order, accounts.Policy{ThresholdPercent: cfg.Accounts.SwitchThresholdPercent}, paths.State)
	if err != nil {
		return nil, err
	}
	sessionKey, err := loadSessionKey(paths.SessionKey)
	if err != nil {
		return nil, fmt.Errorf("dashboard session key: %w", err)
	}
	d := &Daemon{
		paths:        paths,
		sessionKey:   sessionKey,
		notices:      &proxy.Notices{},
		routing:      routingState{wake: make(chan struct{}, 1)},
		forceVerbose: forceVerbose,
		store:        store,
		mgr:          mgr,
		pool:         proxy.NewAccountPool(store, mgr),
		failover:     proxy.NewServerFailover(paths.Selection),
		restart:      make(chan struct{}, 1),
		stop:         make(chan struct{}),
		finished:     make(chan struct{}),
		cfg:          cfg,
		state:        engineState{Phase: PhaseOff, Message: "Proxy off", Since: time.Now()},
		off:          true,
	}
	d.tunWanted.Store(true)
	d.signins = newSignInRegistry(d)
	d.loadSavedLocations()
	return d, nil
}

// loadSavedLocations shows the last server list fetched until the next one
// arrives, so the locations are there at once, also with no network.
func (d *Daemon) loadSavedLocations() {
	cached, _, err := serverlist.LoadCache(d.paths.ServerList)
	if err != nil {
		return
	}
	countries, _ := serverlist.Filter(cached, serverlist.Environment{FirefoxVersion: d.knownFirefoxVersion()})
	d.countries = countries
}

// Run starts the dashboard and supervises the proxy engine until Shutdown.
func (d *Daemon) Run() error {
	defer close(d.finished)
	cfg := d.config()
	logx.Info("service starting version=%s data_dir=%s accounts=%d switch_threshold=%g%%", version.Current, d.paths.Dir, d.mgr.Len(), cfg.Accounts.SwitchThresholdPercent)
	token, err := newLocalToken()
	if err != nil {
		return err
	}
	d.localToken = token
	if cfg.Dashboard.Enabled {
		d.dashboard = newDashboardServer(d)
		if err := d.dashboard.start(cfg.Dashboard.Listen); err != nil {
			// A taken address (*AddressInUseError) is returned as is: the
			// desktop app tells the user and offers another port.
			return fmt.Errorf("starting the dashboard: %w", err)
		}
		// Published only once this instance owns the dashboard address, so
		// a second instance that fails to start cannot replace it.
		if err := securefile.WritePrivate(d.paths.LocalToken, []byte(token)); err != nil {
			logx.Warn("writing the local API token failed; the tray cannot connect err=%s", logx.Err(err))
		}
	} else if d.RequireDashboard {
		return errors.New("the dashboard is disabled in config.json (dashboard.enabled=false); the app needs its API")
	} else {
		logx.Warn("the dashboard is disabled in config.json (dashboard.enabled=false)")
	}
	d.applyRouting(d.config().Routing)
	go d.runRoutingUpdates()
	go d.watchNetwork()
	d.superviseEngine()
	tun.StopAll()
	if d.dashboard != nil {
		d.dashboard.close()
	}
	logx.Info("service stopped")
	return nil
}

// Shutdown stops the proxy engine and the dashboard and waits (bounded)
// for run to return.
func (d *Daemon) Shutdown() {
	tun.StopAll()
	d.stopOnce.Do(func() { close(d.stop) })
	select {
	case <-d.finished:
	case <-time.After(15 * time.Second):
		logx.Warn("service shutdown timed out")
	}
}

// superviseEngine keeps the proxy engine running: it starts the engine,
// waits for a restart request, and retries failed starts. An engine starts
// asleep and contacts Mozilla only when first used (sleep.go). While no
// network is connected (network.wait_for_network) it does not start and
// starts as soon as one connects.
func (d *Daemon) superviseEngine() {
	var connectedAt time.Time
	for {
		select {
		case <-d.stop:
			return
		default:
		}
		if d.isOff() {
			if !d.waitWhileOff() {
				return
			}
			continue
		}
		if d.mustWaitForNetwork() {
			if !d.waitForNetwork() {
				return
			}
			connectedAt = time.Now()
			continue
		}
		d.setState(PhaseStarting, "Starting the proxy", time.Time{})
		engine, err := d.startEngine()
		if err == nil {
			d.mu.Lock()
			d.engine = engine
			// The public IP is found again once the new engine connects.
			d.exit = nil
			d.mu.Unlock()
			d.setState(PhaseRunning, "Proxy running", time.Time{})
			engineStopped := make(chan struct{})
			go d.sleepWhenIdle(engine, engineStopped)
			stopping := false
			select {
			case <-d.restart:
				logx.Info("restarting the proxy to apply changes")
			case <-d.stop:
				stopping = true
			}
			d.mu.Lock()
			d.engine = nil
			d.mu.Unlock()
			close(engineStopped)
			engine.stop()
			if stopping {
				return
			}
			continue
		}

		if d.mustWaitForNetwork() {
			// The network went away during the start; wait for it
			// rather than reporting the failure.
			continue
		}
		var wait time.Duration
		var noAccount *accounts.NoUsableAccountError
		var inUse *AddressInUseError
		switch {
		case errors.Is(err, errNoAccounts):
			d.setStateCode(engineState{Phase: PhaseWaiting, Message: "Add an account in the dashboard to start the proxy", Code: CodeNoAccounts})
			wait = 24 * time.Hour
		case errors.As(err, &noAccount):
			wait = proxy.RenewalRetryDelay(err, time.Now())
			d.setStateCode(engineState{Phase: PhaseWaiting, Message: "No usable account: " + noAccount.Summary, Code: CodeNoUsableAccount, RetryAt: time.Now().Add(wait)})
			logx.Warn("no usable account; proxy waits wait=%s err=%s", wait, logx.Err(err))
		case errors.As(err, &inUse):
			// Retried like other errors, in case the other program lets
			// the port go; a new proxy.listen restarts at once.
			wait = engineStartRetry
			d.setStateCode(engineState{Phase: PhaseError, Message: err.Error() + ". Choose another SOCKS5 listen address in Settings", Code: CodeProxyPortInUse, Address: inUse.Address, RetryAt: time.Now().Add(wait)})
			logx.Error("starting the proxy failed: its address is in use; retrying retry_in=%s listen=%s", wait, inUse.Address)
		default:
			wait = engineStartRetry
			if time.Since(connectedAt) < engineStartRetry {
				wait = networkSettleRetry
			}
			message := err.Error()
			if hint := proxy.GuardianFailureHint(err); hint != "" {
				message += ". " + hint
			}
			// The address when the proxy's port cannot be used, so that apps
			// can name it and offer another.
			address := ""
			var listenErr *ListenError
			if errors.As(err, &listenErr) && listenErr.Listener == ListenerProxy {
				address = listenErr.Address
			}
			d.setStateCode(engineState{Phase: PhaseError, Message: message, Code: CodeStartFailed, Address: address, RetryAt: time.Now().Add(wait)})
			logx.Error("starting the proxy failed; retrying retry_in=%s err=%s", wait, logx.Err(err))
		}
		timer := time.NewTimer(wait)
		select {
		case <-timer.C:
		case <-d.restart:
			timer.Stop()
		case <-d.stop:
			timer.Stop()
			return
		}
	}
}

// mustWaitForNetwork: while no network is connected (no adapter with a
// default gateway; on Android, what the app reports), the proxy start
// waits instead of retrying Mozilla.
func (d *Daemon) mustWaitForNetwork() bool {
	return !networkConnected()
}

// waitForNetwork shows the wait and returns once a network connects or a
// restart is requested (a settings change may turn the wait off); false
// means the service stops.
func (d *Daemon) waitForNetwork() bool {
	d.setStateCode(engineState{Phase: PhaseWaiting, Message: MessageWaitingForNetwork, Code: CodeWaitingForNetwork})
	logx.Info("no network connected; the proxy starts when one connects")
	ticker := time.NewTicker(networkPoll)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			if !d.mustWaitForNetwork() {
				logx.Info("network connected; starting the proxy")
				return true
			}
		case <-d.restart:
			return true
		case <-d.stop:
			return false
		}
	}
}

// SetOn turns the proxy on or off while the daemon and its API keep
// running: off stops the engine, closing the proxy's port, and nothing
// connects to Mozilla until it is turned on again. The phone app uses it;
// it is not stored. It ends an auto-connect attempt and a connect that
// waits to reach Mozilla (Connect).
func (d *Daemon) SetOn(on bool) {
	d.endAutoConnect()
	d.endConnect()
	d.setOn(on)
}

func (d *Daemon) setOn(on bool) {
	d.mu.Lock()
	changed := d.off == on
	d.off = !on
	d.mu.Unlock()
	if changed {
		logx.Info("proxy turned on=%t", on)
		if !on {
			tun.StopAll()
		}
		d.RequestRestart()
	}
}

func (d *Daemon) isTunWanted() bool {
	return d.tunWanted.Load()
}

func (d *Daemon) SetTunWanted(wanted bool) {
	d.tunWanted.Store(wanted)
}

// RequireLocalToken makes the API answer only clients with the local token
// (the app) or a browser signed in, also without a dashboard login: a
// sign-in link from the app (POST /api/session/link) signs it in. The phone
// sets it, since every app on the phone can reach its loopback.
func (d *Daemon) RequireLocalToken() { d.tokenOnly.Store(true) }

// ProxyEndpoint is where clients in this process reach the proxy: the
// address of the listener this daemon's engine holds (on loopback for a
// listen address on every interface), and its login. addr is "" while no
// engine listens, so nothing is sent to another program that may hold the
// configured port. The phone's VPN mode sends its connections there.
func (d *Daemon) ProxyEndpoint() (addr, user, password string) {
	cfg := d.config()
	engine := d.currentEngine()
	if engine == nil {
		return "", cfg.Proxy.Username, cfg.Proxy.Password
	}
	addr = engine.listener.Addr().String()
	if host, port, err := net.SplitHostPort(addr); err == nil {
		if ip := net.ParseIP(host); host == "" || (ip != nil && ip.IsUnspecified()) {
			addr = net.JoinHostPort("127.0.0.1", port)
		}
	}
	// The login that engine's server was built with: a new one in the
	// config takes effect when the engine restarts.
	return addr, engine.cfg.Proxy.Username, engine.cfg.Proxy.Password
}

// NetworkChanged takes the phone's network state from Android: up after a
// change (another network, or one back), a connected proxy opens a new
// upstream session at once; down, the proxy waits for a network
// (network.wait_for_network). Either way the last connection test no longer
// says anything about the connection (StatusView.NetworkChangedAt).
func (d *Daemon) NetworkChanged(up bool) {
	netstate.Report(up)
	d.networkChange(up)
}

// networkChange acts on a network change, reported by the phone or seen by
// watchNetwork.
func (d *Daemon) networkChange(up bool) {
	change := d.networkChanges.Add(1)
	d.mu.Lock()
	d.networkChangedAt = time.Now()
	d.mu.Unlock()
	logx.Info("network changed connected=%t", up)
	if !up {
		return
	}
	engine := d.currentEngine()
	if engine == nil {
		d.RequestRestart() // a start waiting for the network goes on
		return
	}
	controller := engine.currentController()
	if controller == nil {
		// Asleep: the next connection connects on the new network, without
		// waiting out a failure on the old one.
		engine.wakeAgainNow()
		return
	}
	go d.reconnectOnNewNetwork(engine, controller, change)
}

// networkWatchInterval is how often a computer's networks are read for a
// change (networkNow); reading them sends nothing. Tests replace both.
var (
	networkWatchInterval = 2 * time.Second
	networkNow           = netstate.Current
)

// watchNetwork notices on a computer what the phone app reports: another
// network (Wi-Fi to Ethernet, another Wi-Fi, an address renewed), none, or
// one back, so the proxy reconnects at once instead of finding out
// connection by connection. The phone reports its own (NetworkChanged), and
// where the networks cannot be read (macOS) nothing is watched.
func (d *Daemon) watchNetwork() {
	if runtime.GOOS == "android" {
		return
	}
	last, ok := networkNow()
	if !ok {
		return
	}
	ticker := time.NewTicker(networkWatchInterval)
	defer ticker.Stop()
	for {
		select {
		case <-d.stop:
			return
		case <-ticker.C:
		}
		now, ok := networkNow()
		if !ok || now == last {
			continue
		}
		last = now
		d.networkChange(now != "")
	}
}

// networkSettleSteps space the reconnects after a network came back: the
// report often comes before the new network routes anything (mobile data
// takes a moment), and a first failure must not leave the old session,
// which belongs to the network that is gone, in place. Tests shorten them.
var networkSettleSteps = []time.Duration{0, time.Second, 2 * time.Second, 4 * time.Second, 8 * time.Second}

// reconnectOnNewNetwork opens a new upstream session on the network that
// came back, retrying while it settles, until a later network change,
// another engine, or another controller takes over.
func (d *Daemon) reconnectOnNewNetwork(engine *proxyEngine, controller *proxy.Controller, change uint64) {
	controller.RetryNow()
	var err error
	for _, wait := range networkSettleSteps {
		select {
		case <-d.stop:
			return
		case <-time.After(wait):
		}
		if d.networkChanges.Load() != change || d.currentEngine() != engine || engine.currentController() != controller {
			return
		}
		if err = controller.Reconnect(); err == nil {
			logx.Info("reconnected to Mozilla on the new network")
			d.autoTest(engine, "network changed")
			return
		}
		if errors.Is(err, proxy.ErrNoUsableSession) {
			break
		}
	}
	logx.Warn("reconnecting to Mozilla after a network change failed err=%s", logx.Err(err))
}

// ExitCountry is the country code the traffic leaves from: the selected
// location's, or for the recommended location (which has no country of
// its own) the exit's once a test or exit check found it; "" while it is
// unknown or the proxy is off. The phone's notification shows it.
func (d *Daemon) ExitCountry() string {
	engine := d.currentEngine()
	if engine == nil {
		return ""
	}
	selected, _ := engine.selection()
	if code := strings.ToUpper(selected.CountryCode); len(code) == 2 {
		return code
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.exit != nil && len(d.exit.CountryCode) == 2 {
		return strings.ToUpper(d.exit.CountryCode)
	}
	return ""
}

// Speed is the proxy's current speed in bytes per second (a few seconds'
// average); 0 while it is off.
func (d *Daemon) Speed() (down, up int64) {
	engine := d.currentEngine()
	if engine == nil || engine.routed == nil {
		return 0, 0
	}
	t := engine.routed.Traffic()
	return t.DownRate, t.UpRate
}

// Off makes Run start with the proxy off; call it before Run.
func (d *Daemon) Off() {
	d.mu.Lock()
	d.off = true
	d.mu.Unlock()
}

// IsOn reports whether the proxy is on (SetOn, Connect).
func (d *Daemon) IsOn() bool { return !d.isOff() }

func (d *Daemon) isOff() bool {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.off
}

// waitWhileOff shows the off state until SetOn or a restart request; false
// means the service stops.
func (d *Daemon) waitWhileOff() bool {
	d.setState(PhaseOff, "Proxy off", time.Time{})
	select {
	case <-d.restart:
		return true
	case <-d.stop:
		return false
	}
}

// RequestRestart asks the supervisor to (re)start the proxy engine.
func (d *Daemon) RequestRestart() {
	select {
	case d.restart <- struct{}{}:
	default:
	}
}

func (d *Daemon) setState(phase, message string, retryAt time.Time) {
	d.setStateCode(engineState{Phase: phase, Message: message, RetryAt: retryAt})
}

// setStateCode sets the state with its machine-readable code and the
// address the code is about; Since is kept while the phase and the message
// stay.
func (d *Daemon) setStateCode(s engineState) {
	d.mu.Lock()
	defer d.mu.Unlock()
	s.Since = d.state.Since
	if d.state.Phase != s.Phase || d.state.Message != s.Message {
		s.Since = time.Now()
	}
	d.state = s
}

func (d *Daemon) config() config.Config {
	d.mu.Lock()
	defer d.mu.Unlock()
	cfg := d.cfg
	cfg.Accounts.Order = append([]config.AccountRef(nil), d.cfg.Accounts.Order...)
	return cfg
}

func (d *Daemon) currentEngine() *proxyEngine {
	d.mu.Lock()
	defer d.mu.Unlock()
	return d.engine
}

// accountsChanged reconciles the configured order with the store, reloads
// the account manager, and makes the engine pick up the change: a stopped
// engine is started, and a running one switches away from an account that
// was removed or disabled.
func (d *Daemon) accountsChanged() error {
	list, err := d.store.List()
	if err != nil {
		return err
	}
	d.mu.Lock()
	enabled, changed := ReconcileAccountOrder(&d.cfg, list)
	cfg := d.cfg
	d.mu.Unlock()
	if changed {
		if err := config.Save(d.paths.Config, cfg); err != nil {
			return fmt.Errorf("saving account order: %w", err)
		}
	}
	if err := d.mgr.Reload(enabled); err != nil {
		return err
	}
	engine := d.currentEngine()
	if engine == nil {
		d.RequestRestart()
		return nil
	}
	// An account signed in again or added may wake what failed before.
	engine.wakeAgainNow()
	if _, ok := d.mgr.Active(); !ok {
		go d.switchAccount(engine)
	}
	return nil
}

// switchAccount obtains a pass from the account the manager now prefers and
// applies it to the running upstream session.
func (d *Daemon) switchAccount(engine *proxyEngine) {
	controller := engine.currentController()
	if controller == nil {
		// Asleep: the next wake takes a pass from the preferred account.
		return
	}
	if err := controller.SwitchAccountNow(); err != nil {
		logx.Warn("switching account failed: %s", logx.Err(err))
		if errors.Is(err, accounts.ErrNoUsableAccount) || errors.Is(err, proxy.ErrNoUsableSession) {
			d.RequestRestart()
		}
	}
}

// addSignedInAccount stores credentials issued by a sign-in and puts the
// account into rotation.
func (d *Daemon) addSignedInAccount(email, password string, token *fxa.TokenResponse) (accounts.Account, error) {
	now := time.Now()
	acc, created, err := d.store.Add(email, &fxa.SavedTokens{
		AccessToken:  token.AccessToken,
		RefreshToken: token.RefreshToken,
		Scope:        token.Scope,
		ObtainedAt:   now,
		ExpiresIn:    token.ExpiresIn,
	}, now)
	if err != nil {
		return accounts.Account{}, err
	}
	d.pool.Forget(acc.ID)
	if password != "" {
		if err := d.store.SetPassword(acc.ID, password); err != nil {
			logx.Warn("saving the account password failed account=%s err=%s", logx.Email(acc.Name()), logx.Err(err))
		}
	}
	go d.pool.EnsureDevice(context.Background(), acc.ID)
	if created {
		logx.Info("account added account=%s id=%s", logx.Email(acc.Name()), acc.ID)
	} else {
		logx.Info("account signed in again account=%s id=%s", logx.Email(acc.Name()), acc.ID)
	}
	if err := d.accountsChanged(); err != nil {
		return acc, err
	}
	if err := d.refreshAccountUsage(acc.ID); err != nil {
		logx.Debug("reading the new account's quota failed account=%s err=%s", logx.Email(acc.Name()), logx.Err(err))
	}
	return acc, nil
}

// removeAccount deletes an account and its credentials.
func (d *Daemon) removeAccount(id string) error {
	if _, err := d.store.Get(id); err != nil {
		return fmt.Errorf("unknown account %s", id)
	}
	if err := d.store.Remove(id); err != nil {
		return err
	}
	d.pool.Forget(id)
	logx.Info("account removed id=%s", id)
	return d.accountsChanged()
}

// setAccountOrder replaces the priority order; ids must name exactly the
// stored accounts.
func (d *Daemon) setAccountOrder(ids []string) error {
	d.mu.Lock()
	current := make(map[string]config.AccountRef, len(d.cfg.Accounts.Order))
	for _, ref := range d.cfg.Accounts.Order {
		current[ref.ID] = ref
	}
	if len(ids) != len(current) {
		d.mu.Unlock()
		return errors.New("the order must list every account exactly once")
	}
	order := make([]config.AccountRef, 0, len(ids))
	seen := make(map[string]bool, len(ids))
	for _, id := range ids {
		ref, ok := current[id]
		if !ok || seen[id] {
			d.mu.Unlock()
			return errors.New("the order must list every account exactly once")
		}
		seen[id] = true
		order = append(order, ref)
	}
	d.cfg.Accounts.Order = order
	d.mu.Unlock()
	return d.accountsChanged()
}

// setAccountEnabled takes an account in or out of rotation.
func (d *Daemon) setAccountEnabled(id string, enabled bool) error {
	d.mu.Lock()
	found := false
	for i := range d.cfg.Accounts.Order {
		if d.cfg.Accounts.Order[i].ID == id {
			d.cfg.Accounts.Order[i].Enabled = enabled
			found = true
		}
	}
	d.mu.Unlock()
	if !found {
		return fmt.Errorf("unknown account %s", id)
	}
	if err := d.saveConfig(); err != nil {
		return err
	}
	return d.accountsChanged()
}

// activateAccount makes id the active account now, switching the running
// engine to it.
func (d *Daemon) activateAccount(id string) error {
	enabled := false
	for _, acc := range d.mgr.Accounts() {
		if acc.ID == id {
			enabled = true
		}
	}
	if !enabled {
		return errors.New("only enabled accounts can be activated")
	}
	if err := d.mgr.Activate(id); err != nil {
		return err
	}
	logx.Info("account activated from the dashboard id=%s", id)
	if engine := d.currentEngine(); engine != nil {
		go d.switchAccount(engine)
	} else {
		d.RequestRestart()
	}
	return nil
}

// refreshAccountUsage reads an account's quota without minting a pass.
func (d *Daemon) refreshAccountUsage(id string) error {
	acc, err := d.store.Get(id)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), proxy.PassRenewTimeout)
	defer cancel()
	auth, err := d.pool.AuthFor(acc)
	if err != nil {
		return err
	}
	if auth, err = proxy.FreshRuntimeAuth(ctx, auth); err != nil {
		return err
	}
	usage, err := guardian.FetchProxyUsage(ctx, d.config().Network.GuardianEndpoint, auth.Token.AccessToken)
	if err != nil {
		return err
	}
	if _, err := d.mgr.ObserveUsage(id, proxy.AccountUsage(usage)); err == nil {
		return nil
	}
	// Disabled accounts are not managed; record the usage directly.
	u := proxy.AccountUsage(usage)
	acc.Usage = &u
	return d.store.Save(acc)
}

func (d *Daemon) saveConfig() error {
	return config.Save(d.paths.Config, d.config())
}

// settingsChange describes what an accepted settings update requires.
type settingsChange struct {
	restartEngine    bool
	restartDashboard bool
}

// updateSettings validates and saves a new configuration, applies what can
// change live, and reports what needs a restart. The account order is not
// changed here.
func (d *Daemon) updateSettings(next config.Config, newPassword *string) (settingsChange, error) {
	d.mu.Lock()
	prev := d.cfg
	d.mu.Unlock()

	next.Version = config.CurrentVersion
	next.Proxy.AllowLocked = false // ignored; see config.Proxy
	next.Accounts.Order = prev.Accounts.Order
	next.Dashboard.Enabled = prev.Dashboard.Enabled
	next.Dashboard.Username = strings.TrimSpace(next.Dashboard.Username)
	switch {
	case next.Dashboard.Username == "":
		next.Dashboard.PasswordHash = ""
	case newPassword != nil && *newPassword != "":
		hash, err := HashDashboardPassword(*newPassword)
		if err != nil {
			return settingsChange{}, err
		}
		next.Dashboard.PasswordHash = hash
	case prev.Dashboard.PasswordHash != "":
		next.Dashboard.PasswordHash = prev.Dashboard.PasswordHash
	default:
		return settingsChange{}, errors.New("set a password for the dashboard username")
	}
	if dashboardExposedWithoutLogin(next) {
		return settingsChange{}, errors.New("set a dashboard username and password before opening the dashboard to other devices")
	}
	// Another region: its preset rules replace the old region's in the
	// Direct list; the user's own rules stay.
	if next.Routing.Region != prev.Routing.Region {
		next.Routing.Direct = routing.SwapRegionRules(prev.Routing.Region, next.Routing.Region, next.Routing.Direct)
		// One of the offered list sets follows the region (its usual one);
		// lists set by hand stay.
		if _, offered := routing.SourceOf(next.Routing.GeoSiteURL, next.Routing.GeoIPURL); offered {
			src := routing.RegionSource(next.Routing.Region)
			next.Routing.GeoSiteURL, next.Routing.GeoIPURL = src.GeoSiteURL, src.GeoIPURL
		}
	}
	if err := next.Validate(); err != nil {
		return settingsChange{}, err
	}
	if !slices.Equal(next.DNS.Servers, prev.DNS.Servers) || next.DNS.FallbackToSystem != prev.DNS.FallbackToSystem {
		if err := configureDNS(next.DNS); err != nil {
			return settingsChange{}, fmt.Errorf("invalid dns.servers: %w", err)
		}
	}
	if next.Network.APIRelay != prev.Network.APIRelay {
		if err := configureAPIRelay(next.Network.APIRelay); err != nil {
			return settingsChange{}, fmt.Errorf("invalid network.api_relay: %w", err)
		}
	}
	if err := config.Save(d.paths.Config, next); err != nil {
		return settingsChange{}, err
	}
	d.mu.Lock()
	d.cfg = next
	d.mu.Unlock()

	logx.Verbose.Store(next.Logging.Verbose || d.forceVerbose)
	d.mgr.SetPolicy(accounts.Policy{ThresholdPercent: next.Accounts.SwitchThresholdPercent})
	change := settingsChange{
		restartEngine: next.Proxy != prev.Proxy || next.Network.APIRelay != prev.Network.APIRelay ||
			next.Network.GuardianEndpoint != prev.Network.GuardianEndpoint,
		restartDashboard: next.Dashboard.Listen != prev.Dashboard.Listen,
	}
	logx.Info("settings saved restart_proxy=%v restart_dashboard=%v", change.restartEngine, change.restartDashboard)
	if routingChanged(next.Routing, prev.Routing) {
		// Applied live: new connections take the new route.
		d.applyRouting(next.Routing)
		d.wakeRouting()
	}
	if change.restartEngine {
		if next.Proxy.Country != prev.Proxy.Country || next.Proxy.Server != prev.Proxy.Server {
			// A new location must not reuse the persisted hostname.
			_ = removeFile(d.paths.Selection)
		}
		d.RequestRestart()
	}
	return change, nil
}

// dashboardExposedWithoutLogin reports a dashboard reachable from other
// devices without credentials.
func dashboardExposedWithoutLogin(cfg config.Config) bool {
	if cfg.Dashboard.Username != "" {
		return false
	}
	host, _, err := net.SplitHostPort(cfg.Dashboard.Listen)
	if err != nil {
		return false
	}
	if host == "localhost" {
		return false
	}
	ip := net.ParseIP(host)
	return ip == nil || !ip.IsLoopback()
}
