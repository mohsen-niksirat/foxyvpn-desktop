import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/android_core.dart';
import '../core/core_api.dart';
import '../core/models.dart';
import '../core/ports.dart';
import '../core/remote_flags.dart';
import '../l10n/app_localizations.dart';
import 'country_names.dart';
import 'local_country_names.dart';

/// Where a Firefox Account is made: Mozilla's site.
const firefoxAccountSignUpUrl = 'https://accounts.firefox.com/';

/// Where an account made with Google or Apple sign-in gets a password.
const firefoxAccountSetPasswordUrl =
    'https://accounts.firefox.com/reset_password/';

/// The program's logo, Mozilla VPN's tile (assets/logo.png, made by
/// tool/app_icons.py), [size] logical pixels square.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/logo.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );
}

/// Status colors that read in both themes.
abstract final class StatusColors {
  static const good = Color(0xFF22A06B);
  static const busy = Color(0xFFE2A400);
  static const bad = Color(0xFFE5484D);
  static const idle = Color(0xFF8B8D98);
}

/// How the app presents the engine state.
class PhaseLook {
  const PhaseLook(this.label, this.color, this.hint);

  final String label;
  final Color color;

  /// What the state means for states that need it, in the user's words
  /// where the core gives a code ([stateText]); empty otherwise.
  final String hint;

  static PhaseLook of(AppLocalizations l, CoreStatus s) {
    final message = stateText(l, s.state);
    return switch (s.state.phase) {
      // Connected in either mode on the computer (Proxy or System proxy).
      // Asleep (no traffic yet, or idle) still counts as connected: the
      // proxy wakes on the first connection.
      Phase.running => PhaseLook(l.stateConnected, StatusColors.good, ''),
      Phase.starting => PhaseLook(l.stateConnecting, StatusColors.busy, ''),
      // The core's own words name its web dashboard; the app has a page.
      Phase.waiting when s.totalAccounts == 0 => PhaseLook(
        l.stateWaiting,
        StatusColors.busy,
        l.waitingForAccount,
      ),
      // No enabled account, but some exist: they are all turned off.
      Phase.waiting when s.state.code == StateCode.noAccounts => PhaseLook(
        l.stateWaiting,
        StatusColors.busy,
        l.waitingForEnabledAccount,
      ),
      Phase.waiting => PhaseLook(l.stateWaiting, StatusColors.busy, message),
      Phase.error when s.state.proxyPortInUse => PhaseLook(
        l.stateError,
        StatusColors.bad,
        l.proxyPortInUse('${portOf(s.state.address) ?? s.state.address}'),
      ),
      Phase.error => PhaseLook(l.stateError, StatusColors.bad, message),
      // Turned off on the phone.
      Phase.off => PhaseLook(l.stateOff, StatusColors.idle, ''),
      _ => PhaseLook(l.stateUnknown, StatusColors.idle, message),
    };
  }
}

/// The engine state in the user's words, by its code; the core's own
/// English for a state without one, or with a code this app does not know.
String stateText(AppLocalizations l, EngineState s) => switch (s.code) {
  StateCode.waitingForNetwork => l.waitingForNetwork,
  StateCode.noAccounts => l.waitingForAccount,
  StateCode.noUsableAccount => l.failNoAccount,
  StateCode.startFailed when portOf(s.address) != null => l.proxyStartFailed(
    '${portOf(s.address)}',
  ),
  _ => s.message,
};

/// Words a [CoreUnavailable] for people.
String describeProblem(AppLocalizations l, CoreUnavailable e) =>
    switch (e.problem) {
      CoreProblem.starting => l.startingCore,
      CoreProblem.notAnswering => l.errNotAnswering,
      CoreProblem.refused => l.errRefused,
      CoreProblem.portInUse => l.errPortInUse(
        '${portOf(e.detail) ?? e.detail}',
      ),
      CoreProblem.noCore => l.errNoCore(e.detail),
      CoreProblem.exited => l.errCoreExited(e.detail),
    };

/// The color of a real delay: green when quick, amber when slow, red when
/// very slow.
Color delayColor(int ms) => ms < 400
    ? StatusColors.good
    : ms < 1000
    ? StatusColors.busy
    : StatusColors.bad;

/// Mozilla lists its recommended location as a country of its own, code
/// REC (named "Recomended Location").
bool isRecommendedPlace(String code) => code.toUpperCase() == 'REC';

/// A location's name for people: the recommended location in the user's
/// language, otherwise the country's name ([countryName]).
String locationName(AppLocalizations l, String code, String name) =>
    isRecommendedPlace(code)
    ? l.recommendedLocation
    : countryName(l, code, name);

