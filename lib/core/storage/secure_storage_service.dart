import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'secure_storage_service.g.dart';

/// Keys for values kept in secure storage.
abstract final class SecureKeys {
  static const accessToken = 'auth.access_token';
  static const refreshToken = 'auth.refresh_token';
  static const user = 'auth.user';
  static const consentHistory = 'consent.history';
  static const appLockEnabled = 'security.app_lock';

  /// Chat history is stored per user: `chat.history.<userId>`.
  static String chatHistory(String userId) => 'chat.history.$userId';
}

/// Encrypted key-value storage for tokens and sensitive user data.
abstract interface class SecureStorageService {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  /// Removes every stored value. Used on logout.
  Future<void> deleteAll();
}

/// [SecureStorageService] backed by `flutter_secure_storage`.
class FlutterSecureStorageService implements SecureStorageService {
  const new([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

@Riverpod(keepAlive: true)
SecureStorageService secureStorage(Ref ref) =>
    const FlutterSecureStorageService();
