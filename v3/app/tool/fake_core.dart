// A stand-in for the core's dashboard API with made-up data, for working
// on the UI without a real core or real accounts. It never contacts the
// network.
//
//   dart run tool/fake_core.dart <data-dir> [port]
//   flutter run -d windows --dart-entrypoint-args=--data-dir=<data-dir>
//
// It writes local-api.token and config.json into <data-dir>. The page at
// http://127.0.0.1:<port>/fake (no token; the server listens on loopback
// only) switches between scenarios: every state, failure, and account
// problem the app can show. The app shows a switch at its next poll (two
// seconds; the accounts page within six).
//
// The sign-in asks for an emailed code; 123456 is accepted. An email whose
// name (the part before @) is in _magicEmails, such as
// wrong_password@example.com, makes the sign-in go that way instead.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

final _random = Random();

DateTime _now() => DateTime.now().toUtc();

// Proxy only, as the real core starts (system_proxy.mode clear).
String _systemProxy = 'clear';
final Map<String, Object?> _config = {
  'proxy': {
    'enabled': true,
    'listen': '127.0.0.1:10810',
    'transport': 'h3',
    'country': '',
    'username': '',
    'password': '',
    'idle_sleep': '15m0s',
  },
  'accounts': {'switch_threshold_percent': 95},
  'dashboard': {'listen': '127.0.0.1:19090'},
  'dns': {'servers': <String>[], 'fallback_to_system': true},
  'logging': {'verbose': false},
  'routing': {
    'enabled': true,
    'region': 'ir',
    'direct': <String>[],
    'block': <String>[],
  },
  'system_proxy': {'mode': 'clear'},
};

Map<String, Object?> get _proxyConfig =>
    _config['proxy'] as Map<String, Object?>;

/// The chosen location: "" the recommended one, "fastest", or a code.
String get _selection => _proxyConfig['country'] as String? ?? '';

int _down = 1832 * 1024 * 1024;
int _up = 96 * 1024 * 1024;

// What the fake core reports now. A scenario sets it (_apply); the power
// button, a new location, and a new proxy port change it as the core would.

String _scenario = 'connected';
String _phase = 'running';
String _phaseMessage = '';
String _stateCode = '';
String _stateAddress = '';
DateTime _phaseSince = _now();

/// The phase a start ends in (after two seconds of "starting"), so that
/// the power button and a restart come back to the scenario's state.
String _steadyPhase = 'running';
String _steadyMessage = '';
String _steadyCode = '';
String _steadyAddress = '';

/// "starting" stays until the next scenario.
bool _holdStarting = false;

/// The failure code of the scenario and how it shows: "test" (connection
/// tests fail), "wake" (the proxy's last connection to Mozilla failed), or
/// "gaveup" (a connect is given up after 8 seconds); "" for none.
String _failure = '';
String _failureMode = '';
DateTime? _wakeFailedAt;
DateTime? _giveUpAt;
String _connectFailure = '';

bool _noNetwork = false;
DateTime? _networkChangedAt;
bool _autoConnecting = false;

/// The exit's country when it is not the location's (exit-mismatch).
String _exitCountry = '';

/// Every API request answers 401 (core-refuses).
bool _refuseApp = false;

/// Reports system_proxy_supported false, as the phone's core does.
bool _phone = false;

/// Acts as if Mozilla enforced the locks of its server list: choosing one
/// of these countries (or connecting with one chosen) is refused, as the
/// real core reports it (location_refused).
bool _enforceLocks = false;
const _lockedCountries = {
  'AT', 'BE', 'BG', 'BR', 'CA', 'CL', 'CO', 'DK', 'ES', 'FI', 'FR', 'GB', //
  'GH', 'IE', 'IT', 'KR', 'MX', 'MY', 'NL', 'NO', 'NZ', 'PE', 'PH', 'PT', //
  'SE', 'SG', 'TH',
};

/// Whether the chosen country is one Mozilla refuses now.
bool _refusesChoice() =>
    _enforceLocks &&
    _lockedCountries.contains(
      (_proxyConfig['country'] as String? ?? '').toUpperCase(),
    );

List<Map<String, Object?>> _notices = [];
Map<String, Object?>? _lastTest;

final _accounts = <Map<String, Object?>>[];
final _signIns = <String, Map<String, Object?>>{};

final _locations = <Map<String, Object?>>[
  {
    'code': 'NL',
    'name': 'Netherlands',
    'city': 'Amsterdam',
    'server': 'nl-ams-001.example.net:443',
    'recommended': true,
  },
  {
    'code': 'DE',
    'name': 'Germany',
    'city': 'Frankfurt',
    'server': 'de-fra-001.example.net:443',
  },
  {
    'code': 'FR',
    'name': 'France',
    'city': 'Paris',
    'server': 'fr-par-001.example.net:443',
  },
  {
    'code': 'GB',
    'name': 'United Kingdom',
    'city': 'London',
    'server': 'gb-lon-001.example.net:443',
  },
  {
    'code': 'SE',
    'name': 'Sweden',
    'city': 'Stockholm',
    'server': 'se-sto-001.example.net:443',
  },
  {
    'code': 'US',
    'name': 'United States',
    'city': 'New York',
    'server': 'us-nyc-001.example.net:443',
  },
  {
    'code': 'JP',
    'name': 'Japan',
    'city': 'Tokyo',
    'server': 'jp-tyo-001.example.net:443',
  },
];
String? _pingedAt;

final _logs = <Map<String, Object?>>[];

void _log(String level, String message) => _logs.add({
  'id': _logs.length + 1,
  'time': _now().toIso8601String(),
  'level': level,
  'message': message,
});

// --- Accounts ---

const _gib = 1024 * 1024 * 1024;
const _limit = 50 * _gib;
final _resetAt = DateTime.utc(2026, 11, 1);

/// An account view; [usedGb] null for a quota not read yet.
Map<String, Object?> _account(
  String id,
  String email,
  double? usedGb, {
  bool active = false,
  String status = 'ready',
  String reason = '',
  String reasonCode = '',
  String reasonDetail = '',
  DateTime? retryAt,
  bool enabled = true,
  bool hasPassword = true,
  bool unlimited = false,
}) {
  final used = ((usedGb ?? 0) * _gib).round();
  return {
    'id': id,
    'name': email,
    'email': email,
    'enabled': enabled,
    'active': active,
    'status': status,
    'reason': reason,
    if (reasonCode.isNotEmpty) 'reason_code': reasonCode,
    if (reasonDetail.isNotEmpty) 'reason_detail': reasonDetail,
    if (retryAt != null) 'retry_at': retryAt.toIso8601String(),
    if (unlimited)
      'usage': {'unlimited': true}
    else if (usedGb != null)
      'usage': {
        'limit_bytes': _limit,
        'remaining_bytes': _limit - used,
        'reset_at': _resetAt.toIso8601String(),
        'checked_at': _now().toIso8601String(),
      },
    'used_percent': unlimited || usedGb == null ? 0 : used * 100 / _limit,
    'has_password': hasPassword,
  };
}

// The usage colors at the default 95% threshold: green, amber (from 85%),
// red (from 95%, set aside for another account).
List<Map<String, Object?>> _normalAccounts() => [
  _account('a1', 'alice@example.com', 18.4, active: true),
  _account('a2', 'bob@example.com', 43.5),
  _account(
    'a4',
    'dave@example.com',
    48.2,
    status: 'reserved',
    reason: 'used 48.2 GB of 50 GB (switch threshold 95%)',
    reasonCode: 'quota_threshold',
    retryAt: _resetAt,
  ),
  _account(
    'a3',
    'carol@example.com',
    0,
    status: 'reauth_required',
    reason: 'Firefox Account sign-in required',
    reasonCode: 'signin_required',
  ),
];

