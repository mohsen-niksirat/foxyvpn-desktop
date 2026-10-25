package service

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/armanlife/firefox-vpn-client/core/internal/accounts"
	"github.com/armanlife/firefox-vpn-client/core/internal/config"
	"github.com/armanlife/firefox-vpn-client/core/internal/logx"
)

// Files the service keeps in its data folder.
const (
	statusFileName    = "status.json"
	selectionFileName = "selection.json"
	stateFileName     = "state.json"
	localTokenName    = "local-api.token"
	logsDirName       = "logs"
	routingDirName    = "routing"
	sessionKeyName    = "dashboard.key"
	serverListName    = "servers.json"
)

type DataPaths struct {
	Dir        string
	Config     string
	Status     string
	Selection  string
	State      string
	LocalToken string
	// LogDir holds the daily log files (see logx.DayFile).
	LogDir string
	// RoutingDir holds the routing lists (geosite.dat, geoip.dat).
	RoutingDir string
	// SessionKey signs the dashboard's session cookies.
	SessionKey string
	// ServerList keeps the last server list fetched from Mozilla, for
	// when the next fetch fails and to show the locations at once.
	ServerList string
}

// ResolveDataPaths returns the data folder (next to the executable unless
// overridden) and the files inside it, and checks that it is writable.
func ResolveDataPaths(override string) (DataPaths, error) {
	dir := strings.TrimSpace(override)
	if dir == "" {
		var err error
		if dir, err = config.DefaultDataDir(); err != nil {
			return DataPaths{}, err
		}
	}
	dir, err := filepath.Abs(dir)
	if err != nil {
		return DataPaths{}, err
	}
	if err := config.CheckWritable(dir); err != nil {
		return DataPaths{}, err
	}
	return DataPaths{
		Dir:        dir,
		Config:     filepath.Join(dir, config.FileName),
		Status:     filepath.Join(dir, statusFileName),
		Selection:  filepath.Join(dir, selectionFileName),
		State:      filepath.Join(dir, stateFileName),
		LocalToken: filepath.Join(dir, localTokenName),
		LogDir:     filepath.Join(dir, logsDirName),
		RoutingDir: filepath.Join(dir, routingDirName),
		SessionKey: filepath.Join(dir, sessionKeyName),
		ServerList: filepath.Join(dir, serverListName),
	}, nil
}

// LoadConfig loads (or creates) the config and applies its process
// wide settings: log detail, DNS, and the API proxy.
func LoadConfig(paths DataPaths, forceVerbose bool) (config.Config, error) {
	config.Warn = func(message string) { logx.Warn("%s", message) }
	accounts.Warn = func(message string) { logx.Warn("%s", message) }
	cfg, created, err := config.Load(paths.Config)
	if err != nil {
		return config.Config{}, err
	}
	if created {
		logx.Info("created default config path=%s", paths.Config)
	}
	logx.Verbose.Store(cfg.Logging.Verbose || forceVerbose)
	if err := configureDNS(cfg.DNS); err != nil {
		return config.Config{}, fmt.Errorf("invalid dns.servers: %w", err)
	}
	if err := configureAPIRelay(cfg.Network.APIRelay); err != nil {
		return config.Config{}, fmt.Errorf("invalid network.api_relay: %w", err)
	}
	return cfg, nil
}

// OpenAccounts opens the account store and reconciles the configured
// priority order with the stored accounts. It returns the enabled account
// ids in order.
func OpenAccounts(paths DataPaths, cfg *config.Config) (*accounts.Store, []string, error) {
	store, err := accounts.OpenStore(paths.Dir)
	if err != nil {
		return nil, nil, err
	}
	list, err := store.List()
	if err != nil {
		return nil, nil, err
	}
	enabled, changed := ReconcileAccountOrder(cfg, list)
	if changed {
		if err := config.Save(paths.Config, *cfg); err != nil {
			return nil, nil, fmt.Errorf("saving account order: %w", err)
		}
	}
	return store, enabled, nil
}

// ReconcileAccountOrder keeps configured entries whose account exists,
// appends stored accounts missing from the order, and returns the enabled
// ids in priority order.
func ReconcileAccountOrder(cfg *config.Config, list []accounts.Account) (enabled []string, changed bool) {
	stored := make(map[string]bool, len(list))
	for _, acc := range list {
		stored[acc.ID] = true
	}
	order := make([]config.AccountRef, 0, len(list))
	listed := make(map[string]bool, len(cfg.Accounts.Order))
	for _, ref := range cfg.Accounts.Order {
		if !stored[ref.ID] {
			logx.Warn("config lists an unknown account; removing it from the order id=%s", ref.ID)
			changed = true
			continue
		}
		listed[ref.ID] = true
		order = append(order, ref)
	}
	for _, acc := range list {
		if !listed[acc.ID] {
			order = append(order, config.AccountRef{ID: acc.ID, Enabled: true})
			changed = true
		}
	}
	cfg.Accounts.Order = order
	for _, ref := range order {
		if ref.Enabled {
			enabled = append(enabled, ref.ID)
		}
	}
	return enabled, changed
}

// removeFile deletes path, ignoring a missing file.
func removeFile(path string) error {
	if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}
