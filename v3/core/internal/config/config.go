// Package config holds the persistent settings of the multi-account daemon:
// a single JSON file in the data directory that the CLI creates with
// defaults, the user may edit by hand, and the dashboard updates.
package config

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/guardian"
	"github.com/armanlife/firefox-vpn-client/core/internal/resolver"
	"github.com/armanlife/firefox-vpn-client/core/internal/routing"
	"github.com/armanlife/firefox-vpn-client/core/internal/securefile"
)

// CurrentVersion is the config schema version written by this build.
const CurrentVersion = 2

// FileName is the config file name inside the data directory.
const FileName = "config.json"

// Default values for a new config file.
const (
	DefaultProxyListen            = "127.0.0.1:10810"
	DefaultDashboardListen        = "127.0.0.1:10820"
	DefaultSwitchThresholdPercent = 95
)

// Fixed settings: values the program uses that are not in config.json.
// They were settings once, and are kept here, in one place, to read and to
// change in the code.
const (
	// ConnectTimeout bounds opening a connection through Mozilla: the
	// session to Mozilla's proxy server, and each connection through it to
	// a site.
	ConnectTimeout = 20 * time.Second
	// HandshakeTimeout is how long an application connecting to the local
	// proxy has to send its SOCKS5 or HTTP request (the site it wants, and
	// the login).
	HandshakeTimeout = 10 * time.Second
	// IdleTimeout closes a connection that carried no data either way for
	// this long. 0: never, since applications such as chats keep quiet
	// connections open on purpose.
	IdleTimeout time.Duration = 0
	// ExitCheckTimeout is how long the public IP check, which runs after
	// every connection test, waits for each service.
	ExitCheckTimeout = 20 * time.Second
	// The proxy start always waits while no network is connected
	// (service.Daemon.mustWaitForNetwork); that was a setting too.
)

// Config is the complete daemon configuration.
type Config struct {
	Version   int       `json:"version"`
	Proxy     Proxy     `json:"proxy"`
	Accounts  Accounts  `json:"accounts"`
	Dashboard Dashboard `json:"dashboard"`
	Network   Network   `json:"network"`
	DNS       DNS       `json:"dns"`
	Routing   Routing   `json:"routing"`
	// SystemProxy is separate from Proxy so that switching it does not
	// restart the proxy.
	SystemProxy SystemProxy `json:"system_proxy"`
	Logging     Logging     `json:"logging"`
}

// SystemProxy is what the tray icon or the app mode does with Windows'
// proxy setting, in the signed-in user's session (v2rayN's two choices):
//
//	set    point it at the local proxy (HTTP on the SOCKS5 port) while the
//	       proxy runs, and restore the previous one when it stops
//	clear  turn the system proxy off, once when chosen (a setting this
//	       program made is restored first)
type SystemProxy struct {
	Mode string `json:"mode"`
}

// System proxy modes.
const (
	SystemProxySet   = "set"
	SystemProxyClear = "clear"
)

// Routing sends chosen destinations directly through the local network, or
// refuses them, instead of through Mozilla's proxy (package routing). Off
// by default.
type Routing struct {
	Enabled bool `json:"enabled"`
	// Region is the country whose sites and networks go directly
	// (routing.Regions: ir, cn, ru, af, tr, id, br, or "" for none). Its
	// preset rules (routing.RegionRules, private networks included) are
	// put in Direct, where the user can change them; another region
	// replaces them with its own.
	Region string `json:"region"`
	// Direct and Block are rules: geosite:TAG, geoip:TAG, ext:FILE:TAG,
	// domain:NAME, full:NAME, keyword:TEXT, regexp:EXPR, an IP, or a CIDR.
	// Block wins. Direct holds the region's presets and the user's rules.
	Direct []string `json:"direct"`
	Block  []string `json:"block"`
	// ResolveDomains looks up names that no domain rule matched to apply
	// the IP rules to them (a DNS query per new name, outside the proxy).
	ResolveDomains bool `json:"resolve_domains"`
	// GeoSiteURL and GeoIPURL are the v2ray lists, downloaded again every
	// UpdateInterval into data/routing.
	GeoSiteURL     string   `json:"geosite_url"`
	GeoIPURL       string   `json:"geoip_url"`
	UpdateInterval Duration `json:"update_interval"`
}

