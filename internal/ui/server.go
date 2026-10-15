// Package ui serves the local web UI (tabs: Connect / Settings / About).
package ui

import (
	"embed"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"sync"
	"time"

	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/core"
	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/tun"
)

//go:embed static
var staticFS embed.FS

type Server struct {
	mgr     *core.Manager
	servers ProxyServers
	ln      net.Listener
	quit    func() // fully exits the process; optional
}

// SetQuit registers a full-process exit hook (used by the silent/windowed build).
func (s *Server) SetQuit(f func()) { s.quit = f }

type ProxyServers interface {
	StartSocks(addr string) error
	StartHTTP(addr string) error
	Stop()
}

func New(mgr *core.Manager, proxy ProxyServers) *Server {
	return &Server{mgr: mgr, servers: proxy}
}

// Listen starts the UI HTTP server on 127.0.0.1:port. Returns the bound port.
// Handler returns the UI's HTTP handler (routes + static assets). Used by
// both Listen (browser mode) and the Wails desktop shell.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	// serve static/index.html at / (FileServer would list the dir otherwise)
	mux.HandleFunc("/", withSecurityHeaders(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/" {
			b, err := staticFS.ReadFile("static/index.html")
			if err == nil {
				w.Header().Set("Content-Type", "text/html; charset=utf-8")
				w.Write(b)
				return
			}
		}
		http.FileServer(http.FS(staticFS)).ServeHTTP(w, r)
	}))
	mux.HandleFunc("/api/status", withSecurityHeaders(s.handleStatus))
	mux.HandleFunc("/api/login", withSecurityHeaders(rateLimited(s.handleLogin, 5, time.Minute)))
	mux.HandleFunc("/api/connect", withSecurityHeaders(rateLimited(s.handleConnect, 10, time.Minute)))
	mux.HandleFunc("/api/disconnect", withSecurityHeaders(rateLimited(s.handleDisconnect, 10, time.Minute)))
	mux.HandleFunc("/api/quit", withSecurityHeaders(rateLimited(s.handleQuit, 2, time.Minute)))
	mux.HandleFunc("/api/settings", withSecurityHeaders(s.handleSettings))
	mux.HandleFunc("/api/country", withSecurityHeaders(s.handleCountry))
	mux.HandleFunc("/api/proxy/start", withSecurityHeaders(s.handleProxyStart))
	mux.HandleFunc("/api/proxy/stop", withSecurityHeaders(s.handleProxyStop))
	mux.HandleFunc("/api/tun/start", withSecurityHeaders(rateLimited(s.handleTunStart, 2, time.Minute)))
	mux.HandleFunc("/api/tun/stop", withSecurityHeaders(rateLimited(s.handleTunStop, 2, time.Minute)))
	return mux
}

// Listen starts the UI HTTP server on 127.0.0.1:port. Returns the bound port.
func (s *Server) Listen(port int) (int, error) {
	ln, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", port))
	if err != nil {
		return 0, err
	}
	s.ln = ln
	go http.Serve(ln, s.Handler())
	return ln.Addr().(*net.TCPAddr).Port, nil
}

// withSecurityHeaders sets standard security headers on responses.
func withSecurityHeaders(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Content-Security-Policy",
			"default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none';")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Cache-Control", "no-store, no-cache, must-revalidate")
		next(w, r)
	}
}

// rateLimiter provides simple per-IP request rate limiting.
type rateLimiter struct {
	requests map[string][]time.Time
	max      int
	window   time.Duration
	mu       sync.Mutex
}

func newRateLimiter(max int, window time.Duration) *rateLimiter {
	return &rateLimiter{requests: make(map[string][]time.Time), max: max, window: window}
}

func (rl *rateLimiter) allow(ip string) bool {
	now := time.Now()
	rl.mu.Lock()
	defer rl.mu.Unlock()
	cutoff := now.Add(-rl.window)
	requests := rl.requests[ip]
	filtered := requests[:0]
	for _, t := range requests {
		if t.After(cutoff) {
			filtered = append(filtered, t)
		}
	}
	if len(filtered) >= rl.max {
		rl.requests[ip] = filtered
		return false
	}
	rl.requests[ip] = append(filtered, now)
	return true
}

// rateLimited wraps a handler with per-IP rate limiting.
func rateLimited(next http.HandlerFunc, max int, window time.Duration) http.HandlerFunc {
	rl := newRateLimiter(max, window)
	return func(w http.ResponseWriter, r *http.Request) {
		ip := r.RemoteAddr
		if !rl.allow(ip) {
			http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
			return
		}
		next(w, r)
	}
}

