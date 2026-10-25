package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"golang.org/x/term"

	"github.com/armanlife/firefox-vpn-client/core/internal/accounts"
	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/fxa"
	"github.com/armanlife/firefox-vpn-client/core/internal/guardian"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/proxy"
	"github.com/armanlife/firefox-vpn-client/core/internal/service"
)

// runAddAccount signs in interactively and stores the account at the end
// of the priority order.
func runAddAccount(paths service.DataPaths) error {
	// A one-shot command: its own lines only, not the service's log.
	logx.SetOutput(io.Discard)
	cfg, err := service.LoadConfig(paths, false)
	if err != nil {
		return err
	}
	store, _, err := service.OpenAccounts(paths, &cfg)
	if err != nil {
		return err
	}

	token, email, password := interactiveSignIn()
	now := time.Now()
	acc, created, err := store.Add(email, &fxa.SavedTokens{
		AccessToken:  token.AccessToken,
		RefreshToken: token.RefreshToken,
		Scope:        token.Scope,
		ObtainedAt:   now,
		ExpiresIn:    token.ExpiresIn,
	}, now)
	if err != nil {
		return err
	}
	if err := store.SetPassword(acc.ID, password); err != nil {
		fmt.Println("Saving the password failed:", err)
	}
	list, err := store.List()
	if err != nil {
		return err
	}
	if _, changed := service.ReconcileAccountOrder(&cfg, list); changed {
		if err := config.Save(paths.Config, cfg); err != nil {
			return err
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), proxy.APIRequestTimeout)
	usage, usageErr := guardian.FetchProxyUsage(ctx, cfg.Network.GuardianEndpoint, token.AccessToken)
	cancel()
	if usageErr == nil && usage != nil {
		u := proxy.AccountUsage(usage)
		acc.Usage = &u
		if err := store.Save(acc); err != nil {
			logx.Warn("saving account usage failed: %s", logx.Err(err))
		}
	}

	if created {
		fmt.Printf("Account added: %s (id %s)\n", acc.Name(), acc.ID)
	} else {
		fmt.Printf("Account updated with new credentials: %s (id %s)\n", acc.Name(), acc.ID)
	}
	if acc.Usage != nil {
		fmt.Printf("Quota: %s\n", accounts.FormatUsage(acc.Usage))
	} else {
		fmt.Println("Quota: unknown until the account is first used")
	}
	return nil
}

// runListAccounts prints the stored accounts in priority order.
func runListAccounts(paths service.DataPaths) error {
	// A one-shot command: its own lines only, not the service's log.
	logx.SetOutput(io.Discard)
	cfg, err := service.LoadConfig(paths, false)
	if err != nil {
		return err
	}
	store, _, err := service.OpenAccounts(paths, &cfg)
	if err != nil {
		return err
	}
	var all []string
	enabled := make(map[string]bool)
	for _, ref := range cfg.Accounts.Order {
		all = append(all, ref.ID)
		enabled[ref.ID] = ref.Enabled
	}
	mgr, err := accounts.NewManager(store, all, accounts.Policy{ThresholdPercent: cfg.Accounts.SwitchThresholdPercent}, paths.State)
	if err != nil {
		return err
	}
	active, _ := mgr.Active()
	writeAccountList(os.Stdout, newPaint(os.Stdout), mgr.Accounts(), active.ID, enabled, cfg.Accounts.SwitchThresholdPercent, time.Now())
	return nil
}

