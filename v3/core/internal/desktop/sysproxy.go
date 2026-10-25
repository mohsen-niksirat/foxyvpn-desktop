package desktop

import (
	"net"
	"sync"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/service"
)

// systemProxySync carries out the system_proxy mode (Windows, and GNOME's
// setting on Linux), in the
// tray's or the app mode's session:
//
//   - set points the system at the local proxy only while the proxy runs, so
//     stopping the program never leaves applications pointed at a closed
//     port; the previous setting comes back then.
//   - clear restores a setting this program made, then turns the system
//     proxy off once, when the user switches to the mode, so a proxy set
//     later by hand stays. Starting in clear only undoes a setting of this
//     program's: another program's proxy (such as v2rayN's) stays.
type systemProxySync struct {
	mu      sync.Mutex
	applied string // the proxy address this program set, "" for none
	mode    string // the last mode seen

	// report, when set, tells the service about another program's setting
	// in place of this program's, nil once this program's is back (watch).
	report   func(*service.SystemProxyTaken)
	reported *service.SystemProxyTaken
	checked  time.Time // when watch last looked
	// retake is the last system_proxy_retake seen; retakeSeen once one was.
	retake     uint64
	retakeSeen bool
}

// takenCheck is how often watch looks whether another program replaced
// this program's setting.
const takenCheck = 5 * time.Second

// update carries out the mode for st (nil when the service is not
// reachable).
func (s *systemProxySync) update(st *service.TrayStatus) {
	if !systemProxySupported() {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	ours, want := wantedSystemProxy(st)

	// Remove this program's setting that is no longer wanted: what this
	// copy set, and what an earlier copy may have left behind for this
	// address (only when it is not wanted now, or the current setting
	// would be undone on every refresh).
	if s.applied != "" && s.applied != want {
		if err := restoreSystemProxy(s.applied); err != nil {
			logx.Warn("restoring the system proxy setting failed err=%s", logx.Err(err))
		} else if want == "" {
			logx.Info("system proxy setting restored")
		}
	}
	if ours != "" && ours != want {
		if err := restoreSystemProxy(ours); err != nil {
			logx.Warn("restoring the system proxy setting failed err=%s", logx.Err(err))
		}
	}
	if st != nil && st.SystemProxy != s.mode {
		// The first status only records the mode: clearing is the user's
		// action, not something every start of the program does.
		if s.mode != "" && st.SystemProxy == config.SystemProxyClear {
			if err := clearSystemProxy(); err != nil {
				logx.Warn("clearing the system proxy setting failed err=%s", logx.Err(err))
			} else {
				logx.Info("system proxy cleared")
			}
		}
		s.mode = st.SystemProxy
	}
	if want != "" && want != s.applied {
		if err := setSystemProxy(want); err != nil {
			logx.Warn("setting the system proxy failed err=%s", logx.Err(err))
			want = ""
		} else {
			logx.Info("system proxy set to the local proxy address=%s", want)
		}
	}
	s.applied = want
	s.watch(st)
}

// watch looks, every takenCheck, whether another program replaced this
// program's setting: VPN and proxy programs such as v2rayN, Clash, or
// Hiddify set the system proxy when they connect, and may clear it when
// they quit. It tells the service, and takes the setting back only when the
// user asks (system_proxy_retake), never by itself: two programs that each
// take it back would switch it every few seconds.
func (s *systemProxySync) watch(st *service.TrayStatus) {
	retake := false
	if st != nil {
		retake = s.retakeSeen && st.SystemProxyRetake != s.retake
		s.retake, s.retakeSeen = st.SystemProxyRetake, true
	}
	if s.applied == "" {
		s.setTaken(nil)
		return
	}
	if !retake && time.Since(s.checked) < takenCheck {
		return
	}
	s.checked = time.Now()
	taken, by := systemProxyTaken(s.applied)
	if taken && retake {
		if err := setSystemProxy(s.applied); err != nil {
			logx.Warn("setting the system proxy again failed err=%s", logx.Err(err))
		} else {
			logx.Info("system proxy set again at the user's request address=%s", s.applied)
			taken = false
		}
	}
	if taken {
		s.setTaken(&service.SystemProxyTaken{By: by})
	} else {
		s.setTaken(nil)
	}
}

// setTaken reports t to the service when it changed.
func (s *systemProxySync) setTaken(t *service.SystemProxyTaken) {
	if (t == nil && s.reported == nil) || (t != nil && s.reported != nil && *t == *s.reported) {
		return
	}
	s.reported = t
	if t != nil {
		logx.Warn("another program changed the system proxy setting; applications no longer use this proxy by=%s", t.By)
	} else {
		logx.Info("the system proxy setting is this program's again")
	}
	if s.report != nil {
		s.report(t)
	}
}

// wantedSystemProxy is the local proxy's address for st (nil when the
// service is not reachable), and the address the system proxy should
// point at now, "" for none.
func wantedSystemProxy(st *service.TrayStatus) (ours, want string) {
	if st != nil && st.Proxy != nil {
		ours = localProxyAddress(st.Proxy.Listen)
		// Not while auto-connect has not yet seen the connection work.
		if st.State.Phase == service.PhaseRunning && st.SystemProxy == config.SystemProxySet && !st.AutoConnecting {
			want = ours
		}
	}
	return ours, want
}

// handOver leaves the setting to the process serving the folder, which
// applies the mode itself (st.SystemProxyByHost): this copy forgets what
// it set without restoring it (both set the same address), so closing it,
// or a failed poll, never undoes the other copy's setting while that copy
// keeps it recorded as applied. It records the mode, so that applying it
// again later does not count as a switch to clear.
func (s *systemProxySync) handOver(st *service.TrayStatus) {
	if !systemProxySupported() {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	// A setting for another address (the port changed) is not the other
	// copy's; it goes.
	if _, want := wantedSystemProxy(st); s.applied != "" && s.applied != want {
		if err := restoreSystemProxy(s.applied); err != nil {
			logx.Warn("restoring the system proxy setting failed err=%s", logx.Err(err))
		}
	}
	s.applied = ""
	s.mode = st.SystemProxy
	s.setTaken(nil)
}

// active reports whether this program's setting is in place now.
func (s *systemProxySync) active() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.applied != ""
}

// clear restores the user's proxy setting if this program set it.
func (s *systemProxySync) clear() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.applied == "" {
		return
	}
	if err := restoreSystemProxy(s.applied); err != nil {
		logx.Warn("restoring the system proxy setting failed err=%s", logx.Err(err))
	}
	s.applied = ""
	s.setTaken(nil)
}

// localProxyAddress is the address applications on this computer use for
// a proxy listening on listen.
func localProxyAddress(listen string) string {
	host, port, err := net.SplitHostPort(listen)
	if err != nil {
		return ""
	}
	if host == "" || host == "0.0.0.0" || host == "::" {
		host = "127.0.0.1"
	}
	return net.JoinHostPort(host, port)
}
