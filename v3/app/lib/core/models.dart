// Views of the core's dashboard API (core/doc/DASHBOARD.md). The parsers
// are lenient: a missing or mistyped field becomes an empty value, so a
// newer core never crashes the app.

part 'models_more.dart';

String _str(Object? v) => v is String ? v : '';

int _int(Object? v) => v is num ? v.toInt() : 0;

double _double(Object? v) => v is num ? v.toDouble() : 0;

bool _bool(Object? v) => v == true;

Map<String, Object?> _map(Object? v) =>
    v is Map<String, Object?> ? v : const {};

Map<String, Object?>? _mapOrNull(Object? v) =>
    v is Map<String, Object?> ? v : null;

/// Parses an RFC 3339 time; Go's zero time and empty strings are null.
DateTime? _time(Object? v) {
  if (v is! String || v.isEmpty) return null;
  final t = DateTime.tryParse(v);
  if (t == null || t.year <= 1) return null;
  return t.toLocal();
}

/// Engine phases (core/internal/service/daemon.go).
enum Phase { starting, running, waiting, error, off, unknown }

Phase _phase(String s) => switch (s) {
  'starting' => Phase.starting,
  'running' => Phase.running,
  'waiting' => Phase.waiting,
  'error' => Phase.error,
  // Turned off by the phone app; the API still runs.
  'off' => Phase.off,
  _ => Phase.unknown,
};

class EngineState {
  EngineState.fromJson(Map<String, Object?> j)
    : phase = _phase(_str(j['phase'])),
      message = _str(j['message']),
      since = _time(j['since']),
      retryAt = _time(j['retry_at']),
      code = _str(j['code']),
      address = _str(j['address']);

  final Phase phase;
  final String message;
  final DateTime? since;
  final DateTime? retryAt;

  /// What the state is, for the waiting and error states ([StateCode]);
  /// empty otherwise. [message] is the core's English.
  final String code;

  /// The listen address [code] is about.
  final String address;

  bool get proxyPortInUse => code == StateCode.proxyPortInUse;

  /// The proxy cannot listen on its port: another program holds it, or
  /// it cannot be used (Windows reserves it); another port helps.
  bool get proxyPortBlocked =>
      proxyPortInUse || (code == StateCode.startFailed && address.isNotEmpty);
}

/// The core's state codes (state.code in /api/status, core/doc/DASHBOARD.md).
abstract final class StateCode {
  static const waitingForNetwork = 'waiting_for_network';
  static const noAccounts = 'no_accounts';
  static const noUsableAccount = 'no_usable_account';
  static const proxyPortInUse = 'proxy_port_in_use';
  static const startFailed = 'start_failed';
}

class ProxyInfo {
  ProxyInfo.fromJson(Map<String, Object?> j)
    : listen = _str(j['listen']),
      upstream = _str(j['upstream']),
      countryCode = _str(j['country_code']),
      countryName = _str(j['country_name']),
      cityName = _str(j['city_name']),
      selectionSource = _str(j['selection_source']),
      transport = _str(j['transport']),
      startedAt = _time(j['started_at']),
      sleepingSince = _time(j['sleeping_since']),
      wakeError = _str(j['wake_error']),
      wakeErrorCode = _str(j['wake_error_code']),
      wakeFailedAt = _time(j['wake_failed_at']),
      loginRequired = _bool(j['login_required']);

  final String listen;
  final String upstream;
  final String countryCode;
  final String countryName;
  final String cityName;
  final String selectionSource;
  final String transport;
  final DateTime? startedAt;
  final DateTime? sleepingSince;

  /// The last failed attempt to connect to Mozilla, until one succeeds.
  final String wakeError;

  /// Why [wakeError] happened, as a [Failure] code.
  final String wakeErrorCode;
  final DateTime? wakeFailedAt;
  final bool loginRequired;
}

/// The public IP websites see (Mozilla's exit).
class ExitInfo {
  ExitInfo.fromJson(Map<String, Object?> j)
    : ipv4 = _str(j['ipv4']),
      ipv6 = _str(j['ipv6']),
      countryCode = _str(j['country_code']),
      countryName = _str(j['country_name']),
      city = _str(j['city']),
      network = _str(j['network']);