/// One account for every reason and quota look the accounts page knows.
List<Map<String, Object?>> _reasonAccounts() {
  final now = _now();
  return [
    _account('a1', 'alice@example.com', 12, active: true),
    _account('a2', 'bob@example.com', 44),
    _account(
      'a3',
      'dave@example.com',
      48.2,
      status: 'reserved',
      reason: 'used 48.2 GB of 50 GB (switch threshold 95%)',
      reasonCode: 'quota_threshold',
      retryAt: _resetAt,
    ),
    _account(
      'a4',
      'erin@example.com',
      50,
      status: 'reserved',
      reason: 'monthly quota exhausted',
      reasonCode: 'quota_exhausted',
      retryAt: _resetAt,
    ),
    _account(
      'a5',
      'carol@example.com',
      0,
      status: 'reauth_required',
      reason: 'Firefox Account sign-in required',
      reasonCode: 'signin_required',
    ),
    _account(
      'a6',
      'frank@example.com',
      3.2,
      status: 'reauth_required',
      reason: 'Mozilla asks to confirm the sign-in; use Sign in again (only the code is needed)',
      reasonCode: 'signin_confirm',
    ),
    _account(
      'a7',
      'grace@example.com',
      7.5,
      status: 'reauth_required',
      reason: 'Automatic sign-in failed (Incorrect password); sign in again',
      reasonCode: 'signin_failed',
      reasonDetail: 'Incorrect password',
    ),
    _account(
      'a8',
      'heidi@example.com',
      1.1,
      status: 'unavailable',
      reason:
          'The tokens stopped working soon after the last automatic sign-in',
      reasonCode: 'signin_wait',
      retryAt: now.add(const Duration(minutes: 40)),
    ),
    _account(
      'a9',
      'ivan@example.com',
      22,
      status: 'unavailable',
      reason:
          'Automatic sign-in could not finish (Mozilla could not be reached)',
      reasonCode: 'signin_retry',
      reasonDetail: 'Mozilla could not be reached',
      retryAt: now.add(const Duration(minutes: 15)),
    ),
    _account(
      'a10',
      'judy@example.com',
      0.4,
      status: 'unavailable',
      reason: 'rejected by Guardian (not entitled or token refused)',
      reasonCode: 'not_entitled',
      retryAt: now.add(const Duration(hours: 6)),
    ),
    _account(
      'a11',
      'ken@example.com',
      5,
      status: 'unavailable',
      reason: 'A reason from a newer core, in its own English words',
      reasonCode: 'some_new_reason',
    ),
    _account('a12', 'lena@example.com', null),
    _account('a13', 'mike@example.com', 0, unlimited: true),
    _account('a14', 'nina@example.com', 30, enabled: false),
    _account(
      'a15',
      'no_password@example.com',
      0,
      status: 'reauth_required',
      reason: 'Firefox Account sign-in required',
      reasonCode: 'signin_required',
      hasPassword: false,
    ),
  ];
}

List<Map<String, Object?>> _accountViews() => [
  for (var i = 0; i < _accounts.length; i++)
    {..._accounts[i], 'position': i + 1},
];

/// Replaces the active account's data used (for the quota scenarios).
void _setActiveUsage(double? usedGb, {bool unlimited = false}) {
  final i = _accounts.indexWhere((a) => a['active'] == true);
  final a = _accounts[i];
  _accounts[i] = _account(
    a['id'] as String,
    a['email'] as String,
    usedGb,
    active: true,
    unlimited: unlimited,
  );
}

// --- Failures ---

/// The failure codes (core/internal/proxy/failure.go) with what the app's
/// English says for each, and the core's text a hover or long press shows.
const _failureCodes = <({String code, String text, String detail})>[
  (
    code: 'no_network',
    text: 'No internet. Check Wi-Fi or mobile data.',
    detail: 'dial tcp: lookup nl-ams-001.example.net: no such host',
  ),
  (
    code: 'unreachable',
    text:
        "Mozilla's servers are blocked on this internet. Try another "
        'internet connection. + a Connection settings button',
    detail: 'dial udp 203.0.113.7:443: i/o timeout',
  ),
  (
    code: 'refused',
    text:
        "Mozilla's server refused the connection. Try again in a few "
        'minutes.',
    detail: 'proxy CONNECT returned 403 Forbidden',
  ),
  (
    code: 'location_refused',
    text:
        "This country isn't open to your account. Choose another country. + "
        'Use the recommended location (the chosen location is GB; the button '
        'fixes it)',
    detail:
        'Mozilla does not let this account use this location: proxy CONNECT '
        'returned 403 Forbidden',
  ),
  (
    code: 'sign_in',
    text:
        "This account's sign-in has expired. Sign in again on the Accounts "
        'page.',
    detail:
        'the saved Firefox Account credential was rejected; sign the account '
        'in again from the dashboard',
  ),
  (
    code: 'quota',
    text: "This month's data is used up. Add another account.",
    detail: 'getting a proxy pass: monthly quota exceeded (HTTP 429)',
  ),
  (
    code: 'not_entitled',
    text: "Mozilla doesn't let this account use the VPN. Add another account.",
    detail: 'getting a proxy pass: not entitled (HTTP 403)',
  ),
  (
    code: 'region',
    text: "Mozilla doesn't offer its service in your country.",
    detail: 'getting a proxy pass: unavailable for legal reasons (HTTP 451)',
  ),
  (
    code: 'server',
    text:
        "Mozilla's service has a temporary problem. The app tries again by "
        'itself.',
    detail: 'getting a proxy pass: server error (HTTP 503)',
  ),
  (
    code: 'no_account',
    text: 'No account is ready. Open the Accounts page.',
    detail: 'no usable account: 2 reserved, 1 reauth_required',
  ),
  (
    code: 'test_site',
    text:
        "Connected to the server, but sites don't open. Try another "
        'country.',
    detail: 'the test site answered HTTP 502 through the tunnel',
  ),
  (
    code: 'other',
    text: "Couldn't connect. Try again.",
    detail: 'reading the proxy pass: unexpected response format',
  ),
  (
    code: 'something_new',
    text:
        "Couldn't connect. Check your internet. (a code the app does not "
        'know)',
    detail: 'a failure with a code from a newer core',
  ),
];

String _failureDetail(String code) =>
    _failureCodes.where((f) => f.code == code).firstOrNull?.detail ?? code;

/// The failure ways a code can show; test_site exists for tests only.
List<String> _modesFor(String code) =>
    code == 'test_site' ? const ['test'] : const ['test', 'wake', 'gaveup'];

const _modeTitles = {
  'test': 'Test failed',
  'wake': 'Wake failed',
  'gaveup': 'Given up',
};

/// Whether the network itself fails in this scenario (pings, DNS, quota).
bool get _networkDown =>
    _noNetwork || _failure == 'no_network' || _failure == 'unreachable';

// --- Scenarios ---

class _Scenario {
  const _Scenario(this.name, this.group, this.description, this.apply);

  final String name;
  final String group;

  /// What the user should see, and where.
  final String description;
  final void Function() apply;
}

