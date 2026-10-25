package mobile

import (
	_ "embed"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// extraRoots are root CAs the upstream servers chain to (GlobalSign Root
// R46 and E46) that older Android system stores lack. Taken from the
// Windows root store; their SHA-1 fingerprints match Android's own copies.
//
//go:embed extra-roots.pem
var extraRoots []byte

const (
	// Android's updatable store (Android 10+), which Android itself uses
	// in place of the system one when present. Go reads only the latter.
	apexCerts   = "/apex/com.android.conscrypt/cacerts"
	systemCerts = "/system/etc/security/cacerts"
	userCerts   = "/data/misc/keychain/certs-added"
)

// useAndroidRoots points Go's certificate verification at the roots Android
// trusts plus extraRoots, through SSL_CERT_DIR and SSL_CERT_FILE. Go reads
// them once, at the first verification, so this runs before the daemon.
func useAndroidRoots(dataDir string) error {
	if runtime.GOOS != "android" {
		return nil
	}
	if err := os.MkdirAll(dataDir, 0o700); err != nil {
		return err
	}
	file := filepath.Join(dataDir, "extra-roots.pem")
	if err := os.WriteFile(file, extraRoots, 0o600); err != nil {
		return err
	}
	_, err := os.Stat(apexCerts)
	if err := os.Setenv("SSL_CERT_DIR", certDirs(err == nil)); err != nil {
		return err
	}
	return os.Setenv("SSL_CERT_FILE", file)
}

// certDirs lists the directories Android trusts, as SSL_CERT_DIR wants
// them: the updatable store when it exists, else the system one, and the
// roots the user added.
func certDirs(apex bool) string {
	store := systemCerts
	if apex {
		store = apexCerts
	}
	return strings.Join([]string{store, userCerts}, ":")
}
