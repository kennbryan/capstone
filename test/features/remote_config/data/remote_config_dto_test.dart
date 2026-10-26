import 'package:flutter_test/flutter_test.dart';
import 'package:msu_wellbeing/features/remote_config/data/models/remote_config_dto.dart';
import 'package:msu_wellbeing/features/remote_config/domain/national_contacts.dart';

void main() {
  test('no crisis contacts from the server falls back to national lines', () {
    final config = const RemoteConfigDto(
      assessmentWebsiteUrl: 'https://asesmen.msu.example',
    ).toEntity();
    expect(config.crisisContacts, nationalCrisisContacts);
    expect(config.crisisContacts.map((c) => c.phone), contains('112'));
  });

  test('server values are treated as untrusted input', () {
    final config = const RemoteConfigDto(
      assessmentWebsiteUrl: 'javascript:alert(1)',
      whatsappNumber: '+62 812-3456-7890',
      crisisContacts: [
        CrisisContactDto(label: 'Konseling', phone: 'tel:0812;evil'),
        CrisisContactDto(label: 'Kosong', phone: 'abc'),
      ],
    ).toEntity();

    expect(config.assessmentWebsiteUrl, isEmpty);
    expect(config.whatsappNumber, '6281234567890');
    expect(config.crisisContacts, hasLength(1));
    expect(config.crisisContacts.single.phone, '0812');
  });

  test('http websites are not accepted', () {
    final config = const RemoteConfigDto(
      assessmentWebsiteUrl: 'http://asesmen.msu.example',
    ).toEntity();
    expect(config.assessmentWebsiteUrl, isEmpty);
  });
}
