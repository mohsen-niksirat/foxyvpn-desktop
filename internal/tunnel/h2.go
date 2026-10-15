// Package tunnel implements the HTTP/2 CONNECT upstream session to the
// Firefox VPN Fastly edge, authenticated with the Guardian proxy pass.
package tunnel

// h2Session wraps a TLS+HTTP/2 connection to a Fastly VPN edge server and
// exposes per-destination tunnels via HTTP/2 CONNECT, authenticated with
// the Guardian proxy pass as a Bearer credential. This mirrors the
// H2UpstreamSession.kt of FoxyVPN and newH2ProxySession of the Go
// reference client.
import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"golang.org/x/net/http2"
)

type H2Session struct {
	raw     *tls.Conn
	cc      *http2.ClientConn
	proxy   string
	token   string
	tokenMu sync.RWMutex
	mu      sync.Mutex
	closed  bool
}

func NewH2Session(proxyURL *url.URL, token string, timeout time.Duration) (*H2Session, error) {
	proxyHost := proxyURL.Host
	if proxyURL.Port() == "" {
		proxyHost = proxyURL.Hostname() + ":443"
	}
	dialer := &net.Dialer{Timeout: timeout}
	raw, err := tls.DialWithDialer(dialer, "tcp", proxyHost, &tls.Config{
		ServerName: proxyURL.Hostname(),
		MinVersion: tls.VersionTLS12,
		NextProtos: []string{"h2"},
	})
	if err != nil {
		return nil, err
	}
	if raw.ConnectionState().NegotiatedProtocol != "h2" {
		raw.Close()
		return nil, fmt.Errorf("server did not negotiate HTTP/2 (ALPN)")
	}
	transport := &http2.Transport{
		ReadIdleTimeout:  30 * time.Second,
		PingTimeout:      15 * time.Second,
		WriteByteTimeout: 30 * time.Second,
	}
	cc, err := transport.NewClientConn(raw)
	if err != nil {
		raw.Close()
		return nil, err
	}
	return &H2Session{raw: raw, cc: cc, proxy: proxyHost, token: token}, nil
}

// UpdateBearer hot-swaps the proxy pass used by new CONNECT streams.
func (s *H2Session) UpdateBearer(token string) { s.setToken(token) }

func (s *H2Session) setToken(t string) {
	s.tokenMu.Lock()
	s.token = t
	s.tokenMu.Unlock()
}

func (s *H2Session) bearer() string {
	s.tokenMu.RLock()
	defer s.tokenMu.RUnlock()
	return s.token
}

// OpenTunnel opens an HTTP/2 CONNECT stream to authority ("host:port")
// and returns a net.Conn-like duplex over that stream.
func (s *H2Session) OpenTunnel(authority string) (net.Conn, error) {
	s.mu.Lock()
	closed := s.closed
	s.mu.Unlock()
	if closed {
		return nil, fmt.Errorf("session closed")
	}
	if !s.cc.CanTakeNewRequest() {
		return nil, fmt.Errorf("upstream session cannot take new streams")
	}

	reqBody := newPipe()
	req, err := http.NewRequestWithContext(context.Background(), http.MethodConnect,
		"http://"+authority, reqBody)
	if err != nil {
		return nil, err
	}
	req.Host = authority
	req.URL.Host = s.proxy
	req.Header.Set("Proxy-Authorization", s.bearer())

	resp, err := s.cc.RoundTrip(req)
	if err != nil {
		reqBody.failRead(io.ErrClosedPipe)
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		resp.Body.Close()
		reqBody.failRead(io.ErrClosedPipe)
		return nil, fmt.Errorf("CONNECT rejected: HTTP %s %s", resp.Status, strings.TrimSpace(string(body)))
	}
	return &tunnelConn{reader: resp.Body, writer: reqBody}, nil
}

func (s *H2Session) Close() error {
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		return nil
	}
	s.closed = true
	s.mu.Unlock()
	return s.raw.Close()
}

// --- request-body pipe: an io.ReadWriteCloser usable as an http.Request
// Body for CONNECT, so writes from the local client stream to the tunnel
// while the response body carries the return path. ---

type pipe struct {
	pr *io.PipeReader
	pw *io.PipeWriter
	mu sync.Mutex
	// fail is applied to readers once set (e.g. after upstream failure).
	fail error
}

func newPipe() *pipe {
	pr, pw := io.Pipe()
	return &pipe{pr: pr, pw: pw}
}

func (p *pipe) Read(b []byte) (int, error) {
	n, err := p.pr.Read(b)
	if err != nil && p.fail != nil {
		return n, p.fail
	}
	return n, err
}

func (p *pipe) Write(b []byte) (int, error) { return p.pw.Write(b) }

func (p *pipe) failRead(err error) {
	p.mu.Lock()
	p.fail = err
	p.mu.Unlock()
	p.pr.CloseWithError(err)
	p.pw.CloseWithError(err)
}

func (p *pipe) Close() error {
	p.pw.Close()
	return nil
}

type tunnelConn struct {
	reader io.ReadCloser
	writer io.WriteCloser
}

func (c *tunnelConn) Read(b []byte) (int, error)  { return c.reader.Read(b) }
func (c *tunnelConn) Write(b []byte) (int, error) { return c.writer.Write(b) }
func (c *tunnelConn) Close() error {
	c.reader.Close()
	return c.writer.Close()
}
func (c *tunnelConn) LocalAddr() net.Addr                { return dummyAddr{} }
func (c *tunnelConn) RemoteAddr() net.Addr               { return dummyAddr{} }
func (c *tunnelConn) SetDeadline(t time.Time) error      { return nil }
func (c *tunnelConn) SetReadDeadline(t time.Time) error  { return nil }
func (c *tunnelConn) SetWriteDeadline(t time.Time) error { return nil }

type dummyAddr struct{}

func (dummyAddr) Network() string { return "tunnel" }
func (dummyAddr) String() string  { return "h2-tunnel" }
