import '../logic/secure_platform.dart';
import 'lockable_vault.dart';

/// Android Keystore + BiometricPrompt implementation (see BiometricVault.kt).
class NativeBiometrics implements BiometricKeyStore {
  const NativeBiometrics();

  @override
  Future<bool> isAvailable() => SecurePlatform.biometricAvailable();

  @override
  Future<bool> store(
    String secret, {
    required String title,
    required String cancel,
  }) => SecurePlatform.biometricStore(secret, title, cancel);

  @override
  Future<String?> read({required String title, required String cancel}) =>
      SecurePlatform.biometricRead(title, cancel);

  @override
  Future<void> delete() => SecurePlatform.biometricDelete();
}
