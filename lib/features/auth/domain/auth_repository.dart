import 'package:msu_wellbeing/core/utils/result.dart';
import 'package:msu_wellbeing/features/auth/domain/entities/user.dart';

/// Sign-in, session restore, and sign-out.
abstract interface class AuthRepository {
  Future<Result<User>> login({required String email, required String password});

  /// Returns the stored session's user, or null when signed out.
  Future<Result<User?>> restoreSession();

  /// Updates the display name (a nickname is fine).
  Future<Result<User>> updateDisplayName(String displayName);

  /// Clears tokens and every value in secure storage.
  Future<void> logout();
}
