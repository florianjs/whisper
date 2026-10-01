import Foundation
import LocalAuthentication
import Security

/// Biometric unlock (iOS side of BiometricVault.kt): a secret in the Keychain
/// that only Face ID / Touch ID can release, on this device only. Enrolling a
/// new face or finger invalidates it (`biometryCurrentSet`), so someone who
/// adds their own biometrics can't open it.
enum SecureVault {
  private static let service = "app.whisper.messenger.biometric"
  private static let account = "secret"

  static func isAvailable() -> Bool {
    var error: NSError?
    return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
  }

  static func store(_ secret: String) -> Bool {
    delete()
    guard
      let data = secret.data(using: .utf8),
      let access = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        .biometryCurrentSet,
        nil
      )
    else { return false }
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrAccessControl as String: access,
      kSecValueData as String: data,
    ]
    return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
  }

  /// Shows the Face ID / Touch ID prompt; nil if cancelled or failed.
  /// Blocks while the prompt is up: call off the main thread.
  static func read(reason: String, cancel: String) -> String? {
    let context = LAContext()
    context.localizedReason = reason
    context.localizedCancelTitle = cancel
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecUseAuthenticationContext as String: context,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  @discardableResult
  static func delete() -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    let status = SecItemDelete(query as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
  }
}
