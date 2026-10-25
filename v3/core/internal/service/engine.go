package service

import (
	"context"
	"errors"
	"fmt"
	"net"
	"strings"
	"sync/atomic"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
	"github.com/armanlife/firefox-vpn-client/core/internal/serverlist"
	"github.com/armanlife/firefox-vpn-client/core/internal/tun"
)

// errNoAccounts reports that the service has no enabled account to use.
var errNoAccounts = errors.New("no enabled accounts")

// proxyEngine is one running instance of the proxy: the SOCKS5/HTTP
// listener, the upstream controller, and the location it was started for.
// Settings changes stop it and start a new one.
//
// An engine starts asleep (sleep.go): the listener opens at once, but
// nothing is sent to Mozilla until something needs the upstream (a client
// connection, a connection test, or a real-delay test). The first wake
// selects the server and connects (connectEngine); later wakes after
// proxy.idle_sleep reuse that server (reconnectEngine).
type proxyEngine struct {
	// controller is the upstream: nil while the proxy sleeps.
	// Use currentController or reserve, not the field.
	controller *proxy.Controller
	// cfg is the configuration the engine was started with.
	cfg config.Config
	// upstream is what a controller is built from when the proxy wakes.
	// Until the first wake (connected false) it has no server; the first
	// wake selects one. Both are guarded by idle.wakeMu.
	upstream  proxy.ControllerConfig
	connected bool
	// statusFile is the status.json path (fixed for the engine's life).
	statusFile string
	idle       idleState
	// routed is what clients connect through: the controller, or directly
	// for destinations the routing rules send there.
	routed    *proxy.RoutedOpener
	listener  net.Listener
	transport string
	// fellBackToH2 is set when HTTP/3 was configured but did not connect,
	// so the engine uses HTTP/2 (connectEngine).
	fellBackToH2 atomic.Bool
	startedAt    time.Time
	// selected and selectionSource are guarded by idle.mu: before the
	// first wake they show the expected choice (expectedSelection), which
	// the first wake replaces with the real one.
	selected        proxy.Candidate
	selectionSource string
}

// selection returns the engine's location and how it was chosen.
func (e *proxyEngine) selection() (proxy.Candidate, string) {
	e.idle.mu.Lock()
	defer e.idle.mu.Unlock()
	return e.selected, e.selectionSource
}

// startEngine opens the SOCKS5/HTTP listener and returns an engine that
// sleeps until first used; it sends nothing to Mozilla. It fails for a
// taken listen address, with no account, or when every account waits for
// a quota reset or a new sign-in (read from the local account state).
func (d *Daemon) startEngine() (*proxyEngine, error) {
	cfg := d.config()
	// A taken listen address is reported first, whatever the accounts.
	ln, err := listenTCP(ListenerProxy, cfg.Proxy.Listen)
	if err != nil {
		return nil, err
	}
	if d.mgr.Len() == 0 {
		_ = ln.Close()
		return nil, errNoAccounts
	}
	if _, err := d.mgr.Candidate(nil); err != nil {
		_ = ln.Close()
		return nil, err
	}

	engine := &proxyEngine{
		cfg: cfg,
		upstream: proxy.ControllerConfig{
			Guardian:   cfg.Network.GuardianEndpoint,
			Timeout:    connectTimeout,
			UseH3:      cfg.Proxy.Transport == "h3",
			Sessions:   cfg.Proxy.UpstreamConnections,
			StatusFile: d.paths.Status,
			Accounts:   d.pool,
		},
		statusFile: d.paths.Status,
		listener:   ln,
		transport:  cfg.Proxy.Transport,
		startedAt:  time.Now(),
	}
	engine.selected, engine.selectionSource = d.expectedSelection(cfg)
	engine.idle.lastUsed, engine.idle.sleeping = engine.startedAt, engine.startedAt
	routed := proxy.NewRoutedOpener(&engineUpstream{d: d, engine: engine})
	routed.SetRouter(d.currentRouter())
	engine.routed = routed
	socks := proxy.NewSOCKSServer(routed, config.HandshakeTimeout, config.IdleTimeout, cfg.Proxy.MaxConnections)
	socks.Auth = proxy.SOCKSCredentials(cfg.Proxy.Username, cfg.Proxy.Password)
	socks.Notices = d.notices
	if socks.Auth == nil && !hostIsLoopbackListen(cfg.Proxy.Listen) {
		logx.Warn("the SOCKS5 proxy is reachable from other devices without a password; set proxy.username and proxy.password listen=%s", cfg.Proxy.Listen)
	}
	go proxy.ServeSOCKS(ln, socks)
	if err := proxy.WriteIdleStatus(engine.statusFile, proxy.StatusSleeping); err != nil {
		logx.Warn("writing status file failed path=%s err=%s", engine.statusFile, logx.Err(err))
	}
	logx.Info("SOCKS5 proxy started listen=%s transport=%s; it connects to Mozilla when a connection needs it", ln.Addr().String(), cfg.Proxy.Transport)
	return engine, nil
}

