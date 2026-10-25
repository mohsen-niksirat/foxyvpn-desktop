part of 'models.dart';

/// The ProxyPass the proxy uses now (`status.pass`).
class PassInfo {
  PassInfo.fromJson(Map<String, Object?> j)
    : expiresAt = _time(j['proxy_pass_expires_at']),
      secondsUntilExpiry = _int(j['seconds_until_expiry']),
      lastError = _str(j['last_error']);

  final DateTime? expiresAt;
  final int secondsUntilExpiry;
  final String lastError;
}

/// A request the proxy refused recently: a port Mozilla's proxy does not
/// connect to (`kind` port), or a SOCKS command other than CONNECT such as
/// UDP (`kind` command).
class Notice {
  Notice.fromJson(Map<String, Object?> j)
    : kind = _str(j['kind']),
      detail = _str(j['detail']),
      hosts = [
        for (final h in (j['hosts'] as List<Object?>? ?? const [])) _str(h),
      ],
      count = _int(j['count']),
      last = _time(j['last']);

  final String kind;
  final String detail;
  final List<String> hosts;
  final int count;
  final DateTime? last;

  /// Identifies one refusal episode: a newer refusal shows the note again.
  String get key => '$kind|$detail|${last?.millisecondsSinceEpoch}';
}

/// A location from the server list (`GET /api/locations`).
class Location {
  Location.fromJson(Map<String, Object?> j)
    : code = _str(j['code']),
      name = _str(j['name']),
      city = _str(j['city']),
      server = _str(j['server']),
      recommended = _bool(j['recommended']),
      pingMs = _int(j['ping_ms']),
      // The list names it ping_error; the ping result names it error.
      pingError = _str(j['ping_error'] ?? j['error']);

  final String code;
  final String name;
  final String city;
  final String server;
  final bool recommended;

  /// The last real delay; 0 when not measured or failed.
  final int pingMs;
  final String pingError;

  bool get answered => pingMs > 0;
}

class LocationList {
  LocationList.fromJson(Map<String, Object?> j)
    : locations = [
        for (final l in (j['locations'] as List<Object?>? ?? const []))
          Location.fromJson(_map(l)),
      ],
      pingedAt = _time(j['pinged_at']);

  final List<Location> locations;
  final DateTime? pingedAt;
}

/// A line of the core's log (`GET /api/logs`).
class LogEntry {
  LogEntry.fromJson(Map<String, Object?> j)
    : id = _int(j['id']),
      time = _time(j['time']),
      level = _str(j['level']),
      message = _str(j['message']);

  final int id;
  final DateTime? time;
  final String level;
  final String message;
}

/// The routing state (`GET /api/routing`).
class RoutingInfo {
  RoutingInfo.fromJson(Map<String, Object?> j)
    : enabled = _bool(j['enabled']),
      regionRules = [
        for (final r in (j['region_rules'] as List<Object?>? ?? const []))
          _str(r),
      ],
      active = _bool(j['active']),
      summary = _str(j['summary']),
      error = _str(j['error']),
      updating = _bool(j['updating']),
      lastError = _str(j['last_error']),
      lists = [
        for (final f in (j['files'] as List<Object?>? ?? const []))
          (
            name: _str(_map(f)['name']),
            size: _int(_map(f)['size']),
            updatedAt: _time(_map(f)['updated_at']),
          ),
      ],
      source = _str(j['source']),
      sources = [
        for (final s in (j['sources'] as List<Object?>? ?? const []))
          (
            id: _str(_map(s)['id']),
            name: _str(_map(s)['name']),
            geositeUrl: _str(_map(s)['geosite_url']),
            geoipUrl: _str(_map(s)['geoip_url']),
          ),
      ];

  final bool enabled;

  /// The offered list set the lists come from; "" for lists set by hand.
  final String source;
  final List<({String id, String name, String geositeUrl, String geoipUrl})>
  sources;

  /// The Direct rules the routing region adds by itself.
  final List<String> regionRules;
  final bool active;
  final String summary;
  final String error;
  final bool updating;
  final String lastError;
  final List<({String name, int size, DateTime? updatedAt})> lists;
}

/// Where a destination goes (`POST /api/routing/test`).
class DestinationTest {
  DestinationTest.fromJson(Map<String, Object?> j)
    : host = _str(j['host']),
      route = _str(j['route']),
      rule = _str(j['rule']),
      resolved = _str(j['resolved']),
      portRefused = _bool(j['port_refused']),
      note = _str(j['note']);

  final String host;

  /// direct, proxy, or block.
  final String route;
  final String rule;
  final String resolved;
  final bool portRefused;
  final String note;
}

/// One name of the DNS test (`POST /api/dns/test`).
class DnsTestHost {
  DnsTestHost.fromJson(Map<String, Object?> j)
    : host = _str(j['host']),
      addrs = [
        for (final a in (j['addrs'] as List<Object?>? ?? const [])) _str(a),
      ],
      ms = _int(j['ms']),
      error = _str(j['error']),
      role = _str(j['role']),
      source = _str(j['source']),
      systemAddrs = [
        for (final a in (j['system_addrs'] as List<Object?>? ?? const []))
          _str(a),
      ],
      systemMs = _int(j['system_ms']),
      systemError = _str(j['system_error']),
      differs = _bool(j['differs']),
      filtered = _bool(j['filtered']);

  final String host;
  final List<String> addrs;
  final int ms;
  final String error;

  /// What the program uses the name for (Firefox Accounts, Guardian...).
  final String role;

  /// The server that answered.
  final String source;

  /// The network's own DNS's answer, to compare.
  final List<String> systemAddrs;
  final int systemMs;
  final String systemError;
  final bool differs;

  /// The network answered with a block-page address (the core decides).
  final bool filtered;
}