final _scenarios = <_Scenario>[
  _Scenario(
    'connected',
    'Connection',
    'Home: Connected in green, the delay pill and the public IP; place card '
        '"Recommended location", Netherlands. Accounts: the usual four '
        '(active green, ready amber, reserved red, needs sign-in).',
    () {},
  ),
  _Scenario(
    'connected-fastest',
    'Connection',
    'Home: Connected; the place card says Fastest (sparkle), Sweden.',
    () => _proxyConfig['country'] = 'fastest',
  ),
  _Scenario(
    'connected-country',
    'Connection',
    'Home: Connected; place card "Connected to" Germany (chosen by hand), '
        'no warning.',
    () => _proxyConfig['country'] = 'DE',
  ),
  _Scenario(
    'exit-mismatch',
    'Connection',
    'Home: Connected, with the amber box "You chose United Kingdom, but your '
        'IP is in Germany." (chosen GB, exit DE).',
    () {
      _proxyConfig['country'] = 'GB';
      _exitCountry = 'DE';
    },
  ),
  _Scenario(
    'connecting',
    'Connection',
    'Home: Connecting in orange with no line under it (the proxy is '
        'starting; it stays so until you switch). Tray: the turning icon.',
    () {
      _phase = 'starting';
      _holdStarting = true;
    },
  ),
  _Scenario(
    'auto-connecting',
    'Connection',
    'Home: Connecting in orange: the auto-connect at startup waits for a '
        'passed test before Windows uses the proxy (auto_connecting). '
        'Tray: the turning icon.',
    () {
      _autoConnecting = true;
      _lastTest = null;
    },
  ),
  _Scenario(
    'off',
    'Connection',
    'Home: Off with "Tap to connect"; the power button connects, and it '
        'works.',
    () => _setPhase('off'),
  ),
  _Scenario(
    'waiting-no-accounts',
    'Connection',
    'Home: Waiting, "Add a Firefox Account on the Accounts page to '
        'connect."; the power button opens Accounts; the data card says no '
        'active account. Accounts: the empty panel.',
    () {
      _accounts.clear();
      _setPhase(
        'waiting',
        message: 'Add an account in the dashboard to start the proxy',
        code: 'no_accounts',
      );
    },
  ),
  _Scenario(
    'waiting-no-usable',
    'Connection',
    'Home: Waiting, "No account is ready. Open the Accounts page." '
        '(no_usable_account; the core\'s English is "No usable account: 2 '
        'reserved, 1 reauth_required"). Accounts: none can be used.',
    () {
      _accounts
        ..clear()
        ..addAll([
          _account(
            'a1',
            'alice@example.com',
            50,
            status: 'reserved',
            reason: 'monthly quota exhausted',
            reasonCode: 'quota_exhausted',
            retryAt: _resetAt,
          ),
          // Spent: one set aside at the threshold with data left would
          // still be used, once no other account works.
          _account(
            'a2',
            'bob@example.com',
            50,
            status: 'reserved',
            reason: 'monthly quota exhausted',
            reasonCode: 'quota_exhausted',
            retryAt: _resetAt,
          ),
          _account(
            'a3',
            'carol@example.com',
            0,
            status: 'reauth_required',
            reason: 'Firefox Account sign-in required',
            reasonCode: 'signin_required',
          ),
        ]);
      _setPhase(
        'waiting',
        message: 'No usable account: 2 reserved, 1 reauth_required',
        code: 'no_usable_account',
      );
    },
  ),
  _Scenario(
    'waiting-network',
    'Connection',
    'Home: Waiting, "Waiting for an internet connection…" '
        '(waiting_for_network: a computer with no network).',
    () => _setPhase(
      'waiting',
      message: 'Waiting for a network connection',
      code: 'waiting_for_network',
    ),
  ),
  _Scenario(
    'no-network',
    'Connection',
    'Home: "No internet connection. Turn on Wi-Fi or mobile data." in red '
        '(no_network, which only the phone reports).',
    () {
      _noNetwork = true;
      _networkChangedAt = _now();
      _setPhase(
        'waiting',
        message: 'Waiting for a network connection',
        code: 'waiting_for_network',
      );
    },
  ),
  _Scenario(
    'error',
    'Connection',
    'Home: Error in red, "The proxy couldn\'t start on port 10810. Choose '
        'another port." and a Change port button (start_failed: a port '
        'Windows keeps for itself); saving another port connects. Tray: the '
        'error icon.',
    () {
      final listen = _proxyConfig['listen'] as String;
      _setPhase(
        'error',
        message:
            'listening on $listen: listen tcp $listen: bind: An attempt was '
            'made to access a socket in a way forbidden by its access '
            'permissions',
        code: 'start_failed',
        address: listen,
      );
    },
  ),
  _Scenario(
    'error-new-code',
    'Connection',
    'Home: Error in red with the core\'s English message (a state code this '
        'app does not know).',
    () => _setPhase(
      'error',
      message: 'Something this app does not know about went wrong',
      code: 'from_a_newer_core',
    ),
  ),
  _Scenario(
    'port-in-use',
    'Connection',
    'Home: Error, "Port 10810 is used by another program, so the proxy '
        'cannot start." and a Change port button; saving another port '
        'connects.',
    () {
      final listen = _proxyConfig['listen'] as String;
      _setPhase(
        'error',
        message:
            'listen tcp $listen: bind: Only one usage of each socket address '
            'is normally permitted. Choose another SOCKS5 listen address in '
            'Settings',
        code: 'proxy_port_in_use',
        address: listen,
      );
    },
  ),
  _Scenario(
    'unknown-phase',
    'Connection',
    'Home: Unknown, with the core\'s message (a phase this app does not '
        'know).',
    () => _setPhase('sleeping', message: 'A state from a newer core'),
  ),
  _Scenario(
    'quota-amber',
    'Quota and accounts',
    'Home data card: an 88% ring in amber (amber from 10 points under the '
        '95% switch threshold).',
    () => _setActiveUsage(44),
  ),
  _Scenario(
    'quota-red',
    'Quota and accounts',
    'Home data card: 96% in red; another account is ready, so no low-data '
        'note.',
    () {
      _setActiveUsage(48);
      _accounts[1] = _account('a2', 'bob@example.com', 10);
    },
  ),
  _Scenario(
    'quota-low',
    'Quota and accounts',
    'Home: a red 95% ring and the amber note "The current account is '
        'running out of data (2.4 GB left)..." with Add account: shown for a '
        'minute per connection; closing it hides it for a day.',
    () {
      _accounts
        ..clear()
        ..addAll([
          _account('a1', 'alice@example.com', 47.6, active: true),
          _account(
            'a3',
            'carol@example.com',
            0,
            status: 'reauth_required',
            reason: 'Firefox Account sign-in required',
            reasonCode: 'signin_required',
          ),
        ]);
    },
  ),
  _Scenario(
    'quota-unlimited',
    'Quota and accounts',
    'Home data card: Unlimited. Accounts: the active account\'s unlimited '
        'quota.',
    () => _setActiveUsage(0, unlimited: true),
  ),
  _Scenario(
    'quota-not-read',
    'Quota and accounts',
    'Home data card and Accounts: the quota is not read yet.',
    () => _setActiveUsage(null),
  ),
  _Scenario(
    'accounts-reasons',
    'Quota and accounts',
    'Accounts: one card per reason: quota threshold, quota exhausted, sign '
        'in required, sign-in confirmation, automatic sign-in failed, '
        'waiting after a sign-in, retrying a sign-in, not entitled '
        '(Unavailable until a date), an unknown reason (the core\'s English), '
        'quota not read, unlimited, disabled, and no_password@example.com '
        '(no stored password: Sign in again opens the form; any password '
        'then fails with "no password").',
    () {
      _accounts
        ..clear()
        ..addAll(_reasonAccounts());
    },
  ),
  _Scenario(
    'notices',
    'Other',
    'Home: the amber UDP note (count and time) with a close button. A port '
        '5222 notice is in the status too, but the home leaves port notices '
        'out by design; the logs show it.',
    () {
      final last = _now().subtract(const Duration(minutes: 2));
      _notices = [
        {
          'kind': 'port',
          'detail': '5222',
          'hosts': ['chat.example.org:5222'],
          'count': 3,
          'last': last.toIso8601String(),
        },
        {
          'kind': 'command',
          'detail': 'UDP ASSOCIATE',
          'hosts': <String>[],
          'count': 12,
          'last': last.toIso8601String(),
        },
      ];
      _log(
        'WARN',
        'refused port 5222 (Mozilla connects to 80, 443, 8080, 8443 only)',
      );
    },
  ),
  _Scenario(
    'core-refuses',
    'Other',
    'Every API request answers 401: the app shows "Lost the connection to '
        'the core. Retrying..." and then "The core refused the app; it may '
        'belong to another copy." Switch back here.',
    () => _refuseApp = true,
  ),
  for (final f in _failureCodes)
    for (final mode in _modesFor(f.code))
      _Scenario(
        '$mode:${f.code}',
        'Failures',
        f.text,
        () => _setFailure(f.code, mode),
      ),
];