// Proxy configures the local SOCKS5 listener and the upstream location.
type Proxy struct {
	// Listen is the local SOCKS5 address.
	Listen string `json:"listen"`
	// Username and Password, when set, require SOCKS5 username/password
	// authentication (RFC 1929) from every client. Both or neither.
	Username string `json:"username"`
	Password string `json:"password"`
	// Country selects the location by code or name; empty selects the
	// recommended location, and "fastest" the location with the lowest
	// measured latency at each start. Mutually exclusive with Server.
	Country string `json:"country"`
	// Server pins an exact upstream host:port.
	Server string `json:"server"`
	// Transport is "h2" (HTTP/2 over TCP) or "h3" (HTTP/3 over QUIC).
	Transport           string `json:"transport"`
	UpstreamConnections int    `json:"upstream_connections"`
	MaxConnections      int    `json:"max_connections"`
	// IdleSleep, when not 0, lets the proxy sleep after this long without
	// a connection through Mozilla: its upstream session closes and the
	// account renews no proxy pass and checks no quota until the next
	// connection, a connection test, or a real-delay test wakes it.
	IdleSleep Duration `json:"idle_sleep"`
	// AllowLocked is ignored: every location is offered, including those
	// the server list marks locked. It stays only so that files and
	// settings requests that still carry it load; it is cleared on load
	// and not written back.
	AllowLocked bool `json:"allow_locked,omitempty"`
}

// Accounts configures multi-account failover.
type Accounts struct {
	// SwitchThresholdPercent is the share of an account's quota after
	// which the next account takes over (90 means 45 GB of 50 GB).
	SwitchThresholdPercent float64 `json:"switch_threshold_percent"`
	// Order lists the accounts by priority.
	Order []AccountRef `json:"order"`
}

// AccountRef places one stored account in the priority order.
type AccountRef struct {
	ID      string `json:"id"`
	Enabled bool   `json:"enabled"`
}

// Dashboard configures the web dashboard. Without a username the
// dashboard does not ask for credentials.
type Dashboard struct {
	Enabled      bool   `json:"enabled"`
	Listen       string `json:"listen"`
	Username     string `json:"username"`
	PasswordHash string `json:"password_hash"`
}

// Network configures control-plane access.
type Network struct {
	// APIRelay, when set, sends the control-plane requests (FxA, Guardian,
	// the server list, the geo files, and flags) through the user's own
	// relay: an https:// URL that takes the target in its url parameter
	// (scripts/relay: a Cloudflare Worker or a PHP file). The VPN traffic
	// never uses it.
	APIRelay         string `json:"api_relay"`
	GuardianEndpoint string `json:"guardian_endpoint"`
}

// DNS chooses how this program resolves the host names it connects to
// itself: Mozilla's Fastly proxy servers and the account, Guardian, and
// server-list APIs. Names that SOCKS clients send are resolved by Mozilla's
// exit, not here.
type DNS struct {
	// Servers are queried at the same time and the first answer wins:
	// https:// URLs (DNS over HTTPS), tls://host (DNS over TLS), or
	// IP[:port] (plain DNS). Empty uses the system resolver.
	Servers []string `json:"servers"`
	// FallbackToSystem uses the system resolver when every server fails.
	FallbackToSystem bool `json:"fallback_to_system"`
}

// Logging configures log detail.
type Logging struct {
	// Verbose logs CONNECT destinations, which is privacy sensitive.
	Verbose bool `json:"verbose"`
}

// DefaultDNSServers is the "Automatic" choice for the program's own
// lookups: DNS over HTTPS, so a filtering network cannot hijack the names
// of Mozilla's and Firefox Accounts' servers (dns.fallback_to_system still
// uses the system's DNS when none answers).
var DefaultDNSServers = []string{
	"https://1.1.1.1/dns-query",
	"https://8.8.8.8/dns-query",
	"https://9.9.9.9/dns-query",
}

