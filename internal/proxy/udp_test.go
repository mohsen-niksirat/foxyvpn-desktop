package proxy

import (
	"bytes"
	"testing"
)

func TestParseUDPHeaderIPv4(t *testing.T) {
	pkt := []byte{0, 0, 0, atypIPv4, 1, 1, 1, 1, 0, 53, 'q', 'u', 'e', 'r', 'y'}
	dst, payload, err := parseUDPHeader(pkt)
	if err != nil {
		t.Fatal(err)
	}
	if dst.host != "1.1.1.1" || dst.port != 53 {
		t.Fatalf("got %s:%d", dst.host, dst.port)
	}
	if !bytes.Equal(payload, []byte("query")) {
		t.Fatalf("payload %q", payload)
	}
}

func TestParseUDPHeaderDomain(t *testing.T) {
	pkt := []byte{0, 0, 0, atypDomain, 3, 'a', 'b', 'c', 0, 80, 'x'}
	dst, payload, err := parseUDPHeader(pkt)
	if err != nil {
		t.Fatal(err)
	}
	if dst.host != "abc" || dst.port != 80 || !bytes.Equal(payload, []byte("x")) {
		t.Fatalf("got %+v payload %q", dst, payload)
	}
}

func TestParseUDPHeaderRejectsFragments(t *testing.T) {
	pkt := []byte{0, 0, 1, atypIPv4, 1, 1, 1, 1, 0, 53}
	if _, _, err := parseUDPHeader(pkt); err == nil {
		t.Fatal("expected fragment to be rejected")
	}
}

func TestParseUDPHeaderShortInput(t *testing.T) {
	for _, pkt := range [][]byte{
		nil,
		{0, 0, 0},
		{0, 0, 0, atypIPv4, 1, 1},
		{0, 0, 0, atypDomain, 9, 'a'},
	} {
		if _, _, err := parseUDPHeader(pkt); err == nil {
			t.Fatalf("expected error for %v", pkt)
		}
	}
}