/// Sets the phase now and after every start.
void _setPhase(
  String phase, {
  String message = '',
  String code = '',
  String address = '',
}) {
  _phase = _steadyPhase = phase;
  _phaseMessage = _steadyMessage = message;
  _stateCode = _steadyCode = code;
  _stateAddress = _steadyAddress = address;
}

void _setFailure(String code, String mode) {
  final now = _now();
  _failure = code;
  _failureMode = mode;
  // A refused location is a chosen one: the UK unless one is chosen.
  if (code == 'location_refused' &&
      (_proxyConfig['country'] as String? ?? '').isEmpty) {
    _proxyConfig['country'] = 'GB';
  }
  switch (mode) {
    case 'test':
      _lastTest = _failedTest(code, now);
    case 'wake':
      // Connected and confirmed a while ago; then Mozilla failed.
      _phaseSince = now.subtract(const Duration(minutes: 1));
      _lastTest = _passedTest(now.subtract(const Duration(seconds: 10)));
      _wakeFailedAt = now;
    case 'gaveup':
      _phase = 'off';
      _connectFailure = code;
  }
  _log(
    'WARN',
    'connecting through Mozilla failed code=$code err=${_failureDetail(code)}',
  );
}

/// Back to a working connection with the usual accounts.
void _reset() {
  final now = _now();
  _setPhase('running');
  _holdStarting = false;
  _phaseSince = now.subtract(const Duration(seconds: 1));
  _failure = '';
  _failureMode = '';
  _wakeFailedAt = null;
  _giveUpAt = null;
  _connectFailure = '';
  _noNetwork = false;
  _networkChangedAt = null;
  _autoConnecting = false;
  _exitCountry = '';
  _refuseApp = false;
  _notices = [];
  _proxyConfig['country'] = '';
  _accounts
    ..clear()
    ..addAll(_normalAccounts());
  _lastTest = _passedTest(now);
}

bool _apply(String name) {
  final s = _scenarios.where((s) => s.name == name).firstOrNull;
  if (s == null) return false;
  _reset();
  s.apply();
  _scenario = name;
  _log('INFO', 'fake core: scenario $name');
  return true;
}

/// Moves the state on as time passes: a start ends after two seconds, and
/// a connect that keeps failing is given up after eight.
void _tick() {
  final now = _now();
  if (_phase == 'starting' &&
      !_holdStarting &&
      now.difference(_phaseSince).inSeconds >= 2) {
    _phase = _steadyPhase;
    _phaseMessage = _steadyMessage;
    _stateCode = _steadyCode;
    _stateAddress = _steadyAddress;
    _phaseSince = now;
    if (_phase == 'running') {
      switch (_failureMode) {
        case 'test':
          _lastTest = _failedTest(_failure, now);
        case 'wake':
          _wakeFailedAt = now;
        case 'gaveup':
          _wakeFailedAt = now;
          _giveUpAt = now.add(const Duration(seconds: 8));
      }
    }
  }
  if (_giveUpAt != null && now.isAfter(_giveUpAt!)) {
    _phase = 'off';
    _phaseSince = now;
    _connectFailure = _failure;
    _wakeFailedAt = null;
    _giveUpAt = null;
    _log('WARN', 'connect given up code=$_failure');
  }
}

void _start() {
  _phase = 'starting';
  _phaseSince = _now();
  _phaseMessage = '';
  _stateCode = '';
  _stateAddress = '';
  _wakeFailedAt = null;
  _giveUpAt = null;
}

// --- Status ---

Map<String, Object?> _location(String code) =>
    _locations.where((l) => l.code == code).firstOrNull ?? _locations.first;

/// The location the proxy uses for the selection.
Map<String, Object?> _proxyLocation() => switch (_selection) {
  '' => _locations.first,
  'fastest' => _location('SE'),
  final code => _location(code.toUpperCase()),
};