  final String ipv4;
  final String ipv6;
  final String countryCode;
  final String countryName;
  final String city;
  final String network;
}

/// The public IP is in another country than the one the user chose
/// (`exit_mismatch`; only for a chosen country, never for the recommended
/// location or the fastest one).
class ExitMismatch {
  ExitMismatch.fromJson(Map<String, Object?> j)
    : chosenCountryCode = _str(j['chosen_country_code']),
      chosenCountryName = _str(j['chosen_country_name']),
      exitCountryCode = _str(j['exit_country_code']),
      exitCountryName = _str(j['exit_country_name']);

  final String chosenCountryCode;
  final String chosenCountryName;
  final String exitCountryCode;
  final String exitCountryName;
}

class Usage {
  Usage.fromJson(Map<String, Object?> j)
    : unlimited = _bool(j['unlimited']),
      limitBytes = _int(j['limit_bytes']),
      remainingBytes = _int(j['remaining_bytes']),
      resetAt = _time(j['reset_at']),
      checkedAt = _time(j['checked_at']);

  final bool unlimited;
  final int limitBytes;
  final int remainingBytes;
  final DateTime? resetAt;
  final DateTime? checkedAt;

  int get usedBytes => unlimited ? 0 : limitBytes - remainingBytes;
}

/// Account statuses (core/internal/accounts/store.go).
abstract final class AccountStatus {
  static const ready = 'ready';
  static const reserved = 'reserved';
  static const reauthRequired = 'reauth_required';
  static const unavailable = 'unavailable';
}

class Account {
  Account.fromJson(Map<String, Object?> j)
    : id = _str(j['id']),
      name = _str(j['name']),
      email = _str(j['email']),
      position = _int(j['position']),
      enabled = _bool(j['enabled']),
      active = _bool(j['active']),
      status = _str(j['status']),
      reason = _str(j['reason']),
      reasonCode = _str(j['reason_code']),
      reasonDetail = _str(j['reason_detail']),
      retryAt = _time(j['retry_at']),
      usage = switch (_mapOrNull(j['usage'])) {
        final m? => Usage.fromJson(m),
        null => null,
      },
      usedPercent = _double(j['used_percent']),
      hasPassword = _bool(j['has_password']);

  final String id;
  final String name;
  final String email;
  final int position;
  final bool enabled;
  final bool active;
  final String status;
  final String reason;

  /// The reason by name (core/internal/accounts, the Reason* codes), for
  /// the app's own words; [reasonDetail] is the error it carries.
  final String reasonCode;
  final String reasonDetail;
  final DateTime? retryAt;
  final Usage? usage;
  final double usedPercent;
  final bool hasPassword;

  bool get needsSignIn => status == AccountStatus.reauthRequired;
}

class AccountList {
  AccountList.fromJson(Map<String, Object?> j)
    : accounts = [
        for (final a in (j['accounts'] as List<Object?>? ?? const []))
          Account.fromJson(_map(a)),
      ],
      thresholdPercent = _double(j['switch_threshold_percent']);

  final List<Account> accounts;
  final double thresholdPercent;
}

class Traffic {
  Traffic.fromJson(Map<String, Object?> j)
    : up = _int(j['up']),
      down = _int(j['down']),
      directUp = _int(j['direct_up']),
      directDown = _int(j['direct_down']),
      upRate = _int(j['up_rate']),
      downRate = _int(j['down_rate']);

  final int up;
  final int down;
  final int directUp;
  final int directDown;
  final int upRate;
  final int downRate;
}

/// Why connecting through Mozilla failed (core/internal/proxy/failure.go).
abstract final class Failure {
  static const noNetwork = 'no_network';
  static const unreachable = 'unreachable';
  static const refused = 'refused';

  /// The server of a location the user chose refused the account again
  /// with a new pass: Mozilla does not let it use that location.
  static const locationRefused = 'location_refused';
  static const signIn = 'sign_in';
  static const quota = 'quota';
  static const notEntitled = 'not_entitled';
  static const region = 'region';
  static const server = 'server';
  static const noAccount = 'no_account';
  static const testSite = 'test_site';
  static const other = 'other';
}

