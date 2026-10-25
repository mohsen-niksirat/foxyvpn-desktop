import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/core/core_api.dart';

void main() {
  group('CoreApi', () {
    late HttpServer server;
    late CoreApi api;
    final seen = <String, Object?>{};

    setUp(() async {
      seen.clear();
      // A local fixture: unknown requests fail and nothing leaves loopback.
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final body = await utf8.decoder.bind(req).join();
        seen['token'] = req.headers.value('X-Local-Token');
        seen['type'] = req.headers.contentType?.mimeType;
        seen['body'] = body;
        // As the core's guard: a state change must be JSON.
        final json = req.headers.contentType?.mimeType == 'application/json';
        final (status, out) = switch ((req.method, req.uri.path)) {
          (final m, _) when m != 'GET' && !json => (
            415,
            {'error': 'requests must be JSON'},
          ),
          ('GET', '/api/status') => (
            200,
            {
              'state': {'phase': 'running', 'message': 'ok'},
              'system_proxy': 'set',
              'accounts': {'total': 2, 'ready': 1},
            },
          ),
          ('POST', '/api/system-proxy') => (200, {'mode': 'clear'}),
          ('DELETE', '/api/accounts/a') => (200, {}),
          ('DELETE', '/api/signin/s') => (200, {}),
          ('POST', '/api/test') => (409, {'error': 'the proxy is not running'}),
          _ => (404, {'error': 'not found'}),
        };
        req.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(out));
        await req.response.close();
      });
      api = CoreApi(
        CoreEndpoint(
          Uri.parse('http://127.0.0.1:${server.port}'),
          'secret-token',
        ),
      );
    });

    tearDown(() async {
      api.close();
      await server.close(force: true);
    });

    test('sends the local token and parses the status', () async {
      final s = await api.status();
      expect(seen['token'], 'secret-token');
      expect(s.systemProxySet, isTrue);
      expect(s.readyAccounts, 1);
      expect(s.totalAccounts, 2);
    });

    test('sends JSON with a DELETE too, which the core requires', () async {
      await api.removeAccount('a');
      expect(seen['type'], 'application/json');
      await api.cancelSignIn('s');
      expect(seen['type'], 'application/json');
    });

    test('posts JSON', () async {
      await api.setSystemProxy('clear');
      expect(seen['type'], 'application/json');
      expect(jsonDecode(seen['body'] as String), {'mode': 'clear'});
    });

    test('turns error answers into CoreApiException', () async {
      await expectLater(
        api.test(),
        throwsA(
          isA<CoreApiException>()
              .having((e) => e.statusCode, 'status', 409)
              .having((e) => e.message, 'message', 'the proxy is not running'),
        ),
      );
    });

    test('reports a missing core as CoreUnavailable', () async {
      await server.close(force: true);
      await expectLater(api.status(), throwsA(isA<CoreUnavailable>()));
    });
  });

  group('CoreLocator', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('core_locator_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('reads the token and the dashboard address', () async {
      File('${dir.path}/local-api.token').writeAsStringSync('abc\n');
      File('${dir.path}/config.json').writeAsStringSync(
        jsonEncode({
          'dashboard': {'listen': '0.0.0.0:9191'},
        }),
      );
      final e = await CoreLocator.locate(dir.path);
      expect(e.token, 'abc');
      expect(e.baseUri.toString(), 'http://127.0.0.1:9191');
    });

    test('defaults the address without a config', () async {
      File('${dir.path}/local-api.token').writeAsStringSync('abc');
      final e = await CoreLocator.locate(dir.path);
      expect(e.baseUri.toString(), 'http://127.0.0.1:10820');
    });

    test('explains a missing token', () async {
      await expectLater(
        CoreLocator.locate(dir.path),
        throwsA(isA<CoreUnavailable>()),
      );
    });

    test('takes --data-dir from the arguments', () {
      expect(CoreLocator.dataDir(['--data-dir=C:/x/data']), 'C:/x/data');
    });

    test('keeps the data in one place for every version', () {
      String dir({
        bool portable = false,
        String os = 'windows',
        Map<String, String>? env,
      }) => CoreLocator.dataDirFor(
        args: const [],
        exeDir: r'D:\dist\Firefox-VPN-1.3',
        portable: portable,
        env: env ?? {'LOCALAPPDATA': r'C:\Users\u\AppData\Local'},
        os: os,
      );
      // Windows: always beside the app.
      expect(dir(), r'D:\dist\Firefox-VPN-1.3\user-data');
      expect(dir(portable: true), r'D:\dist\Firefox-VPN-1.3\user-data');
      expect(
        dir(os: 'macos', env: {'HOME': '/Users/u'}),
        '/Users/u/Library/Application Support/Firefox VPN Client',
      );
      expect(
        dir(os: 'linux', env: {'HOME': '/home/u'}),
        '/home/u/.local/share/firefox-vpn-client',
      );
    });

    test('maps listen addresses to loopback URLs', () {
      expect(CoreLocator.listenUri('[::1]:9090').host, '::1');
      expect(
        CoreLocator.listenUri(':8080').toString(),
        'http://127.0.0.1:8080',
      );
      expect(CoreLocator.listenUri('[::]:8080').host, '127.0.0.1');
    });
  });
}
