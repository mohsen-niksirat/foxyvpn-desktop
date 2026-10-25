import 'dart:convert';
import 'dart:io';

/// The app's version, "major.minor.patch": `version` in pubspec.yaml, which
/// the build passes (scripts/build-*.ps1: --dart-define=APP_VERSION=1.1.0).
/// "0.0.0" is a development build.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');

/// The GitHub repository, "owner/name", for the source link and the update
/// check.
const githubRepo = 'armanlife/firefox-vpn-client';

/// A newer release on GitHub.
class Release {
  const Release(this.version, this.url);

  final String version;
  final String url;
}

/// Whether "major.minor.patch" [a] is newer than [b].
bool newerVersion(String a, String b) {
  List<int> parts(String v) => [
    for (final p in v.replaceFirst(RegExp('^[vV]'), '').split('.'))
      int.tryParse(p) ?? 0,
  ];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final xi = i < x.length ? x[i] : 0, yi = i < y.length ? y[i] : 0;
    if (xi != yi) return xi > yi;
  }
  return false;
}

/// Reads the latest release of [repo] from GitHub; null when [appVersion] is
/// the newest, or when there is no release yet. [proxy] ("host:port"), when
/// set, carries the request (the VPN's own proxy, for networks where GitHub
/// is blocked); it falls back to a direct connection.
Future<Release?> checkForUpdate({
  String? proxy,
  String repo = githubRepo,
}) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..findProxy = (_) => proxy == null ? 'DIRECT' : 'PROXY $proxy; DIRECT';
  try {
    final req = await client
        .getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'))
        .timeout(const Duration(seconds: 20));
    req.headers
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
      ..set(HttpHeaders.userAgentHeader, 'firefox-vpn/$appVersion');
    final res = await req.close().timeout(const Duration(seconds: 20));
    final body = await res.transform(utf8.decoder).join();
    // GitHub's answer for a repository without releases.
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
    final j = jsonDecode(body);
    final tag = j is Map<String, Object?> ? j['tag_name'] as String? ?? '' : '';
    final url = j is Map<String, Object?> ? j['html_url'] as String? ?? '' : '';
    final version = tag.replaceFirst(RegExp('^[vV]'), '');
    return newerVersion(version, appVersion) ? Release(version, url) : null;
  } finally {
    client.close(force: true);
  }
}