// chosenCountry reports whether the user chose a country: not the
// recommended location (an empty country), not the fastest one, and no
// server set by hand.
func chosenCountry(p config.Proxy) bool {
	country := strings.TrimSpace(p.Country)
	return strings.TrimSpace(p.Server) == "" && country != "" && !strings.EqualFold(country, proxy.FastestCountry)
}

// expectedSelection is the location the status shows before the first
// wake: the configured server, or the persisted choice when it suits the
// configured country. It reads only local files.
func (d *Daemon) expectedSelection(cfg config.Config) (proxy.Candidate, string) {
	if server := strings.TrimSpace(cfg.Proxy.Server); server != "" {
		return proxy.Candidate{Addr: server}, "configured_proxy"
	}
	country := strings.TrimSpace(cfg.Proxy.Country)
	if strings.EqualFold(country, proxy.FastestCountry) {
		return proxy.Candidate{}, ""
	}
	if persisted, ok := proxy.PersistedSelection(d.paths.Selection, country); ok {
		return persisted, "persisted"
	}
	return proxy.Candidate{}, ""
}

// connectEngine is the first wake: it fetches the server list and a pass
// (together), resolves "fastest" with that pass, selects the upstream, and
// builds the controller with its first H2/H3 session. idle.wakeMu is held.
func (d *Daemon) connectEngine(e *proxyEngine) (*proxy.Controller, error) {
	cfg := e.cfg
	server := strings.TrimSpace(cfg.Proxy.Server)
	country := strings.TrimSpace(cfg.Proxy.Country)

	listed := make(chan []serverlist.Country, 1)
	go func() { listed <- d.refreshLocations(cfg) }()
	ctx, cancel := context.WithTimeout(context.Background(), proxy.PassRenewTimeout)
	auth, pass, err := d.pool.AcquirePass(ctx, e.upstream.Guardian)
	cancel()
	if err != nil {
		return nil, err
	}
	// The pass is here: with a list from before (saved or fetched earlier)
	// the connection need not wait for the new one, which still replaces
	// it for the location choices when it arrives.
	var countries []serverlist.Country
	select {
	case countries = <-listed:
	default:
		d.mu.Lock()
		known := d.countries
		d.mu.Unlock()
		if len(known) == 0 || server != "" {
			countries = <-listed
		} else {
			logx.Debug("server list still loading; connecting with the one from before")
			countries = known
		}
	}
	proxy.LogPassTimeCorrection(pass)

	fastest := server == "" && strings.EqualFold(country, proxy.FastestCountry)
	if fastest {
		country = d.resolveFastestCountry(pass.RawToken)
	}
	selected, fromState, err := proxy.ResolveWithStateAndCountry(server, country, countries, d.paths.Selection, d.failover.Avoided)
	if err != nil {
		return nil, fmt.Errorf("selecting proxy: %w", err)
	}
	selectionSource := "single_available_location"
	switch {
	case server != "":
		selectionSource = "configured_proxy"
	case fromState:
		selectionSource = "persisted"
	case fastest:
		selectionSource = "fastest_location"
	case country != "":
		selectionSource = "configured_country"
	case selected.IsRecommended():
		selectionSource = "recommended_location"
	}
	proxyURL, err := proxy.NormalizeURL(selected.Addr)
	if err != nil {
		return nil, fmt.Errorf("invalid proxy %q: %w", selected.Addr, err)
	}

	sessionStart := time.Now()
	upstream := e.upstream
	upstream.ProxyURL = proxyURL
	upstream.ChosenLocation = chosenCountry(cfg.Proxy)
	upstream.Server = selected
	if server == "" {
		// A server set by hand stays; a selected one may move within its
		// location when it keeps failing.
		upstream.Location = proxy.LocationCandidates(countries, country)
		upstream.Failover = d.failover
	}
	withPass := upstream
	withPass.Auth, withPass.Pass = auth, pass
	controller, err := proxy.NewController(withPass)
	if err != nil && upstream.UseH3 {
		// Networks that filter QUIC (UDP), as in Iran, often let the same
		// server through over TCP: HTTP/2 for this engine instead.
		logx.Warn("HTTP/3 did not connect; using HTTP/2 instead proxy=%s err=%s", selected.Addr, logx.Err(err))
		upstream.UseH3, withPass.UseH3 = false, false
		controller, err = proxy.NewController(withPass)
		if err == nil {
			e.fellBackToH2.Store(true)
		}
	}
	if err != nil {
		// A server that keeps failing to connect gives way to another of
		// the location, saved as the persisted choice that the next wake
		// selects.
		if next, ok := upstream.Failover.Failed(upstream.Location, selected, err); ok {
			e.serverSwitched(next)
		}
		return nil, fmt.Errorf("establishing upstream proxy session: %w", err)
	}
	if server == "" {
		if err := proxy.SaveSelection(d.paths.Selection, selected); err != nil {
			logx.Warn("saving proxy selection failed path=%s err=%s", d.paths.Selection, logx.Err(err))
		}
	}
	e.upstream, e.connected = upstream, true
	e.idle.mu.Lock()
	e.selected, e.selectionSource = selected, selectionSource
	e.idle.mu.Unlock()

	logx.Info("connected to Mozilla upstream=%s account=%s proxy_pass_exp=%s transport=%s upstream_conns=%d",
		selected.Addr, logx.Email(d.pool.ActiveName()), pass.ExpiresAt().Format(time.RFC3339), cfg.Proxy.Transport, cfg.Proxy.UpstreamConnections)
	logx.Info("upstream selected configured_country=%q configured_country_code=%s proxy=%s selection_source=%s upstream_session_establish_latency=%s",
		selected.CountryNameOrUnknown(), selected.CountryCodeOrUnknown(), selected.Addr, selectionSource, time.Since(sessionStart).Round(time.Millisecond))
	return controller, nil
}

