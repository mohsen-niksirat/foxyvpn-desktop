package mobile

import (
	"crypto/sha1"
	"crypto/x509"
	"encoding/hex"
	"encoding/pem"
	"testing"
)

func TestExtraRootsAreGlobalSignR46AndE46(t *testing.T) {
	want := map[string]string{
		"GlobalSign Root R46": "53a2b04bca6bd645e6398a8ec40dd2bf77c3a290",
		"GlobalSign Root E46": "39b46cd5fe8006ebe22f4abb0833a0afdbb9dd84",
	}
	rest := extraRoots
	for {
		var block *pem.Block
		block, rest = pem.Decode(rest)
		if block == nil {
			break
		}
		cert, err := x509.ParseCertificate(block.Bytes)
		if err != nil {
			t.Fatal(err)
		}
		sum := sha1.Sum(cert.Raw)
		name := cert.Subject.CommonName
		if want[name] != hex.EncodeToString(sum[:]) {
			t.Fatalf("unexpected root %q %x", name, sum)
		}
		if !cert.IsCA {
			t.Fatalf("%s is not a CA", name)
		}
		delete(want, name)
	}
	if len(want) > 0 {
		t.Fatalf("missing roots: %v", want)
	}
}

func TestCertDirsPreferTheUpdatableStore(t *testing.T) {
	if got := certDirs(true); got != apexCerts+":"+userCerts {
		t.Fatal(got)
	}
	if got := certDirs(false); got != systemCerts+":"+userCerts {
		t.Fatal(got)
	}
}