// writeAccountList prints the accounts in order, one line each: the one in
// use marked, its state, and its data.
func writeAccountList(out io.Writer, p paint, list []accounts.Account, activeID string, enabled map[string]bool, threshold float64, now time.Time) {
	const rule = "────────────────────────────────────────────────────────────────"
	fmt.Fprintf(out, "\n  %s\n  %s\n", p.bold("Firefox VPN accounts"), p.dim(rule))
	if len(list) == 0 {
		fmt.Fprintf(out, "    No accounts yet. Add one: %s\n\n", p.cyan("firefox-vpn add-account"))
		return
	}
	width := 0
	for _, acc := range list {
		width = max(width, len(acc.Name()))
	}
	for i, acc := range list {
		mark := " "
		if acc.ID == activeID {
			mark = p.green("●")
		}
		state, color := accountState(acc, enabled[acc.ID], p)
		fmt.Fprintf(out, "  %2d  %s %-*s  %s  %s\n", i+1, mark, width, acc.Name(), color(fmt.Sprintf("%-14s", state)), accountData(acc, now))
	}
	fmt.Fprintf(out, "  %s\n  %s in use %s the next account takes over at %g%% of its data\n\n",
		p.dim(rule), p.green("●"), p.dim("·"), threshold)
}

// accountState is an account's state in a word or two, and its color.
func accountState(acc accounts.Account, enabled bool, p paint) (string, func(string) string) {
	if !enabled {
		return "disabled", p.dim
	}
	switch acc.Status {
	case accounts.StatusReady:
		return "ready", p.green
	case accounts.StatusReserved:
		return "used up", p.yellow
	case accounts.StatusReauthRequired:
		return "sign in again", p.red
	default:
		return string(acc.Status), p.yellow
	}
}

// accountData is an account's data used and when it resets, or why it
// waits.
func accountData(acc accounts.Account, now time.Time) string {
	var parts []string
	if u := acc.Usage; u != nil {
		switch {
		case u.Unlimited:
			parts = append(parts, "unlimited")
		case u.LimitBytes > 0:
			parts = append(parts, fmt.Sprintf("%s of %s used", statusBytes(u.UsedBytes()), statusBytes(u.LimitBytes)))
		}
		if !u.ResetAt.IsZero() && u.ResetAt.After(now) {
			parts = append(parts, "resets "+u.ResetAt.Local().Format("Jan 2"))
		}
	}
	if acc.Status != accounts.StatusReady && acc.Reason != "" {
		parts = append(parts, acc.Reason)
	}
	return strings.Join(parts, "   ")
}

// paint colors text on a terminal (unless NO_COLOR is set).
type paint struct{ on bool }

func newPaint(f *os.File) paint {
	return paint{on: os.Getenv("NO_COLOR") == "" && term.IsTerminal(int(f.Fd()))}
}

func (p paint) wrap(code, s string) string {
	if !p.on {
		return s
	}
	return "\x1b[" + code + "m" + s + "\x1b[0m"
}

func (p paint) bold(s string) string   { return p.wrap("1", s) }
func (p paint) dim(s string) string    { return p.wrap("2", s) }
func (p paint) green(s string) string  { return p.wrap("32", s) }
func (p paint) cyan(s string) string   { return p.wrap("36", s) }
func (p paint) yellow(s string) string { return p.wrap("33", s) }
func (p paint) red(s string) string    { return p.wrap("31", s) }

// runSetDashboardLogin sets or clears the dashboard credentials on the
// terminal, for headless servers whose dashboard is not reachable yet.
func runSetDashboardLogin(paths service.DataPaths) error {
	cfg, _, err := config.Load(paths.Config)
	if err != nil {
		return err
	}
	reader := bufio.NewReader(os.Stdin)
	fmt.Print("Dashboard username (empty disables the login): ")
	username, _ := reader.ReadString('\n')
	username = strings.TrimSpace(username)
	if username == "" {
		cfg.Dashboard.Username, cfg.Dashboard.PasswordHash = "", ""
		if err := config.Save(paths.Config, cfg); err != nil {
			return err
		}
		fmt.Println("Dashboard login disabled. Restart the service to apply.")
		return nil
	}
	password, err := readPassword("Dashboard password: ")
	if err != nil {
		return err
	}
	confirm, err := readPassword("Repeat the password: ")
	if err != nil {
		return err
	}
	if password != confirm {
		return errors.New("the passwords do not match")
	}
	hash, err := service.HashDashboardPassword(password)
	if err != nil {
		return err
	}
	cfg.Dashboard.Username, cfg.Dashboard.PasswordHash = username, hash
	if err := config.Save(paths.Config, cfg); err != nil {
		return err
	}
	fmt.Println("Dashboard login saved. Restart the service to apply.")
	return nil
}

