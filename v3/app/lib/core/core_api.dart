import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'models.dart';

/// Where the core's API listens and the local token that authorizes the
/// app (`X-Local-Token`, read from `local-api.token` in the data folder).
class CoreEndpoint {
  const CoreEndpoint(this.baseUri, this.token);

  final Uri baseUri;
  final String token;
}

/// Why the app cannot reach the core; the UI words it.
enum CoreProblem {
  /// The app started the core and waits for its API.
  starting,

  /// No token in the data folder, or nothing answers at the address.
  notAnswering,

  /// Something else answers at the core's address (another program, or
  /// another copy's core); [CoreUnavailable.detail] is the address.
  refused,

  /// The core's address is taken by another program; the detail is the
  /// address. The user can move the core to another port.
  portInUse,

  /// The core executable is missing; [CoreUnavailable.detail] is its path.
  noCore,

  /// The core the app started has stopped; the detail is its last error.
  exited,
}

class CoreUnavailable implements Exception {
  const CoreUnavailable(this.problem, [this.detail = '']);

  final CoreProblem problem;
  final String detail;

  @override
  String toString() =>
      detail.isEmpty ? problem.name : '${problem.name}: $detail';
}

/// An error answer of the API (`{"error": "..."}` with a 4xx/5xx status).
class CoreApiException implements Exception {
  const CoreApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// Finds the core from its data folder: the token file and the dashboard
/// address in `config.json` (default `127.0.0.1:10820`).
abstract final class CoreLocator {
  static const tokenFile = 'local-api.token';
  static const configFile = 'config.json';
  static const defaultListen = '127.0.0.1:10820';
  static const _defaultPort = 10820;

  /// The folder name under the per-user data location (macOS).
  static const appFolder = 'Firefox VPN Client';

  /// The file next to the app that makes it portable: its data stays in
  /// `user-data` beside it instead of the per-user location.
  static const portableMarker = 'portable';

  /// The data folder to use (accounts, settings, logs): `--data-dir=<path>`
  /// among [args]; else, on Windows, `user-data` next to the app (the
  /// installer and the portable zip both keep the app in a folder of the
  /// user's own, which a new version replaces in place); elsewhere
  /// `user-data` next to the app when a `portable` file is there, else the
  /// per-user location.
  static String dataDir(List<String> args) {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return dataDirFor(
      args: args,
      exeDir: exeDir,
      portable: File('$exeDir${Platform.pathSeparator}$portableMarker')
          .existsSync(),
      env: Platform.environment,
      os: Platform.operatingSystem,
    );
  }

  /// [dataDir] without the file system, for tests.
  static String dataDirFor({
    required List<String> args,
    required String exeDir,
    required bool portable,
    required Map<String, String> env,
    required String os,
  }) {
    for (final a in args) {
      if (a.startsWith('--data-dir=')) return a.substring('--data-dir='.length);
    }
    final sep = os == 'windows' ? r'\' : '/';
    // Not `data`: Flutter keeps its own files in a `data` folder there.
    if (portable || os == 'windows') return '$exeDir${sep}user-data';
    final home = env['HOME'] ?? env['USERPROFILE'] ?? exeDir;
    return switch (os) {
      'macos' => '$home/Library/Application Support/$appFolder',
      _ => '${env['XDG_DATA_HOME'] ?? '$home/.local/share'}/firefox-vpn-client',
    };
  }

  static Future<CoreEndpoint> locate(String dataDir) async {
    final sep = Platform.pathSeparator;
    final tokenPath = File('$dataDir$sep$tokenFile');
    String token;
    try {
      token = (await tokenPath.readAsString()).trim();
    } on FileSystemException {
      throw CoreUnavailable(CoreProblem.notAnswering, tokenPath.path);
    }
    if (token.isEmpty) {
      throw CoreUnavailable(CoreProblem.notAnswering, tokenPath.path);
    }
    final listen = await dashboardListen(dataDir);
    return CoreEndpoint(listenUri(listen), token);
  }

  /// The loopback URL that reaches a listen address; a wildcard host
  /// (`0.0.0.0`, `::`, empty) is reached on 127.0.0.1.
  static Uri listenUri(String listen) {
    final colon = listen.lastIndexOf(':');
    var host = colon < 0 ? listen : listen.substring(0, colon);
    final port = colon < 0
        ? _defaultPort
        : int.tryParse(listen.substring(colon + 1));
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }
    if (host.isEmpty || host == '0.0.0.0' || host == '::') host = '127.0.0.1';
    return Uri(scheme: 'http', host: host, port: port ?? _defaultPort);
  }

  /// The address the core's API listens on, from config.json.
  static Future<String> dashboardListen(String dataDir) async {
    final config = await _readConfig(dataDir);
    return switch (config) {
      {'dashboard': {'listen': final String l}} when l.isNotEmpty => l,
      _ => defaultListen,
    };
  }

