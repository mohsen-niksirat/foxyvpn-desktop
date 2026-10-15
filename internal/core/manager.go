// Package core implements the connection manager: keeps the FxA tokens,
// Guardian proxy pass and H2 tunnel alive with automatic renewal.
package core

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	vpnclient "firefox-vpn-client"

	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/tunnel"
)

// Logger is the shared logger interface.
type Logger interface {
	Logf(format string, args ...interface{})
}

// H2Session alias to the tunnel session.
type H2Session = tunnel.H2Session

func jsonUnmarshal(data []byte, v interface{}) error { return json.Unmarshal(data, v) }
func jsonMarshal(v interface{}) []byte               { b, _ := json.Marshal(v); return b }

const (
	passRenewLead    = 2 * time.Minute
	renewRetryDelay  = 30 * time.Second
	apiTimeout       = 30 * time.Second
	keepAlivePeriod  = 15 * time.Second
	keepAliveTimeout = 10 * time.Second
)

// Manager owns the whole data path and control-plane state.
type Manager struct {
	mu         sync.Mutex
	state      State
	err        error
	countries  []vpnclient.Country
	country    string
	token      *vpnclient.TokenResponse
	pass       *vpnclient.ProxyPassInfo
	session    *H2Session
	listenAddr string

	traffic      Traffic
	exitIP       string
	exitCountry  string
	logger       Logger
	cred         CredentialStore
	stopRenew    context.CancelFunc
	tunnelDialer func(authority string) (net.Conn, error)
	edgeAddr     string
}

type State int

const (
	StateDisconnected State = iota
	StateConnecting
	StateConnected
	StateError
)

func (s State) String() string {
	switch s {
	case StateConnected:
		return "connected"
	case StateConnecting:
		return "connecting"
	case StateError:
		return "error"
	}
	return "disconnected"
}

type Traffic struct {
	Up, Down uint64
}

// CredentialStore abstracts refresh-token persistence (file now,
// Windows Credential Manager in the Windows build).
type CredentialStore interface {
	Load() (*vpnclient.TokenResponse, error)
	Save(*vpnclient.TokenResponse) error
	Clear() error
}

func NewManager(logger Logger, cred CredentialStore) *Manager {
	return &Manager{logger: logger, cred: cred}
}

func (m *Manager) State() State {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.state
}

func (m *Manager) Err() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.err
}

func (m *Manager) Snapshot() (st State, err error, passExp time.Time, quotaLeft, quotaMax, exitIP, exitCountry string, up, down uint64) {
	m.mu.Lock()
	defer m.mu.Unlock()
	st, err = m.state, m.err
	if m.pass != nil {
		passExp = m.pass.ExpiresAt()
		quotaLeft, quotaMax = m.pass.QuotaLeft, m.pass.QuotaMax
	}
	exitIP, exitCountry = m.exitIP, m.exitCountry
	up, down = m.traffic.Up, m.traffic.Down
	return
}

func (m *Manager) Countries() []vpnclient.Country {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.countries
}

func (m *Manager) Country() string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.country
}

func (m *Manager) SetCountry(code string) {
	m.mu.Lock()
	m.country = code
	m.mu.Unlock()
}

// tokenFromStore returns cached refresh-token tokens, or nil.
func (m *Manager) tokenFromStore() *vpnclient.TokenResponse {
	if m.cred == nil {
		return nil
	}
	tok, err := m.cred.Load()
	if err != nil || tok == nil || tok.RefreshToken == "" {
		return nil
	}
	return tok
}

// Login with email+password (fresh FxA login); verifies session by email
// code if needed. verifyCode is requested via the callback.
func (m *Manager) Login(ctx context.Context, email, password string, askCode func() string) error {
	m.setState(StateConnecting, nil)
	m.logf("logging in to Firefox Account as %s", email)

	login, err := vpnclient.FxaLogin(ctx, email, password)
	if err != nil {
		m.setState(StateError, fmt.Errorf("login failed: %w", err))
		return m.err
	}
	m.logf("login ok uid=%s verified=%v", login.UID, login.Verified)

	if !login.Verified {
		if askCode == nil {
			m.setState(StateError, fmt.Errorf("session unverified and no code prompt available"))
			return m.err
		}
		code := askCode()
		if err := vpnclient.FxaVerifySession(ctx, login.SessionToken, code); err != nil {
			m.setState(StateError, fmt.Errorf("verification failed: %w", err))
			return m.err
		}
		m.logf("session verified")
	}

	token, err := vpnclient.FxaOAuthToken(ctx, login.SessionToken)
	if err != nil {
		m.setState(StateError, fmt.Errorf("oauth failed: %w", err))
		return m.err
	}
	m.setToken(token)
	m.logf("oauth token obtained (expires in %ds)", token.ExpiresIn)
	return nil
}

