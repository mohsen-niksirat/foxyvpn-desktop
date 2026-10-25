//go:build windows || linux

package desktop

import (
	"strings"
	"testing"
	"unicode/utf16"
)

func TestCapTooltip(t *testing.T) {
	units := func(s string) int { return len(utf16.Encode([]rune(s))) }

	short := "Firefox VPN: Connected · Amsterdam, Netherlands"
	if got := capTooltip(short); got != short {
		t.Fatalf("a short tooltip changed: %q", got)
	}
	exact := strings.Repeat("a", maxTooltipUnits)
	if got := capTooltip(exact); got != exact {
		t.Fatal("a tooltip of exactly the limit must stay whole")
	}
	long := "Firefox VPN: Service not reachable · Could not start: " + strings.Repeat("parsing config.json ", 10)
	got := capTooltip(long)
	if units(got) != maxTooltipUnits || !strings.HasSuffix(got, "…") || !strings.HasPrefix(long, strings.TrimSuffix(got, "…")) {
		t.Fatalf("long tooltip: %d units, %q", units(got), got)
	}
	// A character outside the BMP takes two units and is never split.
	emoji := strings.Repeat("a", maxTooltipUnits-2) + "\U0001F600" + "tail"
	got = capTooltip(emoji)
	if units(got) > maxTooltipUnits || strings.ContainsRune(got, 0x1F600) || !strings.HasSuffix(got, "…") {
		t.Fatalf("surrogate pair: %d units, %q", units(got), got)
	}
}
