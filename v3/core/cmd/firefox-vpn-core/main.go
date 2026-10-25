//go:generate go run ../../tools/winres

package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/armanlife/firefox-vpn-client/core/internal/desktop"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/service"
	"github.com/armanlife/firefox-vpn-client/core/internal/version"
)

func main() {
	flag.Usage = func() {
		out := flag.CommandLine.Output()
		fmt.Fprintln(out, "Usage: firefox-vpn-core [-data-dir DIR] [-plain] [-verbose]")
		fmt.Fprintln(out, "       firefox-vpn-core -tray [-data-dir DIR]")
		fmt.Fprintln(out, "       firefox-vpn-core -app [-data-dir DIR] [-verbose]   (started by the desktop app)")
		fmt.Fprintln(out, "       firefox-vpn-core -add-account | -list-accounts | -set-dashboard-login [-data-dir DIR]")
		fmt.Fprintln(out, "       firefox-vpn-core -setup-server USERNAME [-data-dir DIR]   (install.sh, new Linux servers)")
		fmt.Fprintln(out)
		fmt.Fprintln(out, "Without a command, runs the proxy service and its web dashboard (default")
		fmt.Fprintln(out, "http://127.0.0.1:10820) with a status screen in the terminal (-plain prints the")
		fmt.Fprintln(out, "log instead). Settings live in user-data/config.json next to the executable;")
		fmt.Fprintln(out, "routing (routing.enabled, off by default) sends the sites and networks of")
		fmt.Fprintln(out, "routing.region (default ir) directly and everything else through Mozilla.")
		fmt.Fprintln(out)
		fmt.Fprintln(out, "-app runs the service for the desktop app: no tray icon or status screen, the")
		fmt.Fprintln(out, "log in the log file only. It stops on POST /api/app/exit, Ctrl+C, SIGTERM, or")
		fmt.Fprintln(out, "when its standard input (a pipe the app keeps open) ends. Exit status: 0 after")
		fmt.Fprintln(out, "a stop, 1 on an error, 2 on bad arguments, 3 when another copy already serves")
		fmt.Fprintln(out, "the data folder, 4 when another program holds the dashboard address. On a")
		fmt.Fprintln(out, "failure the first line on the standard error is \"app-error: <code> <detail>\".")
		fmt.Fprintln(out)
		flag.PrintDefaults()
	}
	dataDir := flag.String("data-dir", "", "Data folder (default: the desktop app's folder when the core sits beside firefox-vpn(.exe), else the \"user-data\" folder next to the executable)")
	addAccount := flag.Bool("add-account", false, "Sign in on the terminal and add the account, then exit")
	listAccounts := flag.Bool("list-accounts", false, "List the accounts with status and quota, then exit")
	status := flag.Bool("status", false, "Print the running service's proxy state, account, and data left in a few lines, then exit")
	setLogin := flag.Bool("set-dashboard-login", false, "Set or remove the dashboard username and password on the terminal, then exit")
	setupServer := flag.String("setup-server", "", "Open the dashboard and the proxy to the network (the dashboard login for USERNAME, \"-\" for a random one, and a random proxy login, each with a random password), print the logins, then exit (install.sh runs it on a new server)")
	tray := flag.Bool("tray", false, "Show the tray icon; runs the service in-process unless one is already running")
	app := flag.Bool("app", false, "Run the service for the desktop app (no tray icon or status screen); stops when standard input ends")
	showVersion := flag.Bool("version", false, "Print the version and exit")
	plain := flag.Bool("plain", false, "Print the log instead of the status screen")
	verbose := flag.Bool("verbose", false, "Log CONNECT destinations and debug lines regardless of the config")
	checkQUIC := flag.Bool("check-quic", false, "Try QUIC (HTTP/3) handshakes to Mozilla's proxy servers and to well-known sites, print the results, then exit; tells whether this network lets HTTP/3 through")
	flag.Parse()
	if *showVersion {
		fmt.Println(version.Current)
		return
	}
	if *checkQUIC {
		if !runQUICCheck(os.Stdout) {
			os.Exit(1)
		}
		return
	}
	if flag.NArg() > 0 {
		fmt.Fprintf(os.Stderr, "unexpected arguments: %s\n", strings.Join(flag.Args(), " "))
		flag.Usage()
		os.Exit(2)
	}

	if err := runCommand(commandOptions{
		dataDir:      *dataDir,
		addAccount:   *addAccount,
		listAccounts: *listAccounts,
		status:       *status,
		setLogin:     *setLogin,
		setupServer:  *setupServer,
		tray:         *tray,
		app:          *app,
		plain:        *plain,
		verbose:      *verbose,
	}); err != nil {
		logx.Error("%s", logx.Err(err))
		if *app {
			// The log goes to the file only in this mode; the app reads
			// the reason from the standard error.
			os.Exit(desktop.ReportAppError(os.Stderr, err))
		}
		os.Exit(1)
	}
}

