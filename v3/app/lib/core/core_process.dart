import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'core_api.dart';
import 'ports.dart';

/// Runs the core as a child process for as long as the app runs (desktop).
///
/// The core starts with `-app`: no tray, no console, and it exits when its
/// stdin closes, so it never outlives the app, even after a crash. When a
/// core already serves the data folder (started by hand, or another copy of
/// the app), the app uses it and leaves it running on quit.
class CoreProcess {
  CoreProcess({required this.executable, required this.dataDir});

  final String executable;
  final String dataDir;

  Process? _process;
  bool _running = false;
  DateTime? _startedAt;

  /// The core stopped soon after starting; it is not started again until
  /// [retryNow], so a lasting problem (a taken port) does not loop.
  bool _failedFast = false;
  final _stderr = <String>[];

  /// The core's last structured error: `app-error: <code> <detail>` on
  /// stderr (core/doc/OPERATOR.md, desktop app mode).
  ({String code, String detail})? _appError;

  /// Whether this app started the core that is running now.
  bool get owned => _process != null && _running;

  /// The default executable, or `--core=<path>`: in the `core` folder
  /// beside the app (Windows, Linux), so the app is the only program there;
  /// beside the app's executable inside the bundle on macOS.
  static String executableFrom(List<String> args) {
    for (final a in args) {
      if (a.startsWith('--core=')) return a.substring('--core='.length);
    }
    final sep = Platform.pathSeparator;
    final dir = File(Platform.resolvedExecutable).parent.path;
    if (Platform.isMacOS) return '$dir${sep}firefox-vpn-core';
    final name = Platform.isWindows
        ? 'firefox-vpn-core.exe'
        : 'firefox-vpn-core';
    return '$dir${sep}core$sep$name';
  }

  /// Opens a client of the core, starting the core when none answers. It
  /// throws [CoreUnavailable] until the core is ready.
  Future<CoreApi> connect() async {
    // Windows takes about two seconds to refuse a connection to a loopback
    // port nobody listens on; a bind test answers at once. Nothing there:
    // start the core (or wait for the one starting) without that delay.
    final port = portOf(await CoreLocator.dashboardListen(dataDir));
    if (port != null && await isFree(port)) {
      if (_running) throw const CoreUnavailable(CoreProblem.starting);
      if (!_failedFast) {
        if (!File(executable).existsSync()) {
          throw CoreUnavailable(CoreProblem.noCore, executable);
        }
        await _start();
        throw const CoreUnavailable(CoreProblem.starting);
      }
    }
    try {
      final api = CoreApi(await CoreLocator.locate(dataDir));
      try {
        await api.status();
        return api;
      } on Exception {
        api.close();
        rethrow;
      }
    } on CoreUnavailable {
      // Nothing answers: start the core below.
    } on CoreApiException {
      // Something else answers at the address: another program, or another
      // copy's core. The API moves; failing that, the user is asked.
      if (await _moveApi()) throw const CoreUnavailable(CoreProblem.starting);
      throw CoreUnavailable(
        CoreProblem.refused,
        await CoreLocator.dashboardListen(dataDir),
      );
    }
    if (_running) {
      // Started and still coming up; the next poll tries again.
      throw const CoreUnavailable(CoreProblem.starting);
    }
    if (_failedFast) {
      // It stopped right after starting: report why instead of looping.
      final error = _appError;
      // Its API's port is held, or Windows keeps it for itself (WSL and
      // Docker reserve ranges); nothing of ours answers there.
      if (error?.code == 'dashboard_port_in_use' ||
          (port != null && !await isFree(port))) {
        if (await _moveApi()) {
          throw const CoreUnavailable(CoreProblem.starting);
        }
      }
      if (error != null && error.code == 'dashboard_port_in_use') {
        throw CoreUnavailable(CoreProblem.portInUse, error.detail);
      }
      throw CoreUnavailable(
        CoreProblem.exited,
        error?.detail ?? _stderr.join(' '),
      );
    }
    if (!File(executable).existsSync()) {
      throw CoreUnavailable(CoreProblem.noCore, executable);
    }
    await _start();
    throw const CoreUnavailable(CoreProblem.starting);
  }

  /// Lets the next [connect] start the core at once, after the user fixed
  /// what stopped it (such as its port).
  void retryNow() => _failedFast = false;

  /// Times the API was moved this run: a few, so a lasting problem ends in
  /// the "can't reach the core" page instead of a loop.
  int _apiMoves = 0;

  /// Moves the core's API to a free port above its own, in config.json,
  /// for the core to start there. Unlike the proxy's port, which the user
  /// may have set up in other programs, only this app uses it, and it finds
  /// the port in that file. False when it was moved enough already.
  Future<bool> _moveApi() async {
    if (_apiMoves >= 3) return false;
    _apiMoves++;
    final listen = await CoreLocator.dashboardListen(dataDir);
    final port = await findFreePort(portOf(listen) ?? 10820);
    await CoreLocator.setDashboardListen(dataDir, withPort(listen, port));
    _failedFast = false;
    return true;
  }

  Future<void> _start() async {
    _stderr.clear();
    _appError = null;
    _startedAt = DateTime.now();
    // On Windows detachedWithStdio: no console window for the
    // console-subsystem core, and stdin stays a pipe that closes when this
    // process ends. Elsewhere a plain child, which the app reaps (a detached
    // one leaves a zombie on Linux).
    final p = await Process.start(
      executable,
      ['-app', '-data-dir', dataDir],
      mode: Platform.isWindows
          ? ProcessStartMode.detachedWithStdio
          : ProcessStartMode.normal,
    );
    _process = p;
    _running = true;
    p.stdout.drain<void>();
    p.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.startsWith('app-error: ')) {
              final rest = line.substring('app-error: '.length);
              final space = rest.indexOf(' ');
              _appError = space < 0
                  ? (code: rest, detail: '')
                  : (
                      code: rest.substring(0, space),
                      detail: rest.substring(space + 1),
                    );
            }
            _stderr.add(line);
            if (_stderr.length > 5) _stderr.removeAt(0);
          },
          // The pipe closes when the core exits.
          onDone: () {
            if (_process != p) return;
            _running = false;
            final started = _startedAt;
            _failedFast =
                started != null &&
                DateTime.now().difference(started) <
                    const Duration(seconds: 15);
          },
        );
  }

  /// Ends the core if this app started it: asks it to exit, then closes its
  /// stdin, which ends it too.
  Future<void> stop(CoreApi? api) async {
    final p = _process;
    if (p == null || !_running) return;
    try {
      await api?.exitCore().timeout(const Duration(seconds: 3));
    } on Exception {
      // Closing stdin below stops it anyway.
    }
    try {
      await p.stdin.close().timeout(const Duration(seconds: 1));
    } on Exception {
      // Already gone.
    }
    // Give it a moment to restore the system proxy before the app exits.
    for (var i = 0; i < 30 && _running; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    _process = null;
    _running = false;
  }
}