// reconnectEngine wakes an engine that was connected before: a new pass
// and session for the same server (or the one the failover moved to),
// without selecting or measuring again. idle.wakeMu is held.
func (d *Daemon) reconnectEngine(e *proxyEngine) (*proxy.Controller, error) {
	ctx, cancel := context.WithTimeout(context.Background(), proxy.PassRenewTimeout)
	auth, pass, err := d.pool.AcquirePass(ctx, e.upstream.Guardian)
	cancel()
	if err != nil {
		return nil, err
	}
	if e.upstream.Failover != nil {
		if selected, _ := e.selection(); selected.Addr != "" && selected.Addr != e.upstream.Server.Addr {
			if proxyURL, err := proxy.NormalizeURL(selected.Addr); err == nil {
				e.upstream.Server, e.upstream.ProxyURL = selected, proxyURL
			}
		}
	}
	cfg := e.upstream
	cfg.Auth, cfg.Pass = auth, pass
	controller, err := proxy.NewController(cfg)
	if err != nil {
		if next, ok := cfg.Failover.Failed(cfg.Location, cfg.Server, err); ok {
			e.serverSwitched(next)
		}
		return nil, err
	}
	return controller, nil
}

// serverSwitched makes next, where the failover moved the upstream, the
// engine's server: the status shows it and the next wake connects to it
// (reconnectEngine).
func (e *proxyEngine) serverSwitched(next proxy.Candidate) {
	e.idle.mu.Lock()
	e.selected, e.selectionSource = next, "server_failover"
	e.idle.mu.Unlock()
	tun.PinEdge(next.Addr)
}

// runController makes controller the engine's upstream and starts its
// renewal and quota loops. It returns false, closing controller, when the
// engine has stopped meanwhile.
func (d *Daemon) runController(engine *proxyEngine, controller *proxy.Controller) bool {
	// Set before the loops start, which may rebuild the session.
	controller.OnSessionRebuilt = func() {
		if engine.currentController() == controller && d.currentEngine() == engine {
			d.autoTest(engine, "session rebuilt")
		}
	}
	controller.OnServerSwitched = engine.serverSwitched
	engine.idle.mu.Lock()
	if engine.idle.stopped {
		engine.idle.mu.Unlock()
		_ = controller.Close()
		return false
	}
	engine.controller = controller
	engine.idle.sleeping = time.Time{}
	engine.idle.wakeErr, engine.idle.wakeCode, engine.idle.wakeFailedAt = nil, "", time.Time{}
	engine.idle.wakeRetryAt, engine.idle.wakeFailures, engine.idle.wakeLasting = time.Time{}, 0, false
	engine.idle.mu.Unlock()
	go controller.RunRenewalLoop()
	go controller.RunQuotaMonitorLoop()
	return true
}