/// The phone home's colors: a deep navy night and the state's light.
abstract final class Midnight {
  static const top = Color(0xFF141B3D);
  static const bottom = Color(0xFF070A18);
  static const connected = Color(0xFF10D9A0);
  static const busy = Color(0xFFFFB547);
  static const error = Color(0xFFFF5C7A);
  static const idle = Color(0xFF7C83FF);
  static const muted = Color(0xFF9AA3C7);
}

/// A dark theme for the phone's home and its navigation bar, with the
/// app's fonts.
ThemeData midnightTheme(ThemeData base) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Midnight.idle,
        brightness: Brightness.dark,
      ).copyWith(
        surface: Midnight.bottom,
        surfaceContainer: Midnight.bottom,
        onSurface: Colors.white,
        onSurfaceVariant: Midnight.muted,
        secondaryContainer: Colors.white.withValues(alpha: 0.10),
        onSecondaryContainer: Colors.white,
      );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: base.textTheme.bodyMedium?.fontFamily,
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: Midnight.bottom,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

/// A country's name in the app's language; in English (and for a country
/// without a translation) the server list's name [name], else the English
/// name of its code, else the code. A [name] that is only the code (the core
/// sends the code when the server list does not name the country) counts as
/// no name.
String countryName(AppLocalizations l, String code, [String name = '']) {
  final upper = code.toUpperCase();
  final local = localCountryNames[l.localeName]?[upper];
  if (local != null) return local;
  final named = name.isNotEmpty && name.toUpperCase() != upper;
  return named ? name : countryNames[upper] ?? code;
}

/// A key that sorts names the way people of [language] expect, which
/// String.compareTo (code units) does not: accented Latin letters next to
/// their base letter; the Persian letters پ چ ژ ک گ in their place in the
/// alphabet rather than after the Arabic ones; in Arabic, alif with or
/// without hamza as one letter, and ه before و.
String nameSortKey(String language, String name) {
  final lower = name.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final i = switch (language) {
      'fa' => _persianOrder.indexOf(ch),
      'ar' => _arabicOrder.indexWhere((letter) => letter.contains(ch)),
      _ => -1,
    };
    // Letters in alphabet order from U+0E00, past every Latin letter.
    out.write(i >= 0 ? String.fromCharCode(0x0E00 + i) : _latinBase[ch] ?? ch);
  }
  return out.toString();
}

const _persianOrder = 'آاأإبپتثجچحخدذرزژسشصضطظعغفقکكگلمنوؤهةیيئ';

/// The Arabic alphabet; the forms in one entry sort as one letter.
const _arabicOrder = [
  'اأإآ', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص', //
  'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'هة', 'وؤ', 'يىئ',
];

/// Accented Latin letters by their base letter, for sorting.
const _latinBase = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ă': 'a', //
  'ạ': 'a', 'ả': 'a', 'ấ': 'a', 'ầ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a', //
  'ắ': 'a', 'ằ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a', 'ç': 'c', 'đ': 'd', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e', //
  'ế': 'e', 'ề': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e', 'ə': 'e', 'ğ': 'g', //
  // The dot Dart's toLowerCase leaves after the i of Turkish İ.
  '̇': '',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ı': 'i', 'ỉ': 'i', //
  'ĩ': 'i', 'ị': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', //
  'ö': 'o', 'ő': 'o', 'ø': 'o', 'ơ': 'o', 'ọ': 'o', 'ỏ': 'o', 'ố': 'o', //
  'ồ': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o', 'ớ': 'o', 'ờ': 'o', 'ở': 'o', //
  'ỡ': 'o', 'ợ': 'o', 'ş': 's', 'š': 's', 'ù': 'u', 'ú': 'u', 'û': 'u', //
  'ü': 'u', 'ű': 'u', 'ư': 'u', 'ụ': 'u', 'ủ': 'u', 'ũ': 'u', 'ứ': 'u', //
  'ừ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u', 'ý': 'y', 'ỳ': 'y', 'ỷ': 'y', //
  'ỹ': 'y', 'ỵ': 'y', 'ž': 'z',
};

