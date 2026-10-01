import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/data/background_delivery.dart';
import 'package:whisper/data/db.dart';
import 'package:whisper/data/identity_store.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/data/notifier.dart';
import 'package:whisper/data/settings_store.dart';
import 'package:whisper/l10n/app_localizations.dart';
import 'package:whisper/logic/identity.dart';

import 'support/fake_network.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('whisper/background'), (
          c,
        ) async {
          calls.add(c);
          return null;
        });
  });

  test('service runs only with an account and the setting on', () async {
    final identity = IdentityStore(
      MemoryKeyVault(),
      derive: (m) async => deriveIdentity(m),
    );
    final settings = SettingsStore(MemoryDocStore());
    final platform = PlatformBackground(
      () => lookupAppLocalizations(const Locale('fr')),
    );
    final bg = BackgroundDelivery(
      identity: identity,
      settings: settings,
      platform: platform,
      notifier: ArrivalNotifier(
        arrivals: const [],
        sink: platform,
        enabled: () => settings.background,
      ),
    );
    await pumpEventQueue();
    expect(calls.map((c) => c.method), contains('stop'));
    calls.clear();

    await identity.restore(aliceWords);
    await pumpEventQueue();
    final start = calls.singleWhere((c) => c.method == 'start');
    expect((start.arguments as Map)['title'], 'Connexion privée active');

    await settings.setBackground(false);
    await pumpEventQueue();
    expect(calls.last.method, 'stop');

    await settings.setBackground(true);
    await identity.wipe(); // panic
    await pumpEventQueue();
    expect(calls.map((c) => c.method), containsAll(['stop', 'clear']));
    bg.dispose();
  });

  test('notification text is generic and localized', () async {
    final platform = PlatformBackground(
      () => lookupAppLocalizations(const Locale('en')),
    );
    await platform.show(3);
    expect((calls.single.arguments as Map)['text'], '3 new messages');
    expect((calls.single.arguments as Map)['title'], 'Whisper');
  });
}
