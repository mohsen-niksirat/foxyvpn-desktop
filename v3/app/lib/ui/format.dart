/// Formatting for people. Sizes use binary units with the familiar names
/// (GB = GiB), as the core's quota does; numbers keep Latin digits so
/// addresses and sizes read the same in every language. Persian dates use
/// the Solar Hijri (Jalali) calendar.
library;

import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// An email with its name hidden but for the first two letters, for
/// screens others may see: al•••••@example.com.
String maskEmail(String email) {
  final at = email.indexOf('@');
  final name = at < 0 ? email : email.substring(0, at);
  final domain = at < 0 ? '' : email.substring(at);
  // Short names show one letter; an empty one shows none.
  final shown = name.substring(0, name.length < 4 ? (name.isEmpty ? 0 : 1) : 2);
  return '$shown•••••$domain';
}

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 || value >= 100 ? 0 : 1;
  return ltr('${value.toStringAsFixed(digits)} ${units[unit]}');
}

String formatRate(int bytesPerSecond) {
  final size = formatBytes(bytesPerSecond);
  return ltr('${size.substring(1, size.length - 1)}/s');
}

/// Keeps "694 KB/s" in this order inside right-to-left text (a Unicode
/// left-to-right isolate).
String ltr(String s) => '\u2066$s\u2069';

String formatDuration(AppLocalizations l, Duration d) {
  if (d.isNegative) d = Duration.zero;
  if (d.inDays > 0) return l.durationDays(d.inDays, d.inHours % 24);
  if (d.inHours > 0) return l.durationHours(d.inHours, d.inMinutes % 60);
  if (d.inMinutes > 0) return l.durationMinutes(d.inMinutes, d.inSeconds % 60);
  return l.durationSeconds(d.inSeconds);
}

const _jalaliMonths = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', //
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

/// A short date in the language's words and calendar ("Nov 1",
/// "۱۰ آبان").
String formatDate(AppLocalizations l, DateTime t) {
  if (l.localeName == 'fa') {
    final j = toJalali(t);
    return '${persianDigits('${j.day}')} ${_jalaliMonths[j.month - 1]}';
  }
  return DateFormat.MMMd(l.localeName).format(t);
}

/// A date with the year and the time, for list updates and such.
String formatDateTime(AppLocalizations l, DateTime t) {
  if (l.localeName == 'fa') {
    final j = toJalali(t);
    return persianDigits('${j.year}/${j.month}/${j.day} ${formatTime(t)}');
  }
  return '${DateFormat.yMMMd(l.localeName).format(t)} ${formatTime(t)}';
}

String formatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// How long ago, for things that change over days (the geo files): "just
/// now", "5 min ago", "3 h ago", "5 days ago".
String formatSince(AppLocalizations l, DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return l.justNow;
  if (d.inMinutes < 60) return l.minutesAgo(d.inMinutes);
  if (d.inHours < 24) return l.hoursAgo(d.inHours);
  return l.daysAgo(d.inDays);
}

/// "just now", "5 min ago", the time today, or the date.
String formatAgo(AppLocalizations l, DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return l.justNow;
  if (d.inMinutes < 60) return l.minutesAgo(d.inMinutes);
  if (d.inHours < 24) return l.atTime(formatTime(t));
  return formatDate(l, t);
}

String persianDigits(String s) => s.replaceAllMapped(
  RegExp('[0-9]'),
  (m) => String.fromCharCode(0x06F0 + m[0]!.codeUnitAt(0) - 0x30),
);

/// The Jalali (Solar Hijri) date of [t]'s calendar day, by the algorithm
/// of jalaali-js (valid for Jalali years -61 to 3177).
({int year, int month, int day}) toJalali(DateTime t) {
  final jdn = _g2d(t.year, t.month, t.day);
  final gy = t.year;
  var jy = gy - 621;
  final r = _jalCal(jy, gy);
  final jdn1f = _g2d(gy, 3, r.march);
  var k = jdn - jdn1f;
  if (k >= 0) {
    if (k <= 185) {
      return (year: jy, month: 1 + k ~/ 31, day: k.remainder(31) + 1);
    }
    k -= 186;
  } else {
    jy -= 1;
    k += 179;
    if (r.leap == 1) k += 1;
  }
  return (year: jy, month: 7 + k ~/ 30, day: k.remainder(30) + 1);
}

/// The Julian day number of a Gregorian date.
int _g2d(int gy, int gm, int gd) {
  var d =
      ((gy + (gm - 8) ~/ 6 + 100100) * 1461) ~/ 4 +
      (153 * (gm + 9).remainder(12) + 2) ~/ 5 +
      gd -
      34840408;
  d = d - ((gy + 100100 + (gm - 8) ~/ 6) ~/ 100 * 3) ~/ 4 + 752;
  return d;
}

/// Whether Jalali year [jy] is leap (0 = leap) and the March day of its
/// Nowruz in Gregorian year [gy].
({int leap, int march}) _jalCal(int jy, int gy) {
  const breaks = [
    -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, //
    1210, 1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178,
  ];
  var leapJ = -14;
  var jp = breaks[0];
  var jump = 0;
  for (var i = 1; i < breaks.length; i++) {
    final jm = breaks[i];
    jump = jm - jp;
    if (jy < jm) break;
    leapJ += jump ~/ 33 * 8 + jump.remainder(33) ~/ 4;
    jp = jm;
  }
  var n = jy - jp;
  leapJ += n ~/ 33 * 8 + (n.remainder(33) + 3) ~/ 4;
  if (jump.remainder(33) == 4 && jump - n == 4) leapJ += 1;
  final leapG = gy ~/ 4 - ((gy ~/ 100 + 1) * 3) ~/ 4 - 150;
  final march = 20 + leapJ - leapG;
  if (jump - n < 6) n = n - jump + (jump + 4) ~/ 33 * 33;
  var leap = ((n + 1).remainder(33) - 1).remainder(4);
  if (leap == -1) leap = 4;
  return (leap: leap, march: march);
}
