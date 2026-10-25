package mobile

import (
	"path/filepath"
	"testing"

	"github.com/armanlife/firefox-vpn-client/core/internal/config"
)

// The phone's proxy never sleeps: the setting is turned off on start,
// whatever the config said.
func TestPhoneNeverSleeps(t *testing.T) {
	path := filepath.Join(t.TempDir(), config.FileName)
	cfg := config.Default()
	if cfg.Proxy.IdleSleep == 0 {
		t.Fatal("the default sleeps; the phone turns it off")
	}
	if err := config.Save(path, cfg); err != nil {
		t.Fatal(err)
	}
	if err := neverSleep(path); err != nil {
		t.Fatal(err)
	}
	loaded, _, err := config.Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if loaded.Proxy.IdleSleep != 0 {
		t.Fatalf("idle_sleep %v", loaded.Proxy.IdleSleep)
	}
}
