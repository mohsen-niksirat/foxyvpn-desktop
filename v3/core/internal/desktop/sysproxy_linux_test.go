//go:build linux

package desktop

import (
	"errors"
	"path/filepath"
	"testing"
)

// fakeGSettings replaces gsettings and the backup file for a test, starting
// from the user's own manual proxy.
func fakeGSettings(t *testing.T) map[string]string {
	t.Helper()
	store := map[string]string{
		proxySchema + " mode":           "'manual'",
		proxySchema + " autoconfig-url": "''",
		proxySchema + " ignore-hosts":   "['localhost']",
		proxySchema + ".http host":      "'proxy.example'",
		proxySchema + ".http port":      "3128",
		proxySchema + ".https host":     "'proxy.example'",
		proxySchema + ".https port":     "3128",
		proxySchema + ".socks host":     "''",
		proxySchema + ".socks port":     "0",
	}
	oldG, oldB := gsettings, backupPath
	gsettings = func(args ...string) (string, error) {
		k := args[1] + " " + args[2]
		switch args[0] {
		case "get":
			v, ok := store[k]
			if !ok {
				return "", errors.New("no such key")
			}
			return v, nil
		case "set":
			store[k] = args[3]
			return "", nil
		}
		return "", errors.New("unexpected command")
	}
	backup := filepath.Join(t.TempDir(), "previous-proxy.json")
	backupPath = func() (string, error) { return backup, nil }
	t.Cleanup(func() { gsettings, backupPath = oldG, oldB })
	return store
}

func TestSystemProxySetAndRestore(t *testing.T) {
	store := fakeGSettings(t)
	if err := setSystemProxy("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	for _, kind := range []string{"http", "https", "socks"} {
		if store[proxySchema+"."+kind+" host"] != "'127.0.0.1'" || store[proxySchema+"."+kind+" port"] != "10810" {
			t.Fatalf("%s proxy = %s:%s", kind, store[proxySchema+"."+kind+" host"], store[proxySchema+"."+kind+" port"])
		}
	}
	if store[proxySchema+" mode"] != "'manual'" {
		t.Fatalf("mode = %s", store[proxySchema+" mode"])
	}
	// Setting it again keeps the user's setting as the one to restore.
	if err := setSystemProxy("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	if err := restoreSystemProxy("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	if store[proxySchema+".http host"] != "'proxy.example'" || store[proxySchema+".http port"] != "3128" || store[proxySchema+" ignore-hosts"] != "['localhost']" {
		t.Fatalf("the user's proxy did not come back: %v", store)
	}
}

func TestSystemProxyRestoreLeavesTheUsersChoice(t *testing.T) {
	store := fakeGSettings(t)
	if err := setSystemProxy("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	store[proxySchema+".http host"] = "'other.example'"
	if err := restoreSystemProxy("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	if store[proxySchema+".http host"] != "'other.example'" {
		t.Fatalf("a proxy set meanwhile was replaced: %s", store[proxySchema+".http host"])
	}
}

func TestSystemProxyRestoreWithoutBackupTurnsItOff(t *testing.T) {
	store := fakeGSettings(t)
	if err := setSystemProxy("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	deleteBackup()
	if err := restoreSystemProxy("127.0.0.1:10810"); err != nil {
		t.Fatal(err)
	}
	if store[proxySchema+" mode"] != "'none'" {
		t.Fatalf("mode = %s", store[proxySchema+" mode"])
	}
}

func TestSystemProxyClear(t *testing.T) {
	store := fakeGSettings(t)
	if err := clearSystemProxy(); err != nil {
		t.Fatal(err)
	}
	if store[proxySchema+" mode"] != "'none'" {
		t.Fatalf("mode = %s", store[proxySchema+" mode"])
	}
}
