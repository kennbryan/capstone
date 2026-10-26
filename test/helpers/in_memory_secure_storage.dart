import 'package:msu_wellbeing/core/storage/secure_storage_service.dart';

/// [SecureStorageService] kept in memory for tests.
class InMemorySecureStorage implements SecureStorageService {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}
