import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The platform secret store failed (as opposed to: the entry is absent).
class KeyVaultUnavailableException implements Exception {
  const KeyVaultUnavailableException([this.detail]);
  final String? detail;

  @override
  String toString() => 'KeyVaultUnavailableException($detail)';
}

/// Secret storage (Android Keystore / iOS Keychain). Abstract so stores can be
/// unit-tested with [MemoryKeyVault].
abstract class KeyVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureKeyVault implements KeyVault {
  const SecureKeyVault();

  static const _storage = FlutterSecureStorage(
    // Secrets must never leave this device through iCloud Keychain sync or
    // restore onto another phone.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on PlatformException catch (e) {
      // Never report a failure as "absent": callers treat a missing DB key
      // as "start over" and would delete a database that a transient
      // Keystore error left perfectly readable.
      throw KeyVaultUnavailableException(e.message);
    }
  }

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemoryKeyVault implements KeyVault {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