// Default returns the configuration written for a new data directory.
func Default() Config {
	return Config{
		Version: CurrentVersion,
		Proxy: Proxy{
			Listen:              DefaultProxyListen,
			Transport:           "h2",
			UpstreamConnections: 1,
			MaxConnections:      256,
			IdleSleep:           Duration(DefaultIdleSleep),
		},
		Accounts: Accounts{
			SwitchThresholdPercent: DefaultSwitchThresholdPercent,
			Order:                  []AccountRef{},
		},
		Dashboard: Dashboard{
			Enabled: true,
			Listen:  DefaultDashboardListen,
		},
		Network: Network{
			GuardianEndpoint: guardian.DefaultEndpoint,
		},
		DNS: DNS{
			Servers:          append([]string(nil), DefaultDNSServers...),
			FallbackToSystem: true,
		},
		// Proxy only until the user chooses the system proxy; the choice is
		// kept here.
		SystemProxy: SystemProxy{Mode: SystemProxyClear},
		Routing: Routing{
			Region:         routing.RegionIran,
			Direct:         routing.RegionRules(routing.RegionIran),
			Block:          []string{},
			GeoSiteURL:     routing.DefaultGeoSiteURL,
			GeoIPURL:       routing.DefaultGeoIPURL,
			UpdateInterval: Duration(DefaultRoutingUpdateInterval),
		},
	}
}

// DefaultIdleSleep is how long the proxy waits without a connection
// through Mozilla before it sleeps (proxy.idle_sleep).
const DefaultIdleSleep = 15 * time.Minute

// DefaultRoutingUpdateInterval is how often the routing lists are
// downloaded again.
const DefaultRoutingUpdateInterval = 10 * 24 * time.Hour

// Load reads path, filling fields the file omits with defaults. A missing
// file is created with defaults and reported through created. Unknown
// fields are rejected so that typos in a hand-edited file surface.
// Warn receives notices about the config file (dropped settings); the
// program routes it to its log.
var Warn func(string)

// recoverCorrupt handles a config.json that is not JSON at all (empty or
// cut short by a crash, or edited into invalid JSON): the file is kept
// as config.json.corrupt for the user, and the program starts with the
// default settings rather than not at all, which on a phone would leave no
// way to fix it. The accounts are kept apart and come back on their own.
func recoverCorrupt(path string, data []byte, parseErr error) (Config, bool, error) {
	kept := ""
	if len(bytes.TrimSpace(data)) > 0 {
		if err := securefile.WritePrivate(path+".corrupt", data); err != nil {
			return Config{}, false, fmt.Errorf("parsing %s: %w (keeping a copy failed: %v)", path, parseErr, err)
		}
		kept = "; the old file is kept as " + filepath.Base(path) + ".corrupt"
	}
	cfg := Default()
	if err := Save(path, cfg); err != nil {
		return Config{}, false, fmt.Errorf("parsing %s: %w (replacing it failed: %v)", path, parseErr, err)
	}
	if Warn != nil {
		Warn(fmt.Sprintf("%s could not be read (%v); started with the default settings%s", path, parseErr, kept))
	}
	return cfg, true, nil
}

