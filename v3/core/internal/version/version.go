package version

import (
	"strconv"
	"strings"
)

// Current is the program version, "major.minor.patch", shown in the
// dashboard, the status screen, the tray tooltip, and -version. The build
// sets it from app/pubspec.yaml (scripts/build-*.ps1):
//
//	-ldflags "-X github.com/armanlife/firefox-vpn-client/core/internal/version.Current=1.1.0"
//
// "0.0.0" is a development build.
var Current = "0.0.0"

// Newer reports whether version a is newer than b ("major.minor.patch";
// missing or unparsable parts count as 0).
func Newer(a, b string) bool {
	pa, pb := versionParts(a), versionParts(b)
	for i := range pa {
		if pa[i] != pb[i] {
			return pa[i] > pb[i]
		}
	}
	return false
}

func versionParts(v string) [3]int {
	var out [3]int
	for i, part := range strings.SplitN(strings.TrimPrefix(strings.TrimSpace(v), "v"), ".", 3) {
		out[i], _ = strconv.Atoi(part)
	}
	return out
}
