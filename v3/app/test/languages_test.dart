import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/app_settings.dart';
import 'package:firefox_vpn/core/models.dart';
import 'package:firefox_vpn/l10n/app_localizations.dart';
import 'package:firefox_vpn/ui/accounts_page.dart';
import 'package:firefox_vpn/ui/format.dart';

void main() {
  test('the system locale picks the app language', () {
    expect(AppSettings.languageFor(const Locale('fa', 'IR')), 'fa');
    expect(AppSettings.languageFor(const Locale('zh', 'CN')), 'zh');
    expect(AppSettings.languageFor(const Locale('zh', 'TW')), 'zh_Hant');
    expect(
      AppSettings.languageFor(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      'zh_Hant',
    );
    expect(AppSettings.languageFor(const Locale('de')), 'en');
    // The first preferred language the app has; else English, also for a
    // system without one (Linux's C locale).
    expect(
      AppSettings.languageForList(const [Locale('de'), Locale('fa')]),
      'fa',
    );
    expect(AppSettings.languageForList(const [Locale('de')]), 'en');
    expect(AppSettings.languageForList(const [Locale('und')]), 'en');
    expect(AppSettings.languageForList(null), 'en');
    expect(
      AppSettings.localeOf('zh_Hant'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );
  });

  test('an account reason is in the language of the app', () async {
    final fa = await AppLocalizations.delegate.load(const Locale('fa'));
    Account account(String code, String reason, [String detail = '']) =>
        Account.fromJson({
          'id': 'a',
          'status': 'reauth_required',
          'reason': reason,
          'reason_code': code,
          'reason_detail': detail,
        });
    expect(
      accountReason(fa, account('signin_required', 'sign-in required'), 95),
      fa.reasonSignInRequired,
    );
    expect(
      accountReason(fa, account('signin_failed', 'failed', 'bad password'), 95),
      contains('bad password'),
    );
    // A reason this app does not know: the core's words.
    expect(
      accountReason(fa, account('new_code', 'Something new'), 95),
      'Something new',
    );
    expect(accountReason(fa, account('', ''), 95), isNull);
    // The switch reason names the setting.
    expect(
      accountReason(fa, account('quota_threshold', 'threshold'), 92),
      fa.reasonQuotaThreshold(92),
    );
  });

  testWidgets('every language formats dates', (tester) async {
    // Loads the date formats the app gets from flutter_localizations.
    for (final language in AppSettings.supportedLanguages) {
      final locale = AppSettings.localeOf(language);
      await GlobalMaterialLocalizations.delegate.load(locale);
      final l = await AppLocalizations.delegate.load(locale);
      final t = DateTime(2026, 10, 15, 9, 5);
      expect(formatDate(l, t), isNotEmpty, reason: language);
      expect(formatDateTime(l, t), isNotEmpty, reason: language);
    }
  });
}
