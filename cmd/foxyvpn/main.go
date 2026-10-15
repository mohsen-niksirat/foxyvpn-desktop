// foxyvpn-desktop — Stage 1: login, proxy pass, test tunnel.
//
// Uses the firefox-vpn-client Go library (MIT) as the protocol layer:
// FxA login (PBKDF2+HKDF authPW, HAWK), OAuth token, Fastly anti-bot
// challenge solving, Guardian proxy pass, and the HTTP/2 CONNECT tunnel.
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	vpnclient "firefox-vpn-client"
	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/socks"
	"github.com/mohsen-niksirat/foxyvpn-desktop/internal/tunnel"
)

const apiRequestTimeout = 30 * time.Second
const exitCheckURL = "https://www.cloudflare.com/cdn-cgi/trace"

func main() {
	guardian := flag.String("guardian", vpnclient.GuardianEndpointDefault, "Guardian API endpoint")
	listen := flag.String("listen", "", "If set, serve a SOCKS5 proxy on this address after connecting (e.g. 127.0.0.1:1080)")
	country := flag.String("country", "", "Preferred upstream country code (default: first available)")
	flag.Parse()

	if len(flag.Args()) != 2 {
		fmt.Fprintln(os.Stderr, "Usage: foxyvpn-desktop [flags] <email> <password>")
		fmt.Fprintln(os.Stderr, "  Flags:")
		flag.PrintDefaults()
		os.Exit(2)
	}
	email, password := flag.Args()[0], flag.Args()[1]

	ctx := context.Background()

	// --- Steps 1+2: FxA login (or cached refresh token) ---
	token := loadCachedToken()
	if token != nil {
		fmt.Println("[1/5] Using cached refresh token...")
		refreshed, err := vpnclient.FxaRefreshToken(ctx, token.RefreshToken)
		if err != nil {
			fmt.Println("      refresh failed, falling back to fresh login")
			token = nil
		} else {
			if refreshed.RefreshToken == "" {
				refreshed.RefreshToken = token.RefreshToken
			}
			token = refreshed
			saveCachedToken(token)
		}
	}
	if token == nil {
		fmt.Println("[1/5] Logging in to Firefox Account...")
		login, err := vpnclient.FxaLogin(ctx, email, password)
		if err != nil {
			fatal("login failed: %v", err)
		}
		fmt.Printf("      uid=%s verified=%v\n", login.UID, login.Verified)

		if !login.Verified {
			fmt.Print("      Session unverified. Enter the code sent to your email: ")
			reader := bufio.NewReader(os.Stdin)
			code, _ := reader.ReadString('\n')
			code = strings.TrimSpace(code)
			if err := vpnclient.FxaVerifySession(ctx, login.SessionToken, code); err != nil {
				fatal("session verification failed: %v", err)
			}
			fmt.Println("      Session verified.")
		}

		fmt.Println("[2/5] Requesting OAuth token...")
		token, err = vpnclient.FxaOAuthToken(ctx, login.SessionToken)
		if err != nil {
			fatal("oauth token failed: %v", err)
		}
		saveCachedToken(token)
	}
	fmt.Printf("      access_token obtained (expires in %ds), refresh_token present=%v\n",
		token.ExpiresIn, token.RefreshToken != "")

	// --- Step 3: Guardian proxy pass ---
	fmt.Println("[3/5] Fetching proxy pass from Guardian...")
	pass, err := fetchProxyPass(*guardian, token.AccessToken)
	if err != nil {
		// First use of the account: activate the Guardian entitlement
		// (same retry flow as FoxyVpnService.kt).
		fmt.Println("      token rejected, activating Guardian entitlement...")
		if actErr := activateGuardian(*guardian, token.AccessToken); actErr != nil {
			fatal("activate failed: %v", actErr)
		}
		pass, err = fetchProxyPass(*guardian, token.AccessToken)
		if err != nil {
			fatal("proxy pass failed after activation: %v", err)
		}
	}
	fmt.Printf("      proxy pass expires=%s quota: max=%s left=%s reset=%s\n",
		pass.ExpiresAt().Format(time.RFC3339), pass.QuotaMax, pass.QuotaLeft, pass.QuotaReset)

	// --- Step 4: server list + upstream session ---
	fmt.Println("[4/5] Fetching server list and establishing HTTP/2 upstream session...")
	countries, err := vpnclient.FetchServerList(ctx)
	if err != nil {
		fatal("server list failed: %v", err)
	}
	proxyAddr := pickProxy(countries, *country)
	fmt.Printf("      upstream: %s\n", proxyAddr)
	proxyURL, err := url.Parse("https://" + proxyAddr)
	if err != nil {
		fatal("invalid proxy URL %q: %v", proxyAddr, err)
	}

	session, err := tunnel.NewH2Session(proxyURL, pass.BearerToken(), 20*time.Second)
	if err != nil {
		fatal("upstream session failed: %v", err)
	}
	defer session.Close()
	fmt.Println("      HTTP/2 session established (ALPN h2).")

	// --- Step 5: test tunnel + exit IP probe ---
	fmt.Println("[5/5] Probing exit IP through the tunnel...")
	ip, cc, latency, err := probeExit(session, exitCheckURL, 20*time.Second)
	if err != nil {
		fatal("exit probe failed: %v", err)
	}
	fmt.Printf("      exit IP=%s country=%s latency=%s\n", ip, cc, latency.Round(time.Millisecond))
	fmt.Println("OK — stage 1 complete.")

	// --- Optional: local SOCKS5 ---
	if *listen != "" {
		fmt.Printf("Starting SOCKS5 proxy on %s (Ctrl+C to stop)...\n", *listen)
		ln, err := net.Listen("tcp", *listen)
		if err != nil {
			fatal("listen failed: %v", err)
		}
		for {
			conn, err := ln.Accept()
			if err != nil {
				continue
			}
			go socks.HandleConn(conn, session)
		}
	}
}

