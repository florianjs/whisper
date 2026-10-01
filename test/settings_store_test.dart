import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/data/db.dart';
import 'package:whisper/data/settings_store.dart';

void main() {
  test('defaults: system language, paranoia off', () async {
    final s = SettingsStore(MemoryDocStore());
    await s.hydrate();
    expect(s.languageCode, isNull);
    expect(s.paranoia.anyOn, isFalse);
    expect(s.themeMode, ThemeMode.system);
  });

  test('persists theme mode; unknown value falls back to system', () async {
    final db = MemoryDocStore();
    await SettingsStore(db).setThemeMode(ThemeMode.light);
    final reopened = SettingsStore(db);
    await reopened.hydrate();
    expect(reopened.themeMode, ThemeMode.light);

    await db.putDoc('settings', {'id': 'app', 'themeMode': 'sepia'});
    await reopened.hydrate();
    expect(reopened.themeMode, ThemeMode.system);
  });

  test('persists language and paranoia across restarts', () async {
    final db = MemoryDocStore();
    final s = SettingsStore(db);
    await s.setLanguage('fr');
    await s.setParanoia(ParanoiaSettings.all);

    final reopened = SettingsStore(db);
    await reopened.hydrate();
    expect(reopened.languageCode, 'fr');
    expect(reopened.paranoia.allOn, isTrue);
  });

  test('shuffle requires the in-app keyboard', () {
    const s = ParanoiaSettings(inAppKeyboard: true, shuffleKeys: true);
    final off = s.copyWith(inAppKeyboard: false);
    expect(off.shuffleKeys, isFalse);
    expect(
      const ParanoiaSettings().copyWith(shuffleKeys: true).shuffleKeys,
      isFalse,
    );
  });

  test('panic wipe: reset() goes back to defaults without writing', () async {
    final db = MemoryDocStore();
    final s = SettingsStore(db);
    await s.setParanoia(ParanoiaSettings.all);
    await s.setThemeMode(ThemeMode.dark);
    await db.destroy();
    s.reset();
    expect(s.paranoia.anyOn, isFalse);
    expect(s.themeMode, ThemeMode.system);
    expect(await db.getDoc('settings', 'app'), isNull);
  });
}
