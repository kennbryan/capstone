import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

/// The signed-in user (same account as the assessment website).
@freezed
abstract class User with _$User {
  const factory({
    required String id,
    required String displayName,
    required String email,
  }) = _User;
  const new _();

  /// Demo accounts sign in on the device only (ids start with `usr_demo_`).
  bool get isDemo => id.startsWith('usr_demo_');

  /// First letter of the display name, for the avatar.
  String get initial {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}
