import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/core/utils/link_launcher.dart';

void main() {
  const launcher = LinkLauncher();

  test('only https and tel links may be opened', () async {
    for (final uri in [
      Uri.parse('http://asesmen.msu.example'),
      Uri.parse('intent://scan/#Intent;scheme=zxing;end'),
      Uri.parse('file:///data/data/app/secrets'),
      Uri.parse('javascript:alert(1)'),
      Uri.parse('https://'),
    ]) {
      expect(await launcher.open(uri), isFalse, reason: uri.toString());
    }
  });

  test('a number with no dialable characters is not dialed', () async {
    expect(await launcher.dial('abc'), isFalse);
  });
}
