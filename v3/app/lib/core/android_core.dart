import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'core_api.dart';

/// An app installed on the phone.
@immutable
class InstalledApp {
  const InstalledApp(this.package, this.label);

  final String package;
  final String label;
}

/// Which apps use the VPN (CoreService.kt), in v2rayN's words: bypass the
/// selected apps ([bypass]), or proxy only the selected apps ([only]).
class AppRouting {
  AppRouting({
    required this.onlyChosen,
    required this.bypass,
    required this.only,
    required this.suggested,
  });

  /// Proxy selected apps; otherwise bypass them.
  bool onlyChosen;

  /// Bypass selected apps: these connect directly.
  final Set<String> bypass;

  /// Proxy selected apps: only these use the VPN.
  final Set<String> only;

  /// The routing region's apps (from the core), suggested for bypassing:
  /// checked at first, then only by the user's choice.
  final Set<String> suggested;

  Set<String> get _chosen => onlyChosen ? only : bypass;

  /// Whether [package] is checked in the current mode.
  bool checked(String package) => _chosen.contains(package);

  void toggle(String package, bool on) =>
      on ? _chosen.add(package) : _chosen.remove(package);

  /// Checks the suggested apps that are installed; returns how many were
  /// not checked yet.
  int checkSuggested(Iterable<String> installed) {
    final add = installed.where(suggested.contains).toSet()..removeAll(bypass);
    bypass.addAll(add);
    return add.length;
  }

  /// A key that changes with the choice, to know whether to apply it.
  String get key => [
    onlyChosen,
    ...[bypass, only].map((s) => (s.toList()..sort()).join(',')),
  ].join('|');
}

/// The user did not allow the app to set up a VPN.
class VpnNotAllowed implements Exception {
  const VpnNotAllowed();
}

/// The core on Android: it runs in this app's process. It starts with the
/// proxy off while the UI is open, so settings and accounts work; turned
/// on, a foreground service (android/.../CoreService.kt) keeps it running
/// for other apps while the UI is closed. The UI talks to it through the
/// same HTTP API.
class AndroidCore {
  static const _channel = MethodChannel('app/android');

  /// The core's data folder inside the app's private storage.
  static Future<String> dataDir() async =>
      await _channel.invokeMethod<String>('dataDir') ?? '';

  AndroidCore(this._dataDir);

  final String _dataDir;

  /// Opens a client of the core, starting the core (off) when it does not
  /// run; it throws [CoreUnavailable] until the core answers.
  Future<CoreApi> connect() async {
    if (await _channel.invokeMethod<bool>('isRunning') != true) {
      await _channel.invokeMethod<void>('startCore');
      throw const CoreUnavailable(CoreProblem.starting);
    }
    try {
      final api = CoreApi(await CoreLocator.locate(_dataDir));
      try {
        await api.status();
        return api;
      } on Exception {
        api.close();
        rethrow;
      }
    } on CoreUnavailable {
      // Started, and its API is still coming up.
      throw const CoreUnavailable(CoreProblem.starting);
    }
  }

  /// Turns the VPN on (asking the user for the VPN permission the first
  /// time) or off. It throws [VpnNotAllowed] when the user refuses.
  static Future<void> setOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('setOn', {'on': on});
    } on PlatformException catch (e) {
      if (e.code == 'vpn_denied') throw const VpnNotAllowed();
      throw CoreApiException(0, e.message ?? e.code);
    }
  }

  /// The connection mode: 'vpn' (every app on the phone) or 'proxy' (only
  /// apps set up to use the local proxy). Read at start ([loadMode]).
  static final mode = ValueNotifier<String>('vpn');

  static Future<void> loadMode() async {
    mode.value = await _channel.invokeMethod<String>('connectionMode') ?? 'vpn';
    showSpeed.value = await _channel.invokeMethod<bool>('showSpeed') ?? false;
  }

  /// Whether the notification shows the speed (CoreService.kt reads it).
  static final showSpeed = ValueNotifier<bool>(false);

  static Future<void> setShowSpeed(bool on) async {
    await _channel.invokeMethod<void>('setShowSpeed', {'on': on});
    showSpeed.value = on;
  }

  /// Keeps the mode; a running proxy switches at once. Switching to the
  /// VPN the first time turns it off and on again, so Android asks for the
  /// VPN permission; it throws [VpnNotAllowed] when the user refuses.
  static Future<void> setMode(String value) async {
    try {
      await _channel.invokeMethod<void>('setConnectionMode', {'mode': value});
      mode.value = value;
    } on PlatformException catch (e) {
      if (e.code != 'vpn_denied') rethrow;
      await setOn(false);
      await _channel.invokeMethod<void>('setConnectionMode', {'mode': value});
      mode.value = value;
      await setOn(true);
    }
  }

  /// The apps with a launcher icon, but this one.
  static Future<List<InstalledApp>> installedApps() async {
    final list = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'installedApps',
    );
    return [
      for (final m in list ?? const <Map<Object?, Object?>>[])
        InstalledApp('${m['package']}', '${m['label']}'),
    ];
  }

  /// An app's icon as PNG.
  static Future<Uint8List?> appIcon(String package) =>
      _channel.invokeMethod<Uint8List>('appIcon', {'package': package});

  /// Which apps use the VPN.
  static Future<AppRouting> appRouting() async {
    final m =
        await _channel.invokeMapMethod<String, Object?>('appRouting') ??
        const {};
    Set<String> set(String key) => {
      for (final p in (m[key] as List<Object?>? ?? const [])) '$p',
    };
    return AppRouting(
      onlyChosen: m['mode'] == 'include',
      bypass: set('bypass'),
      only: set('only'),
      suggested: set('region'),
    );
  }

  /// Keeps which apps use the VPN; [apply] sets a running VPN up again.
  static Future<void> setAppRouting(AppRouting r, {required bool apply}) =>
      _channel.invokeMethod<void>('setAppRouting', {
        'mode': r.onlyChosen ? 'include' : 'exclude',
        'bypass': r.bypass.toList(),
        'only': r.only.toList(),
        'apply': apply,
      });

  /// The phone's main processor type, such as arm64-v8a.
  static Future<String> abi() async =>
      await _channel.invokeMethod<String>('abi') ?? '';

  /// Opens [url] in the app that handles it (such as a tg:// link).
  static Future<bool> openUrl(String url) async =>
      await _channel.invokeMethod<bool>('openUrl', {'url': url}) ?? false;
}
