//go:build linux

package tun

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"sync"
	"time"

	"golang.org/x/sys/unix"
	"gvisor.dev/gvisor/pkg/tcpip"
	"gvisor.dev/gvisor/pkg/tcpip/adapters/gonet"
	"gvisor.dev/gvisor/pkg/tcpip/header"
	"gvisor.dev/gvisor/pkg/tcpip/link/fdbased"
	"gvisor.dev/gvisor/pkg/tcpip/network/ipv4"
	"gvisor.dev/gvisor/pkg/tcpip/network/ipv6"
	"gvisor.dev/gvisor/pkg/tcpip/stack"
	"gvisor.dev/gvisor/pkg/tcpip/transport/icmp"
	"gvisor.dev/gvisor/pkg/tcpip/transport/tcp"
	"gvisor.dev/gvisor/pkg/tcpip/transport/udp"
	"gvisor.dev/gvisor/pkg/waiter"

	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
)

const nicID = 1

// dnsIdle closes a DNS flow that has had no query for this long.
const dnsIdle = 10 * time.Second

// Tunnel is a running userspace stack on a TUN device.
type Tunnel struct {
	s      *stack.Stack
	fd     int
	ctx    context.Context
	cancel context.CancelFunc
	once   sync.Once
}

// Start takes over the TUN device fd (it closes it on Stop): TCP goes
// through dial, DNS (UDP port 53, to any address) is answered by dns, and
// other UDP is refused with ICMP port unreachable, so apps fall back to TCP.
func Start(fd int, mtu uint32, dial Dialer, allow Allow, dns *FakeDNS) (*Tunnel, error) {
	if err := unix.SetNonblock(fd, true); err != nil {
		return nil, fmt.Errorf("tun: %w", err)
	}
	link, err := fdbased.New(&fdbased.Options{FDs: []int{fd}, MTU: mtu})
	if err != nil {
		return nil, fmt.Errorf("tun: %w", err)
	}
	s := stack.New(stack.Options{
		NetworkProtocols:   []stack.NetworkProtocolFactory{ipv4.NewProtocol, ipv6.NewProtocol},
		TransportProtocols: []stack.TransportProtocolFactory{tcp.NewProtocol, udp.NewProtocol, icmp.NewProtocol4, icmp.NewProtocol6},
	})
	ctx, cancel := context.WithCancel(context.Background())
	t := &Tunnel{s: s, fd: fd, ctx: ctx, cancel: cancel}
	fail := func(e tcpip.Error) (*Tunnel, error) {
		cancel()
		s.Close()
		return nil, fmt.Errorf("tun: %s", e)
	}
	if e := s.CreateNIC(nicID, link); e != nil {
		return fail(e)
	}
	// Take every address: the stack stands in for the whole internet.
	if e := s.SetPromiscuousMode(nicID, true); e != nil {
		return fail(e)
	}
	if e := s.SetSpoofing(nicID, true); e != nil {
		return fail(e)
	}
	s.SetRouteTable([]tcpip.Route{
		{Destination: header.IPv4EmptySubnet, NIC: nicID},
		{Destination: header.IPv6EmptySubnet, NIC: nicID},
	})
	sack := tcpip.TCPSACKEnabled(true)
	_ = s.SetTransportProtocolOption(tcp.ProtocolNumber, &sack)

	tcpForwarder := tcp.NewForwarder(s, 0, 1024, func(r *tcp.ForwarderRequest) {
		t.forwardTCP(r, dial, allow, dns)
	})
	s.SetTransportProtocolHandler(tcp.ProtocolNumber, tcpForwarder.HandlePacket)
	udpForwarder := udp.NewForwarder(s, func(r *udp.ForwarderRequest) bool {
		if r.ID().LocalPort != 53 {
			return false // refused: ICMP port unreachable
		}
		var wq waiter.Queue
		ep, e := r.CreateEndpoint(&wq)
		if e != nil {
			return true
		}
		go t.serveDNS(gonet.NewUDPConn(&wq, ep), dns)
		return true
	})
	s.SetTransportProtocolHandler(udp.ProtocolNumber, udpForwarder.HandlePacket)
	logx.Info("VPN tunnel started mtu=%d", mtu)
	return t, nil
}

// Stop ends every connection, the stack, and the device.
func (t *Tunnel) Stop() {
	t.once.Do(func() {
		t.cancel()
		t.s.Close()
		_ = unix.Close(t.fd)
		t.s.Wait()
		logx.Info("VPN tunnel stopped")
	})
}

func toAddr(a tcpip.Address) netip.Addr {
	if a.Len() == 4 {
		return netip.AddrFrom4(a.As4())
	}
	return netip.AddrFrom16(a.As16())
}

func (t *Tunnel) forwardTCP(r *tcp.ForwarderRequest, dial Dialer, allow Allow, dns *FakeDNS) {
	id := r.ID()
	dst := netip.AddrPortFrom(toAddr(id.LocalAddress), id.LocalPort)
	if dst.Port() == 53 {
		// DNS over TCP, to any server: answered here like DNS over UDP
		// (Mozilla's proxy does not carry port 53).
		var wq waiter.Queue
		ep, e := r.CreateEndpoint(&wq)
		if e != nil {
			r.Complete(true)
			return
		}
		r.Complete(false)
		go func() {
			conn := gonet.NewTCPConn(&wq, ep)
			defer conn.Close()
			_ = conn.SetDeadline(time.Now().Add(dnsIdle))
			_ = dns.ServeStream(conn)
		}()
		return
	}
	if IsVPNAddress(dst.Addr()) || IsFilterAddress(dst.Addr()) {
		// Nothing else listens on the VPN's own addresses (Android's
		// private DNS tries port 853 there), and a filtering DNS's answer
		// cached from before the VPN leads nowhere: refused at once, so
		// the app asks again.
		r.Complete(true)
		return
	}
	target, ok := dns.Target(dst)
	if ok && allow != nil {
		host, port, _ := net.SplitHostPort(target)
		ok = allow(host, port)
	}
	if !ok {
		r.Complete(true)
		return
	}
	// Connect through the proxy before accepting, so a failure resets the
	// app's connection at once.
	ctx, cancel := context.WithTimeout(t.ctx, dialTimeout)
	go func() {
		defer cancel()
		upstream, err := dial(ctx, target)
		if err != nil {
			r.Complete(true)
			if !errors.Is(err, context.Canceled) {
				logx.Debug("VPN connection failed target=%s err=%s", target, logx.Err(err))
			}
			return
		}
		var wq waiter.Queue
		ep, e := r.CreateEndpoint(&wq)
		if e != nil {
			r.Complete(true)
			_ = upstream.Close()
			return
		}
		r.Complete(false)
		ep.SocketOptions().SetKeepAlive(true)
		relay(gonet.NewTCPConn(&wq, ep), upstream)
	}()
}

// serveDNS answers the queries of one UDP flow until it is idle.
func (t *Tunnel) serveDNS(conn *gonet.UDPConn, dns *FakeDNS) {
	defer conn.Close()
	buf := make([]byte, 1500)
	for {
		_ = conn.SetReadDeadline(time.Now().Add(dnsIdle))
		n, err := conn.Read(buf)
		if err != nil {
			return
		}
		reply, err := dns.Answer(buf[:n])
		if err != nil {
			continue
		}
		if _, err := conn.Write(reply); err != nil {
			return
		}
	}
}
