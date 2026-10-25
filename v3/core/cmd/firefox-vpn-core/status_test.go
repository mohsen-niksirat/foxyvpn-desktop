package main

import (
	"strings"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/accounts"
	"github.com/armanlife/firefox-vpn-client/core/internal/service"
)

func TestStatusLines(t *testing.T) {
	now := time.Date(2026, 10, 19, 12, 0, 0, 0, time.UTC)
	text := func(st service.TrayStatus) string {
		var b strings.Builder
		for _, l := range statusLines(st, now) {
			b.WriteString(l[0] + ": " + l[1] + "\n")
		}
		return b.String()
	}

	var st service.TrayStatus
	st.State.Phase = service.PhaseRunning
	st.Proxy = &service.TrayProxy{CountryName: "Belgium", CityName: "Brussels"}
	st.ActiveAccount = &service.AccountView{Email: "hamid@yahoo.com", Usage: &accounts.Usage{
		LimitBytes: 50 << 30, RemainingBytes: 36 << 30, ResetAt: time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC),
	}}
	got := text(st)
	for _, want := range []string{"Proxy: connected     Belgium · Brussels", "Account: ha****@yahoo.com", "Data left: 36.0 GB of 50.0 GB   resets Nov 1"} {
		if !strings.Contains(got, want) {
			t.Errorf("missing %q in:\n%s", want, got)
		}
	}

	st.Proxy.SleepingSince = now
	if got := text(st); !strings.Contains(got, "Proxy: asleep") {
		t.Errorf("a sleeping proxy:\n%s", got)
	}

	var none service.TrayStatus
	none.State.Phase = "waiting"
	none.State.Message = "Add an account in the dashboard to start the proxy"
	none.Accounts = map[string]int{"total": 0}
	got = text(none)
	if !strings.Contains(got, "Proxy: waiting       Add an account") || !strings.Contains(got, "Account: none yet: firefox-vpn add-account") {
		t.Errorf("no account:\n%s", got)
	}
}