func Load(path string) (cfg Config, created bool, err error) {
	rewrite := false
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		cfg = Default()
		if err := Save(path, cfg); err != nil {
			return Config{}, false, err
		}
		return cfg, true, nil
	}
	if err != nil {
		return Config{}, false, err
	}
	cfg = Default()
	// No Direct list in the file: the region's presets, below.
	cfg.Routing.Direct = nil
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&cfg); err != nil {
		// A setting this build no longer has (or a typo) is dropped with a
		// warning and the file is rewritten without it.
		if !strings.HasPrefix(err.Error(), "json: unknown field") {
			// Not JSON at all (empty or cut short by a crash): start
			// anyway. A wrong value in valid JSON is a person's edit,
			// reported as it is rather than reset.
			if !json.Valid(data) {
				return recoverCorrupt(path, data, err)
			}
			return Config{}, false, fmt.Errorf("parsing %s: %w", path, err)
		}
		cfg = Default()
		cfg.Routing.Direct = nil
		if err := json.Unmarshal(data, &cfg); err != nil {
			return Config{}, false, fmt.Errorf("parsing %s: %w", path, err)
		}
		if Warn != nil {
			Warn(fmt.Sprintf("%s: ignored %s (not a setting of this version); the file is rewritten without it", path, strings.TrimPrefix(err.Error(), "json: ")))
		}
		rewrite = true
	}
	if cfg.Version > CurrentVersion {
		return Config{}, false, fmt.Errorf("%s has config version %d; this build supports up to %d", path, cfg.Version, CurrentVersion)
	}
	// The recommended location is the empty country; "REC" (its server-list
	// code) and "recommended" mean the same.
	if c := strings.TrimSpace(cfg.Proxy.Country); strings.EqualFold(c, "REC") || strings.EqualFold(c, "recommended") {
		cfg.Proxy.Country = ""
		rewrite = true
	}
	if cfg.Proxy.AllowLocked {
		cfg.Proxy.AllowLocked = false
		rewrite = true
	}
	if cfg.Accounts.Order == nil {
		cfg.Accounts.Order = []AccountRef{}
	}
	if cfg.DNS.Servers == nil {
		cfg.DNS.Servers = []string{}
	}
	if cfg.Routing.Direct == nil {
		cfg.Routing.Direct = routing.RegionRules(cfg.Routing.Region)
	}
	if cfg.Routing.Block == nil {
		cfg.Routing.Block = []string{}
	}
	// Version 1 added the region's preset rules by itself; they are in
	// the Direct list now, where the user can change them.
	if cfg.Version < 2 {
		cfg.Routing.Direct = routing.WithRegionRules(cfg.Routing.Region, cfg.Routing.Direct)
		rewrite = true
	}
	if err := cfg.Validate(); err != nil {
		return Config{}, false, fmt.Errorf("invalid %s: %w", path, err)
	}
	if rewrite {
		if err := Save(path, cfg); err != nil {
			return Config{}, false, err
		}
	}
	return cfg, false, nil
}

// ValidateRelay checks an API relay URL: empty (none), or https:// with a
// host. Plain http is refused: the sign-in and the account tokens cross
// the relay.
func ValidateRelay(raw string) error {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return nil
	}
	u, err := url.Parse(raw)
	if err != nil {
		return err
	}
	if u.Scheme != "https" || u.Host == "" {
		return errors.New("must be an https:// URL (the sign-in and the account tokens cross it)")
	}
	return nil
}

// Save writes cfg to path with owner-only permissions; the file can hold
// the dashboard password hash.
func Save(path string, cfg Config) error {
	cfg.Version = CurrentVersion
	if err := securefile.EnsurePrivateDir(filepath.Dir(path)); err != nil {
		return err
	}
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return securefile.WritePrivate(path, append(data, '\n'))
}

