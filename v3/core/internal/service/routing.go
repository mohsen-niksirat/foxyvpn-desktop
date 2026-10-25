package service

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"runtime"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/controlplane"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
	"github.com/armanlife/firefox-vpn-client/core/internal/routing"
)

// listDownloadTimeout bounds downloading both routing lists.
const listDownloadTimeout = 3 * time.Minute

// routingCheckInterval is how often the update loop checks the lists' age.
const routingCheckInterval = time.Hour

// routingState is the daemon's routing: the router built from the
// settings and the lists, and the state of the list updates.
type routingState struct {
	mu        sync.Mutex
	router    *routing.Router
	err       string // why routing is on but not working
	updating  bool
	lastCheck time.Time
	lastErr   string
	wake      chan struct{}
}

// routingView is GET /api/routing.
type routingView struct {
	Enabled bool `json:"enabled"`
	// Region is routing.region; Direct is the effective Direct rules: the
	// region's presets, then the user's own.
	Region string   `json:"region"`
	Direct []string `json:"direct"`
	// RegionRules are the Direct rules the region adds by itself (before
	// the user's own), so the app can show them.
	RegionRules []string `json:"region_rules"`
	// Source is the offered list set the lists come from ("" for lists
	// set by hand); Sources are the offered ones.
	Source    string             `json:"source"`
	Sources   []routing.Source   `json:"sources"`
	Active    bool               `json:"active"`
	Summary   string             `json:"summary,omitempty"`
	Error     string             `json:"error,omitempty"`
	Files     []routing.FileInfo `json:"files"`
	Updating  bool               `json:"updating"`
	LastCheck time.Time          `json:"last_check,omitzero"`
	LastError string             `json:"last_error,omitempty"`
	Counts    *proxy.RouteCounts `json:"counts,omitempty"`
}

func routingChanged(a, b config.Routing) bool {
	return a.Enabled != b.Enabled || a.Region != b.Region || a.ResolveDomains != b.ResolveDomains || a.GeoSiteURL != b.GeoSiteURL ||
		a.GeoIPURL != b.GeoIPURL || a.UpdateInterval != b.UpdateInterval ||
		!slices.Equal(a.Direct, b.Direct) || !slices.Equal(a.Block, b.Block)
}

// applyRouting builds the router for cfg (the region's preset Direct rules
// first, then the user's) from the lists on disk and installs it in the
// running proxy; open connections keep their route.
// Routing that is on but cannot load its lists sends everything through
// the proxy until they load.
func (d *Daemon) applyRouting(cfg config.Routing) {
	var router *routing.Router
	var problem string
	if cfg.Enabled {
		built, err := routing.New(routing.Config{Dir: d.paths.RoutingDir, Direct: cfg.Direct, Block: cfg.Block, ResolveDomains: cfg.ResolveDomains})
		if err != nil {
			problem = err.Error()
			logx.Warn("routing is on but everything goes through the proxy until its lists load err=%s", problem)
		} else {
			router = built
			logx.Info("routing on: matching destinations go directly, the rest through Mozilla lists=%q", built.Summary)
		}
	}
	d.routing.mu.Lock()
	d.routing.router, d.routing.err = router, problem
	d.routing.mu.Unlock()
	if engine := d.currentEngine(); engine != nil {
		engine.routed.SetRouter(router)
	}
}

// appListsWanted: the phone app leaves a region's apps out of its VPN
// (DirectApps); other platforms have no use for the lists.
var appListsWanted = runtime.GOOS == "android"

// DirectApps lists the phone apps of the routing region that connect
// directly (routing.ReadAppList): none while routing is off, for a region
// without a list, or before the list is downloaded.
func (d *Daemon) DirectApps() []string {
	cfg := d.config().Routing
	if !cfg.Enabled {
		return nil
	}
	return routing.ReadAppList(d.paths.RoutingDir, cfg.Region)
}

