package service

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/controlplane"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
	"github.com/armanlife/firefox-vpn-client/core/internal/securefile"
)

// Country flags. The web folder carries the flags of Mozilla's locations
// (the ones the program shows); a flag it lacks (a location Mozilla added
// later) is downloaded once from flag-icons, the same set, and kept in the
// data folder. The dashboard and the app both ask GET /flags/xx.svg.

// flagSources are where a missing flag comes from, tried in order: the
// latest flag-icons through jsDelivr's CDN, then GitHub directly.
var flagSources = []string{
	"https://cdn.jsdelivr.net/gh/lipis/flag-icons@main/flags/4x3/%s.svg",
	"https://raw.githubusercontent.com/lipis/flag-icons/main/flags/4x3/%s.svg",
}

var flagCode = regexp.MustCompile(`^[a-z]{2}$`)

const (
	// maxFlagSize bounds a downloaded flag (flag-icons' largest is under
	// 100 KiB).
	maxFlagSize = 100 << 10
	// flagRetryAfter spaces the attempts for a flag that could not be
	// downloaded, so a list full of them does not ask again on every look.
	flagRetryAfter = 10 * time.Minute
	flagTimeout    = 15 * time.Second
	flagsDirName   = "flags"
)

// handleFlag serves a country's flag: built in, saved, or downloaded now.
func (s *dashboardServer) handleFlag(w http.ResponseWriter, r *http.Request) {
	code, ok := strings.CutSuffix(strings.ToLower(r.PathValue("file")), ".svg")
	if !ok || !flagCode.MatchString(code) {
		http.NotFound(w, r)
		return
	}
	data, err := s.d.flag(code)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "image/svg+xml")
	_, _ = w.Write(data)
}

// flag returns the SVG of a country's flag by its two-letter code.
func (d *Daemon) flag(code string) ([]byte, error) {
	if data, err := fs.ReadFile(webFiles, "web/flags/"+code+".svg"); err == nil {
		return data, nil
	}
	saved := filepath.Join(d.paths.Dir, flagsDirName, code+".svg")
	if data, err := os.ReadFile(saved); err == nil {
		return data, nil
	}

	d.flags.mu.Lock()
	defer d.flags.mu.Unlock()
	// Another request may have fetched it while this one waited.
	if data, err := os.ReadFile(saved); err == nil {
		return data, nil
	}
	if failed, ok := d.flags.failed[code]; ok && time.Since(failed) < flagRetryAfter {
		return nil, errors.New("flag download failed recently")
	}
	data, err := d.downloadFlag(code)
	if err != nil {
		if d.flags.failed == nil {
			d.flags.failed = make(map[string]time.Time)
		}
		d.flags.failed[code] = time.Now()
		logx.Debug("downloading a flag failed code=%s err=%s", code, logx.Err(err))
		return nil, err
	}
	if err := securefile.EnsurePrivateDir(filepath.Dir(saved)); err == nil {
		if err := securefile.WritePrivate(saved, data); err != nil {
			logx.Debug("saving a flag failed code=%s err=%s", code, logx.Err(err))
		}
	}
	logx.Info("downloaded the flag of %s", strings.ToUpper(code))
	return data, nil
}

// downloadFlag fetches a flag through Mozilla's proxy when it is awake (the
// flag hosts may be filtered), else the way the program's own requests go.
func (d *Daemon) downloadFlag(code string) ([]byte, error) {
	var clients []*http.Client
	if engine := d.currentEngine(); engine != nil {
		if controller := engine.currentController(); controller != nil {
			clients = append(clients, controller.HTTPClient(flagTimeout))
		}
	}
	clients = append(clients, &http.Client{Transport: controlplane.Transport(), Timeout: flagTimeout})
	var errs []error
	for _, client := range clients {
		for _, source := range flagSources {
			data, err := fetchFlag(client, fmt.Sprintf(source, code))
			if err == nil {
				return data, nil
			}
			errs = append(errs, err)
		}
	}
	return nil, errors.Join(errs...)
}

func fetchFlag(client *http.Client, url string) ([]byte, error) {
	resp, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d from %s", resp.StatusCode, url)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, maxFlagSize+1))
	if err != nil {
		return nil, err
	}
	if len(data) > maxFlagSize {
		return nil, fmt.Errorf("%s is larger than %d KiB", url, maxFlagSize>>10)
	}
	head := data[:min(len(data), 512)]
	if !bytes.Contains(head, []byte("<svg")) {
		return nil, fmt.Errorf("%s is not an SVG image", url)
	}
	return data, nil
}
