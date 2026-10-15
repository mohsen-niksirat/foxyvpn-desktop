package proxy

import (
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"time"
)

// dnsUpstream is the resolver that DNS queries are sent to through the tunnel.
const dnsUpstream = "1.1.1.1:53"

const dnsTimeout = 10 * time.Second

// handleUDPAssociate serves a SOCKS5 UDP ASSOCIATE request. Only DNS queries
// (destination port 53) are relayed: each datagram is sent as a DNS-over-TCP
// query through the tunnel, because the tunnel carries TCP streams only.
// Other UDP datagrams are dropped.
func (s *Servers) handleUDPAssociate(ctrl net.Conn) {
	pc, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		socksReply(ctrl, replyFail)
		return
	}
	defer pc.Close()

	local := pc.LocalAddr().(*net.UDPAddr)
	ctrl.Write([]byte{socksVer, replyOK, 0x00, atypIPv4, 127, 0, 0, 1,
		byte(local.Port >> 8), byte(local.Port)})

	// The association ends when the control connection closes.
	go func() {
		io.Copy(io.Discard, ctrl)
		pc.Close()
	}()

	buf := make([]byte, 65535)
	for {
		n, client, err := pc.ReadFromUDP(buf)
		if err != nil {
			return
		}
		pkt := make([]byte, n)
		copy(pkt, buf[:n])
		go s.relayUDP(pc, client, pkt)
	}
}

// relayUDP forwards one SOCKS5 UDP datagram. The datagram header is
// RSV(2) FRAG(1) ATYP DST.ADDR DST.PORT, followed by the payload.
func (s *Servers) relayUDP(pc *net.UDPConn, client *net.UDPAddr, pkt []byte) {
	dst, payload, err := parseUDPHeader(pkt)
	if err != nil {
		return
	}
	if dst.port != 53 {
		return
	}
	resp, err := s.dnsOverTunnel(payload)
	if err != nil {
		s.logf("dns query via tunnel failed: %v", err)
		return
	}
	header := pkt[:len(pkt)-len(payload)]
	pc.WriteToUDP(append(append([]byte{}, header...), resp...), client)
}

type udpDest struct {
	host string
	port uint16
}

func parseUDPHeader(pkt []byte) (udpDest, []byte, error) {
	if len(pkt) < 4 || pkt[2] != 0 {
		return udpDest{}, nil, fmt.Errorf("unsupported datagram")
	}
	var host string
	off := 4
	switch pkt[3] {
	case atypIPv4:
		if len(pkt) < off+4+2 {
			return udpDest{}, nil, fmt.Errorf("short datagram")
		}
		host = net.IP(pkt[off : off+4]).String()
		off += 4
	case atypIPv6:
		if len(pkt) < off+16+2 {
			return udpDest{}, nil, fmt.Errorf("short datagram")
		}
		host = net.IP(pkt[off : off+16]).String()
		off += 16
	case atypDomain:
		if len(pkt) < off+1 {
			return udpDest{}, nil, fmt.Errorf("short datagram")
		}
		l := int(pkt[off])
		off++
		if len(pkt) < off+l+2 {
			return udpDest{}, nil, fmt.Errorf("short datagram")
		}
		host = string(pkt[off : off+l])
		off += l
	default:
		return udpDest{}, nil, fmt.Errorf("unsupported address type")
	}
	port := binary.BigEndian.Uint16(pkt[off : off+2])
	return udpDest{host: host, port: port}, pkt[off+2:], nil
}

// dnsOverTunnel sends one DNS query over TCP through the tunnel and returns
// the response message without its length prefix.
func (s *Servers) dnsOverTunnel(query []byte) ([]byte, error) {
	conn, err := s.dialer.DialTunnel(dnsUpstream)
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(dnsTimeout))

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
	resp := make([]byte, binary.BigEndian.Uint16(lenBuf[:]))
	if _, err := io.ReadFull(conn, resp); err != nil {
		return nil, err
	}
	return resp, nil
}
