// Package socks implements a minimal local SOCKS5 CONNECT proxy that
// forwards each client connection through the H2 tunnel to the VPN edge.
package socks

import (
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"strconv"

	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/tunnel"
)

const (
	socksVersion5   = 0x05
	socksCmdConnect = 0x01
	socksAtypIPv4   = 0x01
	socksAtypDomain = 0x03
	socksAtypIPv6   = 0x04
)

// HandleConn serves one SOCKS5 client connection.
func HandleConn(conn net.Conn, session *tunnel.H2Session) {
	defer conn.Close()

	// Greeting: version + methods
	hdr := make([]byte, 2)
	if _, err := io.ReadFull(conn, hdr); err != nil || hdr[0] != socksVersion5 {
		return
	}
	methods := make([]byte, hdr[1])
	if _, err := io.ReadFull(conn, methods); err != nil {
		return
	}
	// Reply: no auth required
	if _, err := conn.Write([]byte{socksVersion5, 0x00}); err != nil {
		return
	}

	// Request: VER CMD RSV ATYP ADDR PORT
	head := make([]byte, 4)
	if _, err := io.ReadFull(conn, head); err != nil {
		return
	}
	if head[1] != socksCmdConnect {
		reply(conn, 0x07) // command not supported
		return
	}
	host, err := readAddr(conn, head[3])
	if err != nil {
		reply(conn, 0x01)
		return
	}
	port := make([]byte, 2)
	if _, err := io.ReadFull(conn, port); err != nil {
		return
	}
	authority := net.JoinHostPort(host, strconv.Itoa(int(binary.BigEndian.Uint16(port))))

	upstream, err := session.OpenTunnel(authority)
	if err != nil {
		reply(conn, 0x01) // general failure
		return
	}
	defer upstream.Close()
	reply(conn, 0x00) // success

	done := make(chan struct{}, 2)
	go func() { io.Copy(upstream, conn); done <- struct{}{} }()
	go func() { io.Copy(conn, upstream); done <- struct{}{} }()
	<-done
}

func readAddr(r io.Reader, atyp byte) (string, error) {
	switch atyp {
	case socksAtypIPv4:
		b := make([]byte, 4)
		if _, err := io.ReadFull(r, b); err != nil {
			return "", err
		}
		return net.IP(b).String(), nil
	case socksAtypDomain:
		l := make([]byte, 1)
		if _, err := io.ReadFull(r, l); err != nil {
			return "", err
		}
		b := make([]byte, l[0])
		if _, err := io.ReadFull(r, b); err != nil {
			return "", err
		}
		return string(b), nil
	case socksAtypIPv6:
		b := make([]byte, 16)
		if _, err := io.ReadFull(r, b); err != nil {
			return "", err
		}
		return net.IP(b).String(), nil
	}
	return "", fmt.Errorf("unsupported address type 0x%02x", atyp)
}

func reply(conn net.Conn, code byte) {
	conn.Write([]byte{socksVersion5, code, 0x00, socksAtypIPv4, 0, 0, 0, 0, 0, 0})
}