/// Why connecting fails, in the user's words, and the core's own text for
/// the details: from the newer of the last failed wake and the last failed
/// test. Only a network failure (or an unknown one) asks to check the
/// internet.
({String text, String detail, String code}) failureText(
  AppLocalizations l,
  ProxyInfo? proxy,
  ConnectionTest? test,
) {
  final failed = test != null && !test.ok ? test : null;
  var code = '';
  var detail = '';
  if (proxy != null &&
      proxy.wakeError.isNotEmpty &&
      (failed?.at == null ||
          (proxy.wakeFailedAt?.isAfter(failed!.at!) ?? false))) {
    (code, detail) = (proxy.wakeErrorCode, proxy.wakeError);
  } else if (failed != null) {
    (code, detail) = (failed.errorCode, failed.error);
  }
  return (text: failureCodeText(l, code), detail: detail, code: code);
}

/// What a [Failure] code means, in the user's words.
String failureCodeText(AppLocalizations l, String code) {
  return switch (code) {
    Failure.noNetwork => l.failNoInternet,
    Failure.unreachable => l.failUnreachable,
    Failure.refused => l.failRefused,
    Failure.locationRefused => l.failLocationRefused,
    Failure.signIn => l.failSignIn,
    Failure.quota => l.failQuota,
    Failure.notEntitled => l.failNotEntitled,
    Failure.region => l.failRegion,
    Failure.server => l.failServer,
    Failure.noAccount => l.failNoAccount,
    Failure.testSite => l.failTestSite,
    // The core's own words only on a long press (detail).
    Failure.other => l.failOther,
    _ => l.connectRetrying,
  };
}

/// The soft warning when the public IP is in another country than the
/// chosen one, with both countries named; null without a mismatch, and
/// always for the recommended location and the fastest one, which choose
/// no country.
String? exitMismatchText(AppLocalizations l, CoreStatus status) {
  final m = status.exitMismatch;
  final selection = status.selection.trim().toLowerCase();
  if (m == null ||
      selection.isEmpty ||
      selection == 'fastest' ||
      isRecommendedPlace(selection)) {
    return null;
  }
  return l.exitMismatch(
    countryName(l, m.exitCountryCode, m.exitCountryName),
    countryName(l, m.chosenCountryCode, m.chosenCountryName),
  );
}

/// Whether [code] says Mozilla refused the location the user chose, which
/// the home answers with a button to the recommended location.
bool isLocationRefused(String code) => code == Failure.locationRefused;

/// Where the phone's traffic goes, for its home page.
class HomePlace {
  const HomePlace(this.flag, this.name, this.caption, {this.auto = false});

  /// A country code for the flag ('REC' for the recommended location).
  final String flag;
  final String name;

  /// The line above the name: how the location is chosen, or what it is.
  final String caption;

  /// Chosen by the app (recommended or fastest): the caption says so.
  final bool auto;
}

/// The phone home's location. While connected: the country the traffic
/// leaves from (for the recommended location, the exit's country), under
/// how it was chosen; otherwise the chosen location.
HomePlace homeLocation(
  AppLocalizations l,
  CoreStatus status, {
  required bool connected,
}) {
  final proxy = status.proxy;
  final exit = status.exit;
  final selection = status.selection.toLowerCase();
  final auto = switch (selection) {
    '' => l.recommendedLocation,
    'fastest' => l.modeFastest,
    _ => null,
  };
  if (connected && proxy != null) {
    final (code, name) = !isRecommendedPlace(proxy.countryCode)
        ? (proxy.countryCode, proxy.countryName)
        : exit != null && exit.countryCode.length == 2
        ? (exit.countryCode, exit.countryName)
        : ('', '');
    if (code.isNotEmpty) {
      return HomePlace(
        code,
        countryName(l, code, name),
        auto ?? l.connectedTo,
        auto: auto != null,
      );
    }
  }
  if (auto != null) return HomePlace('REC', auto, l.homeLocation);
  return HomePlace(
    status.selection.toUpperCase(),
    countryName(l, status.selection, status.selectionName),
    l.homeLocation,
  );
}

/// The notes the home pages show: not the ports Mozilla refuses, which
/// apps (every app, in the phone's VPN) try before falling back to 443;
/// the logs keep those.
List<Notice> homeNotices(List<Notice> notices) => [
  for (final n in notices)
    if (n.kind != 'port') n,
];

/// A country's flag, 4:3 with rounded corners; a star for the recommended
/// location, and the code in a small box when there is no flag for it.
class CountryFlag extends StatelessWidget {
  const CountryFlag({super.key, required this.code, this.width = 28});

