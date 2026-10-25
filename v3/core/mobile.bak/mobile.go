// Package mobile is the gomobile entry point of the core: the Android app
// (and later other app shells) starts and stops the same daemon the
// desktop binary runs, with the data folder the app chooses. The app then
// talks to it through the dashboard's HTTP API on loopback, as the desktop
// tray does.
//
// Build: gomobile bind -target=android -androidapi 24 -o ../app/android/app/libs/core.aar ./mobile
package mobile

import (
	"context"
	"errors"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/netstate"
	"github.com/armanlife/firefox-vpn-client/core/internal/service"
	"github.com/armanlife/firefox-vpn-client/core/internal/tun"
)

var (
	mu      sync.Mutex
	running *service.Daemon
	done    chan struct{}
	tunnel  *tun.Tunnel
	// stopErr and stoppedAt are why and when the daemon last stopped by
	// itself (Run returned without Stop).
	stopErr   error
	stoppedAt time.Time
)

// restartPause is how soon after stopping by itself the core may start
// again: the app asks to start it on every poll, and a start that fails
// at once (its port taken) would otherwise loop.
const restartPause = 5 * time.Second

// tunMTU is the VPN interface's MTU; the app sets the same.
const tunMTU = 1500

// Start runs the daemon with its data in dataDir (created when missing),
// with the proxy on or off (SetOn). It returns once the daemon is started;
// Run continues in the background.
func Start(dataDir string, on bool) error {
	mu.Lock()
	defer mu.Unlock()
	if running != nil {
		return errors.New("already running")
	}
	if stopErr != nil && time.Since(stoppedAt) < restartPause {
		return fmt.Errorf("the core stopped a moment ago: %w", stopErr)
	}
	paths, err := service.ResolveDataPaths(dataDir)
	if err != nil {
		return err
	}
	// The token of an earlier run would let the app trust whatever answers
	// on the API port before this run has bound it; Run writes a new one
	// once it has.
	_ = os.Remove(paths.LocalToken)
	if err := useAndroidRoots(paths.Dir); err != nil {
		return err
	}
	if err := neverSleep(paths.Config); err != nil {
		return err
	}
	d, err := service.NewDaemon(paths, false)
	if err != nil {
		return err
	}
	// Every app on the phone can reach its loopback: the API answers only
	// this app (the local token) and a browser it signs in.
	d.RequireLocalToken()
	if !on {
		d.Off()
	}
	running, done = d, make(chan struct{})
	stopErr = nil
	finished := done
	go func() {
		defer close(finished)
		err := d.Run()
		// Run ended by itself (it could not start, for one): the core no
		// longer runs, so Running says so and Start may try again after
		// restartPause.
		mu.Lock()
		if running == d {
			running, done = nil, nil
			if err == nil {
				err = errors.New("the service ended")
			}
			stopErr, stoppedAt = err, time.Now()
			logx.Error("the core stopped err=%s", logx.Err(err))
		}
		mu.Unlock()
	}()
	return nil
}

// Stop shuts the daemon down and waits for it (bounded by the daemon).
func Stop() {
	StopTun()
	mu.Lock()
	d, finished := running, done
	running, done = nil, nil
	mu.Unlock()
	if d == nil {
		return
	}
	d.Shutdown()
	<-finished
}

// SetOn turns the proxy on or off; the daemon and its API keep running.
func SetOn(on bool) {
	mu.Lock()
	d := running
	mu.Unlock()
	if d != nil {
		d.SetOn(on)
	}
}

// Connect turns the proxy on for the user (the button): the core turns it
// off again when it does not reach Mozilla within a minute (IsOn).
func Connect() {
	mu.Lock()
	d := running
	mu.Unlock()
	if d != nil {
		d.Connect()
	}
}

// IsOn reports whether the proxy is on; false once the core gave up a
// connect, which the app then turns off with its VPN.
func IsOn() bool {
	mu.Lock()
	d := running
	mu.Unlock()
	return d != nil && d.IsOn()
}

