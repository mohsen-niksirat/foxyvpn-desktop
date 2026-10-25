//go:build linux

package netstate

import (
	"bufio"
	"os"
	"slices"
	"strconv"
	"strings"
)

// connected looks for a default route (IPv4 or IPv6) on an interface
// other than loopback.
func connected() bool {
	v4, err4 := hasDefaultRoute("/proc/net/route", parseRoute4)
	v6, err6 := hasDefaultRoute("/proc/net/ipv6_route", parseRoute6)
	if err4 != nil && err6 != nil {
		return true
	}
	return v4 || v6
}

// current names the connected networks: the default routes, with their
// interfaces and gateways.
func current() (string, bool) {
	v4, err4 := defaultRoutes("/proc/net/route", parseRoute4, 0, 2)
	v6, err6 := defaultRoutes("/proc/net/ipv6_route", parseRoute6, 9, 4)
	if err4 != nil && err6 != nil {
		return "", false
	}
	return strings.Join(append(v4, v6...), ";"), true
}

// defaultRoutes lists "interface gateway" for each default route in path.
func defaultRoutes(path string, isDefault func([]string) bool, iface, gateway int) ([]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var routes []string
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		if fields := strings.Fields(scanner.Text()); isDefault(fields) {
			routes = append(routes, fields[iface]+" "+fields[gateway])
		}
	}
	slices.Sort(routes)
	return routes, scanner.Err()
}

const routeUp = 0x1 // RTF_UP

func hasDefaultRoute(path string, isDefault func([]string) bool) (bool, error) {
	f, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		if isDefault(strings.Fields(scanner.Text())) {
			return true, nil
		}
	}
	return false, scanner.Err()
}

// parseRoute4 reads a /proc/net/route line: Iface Destination Gateway
// Flags RefCnt Use Metric Mask ...
func parseRoute4(f []string) bool {
	if len(f) < 8 || f[0] == "lo" || f[1] != "00000000" || f[7] != "00000000" {
		return false
	}
	flags, err := strconv.ParseUint(f[3], 16, 32)
	return err == nil && flags&routeUp != 0
}

// parseRoute6 reads a /proc/net/ipv6_route line: Destination PrefixLen
// Source SourcePrefixLen NextHop Metric RefCnt Use Flags Iface. Loopback
// carries unreachable default entries, which do not count.
func parseRoute6(f []string) bool {
	if len(f) < 10 || f[9] == "lo" || f[0] != strings.Repeat("0", 32) || f[1] != "00" {
		return false
	}
	flags, err := strconv.ParseUint(f[8], 16, 32)
	return err == nil && flags&routeUp != 0
}
