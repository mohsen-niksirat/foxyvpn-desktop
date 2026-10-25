package accounts

import (
	"errors"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"github.com/armanlife/firefox-vpn-client/core/internal/fxa"
)

const gib = int64(1) << 30

func creds(refresh string) *fxa.SavedTokens {
	return &fxa.SavedTokens{AccessToken: "access-" + refresh, RefreshToken: refresh, ObtainedAt: time.Now(), ExpiresIn: 3600}
}

func newTestManager(t *testing.T, emails ...string) (*Manager, []Account) {
	t.Helper()
	dir := t.TempDir()
	store, err := OpenStore(dir)
	if err != nil {
		t.Fatal(err)
	}
	var added []Account
	var order []string
	for i, email := range emails {
		acc, created, err := store.Add(email, creds(email), time.Now().Add(time.Duration(i)*time.Second))
		if err != nil || !created {
			t.Fatalf("adding %s: created=%v err=%v", email, created, err)
		}
		added = append(added, acc)
		order = append(order, acc.ID)
	}
	mgr, err := NewManager(store, order, Policy{ThresholdPercent: 90}, filepath.Join(dir, "state.json"))
	if err != nil {
		t.Fatal(err)
	}
	return mgr, added
}

func usage(usedGiB int64, reset time.Time) Usage {
	return Usage{LimitBytes: 50 * gib, RemainingBytes: (50 - usedGiB) * gib, ResetAt: reset}
}

func TestPolicyThresholdReached(t *testing.T) {
	p := Policy{ThresholdPercent: 90}
	for name, tc := range map[string]struct {
		u    *Usage
		want bool
	}{
		"44 of 50":  {&Usage{LimitBytes: 50 * gib, RemainingBytes: 6 * gib}, false},
		"45 of 50":  {&Usage{LimitBytes: 50 * gib, RemainingBytes: 5 * gib}, true},
		"unlimited": {&Usage{Unlimited: true}, false},
		"unknown":   {nil, false},
	} {
		if got := p.ThresholdReached(tc.u); got != tc.want {
			t.Errorf("%s: got %v, want %v", name, got, tc.want)
		}
	}
}

