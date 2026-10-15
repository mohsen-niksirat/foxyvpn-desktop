package socks

import (
	"bytes"
	"io"
	"testing"
)

func TestReadAddr(t *testing.T) {
	dom := append([]byte{9}, []byte("localhost")...)
	host, err := readAddr(bytes.NewReader(dom), socksAtypDomain)
	if err != nil || host != "localhost" {
		t.Fatal(host, err)
	}
	ipv4 := []byte{1, 2, 3, 4}
	host, err = readAddr(bytes.NewReader(ipv4), socksAtypIPv4)
	if err != nil || host != "1.2.3.4" {
		t.Fatal(host, err)
	}
	_, err = readAddr(bytes.NewReader([]byte{0x99, 0}), 0x99)
	if err == nil {
		t.Fatal("expected error for bad atyp")
	}
	_ = io.EOF
}
