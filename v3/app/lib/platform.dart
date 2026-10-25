import 'dart:io';

import 'core/android_core.dart';
import 'desktop/desktop_bridge.dart';

/// Opens [url] in the system's handler: the browser, or the app for a
/// scheme such as tg://. On Windows the runner opens it through the shell
/// and accepts only http and https links.
Future<void> openUrl(String url) async {
  if (Platform.isAndroid) {
    await AndroidCore.openUrl(url);
  } else if (Platform.isWindows) {
    await DesktopBridge.openUrl(url);
  } else if (Platform.isMacOS) {
    await Process.start('open', [url]);
  } else {
    await Process.start('xdg-open', [url]);
  }
}

/// Whether a proxy listen address accepts other devices.
bool sharedWithLan(String listen) =>
    listen.startsWith('0.0.0.0:') || listen.startsWith('[::]:');

/// This device's IPv4 address on the local network, or null: Wi-Fi and
/// Ethernet first, since a phone's mobile data has private addresses too.
Future<String?> lanAddress() async {
  try {
    final found = <(int, String)>[];
    for (final i in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    )) {
      final name = i.name.toLowerCase();
      final rank = ['wlan', 'eth', 'ap', 'wi-fi', 'en'].any(name.startsWith)
          ? 0
          : 1;
      for (final a in i.addresses) {
        if (isPrivateIPv4(a.address)) found.add((rank, a.address));
      }
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    return found.firstOrNull?.$2;
  } on SocketException {
    return null;
  }
}

/// Whether [ip] is in 10/8, 172.16/12, or 192.168/16.
bool isPrivateIPv4(String ip) {
  final p = ip.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.contains(null)) return false;
  return p[0] == 10 ||
      (p[0] == 172 && p[1]! >= 16 && p[1]! <= 31) ||
      (p[0] == 192 && p[1] == 168);
}