// TunnelAllows reports whether the phone's VPN sends a connection to
// host:port to the proxy: a port Mozilla's proxy carries, or a destination
// the routing sends directly (any port). Others are refused at once rather
// than tried: Mozilla would refuse them, and they must not go out directly.
func (d *Daemon) TunnelAllows(host, port string) bool {
	if proxy.PortAllowed(port) {
		return true
	}
	r := d.currentRouter()
	return r != nil && r.Decide(context.Background(), host, nil) == routing.Direct
}

func (d *Daemon) currentRouter() *routing.Router {
	d.routing.mu.Lock()
	defer d.routing.mu.Unlock()
	return d.routing.router
}

// wakeRouting makes the update loop check the lists now.
func (d *Daemon) wakeRouting() {
	select {
	case d.routing.wake <- struct{}{}:
	default:
	}
}

// runRoutingUpdates downloads the lists while routing is on and they are
// missing or older than routing.update_interval; it checks every hour and
// when woken, until the daemon stops.
func (d *Daemon) runRoutingUpdates() {
	for {
		cfg := d.config().Routing
		if cfg.Enabled && (routing.Due(d.paths.RoutingDir, cfg.UpdateInterval.Duration(), routingFiles(cfg)) ||
			routing.SourceChanged(d.paths.RoutingDir, cfg.GeoSiteURL, cfg.GeoIPURL) ||
			(appListsWanted && routing.AppListDue(d.paths.RoutingDir, cfg.Region, cfg.UpdateInterval.Duration()))) {
			_ = d.updateRoutingLists()
		}
		select {
		case <-d.stop:
			return
		case <-d.routing.wake:
		case <-time.After(routingCheckInterval):
		}
	}
}

// updateRoutingLists downloads both lists, through Mozilla's proxy when it
// runs (the list hosts may be filtered) and otherwise, or when that fails,
// the way the program's own requests go (DNS and API proxy settings).
func (d *Daemon) updateRoutingLists() error {
	d.routing.mu.Lock()
	if d.routing.updating {
		d.routing.mu.Unlock()
		return nil
	}
	d.routing.updating = true
	d.routing.mu.Unlock()

	cfg := d.config().Routing
	ctx, cancel := context.WithTimeout(context.Background(), listDownloadTimeout)
	defer cancel()
	var err error
	// Through Mozilla only when awake: a list download does not wake it.
	var controller *proxy.Controller
	if engine := d.currentEngine(); engine != nil {
		controller = engine.currentController()
	}
	download := func(client *http.Client) error {
		err := routing.Download(ctx, client, d.paths.RoutingDir, cfg.GeoSiteURL, cfg.GeoIPURL, routingFiles(cfg))
		if appListsWanted {
			if appErr := routing.DownloadAppList(ctx, client, d.paths.RoutingDir, cfg.Region); appErr != nil {
				err = errors.Join(err, fmt.Errorf("app list: %w", appErr))
			}
		}
		return err
	}
	if controller != nil {
		err = download(controller.HTTPClient(listDownloadTimeout))
		if err != nil {
			logx.Warn("downloading the routing lists through Mozilla failed; trying directly err=%s", logx.Err(err))
		}
	}
	if controller == nil || err != nil {
		err = download(&http.Client{Transport: controlplane.Transport(), Timeout: listDownloadTimeout})
	}

	d.routing.mu.Lock()
	d.routing.updating = false
	d.routing.lastCheck = time.Now()
	d.routing.lastErr = ""
	if err != nil {
		d.routing.lastErr = err.Error()
	}
	d.routing.mu.Unlock()
	if err != nil {
		logx.Warn("downloading the routing lists failed err=%s", logx.Err(err))
		return err
	}
	logx.Info("routing lists downloaded")
	d.applyRouting(d.config().Routing)
	return nil
}

func (s *dashboardServer) handleRouting(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, s.d.routingView())
}

// handleRoutingUpdate downloads the lists now (also while routing is off,
// so they are ready when it is turned on) and reports the new state.
func (s *dashboardServer) handleRoutingUpdate(w http.ResponseWriter, r *http.Request) {
	if err := s.d.updateRoutingLists(); err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, s.d.routingView())
}