Map<String, Object?> _status() {
  _tick();
  final now = _now();
  final running = _phase == 'running';
  final working = running && _failureMode.isEmpty;
  final rateDown = working ? 400000 + _random.nextInt(900000) : 0;
  final rateUp = working ? 20000 + _random.nextInt(60000) : 0;
  _down += rateDown * 2;
  _up += rateUp * 2;
  final views = _accountViews();
  final counts = <String, int>{'total': views.length};
  for (final a in views) {
    final key = a['enabled'] == true ? a['status'] as String : 'disabled';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final active = views.where((a) => a['active'] == true).firstOrNull;
  final loc = _proxyLocation();
  final exit = _exitCountry.isEmpty ? loc : _location(_exitCountry);
  final chosen = _selection.length == 2 ? _selection.toUpperCase() : '';
  final mismatch = working && chosen.isNotEmpty && exit.code != chosen;
  final wake = running && _wakeFailedAt != null;
  return {
    'state': {
      'phase': _phase,
      'message': _phaseMessage.isNotEmpty
          ? _phaseMessage
          : switch (_phase) {
              'running' => 'Proxy running',
              'off' => 'Proxy off',
              _ => 'Starting the proxy',
            },
      'since': _phaseSince.toIso8601String(),
      if (_phase == 'error' || _phase == 'waiting')
        'retry_at': now.add(const Duration(seconds: 30)).toIso8601String(),
      if (_stateCode.isNotEmpty) 'code': _stateCode,
      if (_stateAddress.isNotEmpty) 'address': _stateAddress,
    },
    if (running)
      'proxy': {
        'listen': _proxyConfig['listen'],
        'upstream': loc['server'],
        'country_code': loc.code,
        'country_name': loc['name'],
        'city_name': loc['city'],
        'selection_source': switch (_selection) {
          '' => 'recommended_location',
          'fastest' => 'fastest',
          _ => 'country',
        },
        'transport': _proxyConfig['transport'] == 'h2' ? 'HTTP/2' : 'HTTP/3',
        'started_at': _phaseSince.toIso8601String(),
        if (wake) ...{
          'wake_error': _failureDetail(_failure),
          'wake_error_code': _failure,
          'wake_failed_at': _wakeFailedAt!.toIso8601String(),
        },
      },
    if (working)
      'exit': {
        'ipv4': '203.0.113.42',
        'country_code': exit.code,
        'country_name': exit['name'],
        'city': exit['city'],
        'network': 'Example Transit B.V.',
      },
    if (mismatch)
      'exit_mismatch': {
        'chosen_country_code': chosen,
        'chosen_country_name': _location(chosen)['name'],
        'exit_country_code': exit.code,
        'exit_country_name': exit['name'],
      },
    if (working)
      'pass': {
        'proxy_pass_expires_at': now
            .add(const Duration(minutes: 47))
            .toIso8601String(),
        'seconds_until_expiry': 47 * 60,
      },
    'notices': _notices,
    if (running)
      'traffic': {
        'down': _down,
        'up': _up,
        'direct_down': 240 * 1024 * 1024,
        'direct_up': 12 * 1024 * 1024,
        'down_rate': rateDown,
        'up_rate': rateUp,
      },
    'last_test': ?_lastTest,
    'active_account': ?active,
    'accounts': counts,
    'switch_threshold_percent': _threshold(),
    'version': '3.4-fake',
    'can_exit': true,
    'system_proxy': _systemProxy,
    'system_proxy_supported': !_phone,
    if (_autoConnecting) 'auto_connecting': true,
    if (_connectFailure.isNotEmpty) 'connect_failure': _connectFailure,
    'selection': _selection,
    if (chosen.isNotEmpty) 'selection_name': _location(chosen)['name'],
    if (_noNetwork) 'no_network': true,
    if (_networkChangedAt != null)
      'network_changed_at': _networkChangedAt!.toIso8601String(),
    'data_dir': 'C:/fake/data',
  };
}

Map<String, Object?> _passedTest(DateTime at) {
  final tunnel = 120 + _random.nextInt(80);
  final tls = 90 + _random.nextInt(60);
  final response = 60 + _random.nextInt(60);
  final exit = _exitCountry.isEmpty
      ? _proxyLocation()
      : _location(_exitCountry);
  return {
    'at': at.toIso8601String(),
    'ok': true,
    'target': 'https://www.google.com/generate_204',
    'http_status': 204,
    'tunnel_ms': tunnel,
    'tls_ms': tls,
    'response_ms': response,
    'first_byte_ms': tunnel + tls + response,
    'total_ms': tunnel + tls + response + 4,
    'exit_ipv4': '203.0.113.42',
    'exit_country': exit.code,
    'exit_city': exit['city'],
    'exit_network': 'Example Transit B.V.',
  };
}

Map<String, Object?> _failedTest(String code, DateTime at) => {
  'at': at.toIso8601String(),
  'ok': false,
  'target': 'https://www.google.com/generate_204',
  'error': _failureDetail(code),
  'error_code': code,
  if (code == 'test_site') ...{'tunnel_ms': 180, 'http_status': 502},
};

// --- Sign-in ---

/// Emails whose name (before @) makes the sign-in go another way, and how.
const _magicEmails = <String, String>{
  'no_account':
      'fails: no Firefox Account (the form stays, with a link to '
      "Mozilla's sign-up)",
  'wrong_password':
      'fails: incorrect password (the form stays, the cursor '
      'in Password)',
  'no_password':
      'fails: no password (Google or Apple sign-in; a Set a '
      'password button)',
  'too_many_attempts': 'fails: too many attempts',
  'network': 'fails: Mozilla could not be reached',
  'timed_out':
      'asks for the emailed code, then fails after 8 seconds: '
      'timed out',
  'wrong_code':
      'asks for the emailed code; a wrong one: wrong or expired '
      'code (as any email does)',
  'too_many_codes':
      'asks for the emailed code; the third wrong one fails: '
      'too many codes',
  'wrong_totp': 'asks for the authenticator code; a wrong one: wrong code',
  'unblock_code_rejected':
      'asks for an unblock code; a wrong one: unblock '
      'code not accepted',
  'captcha': 'asks for a CAPTCHA (any text), then the emailed code',
  'captcha_broken': 'asks for a CAPTCHA whose image cannot be shown',
  'email_link':
      'waits for the confirmation link, then finishes by itself '
      'after 6 seconds',
  'other_error':
      'fails with an error that has no code (the core\'s '
      'English)',
  'api_error':
      'the core refuses the request (HTTP 400; its English in the '
      'form)',
};

/// The sign-in without the fake's own notes (keys that start with _).
Map<String, Object?> _signInView(Map<String, Object?> s) => {
  for (final e in s.entries)
    if (!e.key.startsWith('_')) e.key: e.value,
};

void _signInStep(
  Map<String, Object?> s,
  String step, {
  String message = '',
  String errorCode = '',
  String error = '',
}) {
  s['step'] = step;
  s['message'] = message;
  s.remove('captcha');
  if (error.isEmpty) {
    s
      ..remove('error')
      ..remove('error_code');
  } else {
    s['error'] = error;
    if (errorCode.isNotEmpty) {
      s['error_code'] = errorCode;
    } else {
      s.remove('error_code');
    }
  }
}

void _signInFails(Map<String, Object?> s, String code, String text) =>
    _signInStep(
      s,
      'failed',
      message: 'The account was not added.',
      errorCode: code,
      error: text,
    );

/// Moves a sign-in on as time passes, as the core's would.
void _advanceSignIn(Map<String, Object?> s) {
  final now = _now();
  final at = s['_at'] as DateTime?;
  if (at == null || now.isBefore(at)) return;
  s.remove('_at');
  final email = s['email'] as String;
  switch (s['step']) {
    case 'need_email_link':
      _signedIn(s);
      return;
    case 'need_email_code' when s['_timeout'] == true:
      _signInFails(
        s,
        'timed_out',
        'The sign-in took too long. Start it again.',
      );
      return;
    case 'working':
      break;
    default:
      return;
  }
  switch (s['_magic']) {
    case 'no_account':
      _signInFails(
        s,
        'no_account',
        'No Firefox Account exists for this email.',
      );
    case 'wrong_password':
      _signInFails(s, 'wrong_password', 'Incorrect password.');
    case 'no_password':
      _signInFails(
        s,
        'no_password',
        'This account has no password: it was made with Google or Apple '
            'sign-in. Set one on accounts.firefox.com (Forgot password), then '
            'sign in with it.',
      );
    case 'too_many_attempts':
      _signInFails(
        s,
        'too_many_attempts',
        'Too many attempts. Wait a while and try again.',
      );
    case 'network':
      _signInFails(
        s,
        'network',
        'Post "https://api.accounts.firefox.com/v1/account/login": dial tcp: '
            'i/o timeout',
      );
    case 'other_error':
      _signInFails(s, '', 'Firefox Accounts: account is locked (errno 121)');
    case 'unblock_code_rejected':
      _signInStep(
        s,
        'need_unblock_code',
        message:
            'Firefox Accounts blocked this sign-in as unusual and emailed an '
            'unblock code to $email. Enter it.',
      );
    case 'captcha' || 'captcha_broken':
      _signInStep(
        s,
        'need_captcha',
        message:
            'Firefox Accounts asks for a CAPTCHA. Type the characters shown.',
      );
      s['captcha'] = s['_magic'] == 'captcha'
          ? _captchaImage()
          : 'data:image/png;base64,not-an-image';
    case 'email_link':
      s['password_accepted'] = true;
      _signInStep(
        s,
        'need_email_link',
        message: 'Open the confirmation link sent to $email, then continue.',
      );
      s['_at'] = now.add(const Duration(seconds: 6));
    case 'wrong_totp':
      s['password_accepted'] = true;
      _signInStep(
        s,
        'need_totp',
        message: 'Enter the code from your authenticator app.',
      );
    default:
      _askEmailCode(s);
      if (s['_magic'] == 'timed_out') {
        s['_timeout'] = true;
        s['_at'] = now.add(const Duration(seconds: 8));
      }
  }
}

void _askEmailCode(Map<String, Object?> s, {String errorCode = ''}) {
  s['password_accepted'] = true;
  _signInStep(
    s,
    'need_email_code',
    message: 'Enter the verification code sent to ${s['email']}.',
    errorCode: errorCode,
    error: errorCode.isEmpty
        ? ''
        : 'Wrong or expired code. Use the code from the latest email from '
              'Mozilla; an older code stops working when a new one is sent.',
  );
}

/// Takes an answer to the step the sign-in waits on.
void _answerSignIn(Map<String, Object?> s, String value) {
  final right = value == '123456';
  switch (s['step']) {
    case 'need_captcha':
      _askEmailCode(s);
    case 'need_unblock_code':
      if (right) {
        _signedIn(s);
      } else {
        _signInStep(
          s,
          'need_unblock_code',
          message: s['message'] as String,
          errorCode: 'unblock_code_rejected',
          error:
              'That unblock code was not accepted. Check it against the '
              'latest email from Mozilla and try again.',
        );
      }
    case 'need_email_code' || 'need_totp':
      if (right) {
        _signedIn(s);
        return;
      }
      final wrong = (s['_wrong'] as int? ?? 0) + 1;
      s['_wrong'] = wrong;
      if (s['_magic'] == 'too_many_codes' && wrong >= 3) {
        _signInFails(
          s,
          'too_many_codes',
          'Too many wrong codes. Start the sign-in again.',
        );
      } else if (s['step'] == 'need_totp') {
        _signInStep(
          s,
          'need_totp',
          message: s['message'] as String,
          errorCode: 'wrong_totp',
          error: 'Wrong code. Enter the code the authenticator app shows now.',
        );
      } else {
        _askEmailCode(s, errorCode: 'wrong_code');
      }
  }
}

void _signedIn(Map<String, Object?> s) {
  _signInStep(s, 'done', message: 'Account added');
  final email = s['email'] as String;
  var account = _accounts.where((a) => a['email'] == email).firstOrNull;
  if (account != null) {
    account
      ..['status'] = 'ready'
      ..['reason'] = ''
      ..remove('reason_code')
      ..remove('reason_detail')
      ..remove('retry_at')
      ..['has_password'] = true;
  } else {
    account = _account('a${_accounts.length + 100}', email, 0);
    _accounts.add(account);
  }
  s['account_id'] = account['id'];
}

/// A CAPTCHA-like PNG: digits over noise, as a data URL.
String _captchaImage() {
  const w = 180, h = 60, scale = 6;
  const font = {
    '1': ['010', '110', '010', '010', '111'],
    '2': ['111', '001', '111', '100', '111'],
    '4': ['101', '101', '111', '001', '001'],
    '5': ['111', '100', '111', '001', '111'],
    '8': ['111', '101', '111', '101', '111'],
    '9': ['111', '101', '111', '001', '111'],
  };
  final pixels = Uint8List(w * h);
  for (var i = 0; i < pixels.length; i++) {
    pixels[i] = 200 + _random.nextInt(56);
  }
  const text = '482915';
  for (var c = 0; c < text.length; c++) {
    final glyph = font[text[c]]!;
    final left = 18 + c * 4 * scale;
    final top = 15 + (c.isEven ? -3 : 3);
    for (var gy = 0; gy < 5; gy++) {
      for (var gx = 0; gx < 3; gx++) {
        if (glyph[gy][gx] != '1') continue;
        for (var y = 0; y < scale; y++) {
          for (var x = 0; x < scale; x++) {
            pixels[(top + gy * scale + y) * w + left + gx * scale + x] =
                30 + _random.nextInt(50);
          }
        }
      }
    }
  }
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw
      ..addByte(0)
      ..add(pixels.sublist(y * w, (y + 1) * w));
  }
  final header = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8); // 8-bit grayscale, the rest zero
  final png = BytesBuilder()
    ..add(const [137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_pngChunk('IHDR', header.buffer.asUint8List()))
    ..add(_pngChunk('IDAT', ZLibEncoder().convert(raw.takeBytes())))
    ..add(_pngChunk('IEND', const []));
  return 'data:image/png;base64,${base64Encode(png.takeBytes())}';
}

