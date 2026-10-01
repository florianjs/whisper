import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/foundation.dart';

import 'db.dart';

/// Paranoia mode toggles. Each defends against a specific threat; the master
/// switch turns them all on at once.
class ParanoiaSettings {
  const ParanoiaSettings({
    this.inAppKeyboard = false,
    this.shuffleKeys = false,
    this.maskInput = false,
    this.blurHistory = false,
    this.hideFromAccessibility = false,
    this.secureAllScreens = false,
  });

  /// Type with Whisper's own keyboard: the system keyboard never sees text.
  final bool inAppKeyboard;

  /// Reshuffle letter positions each time the keyboard opens, against
  /// malware that logs touch coordinates.
  final bool shuffleKeys;

  /// Show `•` instead of the characters being typed.
  final bool maskInput;

  /// Blur messages until long-pressed.
  final bool blurHistory;

  /// Keep message text out of the accessibility tree, the usual way spyware
  /// reads other apps. Breaks screen readers, hence off by default.
  final bool hideFromAccessibility;

  /// FLAG_SECURE everywhere, not only on seed screens.
  final bool secureAllScreens;

  static const all = ParanoiaSettings(
    inAppKeyboard: true,
    shuffleKeys: true,
    maskInput: true,
    blurHistory: true,
    hideFromAccessibility: true,
    secureAllScreens: true,
  );

  bool get anyOn =>
      inAppKeyboard ||
      shuffleKeys ||
      maskInput ||
      blurHistory ||
      hideFromAccessibility ||
      secureAllScreens;

  bool get allOn =>
      inAppKeyboard &&
      shuffleKeys &&
      maskInput &&
      blurHistory &&
      hideFromAccessibility &&
      secureAllScreens;

  ParanoiaSettings copyWith({
    bool? inAppKeyboard,
    bool? shuffleKeys,
    bool? maskInput,
    bool? blurHistory,
    bool? hideFromAccessibility,
    bool? secureAllScreens,
  }) {
    final keyboard = inAppKeyboard ?? this.inAppKeyboard;
    return ParanoiaSettings(
      inAppKeyboard: keyboard,
      // Shuffling only exists on our keyboard.
      shuffleKeys: keyboard && (shuffleKeys ?? this.shuffleKeys),
      maskInput: maskInput ?? this.maskInput,
      blurHistory: blurHistory ?? this.blurHistory,
      hideFromAccessibility:
          hideFromAccessibility ?? this.hideFromAccessibility,
      secureAllScreens: secureAllScreens ?? this.secureAllScreens,
    );
  }

  Map<String, dynamic> toJson() => {
    'inAppKeyboard': inAppKeyboard,
    'shuffleKeys': shuffleKeys,
    'maskInput': maskInput,
    'blurHistory': blurHistory,
    'hideFromAccessibility': hideFromAccessibility,
    'secureAllScreens': secureAllScreens,
  };

  factory ParanoiaSettings.fromJson(Map<String, dynamic>? json) =>
      ParanoiaSettings(
        inAppKeyboard: json?['inAppKeyboard'] == true,
        shuffleKeys: json?['shuffleKeys'] == true,
        maskInput: json?['maskInput'] == true,
        blurHistory: json?['blurHistory'] == true,
        hideFromAccessibility: json?['hideFromAccessibility'] == true,
        secureAllScreens: json?['secureAllScreens'] == true,
      );
}

/// App settings, stored in the encrypted DB — so the panic button resets
/// them too, leaving no hint that paranoia mode was ever on.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._db);

  static const _collection = 'settings';
  static const _id = 'app';

  final DocStore _db;

  /// Null = follow the system language.
  String? _languageCode;
  String? get languageCode => _languageCode;

  ParanoiaSettings _paranoia = const ParanoiaSettings();
  ParanoiaSettings get paranoia => _paranoia;

  /// Keep a private connection open in the background (foreground service)
  /// and show content-free "new message" notifications.
  bool _background = true;
  bool get background => _background;

  /// Dark, light, or follow the system (default).
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> hydrate() async {
    final Map<String, dynamic>? doc;
    try {
      doc = await _db.getDoc(_collection, _id);
    } on Exception {
      // Locked vault (or unreadable DB): keep defaults until unlocked.
      return;
    }
    _languageCode = doc?['languageCode'] as String?;
    _paranoia = ParanoiaSettings.fromJson(
      (doc?['paranoia'] as Map?)?.cast<String, dynamic>(),
    );
    _background = doc?['background'] != false;
    _themeMode =
        ThemeMode.values.asNameMap()[doc?['themeMode']] ?? ThemeMode.system;
    notifyListeners();
  }

  /// Back to defaults in memory only (after a wipe the DB is gone; writing
  /// would recreate it).
  void reset() {
    _languageCode = null;
    _paranoia = const ParanoiaSettings();
    _background = true;
    _themeMode = ThemeMode.system;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    notifyListeners();
    await _save();
  }

  Future<void> setBackground(bool value) async {
    _background = value;
    notifyListeners();
    await _save();
  }

  Future<void> setLanguage(String? code) async {
    _languageCode = code;
    notifyListeners();
    await _save();
  }

  Future<void> setParanoia(ParanoiaSettings value) async {
    _paranoia = value;
    notifyListeners();
    await _save();
  }

  Future<void> _save() => _db.putDoc(_collection, {
    'id': _id,
    'languageCode': _languageCode,
    'paranoia': _paranoia.toJson(),
    'background': _background,
    'themeMode': _themeMode.name,
  });
}