// Validate reports the first invalid setting.
func (c Config) Validate() error {
	p := c.Proxy
	if err := validateListen("proxy.listen", p.Listen); err != nil {
		return err
	}
	if (p.Username == "") != (p.Password == "") {
		return errors.New("proxy.username and proxy.password must be set together")
	}
	if len(p.Username) > 255 || len(p.Password) > 255 {
		return errors.New("proxy.username and proxy.password are limited to 255 bytes")
	}
	if strings.TrimSpace(p.Country) != "" && strings.TrimSpace(p.Server) != "" {
		return errors.New("proxy.country and proxy.server are mutually exclusive")
	}
	if p.Transport != "h2" && p.Transport != "h3" {
		return fmt.Errorf("proxy.transport must be \"h2\" or \"h3\", not %q", p.Transport)
	}
	if p.UpstreamConnections < 1 {
		return errors.New("proxy.upstream_connections must be at least 1")
	}
	if p.MaxConnections < 0 {
		return errors.New("proxy.max_connections must not be negative (0 disables the limit)")
	}
	if p.IdleSleep != 0 && p.IdleSleep.Duration() < time.Minute {
		return errors.New("proxy.idle_sleep must be 0 (off) or at least 1m")
	}
	a := c.Accounts
	if a.SwitchThresholdPercent <= 0 || a.SwitchThresholdPercent > 100 {
		return errors.New("accounts.switch_threshold_percent must be above 0 and at most 100")
	}
	seen := make(map[string]bool, len(a.Order))
	for _, ref := range a.Order {
		if strings.TrimSpace(ref.ID) == "" {
			return errors.New("accounts.order contains an empty id")
		}
		if seen[ref.ID] {
			return fmt.Errorf("accounts.order lists %q twice", ref.ID)
		}
		seen[ref.ID] = true
	}
	if c.Dashboard.Enabled {
		if err := validateListen("dashboard.listen", c.Dashboard.Listen); err != nil {
			return err
		}
	}
	if (c.Dashboard.Username == "") != (c.Dashboard.PasswordHash == "") {
		return errors.New("dashboard.username and dashboard.password_hash must be set together")
	}
	if err := resolver.Validate(c.DNS.Servers); err != nil {
		return fmt.Errorf("dns.servers: %w", err)
	}
	if err := ValidateRelay(c.Network.APIRelay); err != nil {
		return fmt.Errorf("network.api_relay: %w", err)
	}
	r := c.Routing
	if err := routing.ValidateRegion(r.Region); err != nil {
		return fmt.Errorf("routing.region: %w", err)
	}
	if err := routing.Validate(r.Direct); err != nil {
		return fmt.Errorf("routing.direct: %w", err)
	}
	if err := routing.Validate(r.Block); err != nil {
		return fmt.Errorf("routing.block: %w", err)
	}
	for field, u := range map[string]string{"routing.geosite_url": r.GeoSiteURL, "routing.geoip_url": r.GeoIPURL} {
		if !strings.HasPrefix(strings.ToLower(u), "https://") {
			return fmt.Errorf("%s must be an https URL", field)
		}
	}
	if r.UpdateInterval.Duration() < time.Hour {
		return errors.New("routing.update_interval must be at least 1h")
	}
	switch c.SystemProxy.Mode {
	case SystemProxySet, SystemProxyClear:
	default:
		return fmt.Errorf("system_proxy.mode %q is not supported; it must be %q or %q", c.SystemProxy.Mode, SystemProxySet, SystemProxyClear)
	}
	return nil
}

func validateListen(field, addr string) error {
	host, port, err := net.SplitHostPort(addr)
	if err != nil {
		return fmt.Errorf("%s %q must be host:port: %w", field, addr, err)
	}
	if port == "" || (host != "" && net.ParseIP(host) == nil && host != "localhost") {
		return fmt.Errorf("%s %q must be an IP address and port", field, addr)
	}
	return nil
}

// DataDirName is the folder next to the executable that holds all
// application data (config, accounts, state) when the core runs on its own:
// moving the executable's folder moves the data with it. Not "data": the
// desktop app's build keeps Flutter's own files in a "data" folder beside
// the core.
const DataDirName = "user-data"

// The desktop app (app/lib/core/core_api.dart, CoreLocator.dataDirFor)
// keeps its data in DataDirName beside it on Windows (the installer puts it
// in a folder of the user's own, so that is writable); on macOS and Linux
// in AppFolder in the user's data location, or, with a PortableMarker file
// beside it, in DataDirName beside it. The app keeps its core in CoreFolder
// beside its executable (Windows, Linux) or beside the executable itself
// (inside the macOS bundle). A core started from either place uses the
// app's data folder, so it sees the app's accounts and settings.
const (
	AppFolder      = "Firefox VPN Client"
	PortableMarker = "portable"
	CoreFolder     = "core"
)

