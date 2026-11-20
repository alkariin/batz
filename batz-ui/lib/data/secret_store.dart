import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secrets kept by the operating system: Android Keystore, Windows DPAPI,
/// the Secret Service (GNOME Keyring) on Linux.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SystemSecretStore implements SecretStore {
  SystemSecretStore()
    : _storage = const FlutterSecureStorage(
        // Never wipe silently on a decryption error: losing the database key
        // would make the local database unreadable without a word.
        aOptions: AndroidOptions(resetOnError: false),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Keeps secrets in memory; for tests.
class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
