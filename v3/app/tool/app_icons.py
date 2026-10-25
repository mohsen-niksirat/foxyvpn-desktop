"""Makes every icon of the program from Mozilla VPN's logo (tool/mozilla-vpn,
from mozilla-mobile/mozilla-vpn-client): logo-dock.png, the white symbol on
a black rounded tile (512 px); logo-glyph.png, the symbol alone (1024 px,
transparent); and its tray icons, logo-generic.png and four frames while
connecting, logo-animated1.png to logo-animated4.png (80 px):

- Android (android/app/src/main/res): an adaptive icon for Android 8+, a
  black background layer and the symbol as the foreground layer, 108 dp
  each, which the launcher crops to its own shape; and ic_launcher.png for
  older Android, the same tile, rounded. The status bar icon
  (res/drawable/ic_stat_logo.xml) is the symbol in white, by hand.
- macOS (macos/Runner/Assets.xcassets/AppIcon.appiconset): the black tile
  in Apple's grid, a rounded square of 824 in 1024 with room for its
  shadow, the symbol in its middle, in the sizes the icon set lists.
- Windows (windows/runner/resources/app_icon.ico): the tile, in every size
  Explorer and the taskbar use; the small sizes sharpened, since the
  taskbar shows 24 or 32 px.
- The core (core/internal/desktop): appicon.ico, the same for its
  executable (tools/winres).
- The web dashboard (core/internal/service/web/icon.png): the tile, for
  the page icon and the logo.
- The app's logo (assets/logo.png): the tile, beside its name.
- The tray icons, as Mozilla VPN draws them: the plain logo while off,
  the four frames while connecting, and the logo with a colored dot in the
  lower right corner otherwise. The app's tray (assets/tray: .ico for
  Windows, .png for Linux): off, busy1 to busy4, on and idle (green dot),
  error (red dot). The core's tray (core/internal/desktop/tray: .ico for
  Windows, .png elsewhere): one icon per state, the dot green while the
  proxy runs, blue while Windows' system proxy points at it, faded while
  asleep, red on an error; the first frame while waiting.

The fox shield of the documentation is docs/images/logo.png, kept as is.

Run from app/ after changing the art or the colors (needs Pillow):

    python tool/app_icons.py
"""
import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, '..')
CORE = os.path.join(APP, '..', 'core')
MOZILLA = os.path.join(HERE, 'mozilla-vpn')
TILE = os.path.join(MOZILLA, 'logo-dock.png')
GLYPH = os.path.join(MOZILLA, 'logo-glyph.png')
RES = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')

# The symbol's height as a share of the 108 dp canvas. Launchers show about
# the middle 72 dp (67%), so 0.46 makes it about 70% of the tile, as Mozilla
# VPN's own launcher icon has it.
ART = 0.46
BLACK = (0, 0, 0, 255)
DENSITY = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
WINDOWS_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]

ADAPTIVE = '''<?xml version="1.0" encoding="utf-8"?>
<!-- The launcher icon on Android 8+: Mozilla VPN's symbol over black;
     the launcher crops both layers to its own shape. Made by
     tool/app_icons.py. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'''


def art_layer(art, size, share):
    """The art's visible part, its larger side share of size, centered."""
    art = art.crop(art.getchannel('A').getbbox())
    scale = size * share / max(art.size)
    w, h = max(1, round(art.width * scale)), max(1, round(art.height * scale))
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    layer.alpha_composite(art.resize((w, h), Image.LANCZOS), ((size - w) // 2, (size - h) // 2))
    return layer


def tile(glyph, size):
    """The visible middle of the adaptive icon, rounded."""
    canvas = round(size * 108 / 72)
    full = Image.new('RGBA', (canvas, canvas), BLACK)
    full.alpha_composite(art_layer(glyph, canvas, ART))
    cut = (canvas - size) // 2
    square = full.crop((cut, cut, cut + size, cut + size))
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=size // 5, fill=255)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(square, (0, 0), mask)
    return out


def android(glyph):
    for dpi, k in DENSITY.items():
        folder = os.path.join(RES, 'mipmap-' + dpi)
        os.makedirs(folder, exist_ok=True)
        px = round(108 * k)
        art_layer(glyph, px, ART).save(os.path.join(folder, 'ic_launcher_foreground.png'), optimize=True)
        Image.new('RGBA', (px, px), BLACK).save(os.path.join(folder, 'ic_launcher_background.png'), optimize=True)
        tile(glyph, round(48 * k)).save(os.path.join(folder, 'ic_launcher.png'), optimize=True)
    folder = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, 'ic_launcher.xml'), 'w', newline='\n') as f:
        f.write(ADAPTIVE)


def crisp(art, size):
    """A small size: shrunk from the full art, then sharpened and given a
    little more contrast and color, which a few pixels otherwise lose."""
    image = art_layer(art, size, 1.0)
    alpha = image.getchannel('A')
    rgb = image.convert('RGB').filter(ImageFilter.UnsharpMask(radius=0.6 if size <= 24 else 0.8, percent=120, threshold=0))
    rgb = ImageEnhance.Color(ImageEnhance.Contrast(rgb).enhance(1.06)).enhance(1.10)
    out = rgb.convert('RGBA')
    out.putalpha(alpha)
    return out


