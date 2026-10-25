package desktop

import (
	"bytes"
	"image/png"
	"testing"
)

// Every tray state has its icon in both formats: a PNG with a transparent
// corner and the white shield in the middle, and an ICO.
func TestTrayIcons(t *testing.T) {
	for _, name := range []string{iconRunning, iconRunningAsleep, iconSet, iconSetAsleep, iconWaiting, iconError, iconOff} {
		data, err := trayFiles.ReadFile("tray/" + name + ".png")
		if err != nil {
			t.Fatal(err)
		}
		img, err := png.Decode(bytes.NewReader(data))
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if b := img.Bounds(); b.Dx() != 32 || b.Dy() != 32 {
			t.Fatalf("%s: size %v", name, b)
		}
		if _, _, _, a := img.At(0, 0).RGBA(); a != 0 {
			t.Fatalf("%s: the corner should be transparent", name)
		}
		if r, g, b, _ := img.At(18, 15).RGBA(); r>>8 < 0xf0 || g>>8 < 0xf0 || b>>8 < 0xf0 {
			t.Fatalf("%s: the middle should be the white shield", name)
		}
		ico, err := trayFiles.ReadFile("tray/" + name + ".ico")
		if err != nil || !bytes.Equal(ico[:4], []byte{0, 0, 1, 0}) {
			t.Fatalf("%s: not an ICO file: %v", name, err)
		}
		if len(trayIcon(name)) == 0 {
			t.Fatalf("%s: no icon for this system", name)
		}
	}
}
