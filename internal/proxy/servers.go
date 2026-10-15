// Package proxy serves local SOCKS5 and HTTP CONNECT proxies backed by
// the tunnel, with traffic accounting.
package proxy

import (
	"bufio"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
)

type Dialer interface {
	DialTunnel(authority string) (net.Conn, error)
}

type Servers struct {
	mu       sync.Mutex
	socksLn  net.Listener
	httpLn   net.Listener
	dialer   Dialer
	traffic  func(up, down uint64)
	logf     func(string, ...interface{})
	onBroken func()
	closing  atomic.Bool
	wg       sync.WaitGroup
}

func NewServers(dialer Dialer, traffic func(up, down uint64), logf func(string, ...interface{}), onBroken func()) *Servers {
	return &Servers{dialer: dialer, traffic: traffic, logf: logf, onBroken: onBroken}
}

// StartSocks begins serving a SOCKS5 proxy on addr (idempotent).
func (s *Servers) StartSocks(addr string) error {
	s.mu.Lock()
	if s.socksLn != nil {
		s.mu.Unlock()
		return nil // already running
	}
	s.mu.Unlock()
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	s.mu.Lock()
	s.socksLn = ln
	s.mu.Unlock()
	s.wg.Add(1)
	go s.acceptLoop(ln, s.handleSocks)
	s.logf("SOCKS5 listening on %s", addr)
	return nil
}

// StartHTTP begins serving an HTTP CONNECT proxy on addr (idempotent).
func (s *Servers) StartHTTP(addr string) error {
	s.mu.Lock()
	if s.httpLn != nil {
		s.mu.Unlock()
		return nil // already running
	}
	s.mu.Unlock()
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	s.mu.Lock()
	s.httpLn = ln
	s.mu.Unlock()
	s.wg.Add(1)
	go s.acceptLoop(ln, s.handleHTTP)
	s.logf("HTTP proxy listening on %s", addr)
	return nil
}

func (s *Servers) Stop() {
	s.closing.Store(true)
	s.mu.Lock()
	ln1, ln2 := s.socksLn, s.httpLn
	s.socksLn, s.httpLn = nil, nil
	s.mu.Unlock()
	if ln1 != nil {
		ln1.Close()
	}
	if ln2 != nil {
		ln2.Close()
	}
	s.wg.Wait()
}

func (s *Servers) acceptLoop(ln net.Listener, handler func(net.Conn)) {
	defer s.wg.Done()
	for {
		conn, err := ln.Accept()
		if err != nil {
			if s.closing.Load() {
				return
			}
			s.logf("accept failed: %v", err)
			if s.onBroken != nil {
				go s.onBroken()
			}
			return
		}
		go handler(conn)
	}
}

// --- SOCKS5 ---

const (
	socksVer      = 0x05
	socksConnect  = 0x01
	socksUDPAssociate = 0x03
	atypIPv4      = 0x01
	atypDomain    = 0x03
	atypIPv6      = 0x04
	replyOK       = 0x00
	replyFail     = 0x01
	replyCmdUnsup = 0x07
)

func (s *Servers) handleSocks(conn net.Conn) {
	defer conn.Close()
	hdr := make([]byte, 2)
	if _, err := io.ReadFull(conn, hdr); err != nil || hdr[0] != socksVer {
		return
	}
	methods := make([]byte, hdr[1])
	if _, err := io.ReadFull(conn, methods); err != nil {
		return
	}
	if _, err := conn.Write([]byte{socksVer, 0x00}); err != nil {
		return
	}
	head := make([]byte, 4)
	if _, err := io.ReadFull(conn, head); err != nil {
		return
	}
	if head[1] == socksUDPAssociate {
		s.handleUDPAssociate(conn)
		return
	}
	if head[1] != socksConnect {
		socksReply(conn, replyCmdUnsup)
		return
	}
	host, err := readSocksAddr(conn, head[3])
	if err != nil {
		socksReply(conn, replyFail)
		return
	}
	port := make([]byte, 2)
	if _, err := io.ReadFull(conn, port); err != nil {
		return
	}
	authority := net.JoinHostPort(host, strconv.Itoa(int(binary.BigEndian.Uint16(port))))

	up, err := s.dialer.DialTunnel(authority)
	if err != nil {
		s.logf("socks connect %s failed: %v", authority, err)
		socksReply(conn, replyFail)
		s.broken(err)
		return
	}
	defer up.Close()
	socksReply(conn, replyOK)
	s.relay(conn, up, authority)
}

