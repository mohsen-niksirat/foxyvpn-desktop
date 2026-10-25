package tun

import (
	"context"
	"errors"
	"io"
	"net"
	"sync"
	"time"

	"golang.org/x/net/proxy"
)

// Dialer opens a connection to target ("host:port") through the proxy.
type Dialer func(ctx context.Context, target string) (net.Conn, error)

// Allow reports whether a connection to host:port is sent to the proxy at
// all; one it refuses is reset at once, without being tried.
type Allow func(host, port string) bool

// dialTimeout bounds connecting through the proxy, which may first wake
// and connect to Mozilla.
const dialTimeout = 30 * time.Second

// SOCKS5Dialer dials through the SOCKS5 proxy at addr, with its login if
// user is not empty.
func SOCKS5Dialer(addr, user, password string) (Dialer, error) {
	var auth *proxy.Auth
	if user != "" {
		auth = &proxy.Auth{User: user, Password: password}
	}
	d, err := proxy.SOCKS5("tcp", addr, auth, &net.Dialer{Timeout: dialTimeout})
	if err != nil {
		return nil, err
	}
	cd, ok := d.(proxy.ContextDialer)
	if !ok {
		return nil, errors.New("the SOCKS5 dialer cannot take a context")
	}
	return func(ctx context.Context, target string) (net.Conn, error) {
		return cd.DialContext(ctx, "tcp", target)
	}, nil
}

// closeWriter is a connection that can end its sending half.
type closeWriter interface{ CloseWrite() error }

// relay copies between a and b until both directions end, passing on each
// end of stream as a half close, then closes both.
func relay(a, b net.Conn) {
	var wg sync.WaitGroup
	copyHalf := func(dst, src net.Conn) {
		defer wg.Done()
		_, _ = io.Copy(dst, src)
		if cw, ok := dst.(closeWriter); ok {
			_ = cw.CloseWrite()
		} else {
			_ = dst.Close()
		}
	}
	wg.Add(2)
	go copyHalf(a, b)
	go copyHalf(b, a)
	wg.Wait()
	_ = a.Close()
	_ = b.Close()
}
