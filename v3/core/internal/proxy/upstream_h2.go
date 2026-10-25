package proxy

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/net/http2"

	"github.com/armanlife/firefox-vpn-client/core/internal/controlplane"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/resolver"
)

const (
	upstreamKeepAliveInterval    = 10 * time.Second
	upstreamKeepAlivePingTimeout = 10 * time.Second
	// upstreamKeepAliveMisses is how many PINGs in a row must go
	// unanswered before the session counts as dead: on a busy phone link
	// one PING can wait behind a video's data, and a false alarm moves new
	// tunnels to a new session.
	upstreamKeepAliveMisses = 2
)

var errProxyHTTP2Unavailable = errors.New("proxy did not negotiate HTTP/2")

type h2ProxySession struct {
	raw       *tls.Conn
	cc        *http2.ClientConn
	proxyHost string
	token     string
	timeout   time.Duration
	tokenMu   sync.RWMutex
	health    sessionFailureTracker
	closeOnce sync.Once
	closeErr  error

	// alive is cleared once a keepalive PING fails or the session is closed,
	// so the pool can skip it before binding a client connection to it.
	alive atomic.Bool
	// stopKeepAlive stops the keepalive goroutine on Close.
	stopKeepAlive context.CancelFunc
}

func newH2ProxySession(proxyURL *url.URL, token string, timeout time.Duration) (*h2ProxySession, error) {
	session, err := dialH2ProxySession(proxyURL, token, timeout)
	if err != nil {
		return nil, err
	}
	logx.Info("upstream HTTP/2 session established proxy=%s", session.proxyHost)
	return session, nil
}

// dialH2ProxySession establishes an HTTP/2 session without logging it; the
// latency measurement opens one per location.
func dialH2ProxySession(proxyURL *url.URL, token string, timeout time.Duration) (*h2ProxySession, error) {
	proxyHost := proxyURL.Host
	if proxyURL.Port() == "" {
		proxyHost = proxyURL.Hostname() + ":443"
	}

	// The timeout covers resolving, connecting, and the TLS handshake, as
	// tls.DialWithDialer did.
	dialCtx, cancelDial := context.Background(), context.CancelFunc(func() {})
	if timeout > 0 {
		dialCtx, cancelDial = context.WithTimeout(context.Background(), timeout)
	}
	defer cancelDial()
	raw, err := resolver.Dial(dialCtx, "tcp", proxyHost)
	if err != nil {
		return nil, err
	}
	proxyTLS := tls.Client(raw, &tls.Config{
		RootCAs:    upstreamRoots.Load(),
		ServerName: proxyURL.Hostname(),
		MinVersion: tls.VersionTLS12,
		NextProtos: []string{"h2"},
	})
	if err := proxyTLS.HandshakeContext(dialCtx); err != nil {
		_ = raw.Close()
		return nil, err
	}

	if proxyTLS.ConnectionState().NegotiatedProtocol != "h2" {
		_ = proxyTLS.Close()
		return nil, errProxyHTTP2Unavailable
	}

	transport := &http2.Transport{
		// A new tunnel waits for a free stream when the server's
		// MAX_CONCURRENT_STREAMS is reached, rather than failing as if the
		// connection were gone.
		StrictMaxConcurrentStreams: true,
		ReadIdleTimeout:            30 * time.Second,
		PingTimeout:                15 * time.Second,
		WriteByteTimeout:           30 * time.Second,
	}
	cc, err := transport.NewClientConn(proxyTLS)
	if err != nil {
		_ = proxyTLS.Close()
		return nil, err
	}

	ctx, cancel := context.WithCancel(context.Background())
	session := &h2ProxySession{
		raw:           proxyTLS,
		cc:            cc,
		proxyHost:     proxyHost,
		token:         token,
		timeout:       timeout,
		stopKeepAlive: cancel,
	}
	session.alive.Store(true)
	go session.runKeepAlive(ctx)

	return session, nil
}

// runKeepAlive pings the upstream connection periodically so a silently
// dropped session is noticed while idle, rather than when a client next tries
// to open a tunnel through it.
func (s *h2ProxySession) runKeepAlive(ctx context.Context) {
	ticker := time.NewTicker(upstreamKeepAliveInterval)
	defer ticker.Stop()

	misses := 0
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			pingCtx, cancel := context.WithTimeout(ctx, upstreamKeepAlivePingTimeout)
			err := s.cc.Ping(pingCtx)
			cancel()
			if err == nil {
				misses = 0
				continue
			}
			if ctx.Err() != nil {
				return
			}
			if misses++; misses < upstreamKeepAliveMisses && !s.cc.State().Closed {
				logx.Debug("upstream HTTP/2 keepalive PING unanswered proxy=%s misses=%d err=%s", s.proxyHost, misses, logx.Err(err))
				continue
			}
			s.alive.Store(false)
			logx.Warn("upstream HTTP/2 keepalive failed proxy=%s err=%s", s.proxyHost, logx.Err(err))
			return
		}
	}
}