// NetworkChanged tells the core about Android's network: connected or
// not, after a change (Daemon.NetworkChanged). The state is kept even while
// no core runs, for the next one.
func NetworkChanged(connected bool) {
	mu.Lock()
	d := running
	mu.Unlock()
	if d != nil {
		d.NetworkChanged(connected)
		return
	}
	netstate.Report(connected)
}

// LastError is why the core last stopped by itself, or "".
func LastError() string {
	mu.Lock()
	defer mu.Unlock()
	if stopErr == nil {
		return ""
	}
	return stopErr.Error()
}

// DirectApps lists, one per line, the apps of the routing region that the
// VPN leaves out (Daemon.DirectApps).
func DirectApps() string {
	mu.Lock()
	d := running
	mu.Unlock()
	if d == nil {
		return ""
	}
	return strings.Join(d.DirectApps(), "\n")
}

// ExitCountry is the country code the traffic leaves from, or "" while it
// is unknown (Daemon.ExitCountry).
func ExitCountry() string {
	mu.Lock()
	d := running
	mu.Unlock()
	if d == nil {
		return ""
	}
	return d.ExitCountry()
}

// ProxyAddress is where apps on this phone reach the proxy, such as
// 127.0.0.1:10810 (Daemon.ProxyEndpoint); "" when the core does not run or
// its proxy does not listen (off, waiting, failed, restarting).
// The notification shows it in proxy mode.
func ProxyAddress() string {
	mu.Lock()
	d := running
	mu.Unlock()
	if d == nil {
		return ""
	}
	addr, _, _ := d.ProxyEndpoint()
	return addr
}

// neverSleep sets proxy.idle_sleep to 0 in the config at path: the phone
// keeps its connection to Mozilla open while it is on (the user turned the
// whole phone's VPN on), and the app does not offer the setting there.
func neverSleep(path string) error {
	cfg, _, err := config.Load(path)
	if err != nil {
		return err
	}
	if cfg.Proxy.IdleSleep == 0 {
		return nil
	}
	cfg.Proxy.IdleSleep = 0
	return config.Save(path, cfg)
}

// Speed is the proxy's current speed in bytes per second, "down,up" (a
// few seconds' average); "0,0" while it is off. The notification shows it
// when the user asked for it.
func Speed() string {
	mu.Lock()
	d := running
	mu.Unlock()
	if d == nil {
		return "0,0"
	}
	down, up := d.Speed()
	return strconv.FormatInt(down, 10) + "," + strconv.FormatInt(up, 10)
}

// Running reports whether the daemon was started and not stopped.
func Running() bool {
	mu.Lock()
	defer mu.Unlock()
	return running != nil
}

// StartTun takes over the VPN's TUN device fd (Android's VpnService): the
// phone's TCP connections go through the proxy, DNS is answered with fake
// addresses that stand for names, and other UDP is refused. The fd is
// closed by StopTun, or here when the stack does not start (the VPN then
// ends instead of holding the phone's traffic). The app must exclude itself
// from the VPN, so the core's own connections do not loop back into it.
func StartTun(fd int32) (err error) {
	defer func() {
		if err != nil {
			_ = os.NewFile(uintptr(fd), "tun").Close()
		}
	}()
	mu.Lock()
	defer mu.Unlock()
	d := running
	if d == nil {
		return errors.New("the core does not run")
	}
	if tunnel != nil {
		tunnel.Stop()
		tunnel = nil
	}
	dial := func(ctx context.Context, target string) (net.Conn, error) {
		// Read each time: the port or the login may have changed.
		addr, user, password := d.ProxyEndpoint()
		if addr == "" {
			return nil, errors.New("the proxy is not listening")
		}
		dialer, err := tun.SOCKS5Dialer(addr, user, password)
		if err != nil {
			return nil, err
		}
		return dialer(ctx, target)
	}
	t, err := tun.Start(int(fd), tunMTU, dial, d.TunnelAllows, tun.NewFakeDNS())
	if err != nil {
		return err
	}
	tunnel = t
	return nil
}

// StopTun ends the VPN's stack and closes its device.
func StopTun() {
	mu.Lock()
	t := tunnel
	tunnel = nil
	mu.Unlock()
	if t != nil {
		t.Stop()
	}
}