// appExecutables are the desktop app's executables: Windows, Linux, and
// macOS (inside Firefox VPN.app/Contents/MacOS).
var appExecutables = []string{"firefox-vpn.exe", "firefox-vpn", "Firefox VPN"}

// DefaultDataDir returns the data folder: DataDirName next to the running
// executable (symlinks resolved, so a linked binary still uses its real
// folder), or, beside the desktop app on macOS and Linux, the app's.
func DefaultDataDir() (string, error) {
	dir, err := executableDir()
	if err != nil {
		return "", err
	}
	return defaultDataDirFor(dir, runtime.GOOS, os.Getenv, fileExists), nil
}

// ProgramDir is the program's folder: the desktop app's when this core
// belongs to it, else the running executable's; empty when unknown.
func ProgramDir() string {
	dir, err := executableDir()
	if err != nil {
		return ""
	}
	if app := appDir(dir, fileExists); app != "" {
		return app
	}
	return dir
}

// executableDir is the running executable's folder, symlinks resolved.
func executableDir() (string, error) {
	exe, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("locating the executable: %w", err)
	}
	if resolved, err := filepath.EvalSymlinks(exe); err == nil {
		exe = resolved
	}
	return filepath.Dir(exe), nil
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// appDir is the desktop app's folder when exeDir is that folder or its
// CoreFolder; "" when the core is on its own.
func appDir(exeDir string, exists func(string) bool) string {
	dirs := []string{exeDir}
	if filepath.Base(exeDir) == CoreFolder {
		dirs = append(dirs, filepath.Dir(exeDir))
	}
	for _, dir := range dirs {
		for _, name := range appExecutables {
			if exists(filepath.Join(dir, name)) {
				return dir
			}
		}
	}
	return ""
}

// defaultDataDirFor is DefaultDataDir without the file system and the
// environment, for tests.
func defaultDataDirFor(exeDir, goos string, getenv func(string) string, exists func(string) bool) string {
	app := appDir(exeDir, exists)
	if app == "" {
		return filepath.Join(exeDir, DataDirName)
	}
	if goos == "windows" || exists(filepath.Join(app, PortableMarker)) {
		return filepath.Join(app, DataDirName)
	}
	home := getenv("HOME")
	if home == "" {
		home = getenv("USERPROFILE")
	}
	switch goos {
	case "darwin":
		return filepath.Join(home, "Library", "Application Support", AppFolder)
	default:
		base := getenv("XDG_DATA_HOME")
		if base == "" {
			base = filepath.Join(home, ".local", "share")
		}
		return filepath.Join(base, "firefox-vpn-client")
	}
}

// CheckWritable verifies that dir can be created and written, so a
// read-only installation folder fails with a clear message at startup.
func CheckWritable(dir string) error {
	if err := securefile.EnsurePrivateDir(dir); err != nil {
		return fmt.Errorf("data folder %s is not writable: %w (move the program to a writable folder or pass -data-dir)", dir, err)
	}
	probe, err := os.CreateTemp(dir, ".write-test-*")
	if err != nil {
		return fmt.Errorf("data folder %s is not writable: %w (move the program to a writable folder or pass -data-dir)", dir, err)
	}
	name := probe.Name()
	_ = probe.Close()
	return os.Remove(name)
}

// Duration is a time.Duration written as a Go duration string ("10s").
type Duration time.Duration

func (d Duration) Duration() time.Duration { return time.Duration(d) }

func (d Duration) MarshalJSON() ([]byte, error) {
	return json.Marshal(time.Duration(d).String())
}

func (d *Duration) UnmarshalJSON(data []byte) error {
	var text string
	if err := json.Unmarshal(data, &text); err != nil {
		return fmt.Errorf("durations are strings such as \"10s\" or \"5m\"")
	}
	parsed, err := time.ParseDuration(strings.TrimSpace(text))
	if err != nil {
		return err
	}
	*d = Duration(parsed)
	return nil
}
