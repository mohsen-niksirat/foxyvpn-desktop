import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/core/core_api.dart';
import 'package:firefox_vpn/core/remote_flags.dart';
import 'package:firefox_vpn/ui/widgets.dart';

/// A core that has the flag of Iran only.
class _FlagCore implements CoreApi {
  final asked = <String>[];

  @override
  Future<Uint8List?> flag(String code) async {
    asked.add(code);
    return code == 'ir'
        ? Uint8List.fromList(
            utf8.encode(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4 3">'
              '<rect width="4" height="3" fill="#239f40"/></svg>',
            ),
          )
        : null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('the app carries exactly the flags it lists', () {
    final files = {
      for (final f in Directory('assets/flags').listSync())
        if (f.path.endsWith('.svg'))
          f.uri.pathSegments.last.replaceAll('.svg', ''),
    };
    expect(files, bundledFlags);
  });

  testWidgets('a flag the app lacks comes from the core, once', (tester) async {
    final core = _FlagCore();
    RemoteFlags.use(core);
    Widget flags() => const MaterialApp(
      home: Row(
        children: [
          CountryFlag(code: 'NL'),
          CountryFlag(code: 'IR'),
          CountryFlag(code: 'ZZ'),
        ],
      ),
    );
    await tester.pumpWidget(flags());
    await tester.pumpAndSettle();

    // Carried: not asked; Iran from the core; none for ZZ: its code.
    expect(core.asked, ['ir', 'zz']);
    expect(find.byType(SvgPicture), findsNWidgets(2));
    expect(find.text('ZZ'), findsOneWidget);

    await tester.pumpWidget(flags());
    await tester.pumpAndSettle();
    expect(core.asked, ['ir', 'zz'], reason: 'asked once per run');
  });
}