// commandOptions are the parsed command-line options.
type commandOptions struct {
	dataDir      string
	addAccount   bool
	listAccounts bool
	status       bool
	setLogin     bool
	setupServer  string
	tray         bool
	app          bool
	plain        bool
	verbose      bool
}

// runCommand runs the requested one-shot command, or the service when no
// command is given.
func runCommand(opts commandOptions) error {
	commands := 0
	for _, set := range []bool{opts.addAccount, opts.listAccounts, opts.status, opts.setLogin, opts.setupServer != "", opts.tray, opts.app} {
		if set {
			commands++
		}
	}
	if commands > 1 {
		return errors.New("use only one of -add-account, -list-accounts, -status, -set-dashboard-login, -setup-server, -tray, -app")
	}
	if opts.app && opts.plain {
		return errors.New("-plain applies to the terminal; -app logs to the log file only")
	}
	paths, err := service.ResolveDataPaths(opts.dataDir)
	if err != nil {
		return err
	}
	switch {
	case opts.addAccount:
		return runAddAccount(paths)
	case opts.status:
		return runStatus(paths, os.Stdout)
	case opts.listAccounts:
		return runListAccounts(paths)
	case opts.setLogin:
		return runSetDashboardLogin(paths)
	case opts.setupServer != "":
		return runSetupServer(paths, opts.setupServer)
	case opts.app:
		// Standard output and error are pipes the app may never read; a
		// full pipe would block logging, so the log goes to the file only.
		logx.EnableFile(paths.LogDir, false)
		if desktop.StartedWithOwnConsole() {
			// Windows opened a console window for this process (a GUI
			// parent); the app is the window.
			desktop.DetachConsole()
		}
		return desktop.RunApp(paths, opts.verbose)
	case opts.tray:
		if desktop.StartedWithOwnConsole() {
			// Started from Explorer (a shortcut): the tray icon replaces
			// the console window.
			desktop.DetachConsole()
			logx.EnableFile(paths.LogDir, false)
		} else {
			logx.EnableFile(paths.LogDir, true)
		}
		return desktop.RunTray(paths, opts.verbose)
	}
	if !opts.plain {
		// An interactive terminal (including a double-click on Windows)
		// gets the status screen; anything else gets the plain log.
		if shown, err := desktop.RunConsole(paths, opts.verbose); shown {
			return err
		}
	}
	return runConsole(paths, opts.verbose)
}

// runConsole runs the service in the terminal until Ctrl+C or SIGTERM.
func runConsole(paths service.DataPaths, verbose bool) error {
	logx.EnableFile(paths.LogDir, true)
	d, err := service.NewDaemon(paths, verbose)
	if err != nil {
		return err
	}
	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(signals)
	go func() {
		if _, ok := <-signals; ok {
			logx.Info("stopping")
			d.Shutdown()
		}
	}()
	return d.Run()
}
