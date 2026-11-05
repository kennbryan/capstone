import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:msu_wellbeing/features/auth/domain/entities/user.dart';

part 'user_dto.freezed.dart';
part 'user_dto.g.dart';

@freezed
abstract class UserDto with _$UserDto {
  const factory({
    required String id,
    required String displayName,
    required String email,
  }) = _UserDto;

  factory fromJson(Map<String, Object?> json) => _$UserDtoFromJson(json);
}

/// A session created on the device (demo accounts only; real sessions
/// are owned by `SessionSource`).
@freezed
abstract class LoginResponseDto with _$LoginResponseDto {
  const factory({
    required String accessToken,
    required String refreshToken,
    required UserDto user,
  }) = _LoginResponseDto;

  factory fromJson(Map<String, Object?> json) =>
      _$LoginResponseDtoFromJson(json);
}

extension UserDtoMapper on UserDto {
  User toEntity() => User(id: id, displayName: displayName, email: email);
}
