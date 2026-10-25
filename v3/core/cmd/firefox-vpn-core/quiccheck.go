package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"time"

	"github.com/quic-go/quic-go"
)

// quicTargets are the handshakes -check-quic tries: Mozilla's proxy
// servers (Fastly, the recommended location and Germany) on their HTTP/3
// port, then well-known sites, to tell a block of QUIC as a whole from a
// block of Mozilla's servers.
var quicTargets = []struct{ name, addr string }{
	{"Mozilla proxy (recommended)", "p.m1.fastly-masque.net:2499"},
	{"Mozilla proxy (Germany)", "muc139.m1.fastly-masque.net:2499"},
	{"Google", "www.google.com:443"},
	{"Cloudflare", "cloudflare-quic.com:443"},
}

// quicTimeout bounds one handshake.
const quicTimeout = 6 * time.Second

// runQUICCheck tries a QUIC handshake to each target and prints one line
// per target; it reports whether Mozilla's servers answered.
func runQUICCheck(w io.Writer) bool {
	mozilla := false
	for i, t := range quicTargets {
		host := t.addr[:len(t.addr)-len(":2499")]
		if t.addr[len(t.addr)-4:] == ":443" {
			host = t.addr[:len(t.addr)-4]
		}
		ctx, cancel := context.WithTimeout(context.Background(), quicTimeout)
		start := time.Now()
		conn, err := quic.DialAddr(ctx, t.addr, &tls.Config{ServerName: host, NextProtos: []string{"h3"}}, &quic.Config{})
		cancel()
		took := time.Since(start).Round(time.Millisecond)
		if err != nil {
			fmt.Fprintf(w, "%-30s %-36s QUIC FAILED after %s: %v\n", t.name, t.addr, took, err)
			continue
		}
		_ = conn.CloseWithError(0, "")
		fmt.Fprintf(w, "%-30s %-36s QUIC ok in %s\n", t.name, t.addr, took)
		if i < 2 {
			mozilla = true
		}
	}
	return mozilla
}
