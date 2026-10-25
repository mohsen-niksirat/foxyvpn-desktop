import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/core/updates.dart';

void main() {
  const page = 'https://github.com/o/r/releases/tag/v1.2.3';

  test('a phone downloads the APK for its processor', () {
    expect(
      apkUrl(page, 'arm64-v8a'),
      'https://github.com/o/r/releases/download/v1.2.3/Firefox-VPN-1.2.3-Android-arm64-v8a.apk',
    );
    expect(
      apkUrl(page, 'armeabi-v7a'),
      endsWith('/v1.2.3/Firefox-VPN-1.2.3-Android-armeabi-v7a.apk'),
    );
    expect(apkUrl(page, 'x86_64'), endsWith('-x86_64.apk'));
  });

  test('another processor gets the universal APK', () {
    expect(
      apkUrl(page, 'x86'),
      endsWith('/Firefox-VPN-1.2.3-Android-universal.apk'),
    );
    expect(
      apkUrl(page, ''),
      endsWith('/Firefox-VPN-1.2.3-Android-universal.apk'),
    );
  });

  test('a computer downloads the file for its kind of copy', () {
    expect(
      releaseFileUrl(page, windowsName(installed: true)),
      'https://github.com/o/r/releases/download/v1.2.3/Firefox-VPN-1.2.3-Windows-Setup-x64.exe',
    );
    expect(
      releaseFileUrl(page, windowsName(installed: false)),
      endsWith('/Firefox-VPN-1.2.3-Windows-x64.zip'),
    );
    expect(linuxName('3.10.0 (stable) on "linux_arm64"'), 'Linux-arm64.tar.gz');
    expect(linuxName('3.10.0 (stable) on "linux_x64"'), 'Linux-amd64.tar.gz');
  });
}
