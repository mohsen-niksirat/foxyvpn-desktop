package tunnel

// H2 UDP datagram support (RFC 9297 HTTP Datagrams + RFC 9298 CONNECT-UDP)
// over the same TLS+h2 edge connection type used for CONNECT tunnels.
// Implemented with raw http2.Framer frames because x/net/http2 does not
// expose HTTP Datagrams.

import (
	"context"
	"crypto/tls"
	"encoding/binary"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"sync"
	"time"

	"golang.org/x/net/http2"
	"golang.org/x/net/http2/hpack"
)

const (
	settingH3Datagram = 0x01 // SETTINGS_H3_DATAGRAM (h2-mapped, per draft-ietf-masque)
	frameDatagram     = 0x4d // reserved HTTP Datagrams frame type for h2 (HTTP/2 DATAGRAM)
	capsuleClose      = 3
	capsuleDatagram   = 0 // CONNECT-UDP datagram capsule
)

// UDPSession is one CONNECT-UDP stream: UDP datagrams to a fixed target host.
type UDPSession struct {
	wmu      sync.Mutex
	fr       *http2.Framer
	streamID uint32
	target   string
	in       chan []byte
	closed   chan struct{}
	once     sync.Once
}

// Close shuts the session down.
func (s *UDPSession) Close() {
	s.once.Do(func() { close(s.closed) })
}

// Read waits for the next datagram received from the tunnel.
func (s *UDPSession) Read() ([]byte, bool) {
	select {
	case b := <-s.in:
		return b, true
	case <-s.closed:
		return nil, false
	}
}

// Write sends one datagram toward the target through the tunnel.
func (s *UDPSession) Write(payload []byte) error {
	capsule := encodeDatagramCapsule(payload)
	s.wmu.Lock()
	defer s.wmu.Unlock()
	return s.fr.WriteData(s.streamID, false, capsule)
}

func encodeDatagramCapsule(payload []byte) []byte {
	// Capsule Format (RFC 9297 section 3.3): Type(varint)=0 (DATAGRAM),
	// Value = Quarter Stream ID (varint) + UDP payload.
	// CONNECT-UDP quarter stream ID = streamID/4.
	q := uint64(1) // first CONNECT-UDP stream on this conn
	out := []byte{capsuleDatagram}
	out = appendVarInt(out, q)
	return append(out, payload...)
}

func appendVarInt(b []byte, v uint64) []byte {
	// minimal 1..8 byte varint encoding (h3 style, first byte top bits zero-length for values <64)
	switch {
	case v < 64:
		return append(b, byte(v))
	case v < 16384:
		return append(b, byte(v>>8)|0x40, byte(v))
	case v < 1073741824:
		return append(b, byte(v>>24)|0x80, byte(v>>16), byte(v>>8), byte(v))
	default:
		return append(b, byte(v>>56)|0xC0, byte(v>>48), byte(v>>40), byte(v>>32), byte(v>>24), byte(v>>16), byte(v>>8), byte(v))
	}
}

