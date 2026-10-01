import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    forgetKeychainAfterReinstall()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// The Keychain outlives the app: after a reinstall it would still hold
  /// the previous identity and database keys. UserDefaults doesn't, so a
  /// missing marker means a fresh install: wipe this app's Keychain items.
  private func forgetKeychainAfterReinstall() {
    let marker = "app.whisper.messenger.installed"
    guard !UserDefaults.standard.bool(forKey: marker) else { return }
    for itemClass in [kSecClassGenericPassword, kSecClassKey] {
      SecItemDelete([kSecClass as String: itemClass] as CFDictionary)
    }
    UserDefaults.standard.set(true, forKey: marker)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WhisperPlugin") {
      WhisperPlugin.register(with: registrar)
    }
  }
}
