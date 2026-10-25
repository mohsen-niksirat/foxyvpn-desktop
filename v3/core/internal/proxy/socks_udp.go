package proxy

import (
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
)

const (
	dnsTimeout = 6 * time.Second
)

// handleUDPAssociate serves a SOCKS5 UDP ASSOCIATE request.
// Only DNS queries (destination port 53) are relayed over TCP through the
// tunnel because the upstream proxy carries TCP streams only.
func (s *SOCKSServer) handleUDPAssociate(ctrl net.Conn, clientAddr string) {
	pc, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1), Port: 0})
	if err != nil {
		_ = writeSOCKSReply(ctrl, socksReplyFailure, nil)
		return
	}
	defer pc.Close()

	localAddr := pc.LocalAddr().(*net.UDPAddr)
	if err := writeSOCKSReply(ctrl, socksReplySuccess, localAddr); err != nil {
		return
	}
	logx.Info("SOCKS5 UDP ASSOCIATE active on %s for client %s", localAddr, clientAddr)

	// Association ends when control connection closes
	go func() {
		buf := make([]byte, 1)
		for {
			if _, err := ctrl.Read(buf); err != nil {
				pc.Close()
				return
			}
		}
	}()

	buf := make([]byte, 65535)
	for {
		n, client, err := pc.ReadFromUDP(buf)
		if err != nil {
			return
		}
		pkt := make([]byte, n)
		copy(pkt, buf[:n])
		go s.relayUDP(pc, client, pkt, clientAddr)
	}
}

func (s *SOCKSServer) relayUDP(pc *net.UDPConn, client *net.UDPAddr, pkt []byte, clientAddr string) {
	dstHost, dstPort, payload, err := parseSOCKSUDPHeader(pkt)
	if err != nil {
		return
	}
	if dstPort != 53 {
		// Non-DNS UDP is dropped since Mozilla Fastly only supports TCP web ports
		return
	}
	resp, err := s.dnsOverTunnel(payload, clientAddr)
	if err != nil {
		logx.Debug("DNS over tunnel failed for %s: %v", dstHost, err)
		return
	}
	header := pkt[:len(pkt)-len(payload)]
	out := append(append([]byte{}, header...), resp...)
	_, _ = pc.WriteToUDP(out, client)
}

func parseSOCKSUDPHeader(pkt []byte) (string, uint16, []byte, error) {
	if len(pkt) < 4 || pkt[2] != 0 {
		return "", 0, nil, fmt.Errorf("unsupported datagram")
	}
	var host string
	off := 4
	switch pkt[3] {
	case socksAtypIPv4:
		if len(pkt) < off+4+2 {
			return "", 0, nil, fmt.Errorf("short datagram")
		}
		host = net.IP(pkt[off : off+4]).String()
		off += 4
	case socksAtypIPv6:
		if len(pkt) < off+16+2 {
			return "", 0, nil, fmt.Errorf("short datagram")
		}
		host = net.IP(pkt[off : off+16]).String()
		off += 16
	case socksAtypDomain:
		if len(pkt) < off+1 {
			return "", 0, nil, fmt.Errorf("short datagram")
		}
		l := int(pkt[off])
		off++
		if len(pkt) < off+l+2 {
			return "", 0, nil, fmt.Errorf("short datagram")
		}
		host = string(pkt[off : off+l])
		off += l
	default:
		return "", 0, nil, fmt.Errorf("unsupported address type")
	}
	port := binary.BigEndian.Uint16(pkt[off : off+2])
	return host, port, pkt[off+2:], nil
}

// dnsOverTunnel relays a DNS query over TCP through the tunnel to 1.1.1.1:53 or 8.8.8.8:53.
func (s *SOCKSServer) dnsOverTunnel(query []byte, clientAddr string) ([]byte, error) {
	// Try 1.1.1.1:53 first, then 8.8.8.8:53
	conn, err := s.openTarget(nil, "1.1.1.1:53", clientAddr)
	if err != nil {
		conn, err = s.openTarget(nil, "8.8.8.8:53", clientAddr)
		if err != nil {
			return nil, err
		}
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(dnsTimeout))

	req := make([]byte, 2+len(query))
	binary.BigEndian.PutUint16(req, uint16(len(query)))
	copy(req[2:], query)
	if _, err := conn.Write(req); err != nil {
		return nil, err
	}

	var lenBuf [2]byte
	if _, err := io.ReadFull(conn, lenBuf[:]); err != nil {
		return nil, err
	}
	respLen := binary.BigEndian.Uint16(lenBuf[:])
	resp := make([]byte, respLen)
	if _, err := io.ReadFull(conn, resp); err != nil {
		return nil, err
	}
	return resp, nil
}