List<int> _pngChunk(String type, List<int> data) {
  final body = [...ascii.encode(type), ...data];
  var crc = 0xFFFFFFFF;
  for (final b in body) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = crc & 1 != 0 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  crc ^= 0xFFFFFFFF;
  return [
    ...(ByteData(4)..setUint32(0, data.length)).buffer.asUint8List(),
    ...body,
    ...(ByteData(4)..setUint32(0, crc)).buffer.asUint8List(),
  ];
}

// --- Server ---

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/fake_core.dart <data-dir> [port]');
    exit(2);
  }
  final dir = Directory(args[0])..createSync(recursive: true);
  final port = args.length > 1 ? int.parse(args[1]) : 19090;
  final token = base64Url.encode(
    List.generate(24, (_) => _random.nextInt(256)),
  );
  File('${dir.path}/local-api.token').writeAsStringSync(token);
  File('${dir.path}/config.json').writeAsStringSync(
    jsonEncode({
      'dashboard': {'listen': '127.0.0.1:$port'},
    }),
  );
  _log('INFO', 'service starting data_dir=(fake)');
  _log(
    'INFO',
    'SOCKS5 proxy started listen=127.0.0.1:10810 upstream=nl-ams-001.example.net:443 transport=h3',
  );
  _log('DEBUG', 'quota checked account=a1 used=18.4GiB');
  _apply('connected');
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout
    ..writeln(
      'fake core on http://127.0.0.1:$port, data dir ${dir.absolute.path}',
    )
    ..writeln('scenarios: http://127.0.0.1:$port/fake');
  await for (final req in server) {
    try {
      await _handle(req, token);
    } on Object catch (e) {
      _send(req, 500, {'error': '$e'});
    }
  }
}

