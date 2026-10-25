package main

import (
	"strings"
	"testing"
)

// -app is a run mode of its own: it cannot be combined with another mode
// or command, nor with -plain. The check runs before the data folder is
// touched.
func TestAppModeIsExclusive(t *testing.T) {
	for name, opts := range map[string]commandOptions{
		"tray":   {app: true, tray: true},
		"status": {app: true, status: true},
		"list":   {app: true, listAccounts: true},
	} {
		err := runCommand(opts)
		if err == nil || !strings.Contains(err.Error(), "-app") {
			t.Errorf("%s: got %v, want the exclusive-mode error", name, err)
		}
	}
	if err := runCommand(commandOptions{app: true, plain: true}); err == nil || !strings.Contains(err.Error(), "-plain") {
		t.Errorf("-app -plain: got %v", err)
	}
}
