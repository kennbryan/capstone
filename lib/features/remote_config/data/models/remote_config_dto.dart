import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/features/remote_config/domain/entities/remote_config.dart';
import 'package:msu_wellbeing/features/remote_config/domain/national_contacts.dart';

part 'remote_config_dto.freezed.dart';
part 'remote_config_dto.g.dart';

/// `GET /config` response.
@freezed
abstract class RemoteConfigDto with _$RemoteConfigDto {
  const factory({
    required String assessmentWebsiteUrl,
    String? whatsappNumber,
    @Default(<CrisisContactDto>[]) List<CrisisContactDto> crisisContacts,
    @Default(1) int consentVersion,
  }) = _RemoteConfigDto;

  factory fromJson(Map<String, Object?> json) =>
      _$RemoteConfigDtoFromJson(json);
}

@freezed
abstract class CrisisContactDto with _$CrisisContactDto {
  const factory({
    required String label,
    required String phone,
    String? description,
  }) = _CrisisContactDto;

  factory fromJson(Map<String, Object?> json) =>
      _$CrisisContactDtoFromJson(json);
}

/// Maps the server config to the entity and treats it as untrusted input:
/// only digits for the WhatsApp number, only dialable characters for phone
/// numbers, only `https` for the website, and the verified national help
/// lines when no usable crisis contact is sent.
extension RemoteConfigDtoMapper on RemoteConfigDto {
  RemoteConfig toEntity() {
    final number = whatsappNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
    final contacts = [
      for (final contact in crisisContacts)
        if (_dialable(contact.phone).isNotEmpty &&
            contact.label.trim().isNotEmpty)
          CrisisContact(
            label: contact.label.trim(),
            phone: _dialable(contact.phone),
            description: contact.description,
          ),
    ];
    final website = Uri.tryParse(assessmentWebsiteUrl.trim());
    return RemoteConfig(
      whatsappNumber: number.isEmpty ? null : number,
      crisisContacts: contacts.isEmpty ? nationalCrisisContacts : contacts,
      assessmentWebsiteUrl:
          website != null &&
              website.scheme == 'https' &&
              website.host.isNotEmpty
          ? website.toString()
          : '',
      consentVersion: consentVersion,
    );
  }

  static String _dialable(String phone) =>
      phone.replaceAll(RegExp('[^0-9+*#]'), '');
}
