// Settings persistence for ports (tiny JSON file next to the binary's user dir).
package ui

import (
	"encoding/json"
	"os"
	"path/filepath"
)

const settingsFile = ".foxyvpn-desktop-settings.json"

type settings struct {
	SocksPort   int    `json:"socks_port"`
	HTTPPort    int    `json:"http_port"`
	LastCountry string `json:"last_country,omitempty"`
}

func settingsPath() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return settingsFile
	}
	return filepath.Join(home, settingsFile)
}

func defaultSettings() settings { return settings{SocksPort: 1080, HTTPPort: 8888} }

func loadSettings() settings {
	var s settings
	data, err := os.ReadFile(settingsPath())
	if err != nil || json.Unmarshal(data, &s) != nil {
		return defaultSettings()
	}
	if s.SocksPort == 0 {
		s.SocksPort = 1080
	}
	if s.HTTPPort == 0 {
		s.HTTPPort = 8888
	}
	return s
}

func saveSettings(socks, httpPort int) {
	s := loadSettings()
	s.SocksPort, s.HTTPPort = socks, httpPort
	data, _ := json.Marshal(s)
	_ = os.WriteFile(settingsPath(), data, 0o600)
}

func SaveLastCountry(code string) {
	s := loadSettings()
	s.LastCountry = code
	data, _ := json.Marshal(s)
	_ = os.WriteFile(settingsPath(), data, 0o600)
}

func LoadLastCountry() string { return loadSettings().LastCountry }
