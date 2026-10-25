package service

import (
	"net/http"
	"net/netip"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/armanlife/firefox-vpn-client/core/internal/routing"
	"github.com/armanlife/firefox-vpn-client/core/internal/securefile"
)

// writeTestGeoIP writes a geoip.dat with the given tags and networks into
// the daemon's routing folder (the v2ray protobuf layout: GeoIPList ->
// GeoIP{country_code, cidr{ip, prefix}}).
func writeTestGeoIP(t *testing.T, d *Daemon, tags map[string][]string) {
	t.Helper()
	field := func(b []byte, num int, data []byte) []byte {
		b = binaryUvarint(b, uint64(num)<<3|2)
		b = binaryUvarint(b, uint64(len(data)))
		return append(b, data...)
	}
	var list []byte
	for tag, cidrs := range tags {
		entry := field(nil, 1, []byte(tag))
		for _, c := range cidrs {
			p := netip.MustParsePrefix(c)
			cidr := field(nil, 1, p.Addr().AsSlice())
			cidr = binaryUvarint(binaryUvarint(cidr, 2<<3), uint64(p.Bits()))
			entry = field(entry, 2, cidr)
		}
		list = field(list, 1, entry)
	}
	if err := securefile.EnsurePrivateDir(d.paths.RoutingDir); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(d.paths.RoutingDir, routing.GeoIPFile), list, 0o600); err != nil {
		t.Fatal(err)
	}
}

func binaryUvarint(b []byte, v uint64) []byte {
	for v >= 0x80 {
		b = append(b, byte(v)|0x80)
		v >>= 7
	}
	return append(b, byte(v))
}

// Routing is off by default and applies live when the settings change; a
// rule naming a list that has not been downloaded leaves everything going
// through the proxy and says why. Another region swaps its presets in the
// Direct list for the old region's; the user's own rules stay.
func TestRoutingSettingsApplyLive(t *testing.T) {
	d := newTestDaemon(t)
	cfg := d.config()
	if cfg.Routing.Enabled || d.routingView().Active {
		t.Fatal("routing must be off by default")
	}
	// The region's presets are in the Direct list itself.
	if cfg.Routing.Region != "ir" || strings.Join(cfg.Routing.Direct, " ") != "geosite:ir ext:iran.dat:ir geoip:ir geoip:private" {
		t.Fatalf("default region %q and direct rules %q", cfg.Routing.Region, cfg.Routing.Direct)
	}
	if got := strings.Join(d.routingView().Direct, " "); got != strings.Join(cfg.Routing.Direct, " ") {
		t.Fatalf("default effective direct rules %q", got)
	}

	cfg.Routing.Enabled = true
	if _, err := d.updateSettings(cfg, nil); err != nil {
		t.Fatal(err)
	}
	view := d.routingView()
	if view.Active || !strings.Contains(view.Error, "geosite.dat") {
		t.Fatalf("without lists routing waits for them: %+v", view)
	}

	// No region: the old region's presets leave the list, private
	// networks come in, before the user's rules.
	writeTestGeoIP(t, d, map[string][]string{"private": {"192.168.0.0/16"}})
	cfg.Routing.Region = ""
	cfg.Routing.Direct = []string{"domain:shop.ir", "10.0.0.0/8"}
	if _, err := d.updateSettings(cfg, nil); err != nil {
		t.Fatal(err)
	}
	view = d.routingView()
	if !view.Active || view.Error != "" || view.Region != "" {
		t.Fatalf("rules with the network list work at once: %+v", view)
	}
	if got := strings.Join(view.Direct, " "); got != "geoip:private domain:shop.ir 10.0.0.0/8" {
		t.Fatalf("effective direct rules %q", got)
	}

	// A region whose tags the list has applies live too.
	writeTestGeoIP(t, d, map[string][]string{"private": {"192.168.0.0/16"}, "tr": {"78.160.0.0/11"}})
	cfg.Routing.Region = "tr"
	if _, err := d.updateSettings(cfg, nil); err != nil {
		t.Fatal(err)
	}
	if view := d.routingView(); !view.Active || view.Region != "tr" || !strings.Contains(view.Summary, "geoip:tr=") {
		t.Fatalf("region tr: %+v", view)
	}

	// China: its usual lists (Loyalsoldier's) replace the default ones;
	// lists set by hand stay when the region changes.
	cfg.Routing.Region = "cn"
	if _, err := d.updateSettings(cfg, nil); err != nil {
		t.Fatal(err)
	}
	if got := d.config().Routing; got.GeoSiteURL != routing.RegionSource("cn").GeoSiteURL || d.routingView().Source != "loyalsoldier" {
		t.Fatalf("China's lists: %s %s", got.GeoSiteURL, d.routingView().Source)
	}
	cfg = d.config()
	cfg.Routing.GeoSiteURL = "https://example.com/site.dat"
	cfg.Routing.Region = "tr"
	if _, err := d.updateSettings(cfg, nil); err != nil {
		t.Fatal(err)
	}
	if got := d.config().Routing.GeoSiteURL; got != "https://example.com/site.dat" || d.routingView().Source != "" {
		t.Fatalf("lists set by hand: %s", got)
	}
	cfg = d.config()

	cfg.Routing.Region = "xx"
	if _, err := d.updateSettings(cfg, nil); err == nil || !strings.Contains(err.Error(), "routing.region") {
		t.Fatalf("an unknown region must be refused: %v", err)
	}
	cfg.Routing.Region = "tr"

	cfg.Routing.Block = []string{"not a rule"}
	if _, err := d.updateSettings(cfg, nil); err == nil {
		t.Fatal("an invalid rule must be refused")
	}

	rec := newDashboardClient(t, d).do(http.MethodGet, "/api/routing", nil)
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), `"active":true`) || !strings.Contains(rec.Body.String(), `"region":"tr"`) {
		t.Fatalf("GET /api/routing: %d %s", rec.Code, rec.Body.String())
	}
}