// Token cache: stage 1 keeps the refresh token in a 0600 file so repeated
// runs avoid the FxA login rate limit. Stage 2 moves this to the
// Windows Credential Manager.
const tokenCachePath = ".foxyvpn-desktop-token.json"

func tokenCacheFile() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return tokenCachePath
	}
	return filepath.Join(home, tokenCachePath)
}

type cachedToken struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresIn    int       `json:"expires_in"`
	Scope        string    `json:"scope"`
	TokenType    string    `json:"token_type"`
	ObtainedAt   time.Time `json:"obtained_at"`
}

func loadCachedToken() *vpnclient.TokenResponse {
	data, err := os.ReadFile(tokenCacheFile())
	if err != nil {
		return nil
	}
	var ct cachedToken
	if json.Unmarshal(data, &ct) != nil || ct.RefreshToken == "" {
		return nil
	}
	return &vpnclient.TokenResponse{
		AccessToken: ct.AccessToken, RefreshToken: ct.RefreshToken,
		ExpiresIn: ct.ExpiresIn, Scope: ct.Scope, TokenType: ct.TokenType,
	}
}

func saveCachedToken(t *vpnclient.TokenResponse) {
	data, _ := json.Marshal(cachedToken{
		AccessToken: t.AccessToken, RefreshToken: t.RefreshToken,
		ExpiresIn: t.ExpiresIn, Scope: t.Scope, TokenType: t.TokenType,
		ObtainedAt: time.Now(),
	})
	_ = os.WriteFile(tokenCacheFile(), data, 0o600)
}

func fatal(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
	os.Exit(1)
}

func fetchProxyPass(guardian, accessToken string) (*vpnclient.ProxyPassInfo, error) {
	ctx, cancel := context.WithTimeout(context.Background(), apiRequestTimeout)
	defer cancel()
	return vpnclient.FetchProxyPass(ctx, guardian, accessToken)
}

func activateGuardian(guardian, accessToken string) error {
	req, err := http.NewRequest(http.MethodPost,
		strings.TrimRight(guardian, "/")+"/api/v1/fpn/activate", nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+accessToken)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "MozillaVPN/2.35.0 (sys:linux; iap:true)")
	req.Header.Set("Accept", "application/json")
	client := &http.Client{Timeout: apiRequestTimeout}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 2048))
	if resp.StatusCode != 200 {
		return fmt.Errorf("activate returned HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	fmt.Printf("      activated: %s\n", strings.TrimSpace(string(body)))
	return nil
}

func pickProxy(countries []vpnclient.Country, code string) string {
	for _, c := range countries {
		if code != "" && !strings.EqualFold(c.Code, code) {
			continue
		}
		for _, city := range c.Cities {
			for _, srv := range city.Servers {
				if srv.Quarantined {
					continue
				}
				return fmt.Sprintf("%s:%d", srv.Hostname, srv.Port)
			}
		}
	}
	return ""
}

// probeExit performs an HTTPS GET through the tunnel and parses the
// Cloudflare trace response for ip= and loc=.
func probeExit(session *tunnel.H2Session, rawURL string, timeout time.Duration) (ip, cc string, latency time.Duration, err error) {
	transport := &http.Transport{
		Proxy:               nil,
		DisableKeepAlives:   true,
		TLSHandshakeTimeout: timeout,
		DialContext: func(ctx context.Context, _, authority string) (net.Conn, error) {
			return session.OpenTunnel(authority)
		},
	}
	defer transport.CloseIdleConnections()
	client := &http.Client{Transport: transport, Timeout: timeout}

	started := time.Now()
	resp, err := client.Get(rawURL)
	if err != nil {
		return "", "", 0, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return "", "", 0, fmt.Errorf("probe returned HTTP %d", resp.StatusCode)
	}
	buf := make([]byte, 8192)
	n, _ := resp.Body.Read(buf)
	fields := map[string]string{}
	for _, line := range strings.Split(string(buf[:n]), "\n") {
		if k, v, ok := strings.Cut(strings.TrimSpace(line), "="); ok {
			fields[k] = v
		}
	}
	ip, cc = fields["ip"], fields["loc"]
	if ip == "" || cc == "" {
		return "", "", 0, fmt.Errorf("probe response missing ip/loc: %q", string(buf[:n]))
	}
	return ip, cc, time.Since(started), nil
}