Future<void> _handle(HttpRequest req, String token) async {
  final path = req.uri.path;
  final m = req.method;
  // The scenario page needs no token: the server listens on loopback only.
  if (path == '/fake' || path.startsWith('/fake/')) return _handleFake(req);
  if (_refuseApp || req.headers.value('X-Local-Token') != token) {
    return _send(req, 401, {'error': 'login required'});
  }
  // As the core's guard: a state change must be JSON.
  if (m != 'GET' &&
      m != 'HEAD' &&
      req.headers.contentType?.mimeType != 'application/json') {
    return _send(req, 415, {'error': 'requests must be JSON'});
  }
  final body = await utf8.decoder.bind(req).join();
  final input = body.isEmpty
      ? <String, Object?>{}
      : jsonDecode(body) as Map<String, Object?>;
  final seg = req.uri.pathSegments;

  if (m == 'GET' && path == '/api/status') return _send(req, 200, _status());
  if (m == 'GET' && path == '/api/accounts') {
    return _send(req, 200, {
      'accounts': _accountViews(),
      'switch_threshold_percent': _threshold(),
    });
  }
  if (m == 'GET' && path == '/api/settings') {
    return _send(req, 200, {'config': _config, 'data_dir': 'C:/fake/data'});
  }
  if (m == 'PUT' && path == '/api/settings') {
    _config
      ..clear()
      ..addAll(input['config'] as Map<String, Object?>);
    // A new proxy port ends "port in use", as the core restarts on it.
    if (_stateCode == 'proxy_port_in_use' &&
        _proxyConfig['listen'] != _stateAddress) {
      _setPhase('running');
      _start();
    }
    return _send(req, 200, {'saved': true});
  }
  if (m == 'POST' && path == '/api/system-proxy') {
    final mode = input['mode'] as String;
    if (mode != 'set' && mode != 'clear') {
      return _send(req, 400, {
        'error': 'system_proxy.mode must be set or clear',
      });
    }
    _systemProxy = mode;
    return _send(req, 200, {'mode': _systemProxy});
  }
  if (m == 'POST' && path == '/api/power') {
    if (input['on'] == true) {
      _connectFailure = '';
      _holdStarting = false;
      // The auto-connect's wait for a test is the auto-connecting
      // scenario's; here every connect is the button's.
      _autoConnecting = false;
      _start();
      if (_refusesChoice()) _setFailure('location_refused', 'test');
    } else {
      _phase = 'off';
      _phaseSince = _now();
      _phaseMessage = '';
      _stateCode = '';
      _stateAddress = '';
      _holdStarting = false;
      _autoConnecting = false;
      _wakeFailedAt = null;
      _giveUpAt = null;
    }
    return _send(req, 200, {'on': input['on'] == true});
  }
  if (m == 'POST' && path == '/api/retry') {
    return _send(req, 200, {'ok': true});
  }
  if (m == 'GET' && path == '/api/locations') {
    return _send(req, 200, {'locations': _locations, 'pinged_at': _pingedAt});
  }
  if (m == 'POST' && path == '/api/locations/ping') {
    await Future<void>.delayed(const Duration(seconds: 2));
    final codes = (input['codes'] as List?)?.cast<String>() ?? const [];
    for (final loc in _locations) {
      if (codes.isNotEmpty && !codes.contains(loc.code)) continue;
      // A network that blocks Mozilla: no location answers.
      if (_networkDown) {
        loc
          ..remove('ping_ms')
          ..['ping_error'] = 'i/o timeout';
      } else {
        loc
          ..remove('ping_error')
          ..['ping_ms'] = 150 + _random.nextInt(900);
      }
    }
    _pingedAt = _now().toIso8601String();
    return _send(req, 200, {
      'locations': [
        for (final loc in _locations)
          {...loc, 'error': loc['ping_error']}..remove('ping_error'),
      ],
      'pinged_at': _pingedAt,
    });
  }
  if (m == 'POST' && path == '/api/location') {
    _proxyConfig['country'] = input['country'];
    _log('INFO', 'location changed country=${input['country']}');
    // Another location clears the given-up connect, which was about the
    // one before; a refused location is fixed by choosing another.
    _connectFailure = '';
    if (_failure == 'location_refused') {
      _failure = '';
      _failureMode = '';
    }
    if (_phase != 'off') {
      _start();
      if (_refusesChoice()) _setFailure('location_refused', 'test');
    }
    return _send(req, 200, {'ok': true});
  }
  if (m == 'GET' && path == '/api/logs') {
    final after = int.tryParse(req.uri.queryParameters['after'] ?? '') ?? 0;
    if (_random.nextInt(3) == 0) {
      _log('DEBUG', 'tunnel opened host=www.example.com:443');
    }
    return _send(req, 200, {
      'entries': _logs.where((e) => (e['id'] as int) > after).toList(),
    });
  }
  if (m == 'GET' && path == '/api/routing') {
    return _send(req, 200, {
      'enabled': true,
      'region': 'ir',
      'active': true,
      'summary': 'geosite:ir=57554 geoip:ir=2553 geoip:private=18',
      'files': [
        {'name': 'geosite.dat', 'updated_at': _now().toIso8601String()},
        {'name': 'geoip.dat', 'updated_at': _now().toIso8601String()},
      ],
    });
  }
  if (m == 'POST' && path == '/api/routing/test') {
    final target = input['target'] as String;
    final direct = target.endsWith('.ir');
    return _send(req, 200, {
      'host': target,
      'route': direct ? 'direct' : 'proxy',
      if (direct) 'rule': 'geosite:ir',
    });
  }
  if (m == 'POST' && path == '/api/dns/test') {
    // A network that blocks Mozilla: one name fails, one is filtered.
    if (_networkDown) {
      return _send(req, 200, {
        'results': [
          {
            'host': 'accounts.firefox.com',
            'role': 'Firefox Accounts',
            'error': 'lookup accounts.firefox.com: i/o timeout',
            'system_addrs': ['10.10.34.35'],
            'system_ms': 30,
            'differs': true,
            'filtered': true,
          },
          {
            'host': 'vpn.mozilla.org',
            'role': 'Guardian',
            'addrs': ['203.0.113.10'],
            'ms': 900,
            'system_addrs': ['10.10.34.35'],
            'system_ms': 25,
            'differs': true,
            'filtered': true,
          },
        ],
      });
    }
    return _send(req, 200, {
      'results': [
        for (final host in ['accounts.firefox.com', 'vpn.mozilla.org'])
          {
            'host': host,
            'addrs': ['203.0.113.10'],
            'ms': 40,
            'system_ms': 25,
          },
      ],
    });
  }
  if (m == 'POST' && path == '/api/open-folder') {
    return _send(req, 200, {'result': 'opened'});
  }
  if (m == 'POST' && path == '/api/app/exit') {
    _send(req, 200, {'exiting': true});
    exit(0);
  }
  if (m == 'POST' && path == '/api/test') {
    if (_phase != 'running') {
      return _send(req, 409, {'error': 'the proxy is not running'});
    }
    final failing = _failureMode.isNotEmpty;
    await Future<void>.delayed(
      Duration(milliseconds: failing && _networkDown ? 3000 : 700),
    );
    _lastTest = failing ? _failedTest(_failure, _now()) : _passedTest(_now());
    return _send(req, 200, _lastTest!);
  }
  if (m == 'POST' && path == '/api/proxy/restart') {
    if (_phase != 'off') _start();
    return _send(req, 200, {'ok': true});
  }
  if (m == 'POST' && path == '/api/accounts/order') {
    final ids = (input['ids'] as List).cast<String>();
    _accounts.sort(
      (a, b) => ids
          .indexOf(a['id'] as String)
          .compareTo(ids.indexOf(b['id'] as String)),
    );
    return _send(req, 200, {'ok': true});
  }
  if (seg.length >= 3 && seg[1] == 'accounts') {
    final acc = _accounts.where((a) => a['id'] == seg[2]).firstOrNull;
    if (acc == null) return _send(req, 404, {'error': 'unknown account'});
    final action = seg.length > 3 ? seg[3] : '';
    switch ((m, action)) {
      case ('DELETE', ''):
        _accounts.remove(acc);
      case ('POST', 'activate'):
        for (final a in _accounts) {
          a['active'] = a == acc;
        }
      case ('POST', 'enabled'):
        acc['enabled'] = input['enabled'] == true;
      case ('POST', 'refresh'):
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (_networkDown) {
          return _send(req, 502, {
            'error':
                'reading the quota failed: Get "https://vpn.mozilla.org/api/'
                'v1/fpn/usage": dial tcp: i/o timeout',
          });
        }
      default:
        return _send(req, 404, {'error': 'not found'});
    }
    return _send(req, 200, {'ok': true});
  }
  if (m == 'POST' && path == '/api/signin') {
    final id = 's${_signIns.length + 1}';
    var email = input['email'] as String? ?? '';
    if (input['account_id'] case final String accountId) {
      final acc = _accounts.firstWhere((a) => a['id'] == accountId);
      if (acc['has_password'] != true) {
        return _send(req, 409, {
          'error': 'no stored password for this account; enter it',
        });
      }
      email = acc['email'] as String;
    }
    final magic = email.split('@').first.toLowerCase();
    if (magic == 'api_error') {
      return _send(req, 400, {'error': 'email and password are required'});
    }
    final s = _signIns[id] = {
      'id': id,
      'email': email,
      'step': 'working',
      'message': 'Signing in',
      '_magic': magic,
      '_at': _now().add(const Duration(milliseconds: 1200)),
    };
    return _send(req, 202, _signInView(s));
  }
  if (seg.length == 3 && seg[1] == 'signin') {
    final s = _signIns[seg[2]];
    if (s == null) return _send(req, 404, {'error': 'unknown sign-in'});
    _advanceSignIn(s);
    if (m == 'DELETE') {
      _signInStep(s, 'cancelled', message: 'Sign-in cancelled');
      return _send(req, 200, {'cancelled': true});
    }
    if (m == 'POST') {
      if (!(s['step'] as String).startsWith('need_')) {
        return _send(req, 409, {
          'error': 'this sign-in is not waiting for input',
        });
      }
      _answerSignIn(s, (input['value'] as String? ?? '').trim());
    }
    return _send(req, 200, _signInView(s));
  }
  return _send(req, 404, {'error': 'not found'});
}

