package desktop

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/service"
)

// The app's end of the standard input closing ends the watch; data the
// app writes does not.
func TestWatchParentStopsAtEndOfInput(t *testing.T) {
	r, w := io.Pipe()
	done := make(chan struct{})
	go watchParent(r, func() { close(done) })

	if _, err := w.Write([]byte("ping\n")); err != nil {
		t.Fatal(err)
	}
	select {
	case <-done:
		t.Fatal("input data must not stop the process")
	case <-time.After(50 * time.Millisecond):
	}
	_ = w.Close()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("the end of the input must stop the process")
	}
}

// A broken pipe (the app crashed) also ends the watch.
func TestWatchParentStopsOnReadError(t *testing.T) {
	r, w := io.Pipe()
	done := make(chan struct{})
	go watchParent(r, func() { close(done) })
	_ = w.CloseWithError(errors.New("broken pipe"))
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("a read error must stop the process")
	}
}

// Only a pipe is watched; a file or nothing is not.
func TestStdinIsPipe(t *testing.T) {
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	defer w.Close()
	if !stdinIsPipe(r) {
		t.Error("a pipe must be watched")
	}
	file, err := os.Create(filepath.Join(t.TempDir(), "stdin"))
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	if stdinIsPipe(file) {
		t.Error("a file must not be watched")
	}
	if stdinIsPipe(nil) {
		t.Error("no standard input must not be watched")
	}
}

// fakeService stands in for the daemon: Run blocks until Shutdown, or
// fails at once with runErr.
type fakeService struct {
	runErr error
	events *[]string
	mu     *sync.Mutex
	stop   chan struct{}
	once   sync.Once
}

func newFakeService(runErr error) *fakeService {
	return &fakeService{runErr: runErr, events: &[]string{}, mu: &sync.Mutex{}, stop: make(chan struct{})}
}

func (f *fakeService) record(event string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	*f.events = append(*f.events, event)
}

func (f *fakeService) recorded() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return slices.Clone(*f.events)
}

func (f *fakeService) Run() error {
	if f.runErr != nil {
		return f.runErr
	}
	<-f.stop
	return nil
}

func (f *fakeService) Shutdown() {
	f.record("shutdown")
	f.once.Do(func() { close(f.stop) })
}

// A stop request (exit API, end of input, signal) stops the status loop,
// then restores the system proxy, then stops the service, and is a clean
// exit.
func TestRunHostedStopsInOrder(t *testing.T) {
	svc := newFakeService(nil)
	stop := newStopRequest()
	loopStarted := make(chan struct{})
	result := make(chan error, 1)
	go func() {
		result <- runHosted(svc, stop.ch, func(ctx context.Context) {
			close(loopStarted)
			<-ctx.Done()
			svc.record("loop stopped")
		}, func() { svc.record("system proxy restored") })
	}()
	<-loopStarted
	stop.request("the app closed the standard input")
	stop.request("a second request is dropped")
	select {
	case err := <-result:
		if err != nil {
			t.Fatalf("a requested stop is a clean exit: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("runHosted did not return")
	}
	want := []string{"loop stopped", "system proxy restored", "shutdown"}
	if got := svc.recorded(); !slices.Equal(got, want) {
		t.Fatalf("order %v, want %v", got, want)
	}
}

// A service that cannot start (the dashboard address is taken) ends the
// process with its error, after the same cleanup.
func TestRunHostedReportsServiceFailure(t *testing.T) {
	failure := errors.New("starting the dashboard: address in use")
	svc := newFakeService(failure)
	err := runHosted(svc, newStopRequest().ch, func(ctx context.Context) { <-ctx.Done() }, func() { svc.record("system proxy restored") })
	if !errors.Is(err, failure) {
		t.Fatalf("got %v, want the service's error", err)
	}
	if got, want := svc.recorded(), []string{"system proxy restored", "shutdown"}; !slices.Equal(got, want) {
		t.Fatalf("order %v, want %v", got, want)
	}
}

// The app parses the first line of the standard error: "app-error: ",
// a one-word code, a space, and the detail on the rest of the line.
func TestReportAppError(t *testing.T) {
	dir := filepath.Join("C:", "Users", "A  B", "data")
	for name, tc := range map[string]struct {
		err  error
		exit int
		want []string
	}{
		"already running": {
			err:  &alreadyRunningError{dir: dir, who: "a tray icon runs for it"},
			exit: ExitAlreadyRunning,
			want: []string{
				"app-error: already_running " + dir,
				"firefox-vpn-core: " + ErrAlreadyRunning.Error() + " (" + dir + "): a tray icon runs for it",
			},
		},
		"dashboard port in use": {
			err:  fmt.Errorf("starting the dashboard: %w", &service.AddressInUseError{Listener: service.ListenerDashboard, Address: "127.0.0.1:10820", Err: errors.New("bind")}),
			exit: ExitDashboardPortInUse,
			want: []string{"app-error: dashboard_port_in_use 127.0.0.1:10820"},
		},
		"proxy port is not the dashboard's": {
			err:  &service.AddressInUseError{Listener: service.ListenerProxy, Address: "127.0.0.1:10810", Err: errors.New("bind")},
			exit: ExitStartFailed,
			want: []string{"app-error: start_failed the proxy address 127.0.0.1:10810 is already in use by another program"},
		},
		"other error on one line": {
			err:  errors.New("reading config.json:\r\nbad\nvalue"),
			exit: ExitStartFailed,
			want: []string{"app-error: start_failed reading config.json: bad value"},
		},
	} {
		var out strings.Builder
		if got := ReportAppError(&out, tc.err); got != tc.exit {
			t.Errorf("%s: exit %d, want %d", name, got, tc.exit)
		}
		if got := strings.Split(strings.TrimSuffix(out.String(), "\n"), "\n"); !slices.Equal(got, tc.want) {
			t.Errorf("%s: wrote %q, want %q", name, got, tc.want)
		}
	}
	if !errors.Is(&alreadyRunningError{dir: dir}, ErrAlreadyRunning) {
		t.Error("alreadyRunningError must match ErrAlreadyRunning")
	}
}

// The app-mode start path with its dashboard address held by another
// program ends with the dashboard_port_in_use line and exit status 4.
func TestAppDashboardPortInUse(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("USERPROFILE", home)
	taken, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer taken.Close()
	paths, err := service.ResolveDataPaths(filepath.Join(t.TempDir(), "data"))
	if err != nil {
		t.Fatal(err)
	}
	cfg := config.Default()
	cfg.Dashboard.Listen = taken.Addr().String()
	cfg.Proxy.Listen = "127.0.0.1:0"
	if err := config.Save(paths.Config, cfg); err != nil {
		t.Fatal(err)
	}
	d, err := newHostedDaemon(paths, false, func() {})
	if err != nil {
		t.Fatal(err)
	}
	d.RequireDashboard = true
	result := make(chan error, 1)
	go func() {
		result <- runHosted(d, newStopRequest().ch, func(ctx context.Context) { <-ctx.Done() }, func() {})
	}()
	select {
	case err = <-result:
	case <-time.After(10 * time.Second):
		t.Fatal("the start did not fail")
	}
	var out strings.Builder
	if exit := ReportAppError(&out, err); exit != ExitDashboardPortInUse {
		t.Fatalf("exit %d for %v", exit, err)
	}
	if want := "app-error: dashboard_port_in_use " + taken.Addr().String() + "\n"; out.String() != want {
		t.Fatalf("wrote %q, want %q", out.String(), want)
	}
}
