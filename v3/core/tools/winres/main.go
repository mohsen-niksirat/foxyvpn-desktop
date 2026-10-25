// Command winres writes the Windows resources of the executable (its icon,
// version information, and application manifest) as .syso objects that go
// build links into ./cmd/firefox-vpn-core. scripts/build-windows.ps1 runs
// it before each build with the release version in APP_VERSION (else version.Current):
//
//	APP_VERSION=1.1.0 go generate ./cmd/firefox-vpn-core
//
// The objects are build output, not kept in Git; a build without them has
// no icon, version information, or manifest.
package main

import (
	"bytes"
	"fmt"
	"os"

	"github.com/tc-hib/winres"
	winversion "github.com/tc-hib/winres/version"

	"github.com/armanlife/firefox-vpn-client/core/internal/desktop"
	"github.com/armanlife/firefox-vpn-client/core/internal/version"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "winres:", err)
		os.Exit(1)
	}
}

func run() error {
	// The program's icon in every size, as app/tool/app_icons.py made it.
	icon, err := winres.LoadICO(bytes.NewReader(desktop.AppIconICO))
	if err != nil {
		return err
	}
	var rs winres.ResourceSet
	if err := rs.SetIcon(winres.Name("APP"), icon); err != nil {
		return err
	}

	release := os.Getenv("APP_VERSION")
	if release == "" {
		release = version.Current
	}
	var vi winversion.Info
	vi.SetFileVersion(release)
	vi.SetProductVersion(release)
	for key, value := range map[string]string{
		winversion.ProductName:      "Firefox VPN",
		winversion.FileDescription:  "Firefox VPN Core",
		winversion.OriginalFilename: "firefox-vpn-core.exe",
		winversion.InternalName:     "firefox-vpn-core",
		// The publisher, as in the installer (AppPublisher) and the app.
		winversion.CompanyName:    "Arman",
		winversion.LegalCopyright: "Copyright (c) 2026 Arman",
	} {
		if err := vi.Set(winversion.LangDefault, key, value); err != nil {
			return err
		}
	}
	rs.SetVersionInfo(vi)

	// Runs with the user's rights (no elevation prompt), declares Windows
	// 10 and 11 like the app's manifest, and is per-monitor DPI aware for
	// the tray icon and its menu.
	rs.SetManifest(winres.AppManifest{
		ExecutionLevel: winres.AsInvoker,
		Compatibility:  winres.Win10AndAbove,
		DPIAwareness:   winres.DPIPerMonitorV2,
	})

	for _, arch := range []winres.Arch{winres.ArchAMD64, winres.ArchARM64, winres.ArchI386} {
		if err := writeObject(&rs, arch); err != nil {
			return err
		}
	}
	return nil
}

func writeObject(rs *winres.ResourceSet, arch winres.Arch) error {
	f, err := os.Create("rsrc_windows_" + string(arch) + ".syso")
	if err != nil {
		return err
	}
	if err := rs.WriteObject(f, arch); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}