func (s *Server) Close() {
	if s.ln != nil {
		s.ln.Close()
	}
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

func (s *Server) handleStatus(w http.ResponseWriter, r *http.Request) {
	st, err, passExp, quotaLeft, quotaMax, exitIP, exitCountry, up, down := s.mgr.Snapshot()
	writeJSON(w, map[string]interface{}{
		"state":        st.String(),
		"error":        errString(err),
		"pass_expires": passExp.Format(time.RFC3339),
		"quota_left":   quotaLeft,
		"quota_max":    quotaMax,
		"exit_ip":      exitIP,
		"exit_country": exitCountry,
		"up":           up,
		"down":         down,
		"countries":    s.mgr.Countries(),
		"tun":          tun.Active(),
		"country":      s.mgr.Country(),
	})
}

func errString(err error) string {
	if err == nil {
		return ""
	}
	return err.Error()
}

type loginReq struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	Code     string `json:"code,omitempty"`
	Remember bool   `json:"remember,omitempty"`
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, map[string]string{"error": "bad request"})
		return
	}
	var codeCh = make(chan string, 1)
	if req.Code != "" {
		codeCh <- req.Code
	}
	err := s.mgr.Login(r.Context(), req.Email, req.Password, func() string {
		if req.Code != "" {
			return req.Code
		}
		select {
		case c := <-codeCh:
			return c
		case <-time.After(5 * time.Minute):
			return ""
		}
	})
	writeJSON(w, map[string]string{"error": errString(err)})
}

func (s *Server) handleConnect(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Country string `json:"country,omitempty"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.Country != "" {
		s.mgr.SetCountry(req.Country)
		SaveLastCountry(req.Country)
	}
	var err error
	if s.mgr.State() == core.StateDisconnected {
		err = s.mgr.ConnectCached(r.Context())
		if err != nil {
			writeJSON(w, map[string]string{"error": errString(err), "needs_login": "true"})
			return
		}
	} else {
		err = s.mgr.Connect(r.Context())
	}
	writeJSON(w, map[string]string{"error": errString(err)})
}

func (s *Server) handleDisconnect(w http.ResponseWriter, r *http.Request) {
	tun.StopGlobal()
	s.mgr.Disconnect()
	if s.servers != nil {
		s.servers.Stop()
	}
	writeJSON(w, map[string]string{"error": ""})
}

// handleQuit fully exits the app: disconnect, restore system proxy, stop everything.
func (s *Server) handleQuit(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]string{"error": ""})
	go func() {
		time.Sleep(300 * time.Millisecond) // let the response flush
		tun.StopGlobal()
		s.mgr.Disconnect()
		if s.servers != nil {
			s.servers.Stop()
		}
		if s.quit != nil {
			s.quit()
		}
	}()
}

func (s *Server) handleCountry(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Country string `json:"country"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	s.mgr.SetCountry(req.Country)
	SaveLastCountry(req.Country)
	writeJSON(w, map[string]string{"error": ""})
}

type settingsReq struct {
	SocksPort int `json:"socks_port"`
	HTTPPort  int `json:"http_port"`
}

func (s *Server) handleSettings(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodPost {
		var req settingsReq
		if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
			saveSettings(req.SocksPort, req.HTTPPort)
		}
	}
	st := loadSettings()
	writeJSON(w, map[string]int{"socks_port": st.SocksPort, "http_port": st.HTTPPort})
}

type startReq struct {
	Socks string `json:"socks"`
	HTTP  string `json:"http"`
}

func (s *Server) handleProxyStart(w http.ResponseWriter, r *http.Request) {
	if s.servers == nil {
		writeJSON(w, map[string]string{"error": "proxy servers unavailable"})
		return
	}
	var req startReq
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.Socks != "" {
		if err := s.servers.StartSocks(req.Socks); err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
	}
	if req.HTTP != "" {
		if err := s.servers.StartHTTP(req.HTTP); err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
	}
	writeJSON(w, map[string]string{"error": ""})
}

func (s *Server) handleProxyStop(w http.ResponseWriter, r *http.Request) {
	if s.servers != nil {
		s.servers.Stop()
	}
	writeJSON(w, map[string]string{"error": ""})
}

func (s *Server) handleTunStart(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Socks string `json:"socks"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.Socks == "" {
		req.Socks = "127.0.0.1:1080"
	}
	// TUN routes everything into the local SOCKS5; make sure it is running.
	if s.servers != nil {
		if err := s.servers.StartSocks(req.Socks); err != nil {
			writeJSON(w, map[string]string{"error": err.Error()})
			return
		}
	}
	edge := s.mgr.EdgeAddr()
	if edge == "" {
		writeJSON(w, map[string]string{"error": "connect to a server before enabling TUN mode"})
		return
	}
	if err := tun.StartGlobal(req.Socks, edge); err != nil {
		writeJSON(w, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, map[string]string{"error": ""})
}

func (s *Server) handleTunStop(w http.ResponseWriter, r *http.Request) {
	tun.StopGlobal()
	writeJSON(w, map[string]string{"error": ""})
}