func TestStoreAddDeduplicatesByEmailAndKeepsCredentialsPrivate(t *testing.T) {
	store, err := OpenStore(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	first, created, err := store.Add("User@Example.com", creds("one"), time.Now())
	if err != nil || !created {
		t.Fatal(err)
	}
	if err := store.Save(Account{ID: first.ID, Email: first.Email, AddedAt: first.AddedAt, Status: StatusReauthRequired, Reason: "revoked"}); err != nil {
		t.Fatal(err)
	}
	again, created, err := store.Add("user@example.com", creds("two"), time.Now())
	if err != nil || created || again.ID != first.ID || again.Status != StatusReady {
		t.Fatalf("expected the existing account to be updated and ready, got %+v created=%v err=%v", again, created, err)
	}
	stored, err := store.Credentials(first.ID)
	if err != nil || stored.RefreshToken != "two" {
		t.Fatalf("expected replaced credentials, got %+v %v", stored, err)
	}
	if list, _ := store.List(); len(list) != 1 {
		t.Fatalf("expected one account, got %d", len(list))
	}
	if runtime.GOOS != "windows" {
		info, err := os.Stat(filepath.Join(store.dir, first.ID, credentialsFileName))
		if err != nil || info.Mode().Perm() != 0o600 {
			t.Fatalf("expected 0600 credentials, got %v %v", info.Mode(), err)
		}
	}
	if _, err := store.Credentials("../escape"); err == nil {
		t.Fatal("expected an invalid id to be rejected")
	}
}

func TestManagerFailsOverAtThresholdInPriorityOrder(t *testing.T) {
	mgr, accs := newTestManager(t, "a@example.com", "b@example.com", "c@example.com")
	first, err := mgr.Candidate(nil)
	if err != nil || first.ID != accs[0].ID {
		t.Fatalf("expected the first account, got %+v %v", first, err)
	}
	if err := mgr.Activate(first.ID); err != nil {
		t.Fatal(err)
	}

	reached, err := mgr.ObserveUsage(accs[0].ID, usage(46, time.Now().Add(72*time.Hour)))
	if err != nil || !reached {
		t.Fatalf("expected the threshold to be reached, got %v %v", reached, err)
	}
	next, err := mgr.Candidate(nil)
	if err != nil || next.ID != accs[1].ID {
		t.Fatalf("expected the second account, got %+v %v", next, err)
	}
}

func TestManagerStaysOnActiveAccountAfterHigherPriorityReset(t *testing.T) {
	mgr, accs := newTestManager(t, "a@example.com", "b@example.com")
	clock := time.Now()
	mgr.now = func() time.Time { return clock }

	if _, err := mgr.ObserveUsage(accs[0].ID, usage(46, clock.Add(time.Hour))); err != nil {
		t.Fatal(err)
	}
	if err := mgr.Activate(accs[1].ID); err != nil {
		t.Fatal(err)
	}

	clock = clock.Add(2 * time.Hour) // the first account's quota has reset
	got, err := mgr.Candidate(nil)
	if err != nil || got.ID != accs[1].ID {
		t.Fatalf("expected to stay on the active second account, got %+v %v", got, err)
	}
	// When the active account is used up, the reset first account is next.
	if _, err := mgr.ObserveUsage(accs[1].ID, usage(47, clock.Add(24*time.Hour))); err != nil {
		t.Fatal(err)
	}
	got, err = mgr.Candidate(nil)
	if err != nil || got.ID != accs[0].ID {
		t.Fatalf("expected the reset first account, got %+v %v", got, err)
	}
}

func TestManagerReportsEarliestRetryWhenAllReserved(t *testing.T) {
	mgr, accs := newTestManager(t, "a@example.com", "b@example.com", "c@example.com")
	now := time.Now()
	early, late := now.Add(5*time.Hour), now.Add(48*time.Hour)
	// Spent, so no share is left to use as a last resort.
	if _, err := mgr.ObserveUsage(accs[0].ID, usage(50, late)); err != nil {
		t.Fatal(err)
	}
	if err := mgr.Reserve(accs[1].ID, Why{Code: ReasonQuotaExhausted, Text: "quota exhausted"}, early); err != nil {
		t.Fatal(err)
	}
	if err := mgr.MarkReauthRequired(accs[2].ID, Why{Code: ReasonSignInRequired, Text: "revoked"}); err != nil {
		t.Fatal(err)
	}

	_, err := mgr.Candidate(nil)
	var noAccount *NoUsableAccountError
	if !errors.As(err, &noAccount) || !errors.Is(err, ErrNoUsableAccount) {
		t.Fatalf("expected NoUsableAccountError, got %v", err)
	}
	if !noAccount.RetryAt.Equal(early) {
		t.Fatalf("expected earliest retry %s, got %s", early, noAccount.RetryAt)
	}
}

// The threshold switches to another account in time; with none to switch
// to, the active account goes on to the end of its quota.
func TestManagerUsesTheLastShareWithoutAnotherAccount(t *testing.T) {
	reset := time.Now().Add(48 * time.Hour)

	single, one := newTestManager(t, "a@example.com")
	if err := single.Activate(one[0].ID); err != nil {
		t.Fatal(err)
	}
	if reached, err := single.ObserveUsage(one[0].ID, usage(47, reset)); err != nil || reached {
		t.Fatalf("a single account must not stop at the threshold: reached=%v err=%v", reached, err)
	}
	if reached, _ := single.ObserveUsage(one[0].ID, usage(50, reset)); !reached {
		t.Fatal("a spent quota must hand over")
	}
	// Spent, not set aside at the threshold: no other account took over.
	if a := single.Accounts()[0]; a.ReasonCode != ReasonQuotaExhausted || !a.RetryAt.Equal(reset) {
		t.Fatalf("expected a spent quota until the reset, got %+v", a)
	}

	mgr, accs := newTestManager(t, "a@example.com", "b@example.com")
	if err := mgr.Activate(accs[0].ID); err != nil {
		t.Fatal(err)
	}
	if reached, _ := mgr.ObserveUsage(accs[0].ID, usage(46, reset)); !reached {
		t.Fatal("with another account, the threshold must hand over")
	}
	if a := mgr.Accounts()[0]; a.ReasonCode != ReasonQuotaThreshold || !a.RetryAt.Equal(reset) {
		t.Fatalf("expected a set aside at the threshold until the reset, got %+v", a)
	}
	if err := mgr.Activate(accs[1].ID); err != nil {
		t.Fatal(err)
	}
	if reached, _ := mgr.ObserveUsage(accs[1].ID, usage(50, reset)); !reached {
		t.Fatal("a spent quota must hand over")
	}
	if b := mgr.Accounts()[1]; b.ReasonCode != ReasonQuotaExhausted {
		t.Fatalf("expected b's quota to be spent, got %+v", b)
	}
	// b is spent: a's last 4 GiB are used rather than nothing.
	got, err := mgr.Candidate(nil)
	if err != nil || got.ID != accs[0].ID {
		t.Fatalf("expected the rest of a, got %+v %v", got, err)
	}
}

// An account set aside at the threshold goes back in use when no other
// account takes over after all; a spent or signed-out one never does.
func TestManagerResumesOnlyAnAccountSetAsideAtTheThreshold(t *testing.T) {
	mgr, accs := newTestManager(t, "a@example.com", "b@example.com", "c@example.com")
	reset := time.Now().Add(48 * time.Hour)
	if err := mgr.Activate(accs[0].ID); err != nil {
		t.Fatal(err)
	}
	if reached, _ := mgr.ObserveUsage(accs[0].ID, usage(46, reset)); !reached {
		t.Fatal("expected a to be set aside at the threshold")
	}
	if _, err := mgr.ObserveUsage(accs[1].ID, usage(50, reset)); err != nil {
		t.Fatal(err)
	}
	if err := mgr.MarkReauthRequired(accs[2].ID, Why{Code: ReasonSignInRequired, Text: "revoked"}); err != nil {
		t.Fatal(err)
	}

	for _, id := range []string{accs[1].ID, accs[2].ID} {
		if resumed, err := mgr.Resume(id); resumed || err != nil {
			t.Fatalf("only an account set aside at the threshold may resume, got %v %v", resumed, err)
		}
	}
	if resumed, err := mgr.Resume(accs[0].ID); !resumed || err != nil {
		t.Fatalf("expected a to resume, got %v %v", resumed, err)
	}
	if active, ok := mgr.Active(); !ok || active.ID != accs[0].ID || active.Status != StatusReady || active.ReasonCode != "" {
		t.Fatalf("expected a to be active and ready, got %+v", active)
	}
	if stored, err := mgr.store.Get(accs[0].ID); err != nil || stored.Status != StatusReady {
		t.Fatalf("expected the ready status to be saved, got %+v %v", stored, err)
	}
	if b, c := mgr.Accounts()[1], mgr.Accounts()[2]; b.ReasonCode != ReasonQuotaExhausted || c.Status != StatusReauthRequired {
		t.Fatalf("the other accounts must stay as they were, got %+v and %+v", b, c)
	}
}

func TestManagerReservesWithUnknownResetForAnHour(t *testing.T) {
	mgr, accs := newTestManager(t, "a@example.com")
	now := time.Now()
	mgr.now = func() time.Time { return now }
	if err := mgr.Reserve(accs[0].ID, Why{Code: ReasonQuotaExhausted, Text: "quota exhausted"}, now.Add(-time.Minute)); err != nil {
		t.Fatal(err)
	}
	acc := mgr.Accounts()[0]
	if acc.Status != StatusReserved || !acc.RetryAt.Equal(now.Add(unknownResetRetry)) {
		t.Fatalf("expected a one-hour reservation, got %+v", acc)
	}
}

func TestManagerPersistsActiveAccount(t *testing.T) {
	dir := t.TempDir()
	store, err := OpenStore(dir)
	if err != nil {
		t.Fatal(err)
	}
	a, _, _ := store.Add("a@example.com", creds("a"), time.Now())
	b, _, _ := store.Add("b@example.com", creds("b"), time.Now().Add(time.Second))
	statePath := filepath.Join(dir, "state.json")
	mgr, err := NewManager(store, []string{a.ID, b.ID}, Policy{ThresholdPercent: 90}, statePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := mgr.Activate(b.ID); err != nil {
		t.Fatal(err)
	}

	reloaded, err := NewManager(store, []string{a.ID, b.ID}, Policy{ThresholdPercent: 90}, statePath)
	if err != nil {
		t.Fatal(err)
	}
	if got, err := reloaded.Candidate(nil); err != nil || got.ID != b.ID {
		t.Fatalf("expected the persisted active account, got %+v %v", got, err)
	}
}