func socksReply(conn net.Conn, code byte) {
	conn.Write([]byte{socksVer, code, 0x00, atypIPv4, 0, 0, 0, 0, 0, 0})
}

func readSocksAddr(r io.Reader, atyp byte) (string, error) {
	switch atyp {
	case atypIPv4:
		b := make([]byte, 4)
		if _, err := io.ReadFull(r, b); err != nil {
			return "", err
		}
		return net.IP(b).String(), nil
	case atypDomain:
		l := make([]byte, 1)
		if _, err := io.ReadFull(r, l); err != nil {
			return "", err
		}
		b := make([]byte, l[0])
		if _, err := io.ReadFull(r, b); err != nil {
			return "", err
		}
		return string(b), nil
	case atypIPv6:
		b := make([]byte, 16)
		if _, err := io.ReadFull(r, b); err != nil {
			return "", err
		}
		return net.IP(b).String(), nil
	}
	return "", fmt.Errorf("unsupported atyp 0x%02x", atyp)
}

// --- HTTP CONNECT ---

func (s *Servers) handleHTTP(conn net.Conn) {
	defer conn.Close()
	br := bufio.NewReader(conn)
	req, err := http.ReadRequest(br)
	if err != nil {
		return
	}
	if strings.EqualFold(req.Method, "CONNECT") {
		authority := req.Host
		if authority == "" {
			return
		}
		up, err := s.dialer.DialTunnel(authority)
		if err != nil {
			s.logf("http connect %s failed: %v", authority, err)
			conn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
			s.broken(err)
			return
		}
		defer up.Close()
		conn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))
		s.relay2(struct {
			io.Reader
			io.Writer
		}{br, conn}, up, authority)
		return
	}
	// Plain HTTP proxying: forward as absolute-URI GET/POST through tunnel
	host := req.Host
	if host == "" {
		host = req.URL.Host
	}
	if host == "" {
		conn.Write([]byte("HTTP/1.1 400 Bad Request\r\n\r\n"))
		return
	}
	authority := host
	if !strings.Contains(authority, ":") {
		authority += ":80"
	}
	up, err := s.dialer.DialTunnel(authority)
	if err != nil {
		conn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
		s.broken(err)
		return
	}
	defer up.Close()
	// Rewrite to absolute form already present; write request as-is.
	buf, _ := io.ReadAll(io.LimitReader(br, 1<<20))
	fmt.Fprintf(up, "%s %s %s\r\nHost: %s\r\n", req.Method, req.URL.RequestURI(), req.Proto, host)
	up.Write(buf)
	s.relay2(conn, up, authority)
}

// --- shared relay with traffic counters ---

func (s *Servers) relay(client, upstream io.ReadWriteCloser, authority string) {
	var up, down atomic.Uint64
	done := make(chan struct{}, 2)
	go func() {
		n, _ := io.Copy(upstream, client)
		up.Store(uint64(n))
		done <- struct{}{}
	}()
	go func() {
		n, _ := io.Copy(client, upstream)
		down.Store(uint64(n))
		done <- struct{}{}
	}()
	<-done
	client.Close()
	upstream.Close()
	s.traffic(up.Load(), down.Load())
	s.logf("tunnel %s closed up=%d down=%d", authority, up.Load(), down.Load())
}

// relay2 adapts mixed reader/writer combos (HTTP CONNECT path).
func (s *Servers) relay2(client io.ReadWriter, upstream io.ReadWriteCloser, authority string) {
	var up, down atomic.Uint64
	done := make(chan struct{}, 2)
	go func() {
		n, _ := io.Copy(upstream, client)
		up.Store(uint64(n))
		done <- struct{}{}
	}()
	go func() {
		n, _ := io.Copy(client, upstream)
		down.Store(uint64(n))
		done <- struct{}{}
	}()
	<-done
	if c, ok := client.(io.Closer); ok {
		c.Close()
	}
	upstream.Close()
	s.traffic(up.Load(), down.Load())
}

func (s *Servers) broken(err error) {
	if s.onBroken != nil {
		go s.onBroken()
	}
	_ = err
}