// Connect using a cached refresh token (no password).
func (m *Manager) ConnectCached(ctx context.Context) error {
	tok := m.tokenFromStore()
	if tok == nil {
		return fmt.Errorf("no cached token; password login required")
	}
	m.setState(StateConnecting, nil)
	m.logf("refreshing cached token")
	refreshed, err := vpnclient.FxaRefreshToken(ctx, tok.RefreshToken)
	if err != nil {
		m.logf("token refresh failed: %v", err)
		m.setState(StateError, err)
		return err
	}
	if refreshed.RefreshToken == "" {
		refreshed.RefreshToken = tok.RefreshToken
	}
	m.setToken(refreshed)
	return m.connectUpstream(ctx)
}

func (m *Manager) setToken(t *vpnclient.TokenResponse) {
	m.mu.Lock()
	m.token = t
	m.mu.Unlock()
	if m.cred != nil {
		_ = m.cred.Save(t)
	}
	if m.session != nil {
		m.mu.Lock()
		pass := m.pass
		m.mu.Unlock()
		if pass != nil {
			m.session.UpdateBearer(pass.BearerToken())
		}
	}
}

// Connect runs the full connect flow after Login (or ConnectCached).
func (m *Manager) Connect(ctx context.Context) error {
	m.mu.Lock()
	tok := m.token
	m.mu.Unlock()
	if tok == nil {
		return m.ConnectCached(ctx)
	}
	m.setState(StateConnecting, nil)
	return m.connectUpstream(ctx)
}

func (m *Manager) connectUpstream(ctx context.Context) error {
	// server list
	m.logf("fetching server list")
	countries, err := fetchCountries()
	if err != nil {
		m.setState(StateError, fmt.Errorf("server list failed: %w", err))
		return m.err
	}
	m.mu.Lock()
	m.countries = countries
	code := m.country
	m.mu.Unlock()

	// proxy pass
	pass, err := m.mintPass(ctx)
	if err != nil {
		return err
	}

	addr := pickProxy(countries, code)
	if addr == "" && code != "" {
		m.logf("no server for country %q; falling back to first available", code)
		addr = pickProxy(countries, "")
	}
	if addr == "" {
		m.setState(StateError, fmt.Errorf("no usable server available"))
		return m.err
	}
	m.logf("upstream: %s", addr)

	sess, err := dialH2(addr, pass.BearerToken())
	if err != nil {
		m.setState(StateError, fmt.Errorf("upstream failed: %w", err))
		return m.err
	}

	m.mu.Lock()
	m.session = sess
	m.pass = pass
	m.tunnelDialer = sess.OpenTunnel
	m.edgeAddr = addr
	m.mu.Unlock()
	m.setState(StateConnected, nil)

	// Set the OS-wide proxy so browsers use the tunnel without configuration.
	if perr := EnableSystemProxy(sysHTTPProxyPort); perr != nil {
		m.logf("system proxy enable failed: %v", perr)
	} else {
		m.logf("system proxy set to 127.0.0.1:%d", sysHTTPProxyPort)
	}

	// probe exit IP (non-fatal)
	go m.probeExit()
	// renewal loop
	m.startRenewal()
	return nil
}

func (m *Manager) mintPass(ctx context.Context) (*vpnclient.ProxyPassInfo, error) {
	m.mu.Lock()
	tok := m.token
	m.mu.Unlock()
	if tok == nil {
		err := fmt.Errorf("not signed in")
		m.setState(StateError, err)
		return nil, err
	}
	cctx, cancel := context.WithTimeout(ctx, apiTimeout)
	defer cancel()
	pass, err := vpnclient.FetchProxyPass(cctx, vpnclient.GuardianEndpointDefault, tok.AccessToken)
	if err != nil {
		// first-use activation, like FoxyVpnService.kt
		m.logf("pass rejected (%v); activating Guardian entitlement", err)
		if actErr := activateGuardian(tok.AccessToken); actErr != nil {
			m.setState(StateError, fmt.Errorf("activate failed: %w", actErr))
			return nil, m.err
		}
		cctx2, cancel2 := context.WithTimeout(ctx, apiTimeout)
		defer cancel2()
		pass, err = vpnclient.FetchProxyPass(cctx2, vpnclient.GuardianEndpointDefault, tok.AccessToken)
		if err != nil {
			m.setState(StateError, fmt.Errorf("proxy pass failed: %w", err))
			return nil, m.err
		}
	}
	m.mu.Lock()
	m.pass = pass
	m.mu.Unlock()
	m.logf("proxy pass acquired exp=%s quota left=%s", pass.ExpiresAt().Format(time.RFC3339), pass.QuotaLeft)
	return pass, nil
}

