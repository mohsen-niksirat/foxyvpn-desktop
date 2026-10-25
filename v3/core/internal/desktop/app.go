package desktop

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/service"
)

// The app mode (-app) is the core process of the desktop app: the app
// starts it as a child process when it opens and talks to it only through
// the dashboard API with the local token. It has no tray icon and no
// status screen; it logs to the log file only, because its standard output
// and error are pipes that nobody may read.
//
// The app keeps the write end of the child's standard input open for its
// whole life. When the standard input reaches its end (the app quit or
// crashed and the system closed the pipe), the process restores the system
// proxy, stops the service, and exits.

// ErrAlreadyRunning means another copy of the program already serves the
// data folder; RunApp returns it wrapped, and the executable exits with
// status 3 for it.
var ErrAlreadyRunning = errors.New("another copy of the program already serves this data folder")

// alreadyRunningError is ErrAlreadyRunning for a data folder.
type alreadyRunningError struct {
	dir string
	// who says which copy serves the folder.
	who string
}

func (e *alreadyRunningError) Error() string {
	return fmt.Sprintf("%s (%s): %s", ErrAlreadyRunning, e.dir, e.who)
}

func (e *alreadyRunningError) Is(target error) bool { return target == ErrAlreadyRunning }

// Exit statuses of an -app run that failed (0 after a requested stop, 2
// for bad arguments from the flag package).
const (
	ExitStartFailed        = 1
	ExitAlreadyRunning     = 3
	ExitDashboardPortInUse = 4
)

// Codes of the "app-error: <code> <detail>" line that an -app run that
// failed writes to the standard error, for the app to act on.
const (
	// AppErrorAlreadyRunning: the detail is the data folder.
	AppErrorAlreadyRunning = "already_running"
	// AppErrorDashboardPortInUse: the detail is the dashboard.listen
	// address another program holds.
	AppErrorDashboardPortInUse = "dashboard_port_in_use"
	// AppErrorStartFailed: the detail is the error on one line.
	AppErrorStartFailed = "start_failed"
)

// appErrorPrefix starts the line the app parses.
const appErrorPrefix = "app-error: "

// appFailure is how a failed -app run tells the app why.
type appFailure struct {
	code   string
	detail string
	exit   int
}

// classifyAppError maps the error that ended an -app run to its code,
// detail, and exit status.
func classifyAppError(err error) appFailure {
	var running *alreadyRunningError
	var inUse *service.AddressInUseError
	switch {
	case errors.As(err, &running):
		return appFailure{AppErrorAlreadyRunning, running.dir, ExitAlreadyRunning}
	case errors.As(err, &inUse) && inUse.Listener == service.ListenerDashboard:
		return appFailure{AppErrorDashboardPortInUse, inUse.Address, ExitDashboardPortInUse}
	default:
		return appFailure{AppErrorStartFailed, err.Error(), ExitStartFailed}
	}
}

// ReportAppError writes why an -app run failed to w (the standard error,
// which the app reads; the log goes to the file only in this mode) and
// returns the exit status. The first line is always
// "app-error: <code> <detail>", with a one-word code and the detail on the
// rest of the line; only already_running adds a line for people.
func ReportAppError(w io.Writer, err error) int {
	f := classifyAppError(err)
	fmt.Fprintf(w, "%s%s %s\n", appErrorPrefix, f.code, oneLine(f.detail))
	if f.code == AppErrorAlreadyRunning {
		fmt.Fprintf(w, "firefox-vpn-core: %s\n", oneLine(err.Error()))
	}
	return f.exit
}

// lineBreaks turns line breaks into spaces; anything else, such as double
// spaces in a folder name, is kept.
var lineBreaks = strings.NewReplacer("\r\n", " ", "\r", " ", "\n", " ")

// oneLine puts s on one line.
func oneLine(s string) string { return lineBreaks.Replace(s) }

// appPollInterval spaces the status reads that apply the system proxy
// mode.
const appPollInterval = 2 * time.Second

// appReachTimeout bounds the check for another copy serving the folder.
const appReachTimeout = 2 * time.Second