// destinationTest is POST /api/routing/test: where a destination goes.
type destinationTest struct {
	Host     string `json:"host"`
	Port     string `json:"port,omitempty"`
	Route    string `json:"route"` // direct, proxy, or block
	Rule     string `json:"rule,omitempty"`
	Resolved string `json:"resolved,omitempty"`
	// PortRefused is set when the route is Mozilla and Mozilla's proxy
	// does not connect to the port.
	PortRefused bool   `json:"port_refused"`
	Note        string `json:"note,omitempty"`
}

// handleRoutingTest tells where a destination (a name, an address,
// host:port, or a URL) goes and which rule decides it.
func (s *dashboardServer) handleRoutingTest(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Target string `json:"target"`
	}
	if !readJSON(w, r, &in) {
		return
	}
	host, port, err := splitTarget(in.Target)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, s.d.testDestination(r.Context(), host, port))
}

func (d *Daemon) testDestination(ctx context.Context, host, port string) destinationTest {
	out := destinationTest{Host: host, Port: port, Route: routing.Proxy.String()}
	cfg := d.config().Routing
	router := d.currentRouter()
	switch {
	case !cfg.Enabled:
		out.Note = "Routing is off: everything goes through Mozilla."
	case router == nil:
		out.Note = "Routing is on but its lists are not loaded yet, so everything goes through Mozilla."
	default:
		// Names are looked up through Mozilla, as the proxy does; with
		// the proxy stopped there is nothing to look them up through.
		var lookup routing.LookupFunc
		d.mu.Lock()
		if d.engine != nil {
			lookup = d.engine.routed.Lookup
		}
		d.mu.Unlock()
		decision := router.Explain(ctx, host, lookup)
		out.Route, out.Rule, out.Resolved = decision.Action.String(), decision.Rule, decision.Resolved
	}
	if out.Route == routing.Proxy.String() && port != "" && !proxy.PortAllowed(port) {
		out.PortRefused = true
	}
	return out
}

// splitTarget reads a destination typed by a person: a URL, host:port, or
// a bare name or address.
func splitTarget(target string) (host, port string, err error) {
	target = strings.TrimSpace(target)
	if target == "" {
		return "", "", errors.New("enter a site, an address, or a URL")
	}
	if strings.Contains(target, "://") {
		u, err := url.Parse(target)
		if err != nil || u.Hostname() == "" {
			return "", "", fmt.Errorf("%q is not a URL", target)
		}
		port = u.Port()
		if port == "" {
			port = map[string]string{"http": "80", "https": "443"}[strings.ToLower(u.Scheme)]
		}
		return u.Hostname(), port, nil
	}
	if h, p, err := net.SplitHostPort(target); err == nil {
		return strings.Trim(h, "[]"), p, nil
	}
	target = strings.TrimSuffix(strings.SplitN(target, "/", 2)[0], ".")
	return strings.Trim(target, "[]"), "", nil
}

// routingView reports the routing state.
func (d *Daemon) routingView() routingView {
	cfg := d.config().Routing
	view := routingView{Enabled: cfg.Enabled, Region: cfg.Region, Direct: cfg.Direct, RegionRules: routing.RegionRules(cfg.Region), Files: routing.Files(d.paths.RoutingDir, routingFiles(cfg)), Sources: routing.Sources}
	if src, ok := routing.SourceOf(cfg.GeoSiteURL, cfg.GeoIPURL); ok {
		view.Source = src.ID
	}
	d.routing.mu.Lock()
	if d.routing.router != nil {
		view.Active, view.Summary = true, d.routing.router.Summary
	}
	view.Error, view.Updating = d.routing.err, d.routing.updating
	view.LastCheck, view.LastError = d.routing.lastCheck, d.routing.lastErr
	d.routing.mu.Unlock()
	if engine := d.currentEngine(); engine != nil {
		counts := engine.routed.Counts()
		view.Counts = &counts
	}
	return view
}

// routingFiles are the other geosite files the rules name (ext:), such as
// iran.dat, downloaded with the two lists.
func routingFiles(cfg config.Routing) []routing.ExtraFile {
	return routing.FilesFor(append(append([]string{}, cfg.Direct...), cfg.Block...))
}