func (m *Manager) startRenewal() {
	m.mu.Lock()
	if m.stopRenew != nil {
		m.mu.Unlock()
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	m.stopRenew = cancel
	m.mu.Unlock()

	go func() {
		for {
			m.mu.Lock()
			pass := m.pass
			m.mu.Unlock()
			if pass == nil {
				return
			}
			waitUntil := pass.ExpiresAt().Add(-passRenewLead)
			d := time.Until(waitUntil)
			if d < renewRetryDelay {
				d = renewRetryDelay
			}
			select {
			case <-ctx.Done():
				return
			case <-time.After(d):
			}
			m.logf("renewing proxy pass")
			npass, err := m.mintPass(context.Background())
			if err != nil {
				m.logf("renewal failed: %v (retrying in %s)", err, renewRetryDelay)
				continue
			}
			m.mu.Lock()
			sess := m.session
			m.mu.Unlock()
			if sess != nil {
				sess.UpdateBearer(npass.BearerToken())
				m.logf("proxy pass swapped into live session")
			}
		}
	}()
}

func (m *Manager) probeExit() {
	const probeURL = "https://www.cloudflare.com/cdn-cgi/trace"
	transport := &http.Transport{
		Proxy: nil, DisableKeepAlives: true,
		TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS12},
		DialContext: func(ctx context.Context, _, authority string) (net.Conn, error) {
			m.mu.Lock()
			d := m.tunnelDialer
			m.mu.Unlock()
			if d == nil {
				return nil, fmt.Errorf("not connected")
			}
			return d(authority)
		},
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Timeout: 20 * time.Second}
	resp, err := client.Get(probeURL)
	if err != nil {
		m.logf("exit probe failed: %v", err)
		return
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 8192))
	fields := map[string]string{}
	for _, line := range strings.Split(string(body), "\n") {
		if k, v, ok := strings.Cut(strings.TrimSpace(line), "="); ok {
			fields[k] = v
		}
	}
	m.mu.Lock()
	m.exitIP, m.exitCountry = fields["ip"], fields["loc"]
	m.mu.Unlock()
	m.logf("exit verified ip=%s country=%s", fields["ip"], fields["loc"])
}

// sysHTTPProxyPort is the OS proxy port; the HTTP proxy listener must use it.
const sysHTTPProxyPort = 8888

