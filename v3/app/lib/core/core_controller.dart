import 'dart:async';

import 'package:flutter/foundation.dart';

import 'core_api.dart';
import 'remote_flags.dart';
import 'models.dart';
import 'ports.dart';

/// Connects to the core, polls its status and accounts, and runs the
/// user's actions. It holds no VPN logic: every decision is the core's.
class CoreController extends ChangeNotifier {
  CoreController(
    this._connect, {
    this.pollInterval = const Duration(seconds: 2),
    this.moveStoppedCore,
    this.retryStoppedCore,
    this.turnOn,
  });

  /// Turns the proxy on or off where the app has a switch for the whole
  /// proxy (Android, which has no system proxy); null elsewhere.
  final Future<void> Function(bool on)? turnOn;

  /// Moves a core that could not start to another API port (it edits the
  /// core's config.json, since the core is not there to ask); null where
  /// the app does not start the core.
  final Future<void> Function(int port)? moveStoppedCore;

  /// Lets a core that stopped right after starting start again.
  final Future<void> Function()? retryStoppedCore;

  /// Opens a client; it throws [CoreUnavailable] while there is no core.
  final Future<CoreApi> Function() _connect;
  final Duration pollInterval;

  CoreApi? _api;
  Timer? _timer;

  /// A quick retry while the core is starting, so the app shows it as soon
  /// as its API answers rather than at the next poll.
  Timer? _quick;
  bool _polling = false;
  int _tick = 0;

  /// Failed reads in a row while the core answered before; the first one
  /// is retried at once instead of showing the core as lost.
  int _failures = 0;
  bool _disposed = false;

  CoreStatus? status;
  AccountList? accounts;

  /// Why the core cannot be reached; null while it answers.
  CoreUnavailable? unavailable;

  /// The system proxy mode, or the proxy's power, is being changed.
  bool switchingProxy = false;
  bool testing = false;

  /// The latest connection test, ours or the core's automatic one.
  ConnectionTest? get lastTest => _test ?? status?.lastTest;
  ConnectionTest? _test;

  /// When the phone may test the connection again (_retestUnconfirmed).
  DateTime? _retestAt;

  /// The wait before the next unconfirmed test: it doubles from 5 seconds
  /// to a minute while tests keep failing, so an unreachable Mozilla is not
  /// asked for a pass every few seconds.
  Duration _retestDelay = _retestFirst;
  static const _retestFirst = Duration(seconds: 5);
  static const _retestMax = Duration(minutes: 1);

  /// What the last poll showed of the connection: a new one (the proxy
  /// started again, the network changed, the phase came back to running)
  /// is tested soon again, not after an old backoff.
  String? _seenConnection;

  /// The last log entry the logs page had read when it was cleared, and
  /// when: the page starts after that entry and leaves out anything logged
  /// before the moment, for as long as the app runs.
  int logsClearedAfter = 0;
  DateTime? logsClearedAt;

  /// Accounts with an action in progress.
  final Set<String> busyAccounts = {};

  CoreApi? get api => _api;
  bool get connected => _api != null && unavailable == null;

  void start() {
    _timer ??= Timer.periodic(pollInterval, (_) => refresh());
    refresh();
  }

