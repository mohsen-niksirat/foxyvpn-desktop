package proxy

import (
	"net"
	"sync"
	"time"
)

// UDPSession is a bidirectional datagram pipe to one destination through the
// MASQUE tunnel.
type UDPSession interface {
	Read() ([]byte, bool)
	Write([]byte) error
}

// UDPDialer opens a UDPSession to "host:port" (any UDP destination).
type UDPDialer func(host string, port int) (UDPSession, error)

type udpTunnel struct {
	mu      sync.Mutex
	dial    UDPDialer
	sess    map[string]UDPSession
	lastUse map[string]time.Time
}

func newUDPTunnel(dial UDPDialer) *udpTunnel {
	return &udpTunnel{dial: dial, sess: map[string]UDPSession{}, lastUse: map[string]time.Time{}}
}

// get returns a session for dst, dialing a new one when needed.
func (u *udpTunnel) get(host string, port int) (UDPSession, bool) {
	if u == nil || u.dial == nil {
		return nil, false
	}
	key := net.JoinHostPort(host, itoa(port))
	u.mu.Lock()
	defer u.mu.Unlock()
	if s, ok := u.sess[key]; ok {
		return s, true
	}
	s, err := u.dial(host, port)
	if err != nil {
		return nil, false
	}
	u.sess[key] = s
	u.lastUse[key] = time.Now()
	// pump incoming datagrams to keep them flowing (they are dropped here;
	// relayUDP reads via the same session? No: one session per dest, one
	// consumer. So do not pump here.)
	return s, true
}

func (u *udpTunnel) remove(key string) {
	if u == nil {
		return
	}
	u.mu.Lock()
	delete(u.sess, key)
	u.mu.Unlock()
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b [20]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return string(b[i:])
}
