import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native helpers for handling secrets on screen and in the clipboard.
/// Android implements them in `MainActivity.kt`, iOS in `WhisperPlugin.swift`;
/// elsewhere they degrade to no-ops / the plain clipboard.
class SecurePlatform {
  SecurePlatform._();

  static const _channel = MethodChannel('whisper/secure');

  static bool get _native =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static int _secureHolders = 0;

  /// Blocks screenshots, screen recording and the recents thumbnail
  /// (Android FLAG_SECURE; on iOS, which can't block screenshots, a cover
  /// while recording or in the app switcher) until [releaseSecureScreen].
  /// Ref-counted: stacked secret screens (seed → verify → back to seed) must
  /// not unprotect the one still visible.
  static void acquireSecureScreen() {
    if (_secureHolders++ == 0) _setSecure(true);
  }

  static void releaseSecureScreen() {
    if (_secureHolders == 0) return;
    if (--_secureHolders == 0) _setSecure(false);
  }

  static Future<void> _setSecure(bool enabled) async {
    if (!_native) return;
    try {
      await _channel.invokeMethod('setSecure', enabled);
    } on MissingPluginException {
      // Widget tests have no native side.
    }
  }

  static Timer? _clearTimer;

  /// Copies [text] flagged as sensitive (hidden from Android 13+ clipboard
  /// previews; on iOS kept off other devices and expiring natively) and
  /// wipes it after [ttl] if it is still the clipboard content.
  static Future<void> copySensitive(
    String text, {
    Duration ttl = const Duration(seconds: 60),
  }) async {
    var copied = false;
    if (_native) {
      try {
        await _channel.invokeMethod('copySensitive', text);
        copied = true;
      } on MissingPluginException {
        // Fall through to the plain clipboard.
      }
    }
    if (!copied) await Clipboard.setData(ClipboardData(text: text));

    _clearTimer?.cancel();
    _clearTimer = Timer(ttl, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  /// Empties the clipboard now and cancels any pending timed clear.
  static Future<void> clearClipboard() async {
    _clearTimer?.cancel();
    _clearTimer = null;
    await Clipboard.setData(const ClipboardData(text: ''));
  }

  /// For public data (e.g. the user's npub): no sensitive flag, no auto-clear.
  static Future<void> copyPlain(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  /// Labels of apps holding accessibility access (they can read the screen).
  /// Empty where unsupported.
  static Future<List<String>> enabledAccessibilityServices() async {
    if (defaultTargetPlatform != TargetPlatform.android) return const [];
    try {
      final list = await _channel.invokeListMethod<String>(
        'enabledAccessibilityServices',
      );
      return list ?? const [];
    } on MissingPluginException {
      return const [];
    }
  }

  static Future<void> openAccessibilitySettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on MissingPluginException {
      // Tests.
    }
  }

  static Future<T?> _call<T>(String method, [Object? args]) async {
    if (!_native) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> biometricAvailable() async =>
      await _call<bool>('biometricAvailable') ?? false;

  static Future<bool> biometricStore(
    String secret,
    String title,
    String cancel,
  ) async =>
      await _call<bool>('biometricStore', {
        'secret': secret,
        'title': title,
        'cancel': cancel,
      }) ??
      false;

  static Future<String?> biometricRead(String title, String cancel) =>
      _call<String>('biometricRead', {'title': title, 'cancel': cancel});

  static Future<void> biometricDelete() => _call<void>('biometricDelete');
}
