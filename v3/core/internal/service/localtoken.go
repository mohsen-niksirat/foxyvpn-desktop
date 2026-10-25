package service

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"net/http"
	"os"
	"strings"

	"github.com/armanlife/firefox-vpn-client/core/internal/securefile"
)

// localTokenHeader carries the local API token. Local clients that can read
// the data folder (the tray) use it instead of the dashboard login; anyone
// who can read that folder can already read the account credentials.
const localTokenHeader = "X-Local-Token"

// newLocalToken returns a fresh random local API token.
func newLocalToken() (string, error) {
	var b [32]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	return hex.EncodeToString(b[:]), nil
}

func readLocalToken(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	token := strings.TrimSpace(string(data))
	if token == "" {
		return "", errors.New("empty local API token")
	}
	return token, nil
}

// hasLocalToken reports whether r carries the daemon's local token.
func (d *Daemon) hasLocalToken(r *http.Request) bool {
	got := r.Header.Get(localTokenHeader)
	return got != "" && d.localToken != "" && subtle.ConstantTimeCompare([]byte(got), []byte(d.localToken)) == 1
}

// loadSessionKey reads the key that signs dashboard sessions, creating a
// random one the first time; replacing the file signs everyone out.
func loadSessionKey(path string) ([]byte, error) {
	if data, err := os.ReadFile(path); err == nil && len(data) == 32 {
		return data, nil
	}
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return nil, err
	}
	if err := securefile.WritePrivate(path, key); err != nil {
		return nil, err
	}
	return key, nil
}