  /// Moves the core's API to [listen] in config.json while the core is not
  /// running (it could not start on the old address). Every other field is
  /// kept as it is.
  static Future<void> setDashboardListen(String dataDir, String listen) async {
    final config = await _readConfig(dataDir) ?? <String, Object?>{};
    final dashboard = switch (config['dashboard']) {
      final Map<String, Object?> d => d,
      _ => config['dashboard'] = <String, Object?>{},
    };
    dashboard['listen'] = listen;
    final file = File('$dataDir${Platform.pathSeparator}$configFile');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );
  }

  static Future<Map<String, Object?>?> _readConfig(String dataDir) async {
    try {
      final j = jsonDecode(
        await File('$dataDir${Platform.pathSeparator}$configFile')
            .readAsString(),
      );
      return j is Map<String, Object?> ? j : null;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }
}

/// A client of the core's dashboard API (core/doc/DASHBOARD.md).
class CoreApi {
  CoreApi(this.endpoint, {HttpClient? client})
    : _client = client ?? HttpClient() {
    _client
      ..connectionTimeout = const Duration(seconds: 3)
      // The core is on loopback; never route it through a system proxy.
      ..findProxy = (_) => 'DIRECT';
  }

  final CoreEndpoint endpoint;
  final HttpClient _client;

  void close() => _client.close(force: true);

  Future<CoreStatus> status() async =>
      CoreStatus.fromJson(await _json('GET', '/api/status'));

  Future<AccountList> accounts() async =>
      AccountList.fromJson(await _json('GET', '/api/accounts'));

  /// Runs the connection test; the proxy must be running (409 otherwise).
  Future<ConnectionTest> test() async => ConnectionTest.fromJson(
    await _json('POST', '/api/test', const {}, _slow),
  );

  Future<void> restartProxy() => _json('POST', '/api/proxy/restart', const {});

  Future<void> activateAccount(String id) =>
      _json('POST', '/api/accounts/${_seg(id)}/activate', const {});

  Future<void> setAccountEnabled(String id, bool enabled) =>
      _json('POST', '/api/accounts/${_seg(id)}/enabled', {'enabled': enabled});

  Future<void> refreshAccount(String id) =>
      _json('POST', '/api/accounts/${_seg(id)}/refresh', const {}, _slow);

  Future<void> removeAccount(String id) =>
      _json('DELETE', '/api/accounts/${_seg(id)}');

  Future<void> setAccountOrder(List<String> ids) =>
      _json('POST', '/api/accounts/order', {'ids': ids});

  /// Starts a sign-in with an email and password. The password goes only
  /// to the core on loopback; the app keeps no copy.
  Future<SignInState> startSignIn(String email, String password) async =>
      SignInState.fromJson(
        await _json('POST', '/api/signin', {
          'email': email,
          'password': password,
        }),
      );

  /// Signs an account in again with its stored password; 409 when the core
  /// has none, and the user must type it.
  Future<SignInState> startSignInAgain(String accountId) async =>
      SignInState.fromJson(
        await _json('POST', '/api/signin', {'account_id': accountId}),
      );

  Future<SignInState> signInState(String id) async =>
      SignInState.fromJson(await _json('GET', '/api/signin/${_seg(id)}'));

  Future<SignInState> answerSignIn(String id, String value) async =>
      SignInState.fromJson(
        await _json('POST', '/api/signin/${_seg(id)}', {'value': value}),
      );

  Future<void> cancelSignIn(String id) =>
      _json('DELETE', '/api/signin/${_seg(id)}');

  /// The core's config.json as raw JSON, so a save keeps every field the
  /// app does not know.
  Future<Map<String, Object?>> settings() async {
    final view = await _json('GET', '/api/settings');
    return switch (view['config']) {
      final Map<String, Object?> c => c,
      _ => throw const CoreApiException(500, 'settings without config'),
    };
  }

  Future<void> saveSettings(Map<String, Object?> config) =>
      _json('PUT', '/api/settings', {'config': config});

  /// Sets system_proxy.mode: set or clear.
  Future<void> setSystemProxy(String mode) =>
      _json('POST', '/api/system-proxy', {'mode': mode});

  /// Turns the proxy on or off; off closes its port and gives Windows its
  /// own proxy setting back. The API keeps running.
  Future<void> setPower(bool on) => _json('POST', '/api/power', {'on': on});

  /// Turns the proxy on as the app's auto-connect at startup: with the
  /// system proxy set, the core sets it only once a test passes.
  Future<void> autoConnect() =>
      _json('POST', '/api/power', {'on': true, 'auto': true});

  /// Drops the waits after failures, so the next connection tries at once:
  /// the user is looking.
  Future<void> retry() => _json('POST', '/api/retry', {});

  /// Ends the core process the app started (409 for a copy that neither
  /// the app nor a tray hosts, such as one under systemd).
  Future<void> exitCore() => _json('POST', '/api/app/exit', const {});

  Future<void> openFolder() => _json('POST', '/api/open-folder', const {});