/// The result of `POST /api/test` (core/internal/proxy/conntest.go).
class ConnectionTest {
  ConnectionTest.fromJson(Map<String, Object?> j)
    : at = _time(j['at']),
      ok = _bool(j['ok']),
      error = _str(j['error']),
      errorCode = _str(j['error_code']),
      target = _str(j['target']),
      httpStatus = _int(j['http_status']),
      tunnelMs = _int(j['tunnel_ms']),
      tlsMs = _int(j['tls_ms']),
      responseMs = _int(j['response_ms']),
      totalMs = _int(j['total_ms']),
      exitIpv4 = _str(j['exit_ipv4']),
      exitIpv6 = _str(j['exit_ipv6']),
      exitCountry = _str(j['exit_country']),
      exitCity = _str(j['exit_city']),
      exitNetwork = _str(j['exit_network']),
      exitError = _str(j['exit_error']);

  final DateTime? at;
  final bool ok;
  final String error;

  /// Why the test failed, as a [Failure] code.
  final String errorCode;
  final String target;
  final int httpStatus;
  final int tunnelMs;
  final int tlsMs;
  final int responseMs;
  final int totalMs;
  final String exitIpv4;
  final String exitIpv6;
  final String exitCountry;
  final String exitCity;
  final String exitNetwork;
  final String exitError;
}

/// `GET /api/status`.
class CoreStatus {
  CoreStatus.fromJson(Map<String, Object?> j)
    : state = EngineState.fromJson(_map(j['state'])),
      proxy = switch (_mapOrNull(j['proxy'])) {
        final m? => ProxyInfo.fromJson(m),
        null => null,
      },
      activeAccount = switch (_mapOrNull(j['active_account'])) {
        final m? => Account.fromJson(m),
        null => null,
      },
      exit = switch (_mapOrNull(j['exit'])) {
        final m? => ExitInfo.fromJson(m),
        null => null,
      },
      exitMismatch = switch (_mapOrNull(j['exit_mismatch'])) {
        final m? => ExitMismatch.fromJson(m),
        null => null,
      },
      lastTest = switch (_mapOrNull(j['last_test'])) {
        final m? => ConnectionTest.fromJson(m),
        null => null,
      },
      traffic = switch (_mapOrNull(j['traffic'])) {
        final m? => Traffic.fromJson(m),
        null => null,
      },
      pass = switch (_mapOrNull(j['pass'])) {
        final m? => PassInfo.fromJson(m),
        null => null,
      },
      notices = [
        for (final n in (j['notices'] as List<Object?>? ?? const []))
          Notice.fromJson(_map(n)),
      ],
      accountCounts = {
        for (final e in _map(j['accounts']).entries) e.key: _int(e.value),
      },
      thresholdPercent = _double(j['switch_threshold_percent']),
      version = _str(j['version']),
      canExit = _bool(j['can_exit']),
      systemProxy = _str(j['system_proxy']),
      systemProxySupported = _bool(j['system_proxy_supported']),
      systemProxyTakenBy = switch (_mapOrNull(j['system_proxy_taken'])) {
        final m? => _str(m['by']),
        null => null,
      },
      autoConnecting = _bool(j['auto_connecting']),
      connectFailure = _str(j['connect_failure']),
      selection = _str(j['selection']),
      selectionName = _str(j['selection_name']),
      noNetwork = _bool(j['no_network']),
      networkChangedAt = _time(j['network_changed_at']),
      dataDir = _str(j['data_dir']);

  final EngineState state;
  final ProxyInfo? proxy;
  final Account? activeAccount;
  final ExitInfo? exit;

  /// Set when the public IP is in another country than the chosen one.
  final ExitMismatch? exitMismatch;
  final ConnectionTest? lastTest;
  final Traffic? traffic;
  final PassInfo? pass;
  final List<Notice> notices;
  final Map<String, int> accountCounts;
  final double thresholdPercent;
  final String version;

  /// Whether `POST /api/app/exit` can end the core's process.
  final bool canExit;

  /// system_proxy.mode: set (Windows uses the proxy while it runs) or
  /// clear.
  final String systemProxy;

