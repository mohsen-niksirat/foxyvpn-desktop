import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/app_settings.dart';
import 'package:firefox_vpn/core/models.dart';
import 'package:firefox_vpn/l10n/app_localizations.dart';
import 'package:firefox_vpn/ui/local_country_names.dart';
import 'package:firefox_vpn/ui/widgets.dart';

/// Every country in Mozilla's server list, and the others the exit or the
/// user's region can be in.
const _codes = [
  ...['ZA', 'PE', 'BR', 'KR', 'GH', 'AR', 'PH', 'GB', 'FR', 'CA', 'SG'],
  ...['SE', 'FI', 'NZ', 'DK', 'CL', 'NO', 'NL', 'BE', 'MY', 'ES', 'AT'],
  ...['AU', 'PT', 'JP', 'MX', 'CO', 'IT', 'IE', 'DE', 'US', 'TH', 'BG'],
  ...['IR', 'TR', 'AE', 'CH', 'PL', 'IN', 'CN', 'HK', 'TW', 'RU', 'UA'],
];

void main() {
  test('every app language names every country', () {
    for (final language in AppSettings.supportedLanguages) {
      final l = lookupAppLocalizations(AppSettings.localeOf(language));
      if (language == 'en') continue;
      expect(localCountryNames.keys, contains(l.localeName));
      for (final code in _codes) {
        final name = countryName(l, code, 'Server list name');
        expect(name, isNot('Server list name'), reason: '$language $code');
        expect(name, isNotEmpty, reason: '$language $code');
      }
      // Nothing beyond the languages and codes the app knows.
      expect(localCountryNames[l.localeName]!.keys.toSet(), _codes.toSet());
    }
  });

  test('English keeps the server list name; others fall back to it', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(countryName(en, 'GB', 'United Kingdom'), 'United Kingdom');
    expect(countryName(en, 'de'), 'Germany');
    final fa = lookupAppLocalizations(const Locale('fa'));
    expect(countryName(fa, 'de', 'Germany'), 'آلمان');
    expect(countryName(fa, 'GB'), 'انگلیس');
    // A country without a translation: the server list's name, else the
    // English name of its code, else the code.
    expect(countryName(fa, 'IS', 'Iceland (server)'), 'Iceland (server)');
    expect(countryName(fa, 'IS'), 'Iceland');
    expect(countryName(fa, 'QQ'), 'QQ');
    // The core sends the code as the name of a country its server list does
    // not name: that is no name.
    expect(countryName(fa, 'IS', 'IS'), 'Iceland');
    expect(countryName(en, 'de', 'DE'), 'Germany');
    final zhHant = lookupAppLocalizations(AppSettings.localeOf('zh_Hant'));
    expect(countryName(zhHant, 'US'), '美國');
    // The recommended location keeps its own name.
    expect(
      locationName(fa, 'REC', 'Recomended Location'),
      fa.recommendedLocation,
    );
    expect(locationName(fa, 'NL', 'Netherlands'), 'هلند');
  });

  test('names sort as people of each language expect', () {
    List<String> sorted(String language, List<String> names) => [...names]
      ..sort(
        (a, b) => nameSortKey(language, a).compareTo(nameSortKey(language, b)),
      );
    // پ comes right after ب, and ک before ه, not after every Arabic letter.
    expect(sorted('fa', ['هلند', 'پرتغال', 'بلژیک', 'کانادا']), [
      'بلژیک',
      'پرتغال',
      'کانادا',
      'هلند',
    ]);
    // Accented letters next to their base letter.
    expect(sorted('fr', ['Ukraine', 'États-Unis', 'Espagne']), [
      'Espagne',
      'États-Unis',
      'Ukraine',
    ]);
    expect(sorted('tr', ['Yeni Zelanda', 'İspanya', 'Hollanda']), [
      'Hollanda',
      'İspanya',
      'Yeni Zelanda',
    ]);
    expect(sorted('vi', ['Úc', 'Đức', 'Anh']), ['Anh', 'Đức', 'Úc']);
    // Arabic: أ and إ are alif, and ه comes before و.
    expect(
      sorted('ar', [
        'اليابان',
        'الولايات المتحدة',
        'ألمانيا',
        'الهند',
        'أستراليا',
        'إسبانيا',
      ]),
      [
        'إسبانيا',
        'أستراليا',
        'ألمانيا',
        'الهند',
        'الولايات المتحدة',
        'اليابان',
      ],
    );
  });

  test('with every account turned off, the hint says to turn one on', () {
    final fa = lookupAppLocalizations(const Locale('fa'));
    PhaseLook look(int total) => PhaseLook.of(
      fa,
      CoreStatus.fromJson({
        'state': {
          'phase': 'waiting',
          'code': 'no_accounts',
          'message': 'Add an account in the dashboard to start the proxy',
        },
        'accounts': {'total': total},
      }),
    );
    expect(look(0).hint, fa.waitingForAccount);
    expect(look(2).hint, fa.waitingForEnabledAccount);
  });

  // Persian and Arabic names start with a letter of their script, so that
  // a text beginning with a name (the exit mismatch, the tray, a
  // notification) still reads right to left.
  test('RTL country names read right to left', () {
    final arabicLetter = RegExp('^[\u0600-\u06FF]');
    for (final language in ['fa', 'ar']) {
      for (final name in localCountryNames[language]!.values) {
        expect(name, matches(arabicLetter), reason: '$language $name');
        expect(name, isNot(contains('\u0654')), reason: name);
      }
    }
    final fa = lookupAppLocalizations(const Locale('fa'));
    final status = CoreStatus.fromJson({
      'state': {'phase': 'running'},
      'selection': 'gb',
      'exit_mismatch': {
        'chosen_country_code': 'GB',
        'chosen_country_name': 'United Kingdom',
        'exit_country_code': 'DE',
      },
    });
    final text = exitMismatchText(fa, status)!;
    expect(text, 'انگلیس را انتخاب کردید، اما IP شما مال آلمان است.');
    expect(text, matches(arabicLetter));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(
      exitMismatchText(en, status),
      'You chose United Kingdom, but your IP is in Germany.',
    );
  });
}
