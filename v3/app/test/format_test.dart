import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/l10n/app_localizations.dart';
import 'package:firefox_vpn/ui/format.dart';

void main() {
  test('converts Gregorian dates to Jalali', () {
    expect(toJalali(DateTime(2026, 10, 14)), (year: 1405, month: 7, day: 22));
    expect(toJalali(DateTime(2026, 3, 21)), (year: 1405, month: 1, day: 1));
    expect(toJalali(DateTime(2026, 3, 20)), (year: 1404, month: 12, day: 29));
    expect(toJalali(DateTime(2025, 3, 21)), (year: 1404, month: 1, day: 1));
    expect(toJalali(DateTime(2024, 3, 20)), (year: 1403, month: 1, day: 1));
    // 1403 is a leap year: Esfand has 30 days.
    expect(toJalali(DateTime(2025, 3, 20)), (year: 1403, month: 12, day: 30));
    expect(toJalali(DateTime(2026, 11, 1)), (year: 1405, month: 8, day: 10));
  });

  test('writes Persian digits', () {
    expect(persianDigits('1405/7/22'), '۱۴۰۵/۷/۲۲');
  });

  test('formats sizes', () {
    String plain(String s) => s.replaceAll(RegExp('[\u2066\u2069]'), '');
    expect(plain(formatBytes(512)), '512 B');
    expect(plain(formatBytes(50 * 1024 * 1024 * 1024)), '50.0 GB');
    expect(plain(formatRate(2048)), '2.0 KB/s');
  });

  test('an email shows two letters of its name and the domain', () {
    expect(maskEmail('alice@example.com'), 'al•••••@example.com');
    expect(maskEmail('bob@x.org'), 'b•••••@x.org');
    expect(maskEmail('@x.org'), '•••••@x.org');
    expect(maskEmail('nodomain'), 'no•••••');
  });

  test('says how long ago, up to days', () {
    final now = DateTime(2026, 10, 16, 12);
    String ago(Locale locale, Duration d) =>
        formatSince(lookupAppLocalizations(locale), now.subtract(d), now: now);
    const en = Locale('en');
    expect(ago(en, const Duration(seconds: 20)), 'just now');
    expect(ago(en, const Duration(minutes: 2)), contains('2'));
    expect(ago(en, const Duration(hours: 3)), '3 h ago');
    expect(ago(en, const Duration(days: 1, hours: 5)), '1 day ago');
    expect(ago(en, const Duration(days: 5)), '5 days ago');
    expect(
      ago(const Locale('fa'), const Duration(days: 5)),
      contains('روز پیش'),
    );
  });
}