func TestDestinationTest(t *testing.T) {
	d := newTestDaemon(t)
	client := newDashboardClient(t, d)
	test := func(target string) destinationTest {
		t.Helper()
		rec := client.do(http.MethodPost, "/api/routing/test", map[string]string{"target": target})
		if rec.Code != http.StatusOK {
			t.Fatalf("%s: %d %s", target, rec.Code, rec.Body.String())
		}
		return decodeBody[destinationTest](t, rec)
	}
	if got := test("digikala.com"); got.Route != "proxy" || !strings.Contains(got.Note, "off") {
		t.Fatalf("routing off: %+v", got)
	}

	writeTestGeoIP(t, d, map[string][]string{"private": {"192.168.0.0/16"}})
	cfg := d.config()
	cfg.Routing.Enabled = true
	cfg.Routing.Region = ""
	cfg.Routing.Direct = []string{"domain:shop.ir", "10.0.0.0/8"}
	cfg.Routing.Block = []string{"full:ads.example"}
	if _, err := d.updateSettings(cfg, nil); err != nil {
		t.Fatal(err)
	}
	for target, want := range map[string]destinationTest{
		"https://www.shop.ir/cart?x=1": {Host: "www.shop.ir", Port: "443", Route: "direct", Rule: "domain:shop.ir"},
		"10.1.2.3:9898":                {Host: "10.1.2.3", Port: "9898", Route: "direct", Rule: "10.0.0.0/8"},
		"192.168.1.1":                  {Host: "192.168.1.1", Route: "direct", Rule: "geoip:private"},
		"ads.example":                  {Host: "ads.example", Route: "block", Rule: "full:ads.example"},
		"example.com:9898":             {Host: "example.com", Port: "9898", Route: "proxy", PortRefused: true},
		"[2001:db8::1]:443":            {Host: "2001:db8::1", Port: "443", Route: "proxy"},
	} {
		if got := test(target); got != want {
			t.Errorf("%s: got %+v, want %+v", target, got, want)
		}
	}
	if rec := client.do(http.MethodPost, "/api/routing/test", map[string]string{"target": " "}); rec.Code != http.StatusBadRequest {
		t.Fatalf("empty target: %d", rec.Code)
	}
}