// RunApp runs the service for the desktop app until POST /api/app/exit,
// the end of the standard input (when it is a pipe), Ctrl+C, or SIGTERM.
// It returns an error wrapping ErrAlreadyRunning when a tray icon, another
// app-mode copy, or a service already serves the data folder, and the
// service's error when it cannot start (for example a
// *service.AddressInUseError when the dashboard address is taken).
// ReportAppError tells the app which.
func RunApp(paths service.DataPaths, verbose bool) error {
	release, ok := acquireSingleInstance(paths)
	if !ok {
		return &alreadyRunningError{dir: paths.Dir, who: "a tray icon or another app-mode copy runs for it"}
	}
	defer release()
	client := service.NewClient(paths)
	if reachable(client, appReachTimeout) {
		return &alreadyRunningError{dir: paths.Dir, who: "its dashboard API already answers (a copy in a terminal or a systemd service)"}
	}

	stop := newStopRequest()
	d, err := newHostedDaemon(paths, verbose, func() { stop.request("exit requested through the API") })
	if err != nil {
		return err
	}
	d.RequireDashboard = true
	// The app starts with the proxy off, and so without the system proxy:
	// it connects when the user presses the button (POST /api/power).
	d.Off()

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(signals)
	go func() {
		if sig, ok := <-signals; ok {
			stop.request("signal " + sig.String())
		}
	}()
	if stdinIsPipe(os.Stdin) {
		go watchParent(os.Stdin, func() { stop.request("the app closed the standard input") })
	} else {
		logx.Warn("app: the standard input is not a pipe; the process does not stop when the app quits")
	}

	logx.Info("app: started pid=%d data_dir=%s", os.Getpid(), paths.Dir)
	// Another program replacing the system proxy shows in the status.
	sysproxy := systemProxySync{report: d.SetSystemProxyTaken}
	cleaned := make(chan struct{})
	var cleanOnce sync.Once
	cleanup := func() {
		sysproxy.clear()
		cleanOnce.Do(func() { close(cleaned) })
	}
	// Windows ends the process soon after a sign-out or shutdown; the
	// system proxy is restored before the message returns.
	stopEnd, err := watchEndSession(func() {
		stop.request("Windows is signing out or shutting down")
		select {
		case <-cleaned:
		case <-time.After(endSessionWait):
			sysproxy.clear()
		}
	})
	if err != nil {
		logx.Warn("app: watching for the end of the Windows session failed err=%s", logx.Err(err))
	}
	defer stopEnd()
	return runHosted(d, stop.ch,
		func(ctx context.Context) {
			sysproxy.follow(ctx, func() (service.TrayStatus, error) { return pollStatus(client) }, appPollInterval)
		},
		cleanup)
}

// endSessionWait bounds the wait for the normal stop when Windows ends the
// session; the system proxy is then restored directly. Windows gives a
// program about five seconds.
const endSessionWait = 3 * time.Second

// hostedService is the part of service.Daemon that runHosted uses.
type hostedService interface {
	Run() error
	Shutdown()
}

// runHosted runs svc and loop until a stop request arrives on stop or svc
// fails. It then stops loop, calls cleanup (which restores the system
// proxy, so applications are not left pointed at a closed port), and shuts
// svc down. It returns svc's error, or nil after a stop request.
func runHosted(svc hostedService, stop <-chan string, loop func(context.Context), cleanup func()) error {
	runErr := make(chan error, 1)
	go func() { runErr <- svc.Run() }()
	ctx, cancel := context.WithCancel(context.Background())
	loopDone := make(chan struct{})
	go func() {
		defer close(loopDone)
		loop(ctx)
	}()

	var err error
	select {
	case reason := <-stop:
		logx.Info("app: stopping reason=%s", reason)
	case err = <-runErr:
		if err == nil {
			err = errors.New("the service stopped by itself")
		}
		logx.Error("app: the service stopped err=%s", logx.Err(err))
	}
	cancel()
	<-loopDone
	cleanup()
	svc.Shutdown()
	logx.Info("app: stopped")
	return err
}

// stopRequest carries the first reason to stop; later requests are
// dropped.
type stopRequest struct {
	once sync.Once
	ch   chan string
}

func newStopRequest() *stopRequest { return &stopRequest{ch: make(chan string, 1)} }

func (s *stopRequest) request(reason string) {
	s.once.Do(func() { s.ch <- reason })
}

// stdinIsPipe reports whether f is a pipe or a socket: the desktop app's
// standard input. A terminal, the null device, or a file is not watched,
// since its end (or a key press) says nothing about the app.
func stdinIsPipe(f *os.File) bool {
	if f == nil {
		return false
	}
	info, err := f.Stat()
	if err != nil {
		return false
	}
	return info.Mode()&(os.ModeNamedPipe|os.ModeSocket) != 0
}

// watchParent reads r, discarding what it reads, until it ends or fails,
// then calls done.
func watchParent(r io.Reader, done func()) {
	_, err := io.Copy(io.Discard, r)
	if err != nil {
		logx.Debug("app: reading the standard input failed err=%s", logx.Err(err))
	}
	done()
}