/// The scenario page and its actions.
Future<void> _handleFake(HttpRequest req) async {
  final path = req.uri.path;
  if (req.method == 'GET' && (path == '/fake' || path == '/fake/')) {
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..headers.set('Cache-Control', 'no-store')
      ..write(_page());
    await req.response.close();
    return;
  }
  if (req.method == 'GET' && path == '/fake/state') {
    return _send(req, 200, {'scenario': _scenario, 'phone': _phone});
  }
  if (req.method != 'POST' ||
      req.headers.contentType?.mimeType != 'application/json') {
    return _send(req, 404, {'error': 'not found'});
  }
  final input =
      jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, Object?>;
  if (path == '/fake/scenario') {
    final name = input['name'] as String? ?? '';
    if (!_apply(name)) {
      return _send(req, 404, {'error': 'unknown scenario $name'});
    }
    stdout.writeln('scenario: $name');
    return _send(req, 200, {'scenario': _scenario});
  }
  if (path == '/fake/phone') {
    _phone = input['on'] == true;
    return _send(req, 200, {'phone': _phone});
  }
  if (path == '/fake/locks') {
    _enforceLocks = input['on'] == true;
    stdout.writeln('Mozilla enforces the locks: $_enforceLocks');
    return _send(req, 200, {'locks': _enforceLocks});
  }
  return _send(req, 404, {'error': 'not found'});
}

String _page() {
  const esc = HtmlEscape();
  final out = StringBuffer();
  String button(String name, String label) =>
      '<button data-name="${esc.convert(name)}"'
      '${name == _scenario ? ' class="on"' : ''}>${esc.convert(label)}</button>';
  out.write('''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Fake core scenarios</title>
<style>
:root { color-scheme: light dark; --bg: #f6f7fb; --card: #fff; --text: #1b1e2e;
  --muted: #61667f; --line: #dfe2ec; --accent: #5b4cf0; --on: #e8e5ff; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #10131f; --card: #191d2c; --text: #e9ebf5; --muted: #9aa0bb;
    --line: #2a2f44; --accent: #8f84ff; --on: #2b2759; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--text);
  font: 15px/1.45 system-ui, "Segoe UI", sans-serif; }
main { max-width: 960px; margin: 0 auto; padding: 20px 16px 48px; }
h1 { font-size: 22px; margin: 0 0 4px; }
h2 { font-size: 16px; margin: 28px 0 10px; }
p, li { color: var(--muted); }
.now { position: sticky; top: 0; background: var(--bg); padding: 8px 0;
  border-bottom: 1px solid var(--line); z-index: 1; }
.now b { color: var(--accent); }
.row { display: grid; grid-template-columns: 210px 1fr; gap: 12px;
  align-items: start; padding: 10px 12px; background: var(--card);
  border: 1px solid var(--line); border-radius: 10px; margin-bottom: 8px; }
.row p { margin: 4px 0 0; }
button { font: inherit; padding: 6px 10px; border-radius: 8px; cursor: pointer;
  border: 1px solid var(--line); background: var(--card); color: var(--text);
  text-align: left; }
button:hover { border-color: var(--accent); }
button.on { background: var(--on); border-color: var(--accent); font-weight: 600; }
.row > button { width: 100%; }
table { width: 100%; border-collapse: collapse; background: var(--card);
  border: 1px solid var(--line); border-radius: 10px; overflow: hidden; }
th, td { padding: 8px 10px; border-bottom: 1px solid var(--line);
  text-align: left; vertical-align: top; }
th { font-size: 13px; color: var(--muted); font-weight: 600; }
td.text { color: var(--muted); font-size: 14px; }
code { font-family: ui-monospace, Consolas, monospace; font-size: 13px; }
label { display: flex; gap: 8px; align-items: start; color: var(--muted); }
.wide { overflow-x: auto; }
@media (max-width: 640px) { .row { grid-template-columns: 1fr; } }
</style>
</head>
<body>
<main>
<h1>Fake core scenarios</h1>
<p>Each button switches what the fake core reports; the app shows it at its
next poll (two seconds; the accounts page within six). A switch puts the
usual accounts back, except where the scenario has its own. Keep the window
at least 640 px wide for the computer layout.</p>
<div class="now">Now: <b id="current">${esc.convert(_scenario)}</b></div>
''');
  String? group;
  for (final s in _scenarios.where((s) => s.group != 'Failures')) {
    if (s.group != group) {
      group = s.group;
      out.write('<h2>${esc.convert(group)}</h2>\n');
    }
    out.write(
      '<div class="row">${button(s.name, s.name)}'
      '<p>${esc.convert(s.description)}</p></div>\n',
    );
  }
  out.write('''
<h2>Failures</h2>
<p><b>Test failed</b>: the proxy runs but connection tests fail: Home shows
Connecting in orange and the reason in red; hovering it shows the core's
text. <b>Wake failed</b>: it was connected, then connecting to Mozilla
failed: the same look, from the proxy's wake error (the app's own retest
then fails too). <b>Given up</b>: the last connect was given up: Off and the
reason in red; connecting again shows Connecting with the reason for eight
seconds, then gives up again.</p>
<div class="wide"><table>
<tr><th>Code</th><th>What the app says (English)</th><th>Show it as</th></tr>
''');
  for (final f in _failureCodes) {
    out.write(
      '<tr><td><code>${esc.convert(f.code)}</code></td>'
      '<td class="text">${esc.convert(f.text)}</td><td>',
    );
    for (final mode in _modesFor(f.code)) {
      out.write('${button('$mode:${f.code}', _modeTitles[mode]!)} ');
    }
    out.write('</td></tr>\n');
  }
  out.write('''
</table></div>
<h2>Locked locations</h2>
<label><input type="checkbox" id="locks"${_enforceLocks ? ' checked' : ''}>
<span>Act as if Mozilla enforced its locks: choosing a country its server
list marks locked (${esc.convert((_lockedCountries.toList()..sort()).join(' '))})
on the Servers page, or connecting with one chosen, is refused: Home shows
<i>This country isn't open to your account</i> and the <i>Use the
recommended location</i> button. Today Mozilla does not enforce them.</span></label>
<h2>Phone layout</h2>
<label><input type="checkbox" id="phone"${_phone ? ' checked' : ''}>
<span>Report <code>system_proxy_supported: false</code>, as the phone's core
does. A window narrower than 640 px then shows the phone home with the
phone's logic (the power button turns the proxy on and off; failures
show).</span></label>
<h2>Sign-in</h2>
<p>Add account (or Sign in again) with any password. The emailed code
<code>123456</code> is accepted. These emails (any domain) go another way:</p>
<div class="wide"><table>
<tr><th>Email</th><th>What happens</th></tr>
''');
  for (final e in _magicEmails.entries) {
    out.write(
      '<tr><td><code>${esc.convert(e.key)}@example.com</code></td>'
      '<td class="text">${esc.convert(e.value)}</td></tr>\n',
    );
  }
  out.write('''
</table></div>
</main>
<script>
function mark(name) {
  document.querySelectorAll('[data-name]').forEach(function (b) {
    b.classList.toggle('on', b.dataset.name === name);
  });
  document.getElementById('current').textContent = name;
}
function post(path, body) {
  return fetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
}
document.addEventListener('click', function (e) {
  var b = e.target.closest('[data-name]');
  if (!b) return;
  post('/fake/scenario', { name: b.dataset.name }).then(function (r) {
    if (r.ok) mark(b.dataset.name); else alert('The fake core said ' + r.status);
  }, function () { alert('The fake core is not running.'); });
});
document.getElementById('phone').addEventListener('change', function (e) {
  post('/fake/phone', { on: e.target.checked });
});
document.getElementById('locks').addEventListener('change', function (e) {
  post('/fake/locks', { on: e.target.checked });
});
</script>
</body>
</html>
''');
  return out.toString();
}

void _send(HttpRequest req, int status, Object body) {
  req.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  req.response.close();
}

extension on Map<String, Object?> {
  String get code => this['code'] as String;
}

/// The switch threshold in the settings, which Settings can change.
num _threshold() =>
    (_config['accounts'] as Map)['switch_threshold_percent'] as num? ?? 95;