func (m *Manager) Disconnect() {
	if derr := DisableSystemProxy(); derr != nil {
		m.logf("system proxy disable failed: %v", derr)
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.stopRenew != nil {
		m.stopRenew()
		m.stopRenew = nil
	}
	if m.session != nil {
		m.session.Close()
		m.session = nil
	}
	m.pass = nil
	m.tunnelDialer = nil
	m.edgeAddr = ""
	m.exitIP, m.exitCountry = "", ""
	m.setState(StateDisconnected, nil)
}

// EdgeAddr returns the upstream edge "host:port" of the active session, or "" when disconnected.
func (m *Manager) EdgeAddr() string {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.edgeAddr
}

// DialTunnel exposes the tunnel opener to the local proxy servers.
func (m *Manager) DialTunnel(authority string) (net.Conn, error) {
	m.mu.Lock()
	d := m.tunnelDialer
	m.mu.Unlock()
	if d == nil {
		return nil, fmt.Errorf("not connected")
	}
	return d(authority)
}

func (m *Manager) setState(s State, err error) {
	m.mu.Lock()
	m.state, m.err = s, err
	m.mu.Unlock()
	m.logf("state -> %s", s)
}

func (m *Manager) logf(format string, args ...interface{}) {
	if m.logger != nil {
		m.logger.Logf(format, args...)
	}
}

// AddTraffic records byte counters.
func (m *Manager) AddTraffic(up, down uint64) {
	m.mu.Lock()
	m.traffic.Up += up
	m.traffic.Down += down
	m.mu.Unlock()
}

// --- helpers ---

func fetchCountries() ([]vpnclient.Country, error) {
	ctx, cancel := context.WithTimeout(context.Background(), apiTimeout)
	defer cancel()
	return vpnclient.FetchServerList(ctx)
}

func activateGuardian(accessToken string) error {
	req, err := http.NewRequest(http.MethodPost,
		vpnclient.GuardianEndpointDefault+"/api/v1/fpn/activate", nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "MozillaVPN/2.35.0 (sys:linux; iap:true)")
	req.Header.Set("Accept", "application/json")
	client := &http.Client{Timeout: apiTimeout}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
	if resp.StatusCode != 200 {
		return fmt.Errorf("activate returned HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	return nil
}

func pickProxy(countries []vpnclient.Country, code string) string {
	for _, c := range countries {
		if code != "" && !strings.EqualFold(c.Code, code) {
			continue
		}
		for _, city := range c.Cities {
			for _, srv := range city.Servers {
				if srv.Quarantined {
					continue
				}
				return fmt.Sprintf("%s:%d", srv.Hostname, srv.Port)
			}
		}
	}
	return ""
}

func dialH2(proxyAddr, bearer string) (*H2Session, error) {
	host := proxyAddr
	if h, p, err := net.SplitHostPort(proxyAddr); err == nil && p == "" {
		host = net.JoinHostPort(h, "443")
	}
	u, err := url.Parse("https://" + host)
	if err != nil {
		return nil, err
	}
	return tunnel.NewH2Session(u, bearer, 20*time.Second)
}

// FileCredentialStore keeps the refresh token in a 0600 file (fallback;
// Windows build uses the Credential Manager implementation).
type FileCredentialStore struct{ Path string }

func (f *FileCredentialStore) Load() (*vpnclient.TokenResponse, error) {
	data, err := os.ReadFile(f.Path)
	if err != nil {
		return nil, err
	}
	var t vpnclient.TokenResponse
	if err := jsonUnmarshal(data, &t); err != nil {
		return nil, err
	}
	return &t, nil
}

func (f *FileCredentialStore) Save(t *vpnclient.TokenResponse) error {
	data := jsonMarshal(map[string]string{
		"access_token": t.AccessToken, "refresh_token": t.RefreshToken,
		"scope": t.Scope, "token_type": t.TokenType,
	})
	if err := os.MkdirAll(filepath.Dir(f.Path), 0o700); err != nil {
		return err
	}
	return os.WriteFile(f.Path, data, 0o600)
}

func (f *FileCredentialStore) Clear() error { return os.Remove(f.Path) }

// PrefetchCountries loads the server list without connecting (UI dropdown).
func (m *Manager) PrefetchCountries() {
	go func() {
		if cs, err := fetchCountries(); err == nil {
			m.mu.Lock()
			m.countries = cs
			m.mu.Unlock()
			m.logf("server list loaded (%d countries)", len(cs))
		}
	}()
}

// TryAutoConnect reconnects from the cached refresh token at startup.
func (m *Manager) TryAutoConnect() bool {
	if m.tokenFromStore() == nil {
		return false
	}
	go func() {
		m.logf("cached session found; auto-connecting")
		if err := m.ConnectCached(context.Background()); err != nil {
			m.logf("auto-connect failed: %v (sign in required)", err)
		}
	}()
	return true
}

// pickMasque returns a MASQUE edge address and its CONNECT-UDP template for
// the given country (falls back to the first available country).
func pickMasque(countries []vpnclient.Country, code string) (addr, template string) {
	for _, c := range countries {
		if code != "" && !strings.EqualFold(c.Code, code) {
			continue
		}
		for _, city := range c.Cities {
			for _, srv := range city.Servers {
				if srv.Quarantined {
					continue
				}
				for _, pr := range srv.Protocols {
					if strings.EqualFold(pr.Name, "masque") && pr.TemplateString != "" {
						return fmt.Sprintf("%s:%d", pr.Host, pr.Port), pr.TemplateString
					}
				}
			}
		}
	}
	return "", ""
}

// MasqueInfo returns the active MASQUE edge address, bearer token and
// CONNECT-UDP template, or ok=false when unavailable.
func (m *Manager) MasqueInfo() (addr, bearer, template string, ok bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.pass == nil || m.countries == nil {
		return "", "", "", false
	}
	a, t := pickMasque(m.countries, m.country)
	if a == "" {
		return "", "", "", false
	}
	return a, m.pass.BearerToken(), t, true
}