  final String code;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = width * 3 / 4;
    final fallback = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: scheme.secondaryContainer,
      child: Text(
        code.toUpperCase(),
        style: TextStyle(
          fontSize: height * 0.45,
          fontWeight: FontWeight.w700,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.6),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: isRecommendedPlace(code)
          ? Container(
              width: width,
              height: height,
              alignment: Alignment.center,
              color: scheme.primaryContainer,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: height * 0.7,
                color: scheme.onPrimaryContainer,
              ),
            )
          : code.length != 2
          ? fallback
          : bundledFlags.contains(code.toLowerCase())
          ? SvgPicture.asset(
              'assets/flags/${code.toLowerCase()}.svg',
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          // Not carried: from the core, the code until it arrives.
          : FutureBuilder(
              future: RemoteFlags.load(code.toLowerCase()),
              builder: (context, snapshot) => switch (snapshot.data) {
                final svg? => SvgPicture.memory(
                  svg,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                ),
                null => fallback,
              },
            ),
    );
  }
}

/// The name of a routing region (`routing.region`) in the UI language.
String regionName(AppLocalizations l, String code) => switch (code) {
  'ir' => l.regionIr,
  'cn' => l.regionCn,
  'ru' => l.regionRu,
  'af' => l.regionAf,
  'tr' => l.regionTr,
  'id' => l.regionId,
  'br' => l.regionBr,
  _ => l.regionNone,
};

/// The languages, each in its own words.
const languageNames = {
  'en': 'English',
  'fa': 'فارسی',
  'ar': 'العربية',
  'zh': '简体中文',
  'zh_Hant': '繁體中文',
  'ru': 'Русский',
  'es': 'Español',
  'pt': 'Português (Brasil)',
  'tr': 'Türkçe',
  'fr': 'Français',
  'hu': 'Magyar',
  'id': 'Bahasa Indonesia',
  'az': 'Azərbaycan dili',
  'vi': 'Tiếng Việt',
  'bn': 'বাংলা',
};

/// The bundled font for a language: Vazirmatn for the Arabic script
/// (Persian, Arabic); null for the system font.
String? languageFont(String code) =>
    const {'fa', 'ar'}.contains(code) ? 'Vazirmatn' : null;

/// A title or label in its own language's font.
TextStyle? languageStyle(String code) => switch (languageFont(code)) {
  final font? => TextStyle(fontFamily: font),
  null => null,
};

/// The margin around a page: narrower on a phone.
EdgeInsets pagePadding(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600
    ? const EdgeInsets.fromLTRB(16, 16, 16, 20)
    : const EdgeInsets.fromLTRB(28, 24, 28, 28);

/// Marks a page opened with its own top bar (Android), which names it.
class OwnTopBar extends InheritedWidget {
  const OwnTopBar({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OwnTopBar>() != null;

  @override
  bool updateShouldNotify(OwnTopBar oldWidget) => false;
}

/// A page's title; nothing when the page has its own top bar.
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => OwnTopBar.of(context)
      ? const SizedBox.shrink()
      : Text(text, style: Theme.of(context).textTheme.headlineSmall);
}

/// A titled card section.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// The color of a quota by the share used, as the web dashboard shows it:
/// amber from 10 points before the account-switch threshold, red from the
/// threshold (where another account takes over, or, with none left, the
/// last share is being used). Without a threshold, the core's default.
Color quotaColor(double usedPercent, double thresholdPercent) {
  final threshold = thresholdPercent > 0 ? thresholdPercent : 95.0;
  return usedPercent >= threshold
      ? StatusColors.bad
      : usedPercent >= threshold - 10
      ? StatusColors.busy
      : StatusColors.good;
}

/// A usage bar with the account-switch threshold marked.
class QuotaBar extends StatelessWidget {
  const QuotaBar({super.key, required this.percent, this.threshold = 0});

  final double percent;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = (percent / 100).clamp(0.0, 1.0);
    final color = quotaColor(percent, threshold);
    return SizedBox(
      height: 8,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  color: color,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
            if (threshold > 0 && threshold < 100)
              PositionedDirectional(
                start: box.maxWidth * threshold / 100 - 1,
                top: -3,
                bottom: -3,
                child: Tooltip(
                  message: AppLocalizations.of(context)
                      .switchAt(threshold.round()),
                  child: Container(width: 2, color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small rounded label.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c),
          ),
        ],
      ),
    );
  }
}

/// Runs [action] and shows its error, if any, in a snack bar.
Future<bool> runShowingErrors(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } on CoreApiException catch (e) {
    if (context.mounted) showError(context, e.message);
  } on CoreUnavailable catch (e) {
    if (context.mounted) {
      showError(context, describeProblem(AppLocalizations.of(context), e));
    }
  } on VpnNotAllowed {
    if (context.mounted) {
      showError(context, AppLocalizations.of(context).vpnNotAllowed);
    }
  }
  return false;
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        width: 520,
      ),
    );
}
