package service

import (
	"context"
	"net/http"
	"net/netip"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
	"github.com/armanlife/firefox-vpn-client/core/internal/resolver"
)

const dnsTestTimeout = 8 * time.Second

// dnsTestHost is one host name resolved by the DNS test, through the
// configured servers and through the system resolver for comparison.
type dnsTestHost struct {
	Host        string   `json:"host"`
	Role        string   `json:"role"`
	Addrs       []string `json:"addrs,omitempty"`
	Source      string   `json:"source,omitempty"`
	MS          int64    `json:"ms"`
	Error       string   `json:"error,omitempty"`
	SystemAddrs []string `json:"system_addrs,omitempty"`
	SystemMS    int64    `json:"system_ms"`
	SystemError string   `json:"system_error,omitempty"`
	// Differs is set when both answered with no address in common. Alone
	// it means little: sites served from many places (CDNs) give each
	// resolver a nearby address.
	Differs bool `json:"differs"`
	// Filtered is set when the system answered with a block-page address
	// (a private, loopback, or link-local address, or Iran's filtering
	// page): the network tampers with DNS.
	Filtered bool `json:"filtered"`
}

// systemDNS resolves with the system resolver; tests replace it.
var systemDNS = func(ctx context.Context, host string) (resolver.Result, error) {
	return (*resolver.Resolver)(nil).Lookup(ctx, host)
}

// dnsDescription summarizes the DNS settings for the status view.
func dnsDescription(cfg config.DNS) string {
	r, err := resolver.New(cfg.Servers, cfg.FallbackToSystem)
	if err != nil {
		return "invalid: " + err.Error()
	}
	return r.String()
}

// dnsTestTargets lists the names this program resolves itself.
func (d *Daemon) dnsTestTargets() [][2]string {
	cfg := d.config()
	targets := [][2]string{
		{"api.accounts.firefox.com", "Firefox Accounts"},
		{hostOf(cfg.Network.GuardianEndpoint), "Guardian (proxy pass)"},
		{"firefox.settings.services.mozilla.com", "Server list"},
	}
	upstream := "us.m1.fastly-masque.net"
	if engine := d.currentEngine(); engine != nil {
		if selected, _ := engine.selection(); selected.Addr != "" {
			if host, _, err := splitHostPortDefault(selected.Addr); err == nil {
				upstream = host
			}
		}
	}
	return append(targets, [2]string{upstream, "Proxy server (Fastly)"})
}

func hostOf(raw string) string {
	u, err := url.Parse(raw)
	if err != nil || u.Hostname() == "" {
		return raw
	}
	return u.Hostname()
}

func splitHostPortDefault(addr string) (string, string, error) {
	u, err := proxy.NormalizeURL(addr)
	if err != nil {
		return "", "", err
	}
	return u.Hostname(), u.Port(), nil
}

// testDNS resolves every target through servers (without falling back)
// and through the system resolver.
func (d *Daemon) testDNS(ctx context.Context, servers []string) ([]dnsTestHost, error) {
	configured, err := resolver.New(servers, false)
	if err != nil {
		return nil, err
	}
	targets := d.dnsTestTargets()
	results := make([]dnsTestHost, len(targets))
	var wg sync.WaitGroup
	for i, target := range targets {
		wg.Add(1)
		go func(i int, host, role string) {
			defer wg.Done()
			ctx, cancel := context.WithTimeout(ctx, dnsTestTimeout)
			defer cancel()
			out := dnsTestHost{Host: host, Role: role}
			if !configured.System() {
				start := time.Now()
				res, err := configured.Lookup(ctx, host)
				out.MS = time.Since(start).Milliseconds()
				if err != nil {
					out.Error = err.Error()
				} else {
					out.Addrs, out.Source = addrStrings(res), res.Source
				}
			}
			start := time.Now()
			sys, err := systemDNS(ctx, host)
			out.SystemMS = time.Since(start).Milliseconds()
			if err != nil {
				out.SystemError = err.Error()
			} else {
				out.SystemAddrs = addrStrings(sys)
			}
			out.Differs = len(out.Addrs) > 0 && len(out.SystemAddrs) > 0 && !overlap(out.Addrs, out.SystemAddrs)
			out.Filtered = anyBlockPage(out.SystemAddrs)
			results[i] = out
		}(i, target[0], target[1])
	}
	wg.Wait()
	return results, nil
}

func addrStrings(res resolver.Result) []string {
	out := make([]string, len(res.Addrs))
	for i, a := range res.Addrs {
		out[i] = a.String()
	}
	return out
}

// iranBlockPageV6 holds the IPv6 addresses of Iran's filtering page
// (its IPv4 ones, 10.10.34.34-36, are private).
var iranBlockPageV6 = netip.MustParsePrefix("2001:4188:2:600:10:10:34:0/112")

// anyBlockPage reports whether a public name resolved to an address that
// cannot be its real one: a filtering network's answer.
func anyBlockPage(addrs []string) bool {
	for _, s := range addrs {
		a, err := netip.ParseAddr(s)
		if err != nil {
			continue
		}
		a = a.Unmap()
		if a.IsPrivate() || a.IsLoopback() || a.IsUnspecified() || a.IsLinkLocalUnicast() || iranBlockPageV6.Contains(a) {
			return true
		}
	}
	return false
}

func overlap(a, b []string) bool {
	seen := make(map[string]bool, len(a))
	for _, x := range a {
		seen[x] = true
	}
	for _, y := range b {
		if seen[y] {
			return true
		}
	}
	return false
}

// handleDNSTest tests the servers in the request body (the unsaved form),
// or the saved ones when the body names none.
func (s *dashboardServer) handleDNSTest(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Servers *[]string `json:"servers"`
	}
	if !readJSON(w, r, &in) {
		return
	}
	servers := s.d.config().DNS.Servers
	if in.Servers != nil {
		servers = *in.Servers
	}
	cleaned := make([]string, 0, len(servers))
	for _, spec := range servers {
		if spec = strings.TrimSpace(spec); spec != "" {
			cleaned = append(cleaned, spec)
		}
	}
	results, err := s.d.testDNS(r.Context(), cleaned)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"servers": cleaned, "results": results})
}