// stop closes the listener and the upstream sessions; open tunnels end.
// A wake that finishes afterwards closes its controller (runController).
func (e *proxyEngine) stop() {
	_ = e.listener.Close()
	e.idle.mu.Lock()
	e.idle.stopped = true
	c := e.controller
	e.controller = nil
	e.idle.mu.Unlock()
	if c != nil {
		_ = c.Close()
	} else if err := proxy.WriteIdleStatus(e.statusFile, proxy.StatusClosed); err != nil {
		logx.Warn("writing status file failed path=%s err=%s", e.statusFile, logx.Err(err))
	}
	e.routed.Close()
}

// refreshLocations fetches and filters the server list (unless an exact
// server is configured) and keeps it for the dashboard's location choices.
func (d *Daemon) refreshLocations(cfg config.Config) []serverlist.Country {
	if strings.TrimSpace(cfg.Proxy.Server) != "" {
		return nil
	}
	// The Firefox version the records are evaluated for is looked up
	// while the list downloads.
	version := make(chan string, 1)
	go func() { version <- d.firefoxVersion() }()
	ctx, cancel := context.WithTimeout(context.Background(), proxy.APIRequestTimeout)
	countries, err := serverlist.Fetch(ctx)
	cancel()
	if err == nil && len(countries) > 0 {
		if err := serverlist.SaveCache(d.paths.ServerList, countries); err != nil {
			logx.Warn("saving the server list failed err=%s", logx.Err(err))
		}
	} else {
		// The list changes rarely: the last one fetched does.
		logx.Warn("fetching server list failed: %v", err)
		if cached, savedAt, cacheErr := serverlist.LoadCache(d.paths.ServerList); cacheErr == nil {
			logx.Info("using the server list saved %s", savedAt.Local().Format("2006-01-02 15:04"))
			countries = cached
		}
	}
	var dropped []serverlist.FilteredRecord
	countries, dropped = serverlist.Filter(countries, serverlist.Environment{FirefoxVersion: <-version})
	for _, record := range dropped {
		logx.Debug("server-list record skipped country_code=%s filter=%q reason=%s", record.Code, record.Expression, record.Reason)
	}
	if len(countries) > 0 {
		d.mu.Lock()
		d.countries = countries
		d.mu.Unlock()
	}
	return countries
}

// latestFirefoxVersion fetches the newest Firefox version; tests replace it.
var latestFirefoxVersion = serverlist.LatestFirefoxVersion

// knownFirefoxVersion returns the version the server list was last
// evaluated for, without fetching.
func (d *Daemon) knownFirefoxVersion() string {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.ffVersion == "" {
		return serverlist.DefaultFirefoxVersion
	}
	return d.ffVersion
}

// firefoxVersionRefresh is how long a fetched Firefox version is used.
const firefoxVersionRefresh = 12 * time.Hour

// firefoxVersion returns the newest Firefox version, fetched from Mozilla
// and refreshed twice a day, so version-gated server-list records apply as
// they do for current Firefox. Without a fetch it keeps the last value, or
// serverlist.DefaultFirefoxVersion.
func (d *Daemon) firefoxVersion() string {
	d.mu.Lock()
	version, at := d.ffVersion, d.ffVersionAt
	d.mu.Unlock()
	if version != "" && time.Since(at) < firefoxVersionRefresh {
		return version
	}
	ctx, cancel := context.WithTimeout(context.Background(), proxy.APIRequestTimeout)
	latest, err := latestFirefoxVersion(ctx)
	cancel()
	switch {
	case err == nil:
		if latest != version {
			logx.Info("server list evaluated for Firefox %s (latest)", latest)
		}
		version = latest
	case version == "":
		logx.Warn("reading the latest Firefox version failed; using %s err=%s", serverlist.DefaultFirefoxVersion, logx.Err(err))
		version = serverlist.DefaultFirefoxVersion
	default:
		logx.Debug("reading the latest Firefox version failed; keeping %s err=%s", version, logx.Err(err))
	}
	d.mu.Lock()
	d.ffVersion, d.ffVersionAt = version, time.Now()
	d.mu.Unlock()
	return version
}

// currentTransport is the transport the engine uses: proxy.transport, or
// "h2" after HTTP/3 did not connect.
func (e *proxyEngine) currentTransport() string {
	if e.fellBackToH2.Load() {
		return "h2"
	}
	return e.transport
}
