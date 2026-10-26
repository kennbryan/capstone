import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/features/chat/domain/whatsapp_link.dart';

void main() {
  const message = 'Halo, saya ingin konsultasi dengan psikolog MSU.';

  group('WhatsAppLink.build', () {
    test('builds a wa.me link with only the number and generic text', () {
      final uri = WhatsAppLink.build(number: '628123456789', message: message);

      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.path, '/628123456789');
      expect(uri.queryParameters.keys, ['text']);
      expect(uri.queryParameters['text'], message);
    });

    test('strips "+" and spaces from the number', () {
      final uri = WhatsAppLink.build(number: '+62 812-3456', message: message);
      expect(uri!.path, '/628123456');
    });

    test('returns null when there is no number', () {
      expect(WhatsAppLink.build(number: null, message: message), isNull);
      expect(WhatsAppLink.build(number: '  ', message: message), isNull);
    });

    test('never contains personal data beyond the given message', () {
      final uri = WhatsAppLink.build(number: '628123456789', message: message);
      final url = uri.toString();
      // Only the number and the generic text: no report, chat, email, or
      // user id parameters.
      for (final forbidden in ['rapor', 'report', 'email', 'user', 'chat=']) {
        expect(url.toLowerCase(), isNot(contains(forbidden)));
      }
    });
  });
}