// IsAlive reports whether this session can still carry new tunnels. A
// session whose streams are all in use is busy, not dead: new tunnels wait
// for a free stream (StrictMaxConcurrentStreams). A connection closing after
// a GOAWAY may still look alive here; its next open fails and the session is
// rebuilt then.
func (s *h2ProxySession) IsAlive() bool {
	if !s.alive.Load() {
		return false
	}
	st := s.cc.State()
	return !st.Closed && !st.Closing
}

// saturated reports whether every stream the server allows is in use or
// waited for, so a new tunnel has to wait for one to end.
func (s *h2ProxySession) saturated() bool {
	st := s.cc.State()
	return st.MaxConcurrentStreams > 0 && st.StreamsActive+st.StreamsReserved+st.StreamsPending >= int(st.MaxConcurrentStreams)
}

// saturatedOpenWait bounds how long a new tunnel waits for a free stream on
// a session whose streams are all in use.
const saturatedOpenWait = 10 * time.Second

// errSessionSaturated is a tunnel that found no free stream in time. The
// session is busy, not broken: it is neither counted against its health nor
// rebuilt (which would fetch a new pass for nothing).
var errSessionSaturated = errors.New("upstream session has no free stream")

func (s *h2ProxySession) OpenTunnel(authority string) (net.Conn, error) {
	reqBody := newTunnelWriteBuffer(defaultTunnelWriteBufSize)
	busy := s.saturated()
	timeout := s.timeout
	if busy && (timeout <= 0 || timeout > saturatedOpenWait) {
		timeout = saturatedOpenWait
	}
	resp, cancel, err := roundTripWithOpenTimeout(timeout, func(ctx context.Context) (*http.Response, error) {
		req, err := http.NewRequestWithContext(ctx, http.MethodConnect, "http://"+authority, reqBody)
		if err != nil {
			return nil, err
		}
		req.Host = authority
		req.URL.Host = s.proxyHost
		req.Header.Set("Proxy-Authorization", "Bearer "+s.bearerToken())
		// As Firefox's CONNECT; Go would otherwise name itself.
		req.Header.Set("User-Agent", controlplane.FirefoxUserAgent())
		return s.cc.RoundTrip(req)
	})
	if err != nil {
		reqBody.failRead(io.ErrClosedPipe)
		var timeoutErr *tunnelOpenTimeoutError
		if busy && errors.As(err, &timeoutErr) {
			return nil, fmt.Errorf("%w: %w", errSessionSaturated, err)
		}
		return nil, s.health.observe(authority, err)
	}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		cancel()
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
		_ = resp.Body.Close()
		reqBody.failRead(io.ErrClosedPipe)
		return nil, s.health.observe(authority, &proxyConnectHTTPError{
			statusCode: resp.StatusCode,
			status:     resp.Status,
			body:       strings.TrimSpace(string(body)),
		})
	}
	s.health.observe(authority, nil)

	return &tunnelConn{
		reader:  resp.Body,
		writer:  reqBody,
		reqBody: reqBody,
		name:    "h2-connect-stream",
		cancel:  cancel,
	}, nil
}

func (s *h2ProxySession) bearerToken() string {
	s.tokenMu.RLock()
	defer s.tokenMu.RUnlock()
	return s.token
}

func (s *h2ProxySession) UpdateToken(token string) error {
	if strings.TrimSpace(token) == "" {
		return fmt.Errorf("empty proxy session token")
	}
	s.tokenMu.Lock()
	s.token = token
	s.tokenMu.Unlock()
	return nil
}

func (s *h2ProxySession) Close() error {
	s.closeOnce.Do(func() {
		s.alive.Store(false)
		if s.stopKeepAlive != nil {
			s.stopKeepAlive()
		}
		if s.cc != nil {
			s.closeErr = s.cc.Close()
		}
		if s.raw != nil {
			if closeErr := s.raw.Close(); s.closeErr == nil {
				s.closeErr = closeErr
			}
		}
	})
	return s.closeErr
}