  /// A sign-in link to the web dashboard: it opens signed in, once, within
  /// 15 minutes.
  Future<Uri> loginLink() async {
    final answer = await _json('POST', '/api/session/link', const {});
    final path = answer['path'];
    if (path is! String || path.isEmpty) {
      throw const CoreUnavailable(CoreProblem.notAnswering, 'no sign-in link');
    }
    return endpoint.baseUri.replace(path: path);
  }

  Future<LocationList> locations() async =>
      LocationList.fromJson(await _json('GET', '/api/locations'));

  /// Tests the real delay of [codes] (all when empty) through the tunnel;
  /// the proxy must run (409 otherwise). It can take two minutes.
  Future<LocationList> pingLocations(List<String> codes) async =>
      LocationList.fromJson(
        await _json('POST', '/api/locations/ping', {'codes': codes}, _slowest),
      );

  /// Chooses the location: a country code, `fastest`, or empty for the
  /// recommended one. The proxy restarts.
  Future<void> setLocation(String country) =>
      _json('POST', '/api/location', {'country': country});

  /// Log lines after [after] (an entry id; 0 for the buffered ones).
  Future<List<LogEntry>> logs(int after) async {
    final j = await _json('GET', '/api/logs?after=$after');
    return [
      for (final e in (j['entries'] as List<Object?>? ?? const []))
        if (e is Map<String, Object?>) LogEntry.fromJson(e),
    ];
  }

  Future<RoutingInfo> routing() async =>
      RoutingInfo.fromJson(await _json('GET', '/api/routing'));

  Future<RoutingInfo> updateRoutingLists() async => RoutingInfo.fromJson(
    await _json('POST', '/api/routing/update', const {}, _slowest),
  );

  Future<DestinationTest> testDestination(String target) async =>
      DestinationTest.fromJson(
        await _json('POST', '/api/routing/test', {'target': target}, _slow),
      );

  /// Resolves the core's own names through [servers] and the system DNS.
  Future<List<DnsTestHost>> testDns(List<String> servers) async {
    final j = await _json('POST', '/api/dns/test', {'servers': servers}, _slow);
    return [
      for (final r in (j['results'] as List<Object?>? ?? const []))
        if (r is Map<String, Object?>) DnsTestHost.fromJson(r),
    ];
  }

  /// A country's flag (SVG) by its two-letter code, from the core: built
  /// in there, or downloaded once and kept. Null when it has none.
  Future<Uint8List?> flag(String code) async {
    final uri = endpoint.baseUri.replace(path: '/flags/${_seg(code)}.svg');
    try {
      final req = await _client.getUrl(uri).timeout(_slow);
      req.headers.set('X-Local-Token', endpoint.token);
      final res = await req.close().timeout(_slow);
      final bytes = await res
          .fold<BytesBuilder>(BytesBuilder(), (b, chunk) => b..add(chunk))
          .timeout(_slow);
      return res.statusCode == 200 ? bytes.takeBytes() : null;
    } on IOException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  static const _normal = Duration(seconds: 10);
  static const _slow = Duration(seconds: 60);
  static const _slowest = Duration(seconds: 150);

  static String _seg(String s) => Uri.encodeComponent(s);

  Future<Map<String, Object?>> _json(
    String method,
    String path, [
    Object? body,
    Duration timeout = _normal,
  ]) async {
    final query = path.indexOf('?');
    final uri = query < 0
        ? endpoint.baseUri.replace(path: path)
        : endpoint.baseUri.replace(
            path: path.substring(0, query),
            query: path.substring(query + 1),
          );
    try {
      final req = await _client.openUrl(method, uri).timeout(timeout);
      req.headers
        ..set('X-Local-Token', endpoint.token)
        ..set(HttpHeaders.acceptHeader, 'application/json');
      // The core takes a state change only as JSON (415 otherwise), so
      // every request but a read carries a body, {} when it has none.
      final payload =
          body ?? (method == 'GET' ? null : const <String, Object?>{});
      if (payload != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(payload));
      }
      final res = await req.close().timeout(timeout);
      final text = await res.transform(utf8.decoder).join().timeout(timeout);
      final decoded = text.isEmpty ? null : jsonDecode(text);
      if (res.statusCode >= 400) {
        final message = switch (decoded) {
          {'error': final String e} => e,
          _ => 'HTTP ${res.statusCode}',
        };
        throw CoreApiException(res.statusCode, message);
      }
      return decoded is Map<String, Object?> ? decoded : const {};
    } on SocketException catch (e) {
      throw CoreUnavailable(
        CoreProblem.notAnswering,
        '${endpoint.baseUri}: ${e.message}',
      );
    } on HttpException catch (e) {
      throw CoreUnavailable(CoreProblem.notAnswering, e.message);
    } on TimeoutException {
      throw CoreUnavailable(
        CoreProblem.notAnswering,
        '${endpoint.baseUri}: timeout',
      );
    } on FormatException {
      throw const CoreUnavailable(
        CoreProblem.notAnswering,
        'unreadable answer',
      );
    }
  }
}
