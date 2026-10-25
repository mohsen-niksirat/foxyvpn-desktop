package service

import (
	"strings"
	"testing"

	"github.com/armanlife/firefox-vpn-client/core/internal/accounts"
	"github.com/armanlife/firefox-vpn-client/core/internal/config"
)

func TestReconcileAccountOrder(t *testing.T) {
	t.Parallel()

	cfg := config.Default()
	cfg.Accounts.Order = []config.AccountRef{{ID: "b", Enabled: true}, {ID: "gone", Enabled: true}, {ID: "a", Enabled: false}}
	list := []accounts.Account{{ID: "a"}, {ID: "b"}, {ID: "c"}}

	enabled, changed := ReconcileAccountOrder(&cfg, list)
	if !changed || strings.Join(enabled, ",") != "b,c" {
		t.Fatalf("expected enabled order b,c with a change, got %v %v", enabled, changed)
	}
	var ids []string
	for _, ref := range cfg.Accounts.Order {
		ids = append(ids, ref.ID)
	}
	if strings.Join(ids, ",") != "b,a,c" {
		t.Fatalf("expected order b,a,c, got %v", ids)
	}
}