def write_ico(path, art):
    # Each size drawn from the full art; up to 48 px sharpened.
    images = [crisp(art, n) if n <= 48 else art_layer(art, n, 1.0) for n in WINDOWS_SIZES]
    images[-1].save(path, format='ICO', sizes=[(n, n) for n in WINDOWS_SIZES], append_images=images[:-1])


MACOS_SIZES = [16, 32, 64, 128, 256, 512, 1024]


def macos_icon(glyph):
    """The 1024 px macOS icon: the black tile, 824 px with rounded corners,
    over a soft shadow, the symbol in its middle."""
    size, body = 1024, 824
    off = (size - body) // 2
    mask = Image.new('L', (body, body), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, body - 1, body - 1], radius=round(body * 0.225), fill=255)
    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 90), (off, off + 12), mask)
    out = shadow.filter(ImageFilter.GaussianBlur(14))
    face = Image.new('RGBA', (body, body), BLACK)
    face.alpha_composite(art_layer(glyph, body, ART * 108 / 72 * 0.9))
    out.paste(face, (off, off), mask)
    return out


def macos(glyph):
    folder = os.path.join(APP, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    big = macos_icon(glyph)
    for n in MACOS_SIZES:
        big.resize((n, n), Image.LANCZOS).save(os.path.join(folder, 'app_icon_%d.png' % n), optimize=True)


def app_logo(tile_art):
    art_layer(tile_art, 256, 1.0).save(os.path.join(APP, 'assets', 'logo.png'), optimize=True)


def windows(tile_art):
    write_ico(os.path.join(APP, 'windows', 'runner', 'resources', 'app_icon.ico'), tile_art)


def core(tile_art):
    desktop = os.path.join(CORE, 'internal', 'desktop')
    write_ico(os.path.join(desktop, 'appicon.ico'), tile_art)
    art_layer(tile_art, 192, 1.0).save(os.path.join(CORE, 'internal', 'service', 'web', 'icon.png'), optimize=True)


# The tray's status dots, as Mozilla VPN's (green, red), and the core's own:
# blue while Windows' system proxy points at the proxy, faded while asleep.
DOT_GOOD, DOT_BAD = (63, 225, 176), (226, 40, 80)
DOT_SET = (96, 165, 250)
TRAY_SIZES = [16, 20, 24, 32, 48, 64]


def asleep(color):
    return tuple(round(c * 0.45 + g * 0.55) for c, g in zip(color, (150, 160, 158)))


def mozilla_icon(name, dot=None):
    """A Mozilla VPN tray icon (80 px), with a status dot of color dot."""
    img = Image.open(os.path.join(MOZILLA, name)).convert('RGBA')
    if dot:
        n = img.width
        # A gap around the dot, then the dot.
        gap = Image.new('L', img.size, 0)
        ImageDraw.Draw(gap).ellipse([n * 0.56, n * 0.56, n * 1.0, n * 1.0], fill=255)
        img.paste((0, 0, 0, 0), (0, 0), gap)
        ImageDraw.Draw(img).ellipse([n * 0.62, n * 0.62, n * 0.94, n * 0.94], fill=dot + (255,))
    return img


def save_ico(path, big):
    images = [big.resize((n, n), Image.LANCZOS) for n in TRAY_SIZES]
    images[-1].save(path, format='ICO', sizes=[(n, n) for n in TRAY_SIZES], append_images=images[:-1])


def tray():
    logo = 'logo-generic.png'
    # The app's tray.
    app = os.path.join(APP, 'assets', 'tray')
    for old in os.listdir(app):
        os.remove(os.path.join(app, old))
    icons = {
        'off': mozilla_icon(logo),
        'on': mozilla_icon(logo, DOT_GOOD),
        'idle': mozilla_icon(logo, DOT_GOOD),
        'error': mozilla_icon(logo, DOT_BAD),
    }
    for frame in range(1, 5):
        icons['busy%d' % frame] = mozilla_icon('logo-animated%d.png' % frame)
    for name, big in icons.items():
        save_ico(os.path.join(app, name + '.ico'), big)
        # Linux (AppIndicator) takes a .png; 64 px stays sharp when scaled.
        big.resize((64, 64), Image.LANCZOS).save(os.path.join(app, name + '.png'), optimize=True)
    # The core's tray: an .ico for Windows, a 32 px .png elsewhere.
    folder = os.path.join(CORE, 'internal', 'desktop', 'tray')
    os.makedirs(folder, exist_ok=True)
    states = {
        'running': mozilla_icon(logo, DOT_GOOD),
        'set': mozilla_icon(logo, DOT_SET),
        'running-asleep': mozilla_icon(logo, asleep(DOT_GOOD)),
        'set-asleep': mozilla_icon(logo, asleep(DOT_SET)),
        'waiting': mozilla_icon('logo-animated1.png'),
        'error': mozilla_icon(logo, DOT_BAD),
        'off': mozilla_icon(logo),
    }
    for name, big in states.items():
        save_ico(os.path.join(folder, name + '.ico'), big)
        big.resize((32, 32), Image.LANCZOS).save(os.path.join(folder, name + '.png'), optimize=True)


def main():
    tile_art = Image.open(TILE).convert('RGBA')
    glyph = Image.open(GLYPH).convert('RGBA')
    android(glyph)
    macos(glyph)
    windows(tile_art)
    core(tile_art)
    app_logo(tile_art)
    tray()


if __name__ == '__main__':
    main()
