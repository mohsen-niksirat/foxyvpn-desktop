package version

import (
	"strings"
	"testing"
)

func TestVersionFormatAndOrder(t *testing.T) {
	parts := strings.Split(Current, ".")
	if len(parts) != 3 {
		t.Fatalf("version %q must be major.minor.patch", Current)
	}
	for _, tc := range []struct {
		a, b string
		want bool
	}{
		{"1.1.0", "1.0.9", true},
		{"1.1.1", "1.1.0", true},
		{"1.1.10", "1.1.9", true},
		{"1.10.0", "1.9.5", true},
		{"2.0.0", "1.9.9", true},
		{"1.1.0", "1.1.0", false},
		{"1.1.0", "1.1.1", false},
		{"1.1", "1.1.0", false},
		{"v1.2.0", "1.1.3", true},
		{"1", "0.9.9", true},
		{"", "1.0.0", false},
	} {
		if got := Newer(tc.a, tc.b); got != tc.want {
			t.Errorf("versionNewer(%q, %q) = %v, want %v", tc.a, tc.b, got, tc.want)
		}
	}
}