  /// Reads the status, and the accounts every third tick (the core reads
  /// them from disk). [accountsToo] reads them now.
  Future<void> refresh({bool accountsToo = false}) async {
    if (_polling || _disposed) return;
    _polling = true;
    try {
      final api = _api ??= await _connect();
      // Flags the app does not carry come from this core.
      RemoteFlags.use(api);
      final next = await api.status();
      final readAccounts = accountsToo || accounts == null || _tick % 3 == 0;
      _tick++;
      status = next;
      // The phone's VPN while on; the computer's proxy, which always runs,
      // in either mode.
      if (turnOn != null || next.systemProxySupported) {
        _retestUnconfirmed(next);
      }
      if (_test != null &&
          next.lastTest?.at != null &&
          _test!.at != null &&
          next.lastTest!.at!.isAfter(_test!.at!)) {
        _test = null;
      }
      if (readAccounts) accounts = await api.accounts();
      unavailable = null;
      _failures = 0;
    } on CoreUnavailable catch (e) {
      // One failed read while the core answered is tried again at once:
      // Android closes the app's open connections, the one to the core
      // included, when the phone's network goes away.
      if (unavailable == null && status != null && _failures == 0) {
        _failures++;
      } else {
        _lost(e);
      }
    } on CoreApiException catch (e) {
      // 401/403: the token changed (another core took the address); find
      // the core again. Other errors are passing.
      if (e.statusCode == 401 || e.statusCode == 403) {
        _lost(CoreUnavailable(CoreProblem.refused, e.message));
      }
    } finally {
      _polling = false;
      if (!_disposed) {
        notifyListeners();
        if ((unavailable?.problem == CoreProblem.starting || _failures > 0) &&
            _timer != null) {
          _quick?.cancel();
          _quick = Timer(const Duration(milliseconds: 250), refresh);
        }
      }
    }
  }

  void _lost(CoreUnavailable problem) {
    _failures = 0;
    _api?.close();
    _api = null;
    unavailable = problem;
  }

  Future<void> runTest() => _act(() async {
    testing = true;
    notifyListeners();
    try {
      _test = await _require().test();
    } finally {
      testing = false;
      // Any test, the user's too, puts the next unconfirmed one off by the
      // current step, counted from its end: a slow failing test is not
      // followed by another at once.
      _retestAt = DateTime.now().add(
        _retestAt == null ? _retestFirst : _retestDelay ~/ 2,
      );
    }
  });

  Future<void> restartProxy() => _act(() => _require().restartProxy());

  /// Sets the system proxy mode: set (Windows uses the VPN) or clear.
  Future<void> setSystemProxy(String mode) => _act(() async {
    switchingProxy = true;
    notifyListeners();
    try {
      await _require().setSystemProxy(mode);
    } finally {
      switchingProxy = false;
    }
  });

