import Flutter
import LocalAuthentication
import UIKit
import UniformTypeIdentifiers
import UserNotifications

/// iOS side of Whisper's platform channels (Android: MainActivity.kt).
///
/// - `whisper/secure`: privacy cover, sensitive clipboard, biometric vault.
/// - `whisper/files`: document picker (no photo-library or files permission).
/// - `whisper/pt`: pluggable transports for Tor (PluggableTransports.swift).
/// - `whisper/background`: content-free local notifications. iOS keeps no
///   connection alive in the background: messages arrive while Whisper runs.
///
/// - `whisper/update`: version only. Updates come from SideStore / AltStore
///   (the release's apps.json source), never from the app itself.
final class WhisperPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = WhisperPlugin()
    let messenger = registrar.messenger()
    FlutterMethodChannel(name: "whisper/secure", binaryMessenger: messenger)
      .setMethodCallHandler(plugin.handleSecure)
    FlutterMethodChannel(name: "whisper/files", binaryMessenger: messenger)
      .setMethodCallHandler(plugin.handleFiles)
    FlutterMethodChannel(name: "whisper/pt", binaryMessenger: messenger)
      .setMethodCallHandler(plugin.handlePluggableTransports)
    FlutterMethodChannel(name: "whisper/background", binaryMessenger: messenger)
      .setMethodCallHandler(plugin.handleBackground)
    FlutterMethodChannel(name: "whisper/update", binaryMessenger: messenger)
      .setMethodCallHandler(plugin.handleUpdate)
    plugin.observePrivacyEvents()
  }

  // MARK: - Privacy cover

  /// Requested by Dart for secret screens (recovery phrase…) or everywhere
  /// (paranoia). iOS can't block screenshots; it can hide the screen while
  /// it is recorded or mirrored.
  private var secure = false
  private var cover: UIView?

  private func observePrivacyEvents() {
    let center = NotificationCenter.default
    // The app switcher snapshot is taken after this: never show chats there.
    center.addObserver(
      self, selector: #selector(showCover),
      name: UIApplication.willResignActiveNotification, object: nil)
    center.addObserver(
      self, selector: #selector(updateCover),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    center.addObserver(
      self, selector: #selector(updateCover),
      name: UIScreen.capturedDidChangeNotification, object: nil)
  }

  private var window: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }
  }

  @objc private func showCover() {
    guard cover == nil, let window else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    blur.frame = window.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(blur)
    cover = blur
  }

  @objc private func updateCover() {
    let recorded = UIScreen.main.isCaptured
    if secure && recorded {
      showCover()
    } else if UIApplication.shared.applicationState == .active {
      cover?.removeFromSuperview()
      cover = nil
    }
  }

  // MARK: - whisper/secure

  private func handleSecure(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "setSecure":
      secure = call.arguments as? Bool == true
      updateCover()
      result(nil)
    case "copySensitive":
      guard let text = call.arguments as? String else {
        result(FlutterError(code: "bad_args", message: "expected a string", details: nil))
        return
      }
      // Not synced to other devices (Universal Clipboard), gone after 60 s
      // even if Whisper is killed before its own timer clears it.
      UIPasteboard.general.setItems(
        [[UTType.utf8PlainText.identifier: text]],
        options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
      result(nil)
    case "enabledAccessibilityServices":
      // No iOS equivalent: apps can't read other apps' screens this way.
      result([String]())
    case "openAccessibilitySettings":
      result(nil)
    case "biometricAvailable":
      result(SecureVault.isAvailable())
    case "biometricStore":
      let secret = args?["secret"] as? String ?? ""
      // Same as Android: enabling needs the user's face / finger.
      let context = LAContext()
      context.localizedCancelTitle = args?["cancel"] as? String
      context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: args?["title"] as? String ?? "Whisper"
      ) { ok, _ in
        let stored = ok && SecureVault.store(secret)
        DispatchQueue.main.async { result(stored) }
      }
    case "biometricRead":
      let reason = args?["title"] as? String ?? "Whisper"
      let cancel = args?["cancel"] as? String ?? ""
      DispatchQueue.global(qos: .userInitiated).async {
        let secret = SecureVault.read(reason: reason, cancel: cancel)
        DispatchQueue.main.async { result(secret) }
      }
    case "biometricDelete":
      SecureVault.delete()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - whisper/files

  private var pendingFiles: FlutterResult?
  private var exported: URL?

  private func handleFiles(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard pendingFiles == nil else {
      result(FlutterError(code: "busy", message: "a picker is already open", details: nil))
      return
    }
    let picker: UIDocumentPickerViewController
    switch call.method {
    case "save":
      let args = call.arguments as? [String: Any]
      guard let data = (args?["bytes"] as? FlutterStandardTypedData)?.data else {
        result(FlutterError(code: "bad_args", message: "expected bytes", details: nil))
        return
      }
      let name = (args?["name"] as? String).map { ($0 as NSString).lastPathComponent } ?? "whisper"
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
      do {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
      } catch {
        result(FlutterError(code: "write_failed", message: error.localizedDescription, details: nil))
        return
      }
      exported = url
      picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    case "open":
      picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
    default:
      result(FlutterMethodNotImplemented)
      return
    }
    guard let root = window?.rootViewController else {
      result(FlutterError(code: "no_window", message: nil, details: nil))
      return
    }
    pendingFiles = result
    picker.delegate = self
    (root.presentedViewController ?? root).present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    if exported != nil {
      finishFiles(true)
    } else {
      finishFiles(urls.first.flatMap { try? Data(contentsOf: $0) }.map(FlutterStandardTypedData.init(bytes:)))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishFiles(exported != nil ? false : nil)
  }

  private func finishFiles(_ value: Any?) {
    // The exported copy may hold a backup: don't leave it in tmp.
    if let url = exported { try? FileManager.default.removeItem(at: url) }
    exported = nil
    pendingFiles?(value)
    pendingFiles = nil
  }

  // MARK: - whisper/pt

  private func handlePluggableTransports(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    guard let transport = args?["transport"] as? String else {
      result(FlutterError(code: "bad_args", message: "expected a transport", details: nil))
      return
    }
    // IPtProxy start blocks while it binds: off the main thread.
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let value: Any?
        switch call.method {
        case "start":
          value = try PluggableTransports.start(
            transport, params: args?["params"] as? [String: String] ?? [:])
        case "stop":
          PluggableTransports.stop(transport)
          value = nil
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
          return
        }
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "pt_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // MARK: - whisper/update

  private func handleUpdate(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "info" else {
      result(FlutterMethodNotImplemented)
      return
    }
    result([
      "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
      "abis": [String](),
      "installer": "ios",
    ] as [String: Any])
  }

  // MARK: - whisper/background

  private static let messagesId = "messages"

  private func handleBackground(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let center = UNUserNotificationCenter.current()
    switch call.method {
    case "start":
      // No foreground service on iOS; only ask for notifications.
      center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    case "stop":
      break
    case "notify":
      let content = UNMutableNotificationContent()
      content.title = args?["title"] as? String ?? "Whisper"
      content.body = args?["text"] as? String ?? ""
      content.sound = .default
      // Same id: a new count replaces the previous notification.
      center.add(UNNotificationRequest(identifier: Self.messagesId, content: content, trigger: nil))
    case "clear":
      center.removeDeliveredNotifications(withIdentifiers: [Self.messagesId])
    default:
      result(FlutterMethodNotImplemented)
      return
    }
    result(nil)
  }
}
