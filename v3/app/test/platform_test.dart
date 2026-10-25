import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/platform.dart';

void main() {
  test('a listen address on every interface is shared with the LAN', () {
    expect(sharedWithLan('0.0.0.0:10810'), isTrue);
    expect(sharedWithLan('[::]:10810'), isTrue);
    expect(sharedWithLan('127.0.0.1:10810'), isFalse);
  });

  test('private IPv4 addresses', () {
    for (final ip in [
      '10.0.0.2',
      '172.16.1.1',
      '172.31.255.1',
      '192.168.1.5',
    ]) {
      expect(isPrivateIPv4(ip), isTrue, reason: ip);
    }
    for (final ip in [
      '172.32.0.1',
      '8.8.8.8',
      '127.0.0.1',
      'fe80::1',
      '1.2.3',
    ]) {
      expect(isPrivateIPv4(ip), isFalse, reason: ip);
    }
  });
}