  /// Turns the proxy on or off ([turnOn] on the phone, the core's API on the
  /// computer) and waits, briefly, until the core reports it.
  Future<void> setOn(bool on) => _act(() async {
    switchingProxy = true;
    notifyListeners();
    try {
      await (turnOn ?? _require().setPower)(on);
      final api = _require();
      for (var i = 0; i < 20; i++) {
        final next = await api.status();
        status = next;
        if ((next.state.phase == Phase.off) != on) break;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    } finally {
      switchingProxy = false;
    }
  });

  /// The user is looking (the app came to the front): the core tries the
  /// next connection at once instead of waiting after a failure. At most
  /// every few seconds.
  Future<void> retryNow() async {
    final now = DateTime.now();
    if (_retriedAt != null && now.difference(_retriedAt!) < _retryGap) return;
    _retriedAt = now;
    try {
      await _api?.retry();
    } on Exception {
      // Not answering: the next poll says so.
    }
  }

  DateTime? _retriedAt;
  static const _retryGap = Duration(seconds: 5);

  /// Turns the proxy on by itself, for an app started with the computer.
  Future<void> autoConnect() => _act(() => _require().autoConnect());

  /// The core's config.json as raw JSON.
  Future<Map<String, Object?>> settings() => _require().settings();

  /// Changes the core's config: [edit] changes the raw JSON in place.
  Future<void> editSettings(void Function(Map<String, Object?> config) edit) =>
      _act(() async {
        final api = _require();
        final config = await api.settings();
        edit(config);
        await api.saveSettings(config);
      });

  Future<void> openFolder() => _act(() => _require().openFolder());

  /// A fresh sign-in link to the web dashboard.
  Future<Uri> dashboardLink() => _require().loginLink();

  /// Tries the core again at once, also one that stopped right after
  /// starting.
  Future<void> retry() async {
    await retryStoppedCore?.call();
    await refresh(accountsToo: true);
  }

  /// Moves the core's API to [port]: through the core while it runs, or in
  /// its config.json when it could not start.
  Future<void> setAppPort(int port) async {
    if (_api != null) {
      await editSettings((config) {
        final dashboard = config['dashboard'];
        if (dashboard is Map<String, Object?>) {
          dashboard['listen'] = withPort(
            dashboard['listen'] as String? ?? '',
            port,
          );
        }
      });
      return;
    }
    await moveStoppedCore?.call(port);
    await refresh(accountsToo: true);
  }

  /// Moves the proxy (SOCKS5 and HTTP) to [port]; the core restarts it.
  Future<void> setProxyPort(int port) => editSettings((config) {
    final proxy = config['proxy'];
    if (proxy is Map<String, Object?>) {
      proxy['listen'] = withPort(proxy['listen'] as String? ?? '', port);
    }
  });

  /// Runs a request for a page (servers, logs, routing tools) with the
  /// connection's error handling; errors reach the caller.
  Future<T> call<T>(Future<T> Function(CoreApi api) request) async {
    try {
      return await request(_require());
    } on CoreUnavailable catch (e) {
      _lost(e);
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  /// Chooses the location (a country code, `fastest`, or empty for the
  /// recommended one); the proxy restarts on it.
  Future<void> setLocation(String country) =>
      _act(() => _require().setLocation(country));

  /// Stops polling, before the app quits.
  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> activate(Account a) =>
      _account(a.id, () => _require().activateAccount(a.id));

  Future<void> setEnabled(Account a, bool enabled) =>
      _account(a.id, () => _require().setAccountEnabled(a.id, enabled));

  Future<void> refreshQuota(Account a) =>
      _account(a.id, () => _require().refreshAccount(a.id));

  Future<void> remove(Account a) =>
      _account(a.id, () => _require().removeAccount(a.id));

  /// Moves [a] by [delta] places in the priority order.
  Future<void> move(Account a, int delta) {
    final list = [...?accounts?.accounts];
    final from = list.indexWhere((x) => x.id == a.id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) return Future.value();
    list.insert(to, list.removeAt(from));
    return _act(() => _require().setAccountOrder([for (final x in list) x.id]));
  }

  Future<void> _account(String id, Future<void> Function() action) async {
    busyAccounts.add(id);
    notifyListeners();
    try {
      await _act(action);
    } finally {
      busyAccounts.remove(id);
      if (!_disposed) notifyListeners();
    }
  }

  /// Runs [action], then reads the status and accounts again. Errors reach
  /// the caller, which shows them.
  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } on CoreUnavailable catch (e) {
      _lost(e);
      rethrow;
    } finally {
      if (!_disposed) {
        notifyListeners();
        unawaited(refresh(accountsToo: true));
      }
    }
  }

  /// The home page shows "Connecting" until a test confirms the connection
  /// (CoreStatus.confirmedBy); until then it tests again after 5 seconds,
  /// then less often (up to once a minute) while tests keep failing.
  void _retestUnconfirmed(CoreStatus s) {
    final connection = s.state.phase == Phase.running
        ? '${s.proxy?.startedAt}|${s.networkChangedAt}'
        : null;
    if (connection != _seenConnection) {
      _seenConnection = connection;
      _retestAt = null;
      _retestDelay = _retestFirst;
    }
    if (s.state.phase != Phase.running || testing || switchingProxy) return;
    if (s.noNetwork) return;
    // The core's auto-connect tests by itself.
    if (s.autoConnecting) return;
    if (s.confirmedBy(lastTest)) {
      _retestAt = null;
      _retestDelay = _retestFirst;
      return;
    }
    final now = DateTime.now();
    if (_retestAt != null && now.isBefore(_retestAt!)) return;
    _retestAt = now.add(_retestDelay);
    final doubled = _retestDelay * 2;
    _retestDelay = doubled > _retestMax ? _retestMax : doubled;
    unawaited(runTest().catchError((Object _) {}));
  }

  CoreApi _require() {
    final api = _api;
    if (api == null) {
      throw unavailable ?? const CoreUnavailable(CoreProblem.notAnswering);
    }
    return api;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _quick?.cancel();
    _api?.close();
    super.dispose();
  }
}
