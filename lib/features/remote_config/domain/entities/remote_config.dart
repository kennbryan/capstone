import 'package:freezed_annotation/freezed_annotation.dart';

part 'remote_config.freezed.dart';

/// Server-controlled settings: psychologist WhatsApp number, crisis
/// contacts, assessment website, and the current consent version.
@freezed
abstract class RemoteConfig with _$RemoteConfig {
  const factory({
    required List<CrisisContact> crisisContacts,
    required String assessmentWebsiteUrl,
    required int consentVersion,

    /// International format without `+`, e.g. `628xxxxxxxxxx`. Null hides
    /// the WhatsApp button.
    String? whatsappNumber,
  }) = _RemoteConfig;
}

/// A crisis contact opened with the phone dialer.
@freezed
abstract class CrisisContact with _$CrisisContact {
  const factory({
    required String label,
    required String phone,
    String? description,
  }) = _CrisisContact;
}