// runSetupServer opens a new server's dashboard and proxy to the network,
// each behind a random password, and prints the logins as key=value lines
// for install.sh.
func runSetupServer(paths service.DataPaths, username string) error {
	cfg, _, err := config.Load(paths.Config)
	if err != nil {
		return err
	}
	login, err := service.SetupServer(&cfg, username)
	if err != nil {
		return err
	}
	if err := config.Save(paths.Config, cfg); err != nil {
		return err
	}
	fmt.Printf("dashboard_username=%s\ndashboard_password=%s\ndashboard_port=%s\n", login.DashboardUsername, login.DashboardPassword, login.DashboardPort)
	fmt.Printf("proxy_username=%s\nproxy_password=%s\nproxy_port=%s\n", login.ProxyUsername, login.ProxyPassword, login.ProxyPort)
	return nil
}

func readPassword(prompt string) (string, error) {
	fmt.Print(prompt)
	data, err := term.ReadPassword(int(os.Stdin.Fd()))
	fmt.Println()
	if err != nil {
		return "", fmt.Errorf("reading password: %w", err)
	}
	return string(data), nil
}

// interactiveSignIn prompts for the account email and password on the
// terminal, completes any sign-in verification, and returns the issued
// OAuth credentials with the email. It exits the process on failure.
func interactiveSignIn() (*fxa.TokenResponse, string, string) {
	email, password := promptCredentials()

	fmt.Print("Logging in... ")
	loginCtx, loginCancel := context.WithTimeout(context.Background(), proxy.APIRequestTimeout)
	loginResp, err := fxa.Login(loginCtx, email, password)
	loginCancel()
	if err != nil {
		fmt.Printf("failed: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("OK")

	if !loginResp.Verified {
		verifySessionInteractively(email, loginResp.SessionToken, loginResp.VerificationMethod)
	}

	fmt.Print("Getting OAuth token... ")
	tokenCtx, tokenCancel := context.WithTimeout(context.Background(), proxy.APIRequestTimeout)
	token, err := fxa.OAuthToken(tokenCtx, loginResp.SessionToken)
	if err == nil {
		// Not needed once the tokens exist; left alive it shows as
		// "unknown" in the account's connected services.
		if destroyErr := fxa.DestroySession(tokenCtx, loginResp.SessionToken); destroyErr != nil {
			logx.Warn("ending the sign-in session failed err=%s", logx.Err(destroyErr))
		}
	}
	tokenCancel()
	if err != nil {
		fmt.Printf("failed: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("OK")
	return token, email, password
}

// verifySessionInteractively prompts for the confirmation code FxA sent to
// the account email at login time and retries until the session is verified.
func verifySessionInteractively(email, sessionToken, verificationMethod string) {
	reader := bufio.NewReader(os.Stdin)

	if verificationMethod == "email" {
		// Server fell back to the confirmation-link flow; there is no
		// code to enter.
		fmt.Printf("This sign-in must be confirmed: a confirmation link was sent to %s.\n", email)
		fmt.Print("Open the link from the email, then press Enter here to continue: ")
		if _, err := reader.ReadString('\n'); err != nil {
			fmt.Fprintf(os.Stderr, "Reading the answer failed: %v\n", err)
			os.Exit(1)
		}
		return
	}

	fmt.Printf("This sign-in must be confirmed: a verification code was sent to %s.\n", email)
	for {
		fmt.Print("Enter the verification code from the email: ")
		line, err := reader.ReadString('\n')
		if err != nil {
			fmt.Fprintf(os.Stderr, "Reading the code failed: %v\n", err)
			os.Exit(1)
		}
		code := strings.TrimSpace(line)
		if code == "" {
			continue
		}

		ctx, cancel := context.WithTimeout(context.Background(), proxy.APIRequestTimeout)
		err = fxa.VerifySession(ctx, sessionToken, code)
		cancel()
		if err == nil {
			fmt.Println("Session verified.")
			return
		}
		fmt.Printf("Verification failed: %v\n", err)
	}
}

func promptCredentials() (string, string) {
	reader := bufio.NewReader(os.Stdin)
	p := newPaint(os.Stdout)
	fmt.Printf("\n  %s\n  %s\n", p.bold("Add a Firefox Account"), p.dim("────────────────────────────────"))
	fmt.Print("Firefox Account email: ")
	email, _ := reader.ReadString('\n')

	fmt.Print("Password: ")
	passwordBytes, err := term.ReadPassword(int(os.Stdin.Fd()))
	fmt.Println()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Reading the password failed: %v\n", err)
		os.Exit(1)
	}
	return fxa.NormalizeEmail(email), string(passwordBytes)
}

// runStatus prints the running service's state in a few aligned lines
// (firefox-vpn status adds the service's own lines above them): the proxy,
// the active account, and its data left.
func runStatus(paths service.DataPaths, out io.Writer) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	st, err := service.NewClient(paths).Status(ctx)
	if err != nil {
		fmt.Fprintf(out, "    %-11s %s\n", "Proxy", "not answering (is the service running?)")
		return nil
	}
	for _, line := range statusLines(st, time.Now()) {
		fmt.Fprintf(out, "    %-11s %s\n", line[0], line[1])
	}
	return nil
}

// statusLines is runStatus's text: label and value pairs.
func statusLines(st service.TrayStatus, now time.Time) [][2]string {
	var lines [][2]string
	proxyLine := ""
	switch st.State.Phase {
	case service.PhaseRunning:
		switch {
		case st.Proxy != nil && !st.Proxy.SleepingSince.IsZero():
			proxyLine = "asleep        connects when something uses it"
		default:
			proxyLine = "connected"
			if place := statusPlace(st); place != "" {
				proxyLine += "     " + place
			}
		}
	case service.PhaseOff:
		proxyLine = "off"
	case service.PhaseStarting:
		proxyLine = "starting"
	default:
		proxyLine = fmt.Sprintf("%-13s %s", st.State.Phase, st.State.Message)
	}
	lines = append(lines, [2]string{"Proxy", strings.TrimSpace(proxyLine)})
	if acc := st.ActiveAccount; acc != nil {
		name := acc.Email
		if name == "" {
			name = acc.Name
		}
		lines = append(lines, [2]string{"Account", logx.Email(name)})
		if u := acc.Usage; u != nil {
			switch {
			case u.Unlimited:
				lines = append(lines, [2]string{"Data left", "unlimited"})
			case u.LimitBytes > 0:
				left := fmt.Sprintf("%s of %s", statusBytes(u.RemainingBytes), statusBytes(u.LimitBytes))
				if !u.ResetAt.IsZero() && u.ResetAt.After(now) {
					left += "   resets " + u.ResetAt.Local().Format("Jan 2")
				}
				lines = append(lines, [2]string{"Data left", left})
			}
		}
	} else if st.Accounts["total"] == 0 {
		lines = append(lines, [2]string{"Account", "none yet: firefox-vpn add-account"})
	}
	return lines
}

// statusPlace names where the traffic leaves: the public IP check's
// place, else the chosen server's.
func statusPlace(st service.TrayStatus) string {
	if e := st.Exit; e != nil && (e.CountryName != "" || e.City != "") {
		return strings.Trim(strings.Join([]string{e.CountryName, e.City}, " · "), " ·")
	}
	if p := st.Proxy; p != nil && (p.CountryName != "" || p.CityName != "") {
		return strings.Trim(strings.Join([]string{p.CountryName, p.CityName}, " · "), " ·")
	}
	return ""
}

// statusBytes is n in GB, one decimal (Mozilla's 50 GB is 50 << 30).
func statusBytes(n int64) string {
	return fmt.Sprintf("%.1f GB", float64(n)/(1<<30))
}