// OpenUDPSession dials the edge, opens an extended CONNECT-UDP stream to the
// template target, and returns a session for sending/receiving datagrams.
// authority example: "us.masque.fastly-edge.net:443"
// target example: "https://us.masque.fastly-edge.net/.well-known/masque/udp/1.1.1.1/53/"
func OpenUDPSession(ctx context.Context, edgeAddr, bearer, template string, dialTLS func(addr string) (net.Conn, error)) (*UDPSession, error) {
	// target = template with {target_host}/{target_port} filled if present,
	// else the template itself already contains the target.
	tu, err := url.Parse(template)
	if err != nil {
		return nil, fmt.Errorf("masque template: %w", err)
	}
	tc, err := dialTLS(edgeAddr)
	if err != nil {
		return nil, err
	}
	if t, ok := tc.(*tls.Conn); ok {
		if err := t.HandshakeContext(ctx); err != nil {
			tc.Close()
			return nil, err
		}
	}
	fr := http2.NewFramer(tc, tc)
	// client preface + SETTINGS (enable datagrams)
	if _, err := tc.Write([]byte(http2.ClientPreface)); err != nil {
		tc.Close()
		return nil, err
	}
	if err := fr.WriteSettings(http2.Setting{ID: settingH3Datagram, Val: 1}); err != nil {
		tc.Close()
		return nil, err
	}
	go func() {
		for {
			_, err := fr.ReadFrame()
			if err != nil {
				return
			}
		}
	}()

	// Build extended CONNECT HEADERS via hpack manually.
	var buf hpackBuffer
	enc := hpack.NewEncoder(&buf)
	writeHeader := func(name, value string) {
		enc.WriteField(hpack.HeaderField{Name: name, Value: value})
	}
	writeHeader(":method", "CONNECT")
	writeHeader(":scheme", "https")
	writeHeader(":authority", tu.Host)
	writeHeader(":path", requestPath(tu, template))
	writeHeader(":protocol", "connect-udp")
	writeHeader("proxy-authorization", "Bearer "+bearer)
	writeHeader("capsule-protocol", "?1")

	streamID := uint32(1)
	fr.WriteHeaders(http2.HeadersFrameParam{
		StreamID:      streamID,
		BlockFragment: buf.b,
		EndHeaders:    true,
	})
	// keep stream open (no END_STREAM) — capsule flow follows as DATA.

	s := &UDPSession{fr: fr, streamID: streamID, in: make(chan []byte, 64), closed: make(chan struct{})}

	// read response headers (blocking, with deadline)
	tc.SetReadDeadline(time.Now().Add(10 * time.Second))
	for {
		f, err := fr.ReadFrame()
		if err != nil {
			tc.Close()
			return nil, fmt.Errorf("connect-udp response: %w", err)
		}
		hf, ok := f.(*http2.HeadersFrame)
		if !ok {
			continue
		}
		if hf.StreamID != streamID {
			continue
		}
		dec := hpack.NewDecoder(4096, func(hf hpack.HeaderField) {})
		hdrs, _ := dec.DecodeFull(hf.HeaderBlockFragment())
		status := ""
		for _, h := range hdrs {
			if h.Name == ":status" {
				status = h.Value
			}
		}
		if status != "200" {
			tc.Close()
			return nil, fmt.Errorf("connect-udp rejected: HTTP %s", status)
		}
		break
	}
	tc.SetReadDeadline(time.Time{})

	// reader goroutine: DATA frames → capsule DATAGRAM payloads → in
	go func() {
		defer s.Close()
		for {
			f, err := fr.ReadFrame()
			if err != nil {
				return
			}
			df, ok := f.(*http2.DataFrame)
			if !ok || df.StreamID != streamID {
				continue
			}
			payloads := decodeDatagramCapsules(df.Data())
			for _, p := range payloads {
				select {
				case s.in <- p:
				case <-s.closed:
					return
				}
			}
		}
	}()
	return s, nil
}

// requestPath fills the template's {target_host} and {target_port} variables.
func requestPath(tu *url.URL, template string) string {
	host, portStr, err := net.SplitHostPort(tu.Host)
	if err != nil {
		host, portStr = tu.Hostname(), "443"
	}
	_ = portStr
	p := template
	// RFC 9298 URI template variables
	p = replaceTemplateVar(p, "target_host", host)
	p = replaceTemplateVar(p, "target_port", portStr)
	return p
}

func replaceTemplateVar(t, name, value string) string {
	for _, pat := range []string{"{" + name + "}", "%7B" + name + "%7D"} {
		t = replaceAll(t, pat, value)
	}
	return t
}

func replaceAll(s, old, new string) string {
	for {
		i := indexOf(s, old)
		if i < 0 {
			return s
		}
		s = s[:i] + new + s[i+len(old):]
	}
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}

// decodeDatagramCapsules parses a DATA buffer of concatenated capsules,
// returning DATAGRAM payloads.
func decodeDatagramCapsules(data []byte) [][]byte {
	var out [][]byte
	for len(data) >= 2 {
		typ := int(data[0]) // capsule type (varint, simplified <64)
		// capsule length varint
		l, n := readVarInt(data[1:])
		if n == 0 || len(data) < 1+n+int(l) {
			break
		}
		body := data[1+n : 1+n+int(l)]
		if typ == capsuleDatagram && len(body) > 0 {
			// strip quarter stream id varint
			_, qn := readVarInt(body)
			if qn > 0 && len(body) > qn {
				out = append(out, body[qn:])
			}
		}
		data = data[1+n+int(l):]
	}
	return out
}

func readVarInt(b []byte) (uint64, int) {
	if len(b) == 0 {
		return 0, 0
	}
	first := b[0]
	switch {
	case first&0xC0 == 0x00:
		return uint64(first & 0x3F), 1
	case first&0xC0 == 0x40:
		if len(b) < 2 {
			return 0, 0
		}
		return uint64(first&0x3F)<<8 | uint64(b[1]), 2
	case first&0xC0 == 0x80:
		if len(b) < 4 {
			return 0, 0
		}
		return uint64(first&0x3F)<<24 | uint64(b[1])<<16 | uint64(b[2])<<8 | uint64(b[3]), 4
	default:
		if len(b) < 8 {
			return 0, 0
		}
		v := uint64(first & 0x3F)
		for i := 1; i < 8; i++ {
			v = v<<8 | uint64(b[i])
		}
		return v, 8
	}
}

type hpackBuffer struct{ b []byte }

func (h *hpackBuffer) Write(p []byte) (int, error) {
	h.b = append(h.b, p...)
	return len(p), nil
}

var _ = binary.BigEndian
var _ = strconv.Itoa
var _ = http.MethodGet