  bool get systemProxySet => systemProxy == 'set';
  final bool systemProxySupported;

  /// Another program (another VPN or proxy) replaced the system proxy the
  /// core set: the proxy or setup script it points at now, "" when it
  /// turned the proxy off; null while the core's setting is in place.
  final String? systemProxyTakenBy;

  /// The app's auto-connect tests the connection; the system proxy waits
  /// for a passed test.
  final bool autoConnecting;

  /// Why the user's last connect was given up (a [Failure] code): it never
  /// reached Mozilla within a minute, and the proxy went off again.
  final String connectFailure;

  /// The phone reported that no network is connected (Android's own
  /// state: no Wi-Fi and no mobile data).
  final bool noNetwork;

  /// When the phone last reported a network change.
  final DateTime? networkChangedAt;

  /// Whether [test] confirms the running proxy works: it passed, since the
  /// proxy started, and no connection to Mozilla failed after it. The phone
  /// shows "Connecting" until then.
  bool confirmedBy(ConnectionTest? test) {
    final p = proxy;
    final at = test?.at;
    if (state.phase != Phase.running || p == null || at == null) return false;
    if (!test!.ok || noNetwork) return false;
    if (p.startedAt != null && at.isBefore(p.startedAt!)) return false;
    // A test from before the network changed says nothing about it now.
    final changed = networkChangedAt;
    if (changed != null && at.isBefore(changed)) return false;
    final failed = p.wakeFailedAt;
    return !(p.wakeError.isNotEmpty && failed != null && failed.isAfter(at));
  }

  /// The chosen location, also while the proxy is off: "" the recommended
  /// location, "fastest", or a country code; and the list's name for it.
  final String selection;
  final String selectionName;
  final String dataDir;

  int get totalAccounts => accountCounts['total'] ?? 0;
  int get readyAccounts => accountCounts[AccountStatus.ready] ?? 0;
}

/// Sign-in steps (core/internal/service/signin_flow.go).
abstract final class SignInStep {
  static const working = 'working';
  static const needEmailCode = 'need_email_code';
  static const needTotp = 'need_totp';
  static const needUnblockCode = 'need_unblock_code';
  static const needCaptcha = 'need_captcha';
  static const needEmailLink = 'need_email_link';
  static const done = 'done';
  static const failed = 'failed';
  static const cancelled = 'cancelled';
}

/// What went wrong in a sign-in ([SignInState.errorCode];
/// core/internal/service/signin_flow.go).
abstract final class SignInError {
  static const noAccount = 'no_account';
  static const wrongPassword = 'wrong_password';
  static const noPassword = 'no_password';
  static const tooManyAttempts = 'too_many_attempts';
  static const unblockCodeRejected = 'unblock_code_rejected';
  static const wrongCode = 'wrong_code';
  static const wrongTotp = 'wrong_totp';
  static const tooManyCodes = 'too_many_codes';
  static const timedOut = 'timed_out';
  static const network = 'network';
}

class SignInState {
  SignInState.fromJson(Map<String, Object?> j)
    : id = _str(j['id']),
      email = _str(j['email']),
      step = _str(j['step']),
      message = _str(j['message']),
      error = _str(j['error']),
      errorCode = _str(j['error_code']),
      passwordAccepted = _bool(j['password_accepted']),
      captcha = _str(j['captcha']),
      accountId = _str(j['account_id']);

  final String id;
  final String email;
  final String step;
  final String message;
  final String error;

  /// Which [SignInError] [error] is; empty for anything else.
  final String errorCode;

  /// Mozilla accepted the email and the password.
  final bool passwordAccepted;

  /// A `data:` URL of the CAPTCHA image during [SignInStep.needCaptcha].
  final String captcha;
  final String accountId;

  bool get finished =>
      step == SignInStep.done ||
      step == SignInStep.failed ||
      step == SignInStep.cancelled;

  /// Whether the step waits for a typed answer.
  bool get needsAnswer =>
      step == SignInStep.needEmailCode ||
      step == SignInStep.needTotp ||
      step == SignInStep.needUnblockCode ||
      step == SignInStep.needCaptcha;
}
