import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/core/android_core.dart';

AppRouting routing() => AppRouting(
  onlyChosen: false,
  bypass: {'my.bank'},
  only: {},
  suggested: {'ir.bale', 'cab.snapp.passenger'},
);

void main() {
  test('suggested apps are not forced; the button selects them', () {
    final r = routing();
    // Only what the user chose is checked.
    expect(r.checked('ir.bale'), isFalse);
    expect(r.checked('my.bank'), isTrue);

    // "Suggested apps": the installed ones are selected.
    expect(r.checkSuggested(['ir.bale', 'org.telegram']), 1);
    expect(r.checked('ir.bale'), isTrue);
    expect(r.checked('cab.snapp.passenger'), isFalse); // not installed
    expect(r.checkSuggested(['ir.bale']), 0);

    // The user may uncheck one, and it stays unchecked.
    r.toggle('ir.bale', false);
    expect(r.checked('ir.bale'), isFalse);
  });

  test('proxy selected apps keeps its own choice', () {
    final r = routing()..onlyChosen = true;
    expect(r.checked('my.bank'), isFalse);
    r.toggle('org.telegram', true);
    expect(r.only, {'org.telegram'});
    expect(r.bypass, {'my.bank'});
  });

  test('the key changes with the choice', () {
    final r = routing();
    final before = r.key;
    r.toggle('org.telegram', true);
    expect(r.key, isNot(before));
  });
}
