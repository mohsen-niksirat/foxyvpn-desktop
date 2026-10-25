import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/core/models.dart';
import 'package:firefox_vpn/l10n/app_localizations.dart';
import 'package:firefox_vpn/ui/widgets.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  ProxyInfo proxy({String error = '', String code = '', String? at}) =>
      ProxyInfo.fromJson({
        'wake_error': error,
        'wake_error_code': code,
        'wake_failed_at': ?at,
      });

  ConnectionTest failedTest({
    String error = '',
    String code = '',
    String? at,
  }) => ConnectionTest.fromJson({
    'ok': false,
    'error': error,
    'error_code': code,
    'at': ?at,
  });

  test('the reason is named, not the internet', () {
    final quota = failureText(
      l,
      proxy(error: 'quota exceeded', code: Failure.quota),
      null,
    );
    expect(quota.text, l.failQuota);
    expect(quota.detail, 'quota exceeded');

    expect(
      failureText(l, null, failedTest(error: 'x', code: Failure.testSite)).text,
      l.failTestSite,
    );
    expect(
      failureText(
        l,
        null,
        failedTest(error: 'x', code: Failure.unreachable),
      ).text,
      l.failUnreachable,
    );
    expect(
      failureText(l, null, failedTest(error: 'odd', code: Failure.other)).text,
      l.failOther,
    );
  });

  test("a refused chosen location is named in the app's language", () {
    expect(
      failureText(
        l,
        null,
        failedTest(error: 'x', code: Failure.locationRefused),
      ).text,
      "This country isn't open to your account. Choose another country.",
    );
    final fa = lookupAppLocalizations(const Locale('fa'));
    expect(
      failureCodeText(fa, Failure.locationRefused),
      'این کشور برای حساب شما باز نیست. کشور دیگری انتخاب کنید.',
    );
    expect(fa.useRecommendedLocation, 'استفاده از مکان پیشنهادی');
  });

  test('every failure says what happened and what to do', () {
    expect(l.failNoInternet, 'No internet. Check Wi-Fi or mobile data.');
    expect(
      l.failSignIn,
      "This account's sign-in has expired. Sign in again on the Accounts "
      'page.',
    );
    expect(l.failOther, "Couldn't connect. Try again.");
    final fa = lookupAppLocalizations(const Locale('fa'));
    expect(
      failureCodeText(fa, Failure.noNetwork),
      'اینترنت وصل نیست. Wi-Fi یا اینترنت موبایل را بررسی کنید.',
    );
    // Mozilla answers and refuses the country (HTTP 451): not a block.
    expect(
      failureCodeText(fa, Failure.region),
      'سرویس Mozilla در کشور شما ارائه نمی‌شود.',
    );
    expect(fa.noNetwork, isNot(contains('داده')));
  });

  // In Persian and Arabic every failure and state text starts with a word
  // of the language: notifications and plain text take their direction
  // from the first strong character. Persian has no hamza above (U+0654)
  // and no «ی» ezafe after «ه».
  test('RTL failure texts start right to left', () {
    final rtlStart = RegExp('^[\u0600-\u06FF]');
    for (final language in ['fa', 'ar']) {
      final rtl = lookupAppLocalizations(Locale(language));
      final texts = [
        for (final code in [
          Failure.noNetwork,
          Failure.unreachable,
          Failure.refused,
          Failure.locationRefused,
          Failure.signIn,
          Failure.quota,
          Failure.notEntitled,
          Failure.region,
          Failure.server,
          Failure.noAccount,
          Failure.testSite,
          Failure.other,
        ])
          failureCodeText(rtl, code),
        rtl.noNetwork,
        rtl.waitingForNetwork,
        rtl.proxyStartFailed('10810'),
        rtl.systemProxyTakenBy('127.0.0.1:7890'),
        rtl.systemProxyTakenOff,
        rtl.setSystemProxyAgain,
        rtl.proxyPortInUse('10810'),
      ];
      for (final text in texts) {
        expect(text, matches(rtlStart), reason: '$language: $text');
        if (language == 'fa') {
          expect(text, isNot(contains('\u0654')), reason: text);
          expect(text, isNot(contains('\u0647\u200c\u06cc')), reason: text);
        }
      }
    }
  });

  test('the core states are worded by their code', () {
    EngineState state(
      String phase,
      String message, [
      String? code,
      String? address,
    ]) => EngineState.fromJson({
      'phase': phase,
      'message': message,
      'code': ?code,
      'address': ?address,
    });
    CoreStatus status(Map<String, Object?> state) => CoreStatus.fromJson({
      'state': state,
      'accounts': {'total': 3},
    });

    expect(
      stateText(
        l,
        state(
          'waiting',
          'Waiting for a network connection',
          StateCode.waitingForNetwork,
        ),
      ),
      l.waitingForNetwork,
    );
    expect(
      stateText(
        l,
        state(
          'waiting',
          'No usable account: 2 reserved, 1 reauth_required',
          StateCode.noUsableAccount,
        ),
      ),
      'No account is ready. Open the Accounts page.',
    );
    expect(
      stateText(l, state('waiting', 'Add an account', StateCode.noAccounts)),
      l.waitingForAccount,
    );
    // A port that cannot be used names it; the button changes it.
    final blocked = state(
      'error',
      'listening on 127.0.0.1:10810: bind: forbidden',
      StateCode.startFailed,
      '127.0.0.1:10810',
    );
    expect(
      stateText(l, blocked),
      "The proxy couldn't start on port 10810. Choose another port.",
    );
    expect(blocked.proxyPortBlocked, isTrue);
    // Without the address (an older core), the core's own words.
    final unnamed = state('error', 'listen failed', StateCode.startFailed);
    expect(stateText(l, unnamed), 'listen failed');
    expect(unnamed.proxyPortBlocked, isFalse);
    // The core's English for a code this app does not know, and without
    // one.
    expect(
      stateText(l, state('error', 'Something new', 'from_a_newer_core')),
      'Something new',
    );
    expect(stateText(l, state('error', 'Plain words')), 'Plain words');

    final fa = lookupAppLocalizations(const Locale('fa'));
    final look = PhaseLook.of(
      fa,
      status({
        'phase': 'waiting',
        'message': 'No usable account: 2 reserved, 1 reauth_required',
        'code': StateCode.noUsableAccount,
      }),
    );
    expect(look.hint, 'هیچ حسابی آماده نیست. صفحه حساب‌ها را باز کنید.');
    expect(
      PhaseLook.of(
        fa,
        status({
          'phase': 'waiting',
          'message': 'Waiting for a network connection',
          'code': StateCode.waitingForNetwork,
        }),
      ).hint,
      'منتظر اتصال اینترنت…',
    );
  });

  test('no internet says so; an unknown code asks to check it', () {
    expect(
      failureText(
        l,
        null,
        failedTest(error: 'x', code: Failure.noNetwork),
      ).text,
      l.failNoInternet,
    );
    // The core's own words stay out of the text.
    final other = failureText(
      l,
      null,
      failedTest(
        error: 'Get "https://www.google.com/generate_204": odd',
        code: Failure.other,
      ),
    );
    expect(other.text, l.failOther);
    expect(other.detail, contains('generate_204'));
    expect(
      failureText(l, null, failedTest(error: 'x', code: 'new_kind')).text,
      l.connectRetrying,
    );
  });

  test('the newer of the wake failure and the test speaks', () {
    const early = '2026-10-19T10:00:00Z';
    const late = '2026-10-19T10:05:00Z';
    final wakeLater = failureText(
      l,
      proxy(error: 'w', code: Failure.signIn, at: late),
      failedTest(error: 't', code: Failure.unreachable, at: early),
    );
    expect(wakeLater.text, l.failSignIn);
    final testLater = failureText(
      l,
      proxy(error: 'w', code: Failure.signIn, at: early),
      failedTest(error: 't', code: Failure.unreachable, at: late),
    );
    expect(testLater.text, l.failUnreachable);
    expect(testLater.detail, 't');
  });
}
