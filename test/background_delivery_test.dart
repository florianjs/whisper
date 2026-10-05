import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart' show Nip01Event;
import 'package:whisper/data/background_delivery.dart';
import 'package:whisper/data/db.dart';
import 'package:whisper/data/identity_store.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/data/notifier.dart';
import 'package:whisper/data/relay_service.dart';
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

  test('locked with the inbox watched: service stays, wraps notify', () async {
    final identity = IdentityStore(
      MemoryKeyVault(),
      derive: (m) async => deriveIdentity(m),
    );
    final settings = SettingsStore(MemoryDocStore());
    final watches = <FakeWatchBackend>[];
    final relays = RelayService(
      identity: identity,
      db: MemoryDocStore(),
      backendFactory: (id, urls) => FakeRelayBackend(),
      watchFactory: (urls) {
        final w = FakeWatchBackend();
        watches.add(w);
        return w;
      },
    );
    final platform = PlatformBackground(
      () => lookupAppLocalizations(const Locale('en')),
    );
    final bg = BackgroundDelivery(
      identity: identity,
      settings: settings,
      platform: platform,
      relays: relays,
      notifier: ArrivalNotifier(
        arrivals: const [],
        sink: platform,
        enabled: () => settings.background,
      ),
    );
    await identity.restore(aliceWords);
    await pumpEventQueue();
    bg.setForeground(false);
    calls.clear();

    relays.watchInbox();
    identity.forget(); // app lock
    await pumpEventQueue();
    expect(calls.map((c) => c.method), isNot(contains('stop')));

    watches.single.wraps.add(
      Nip01Event(pubKey: 'cd' * 32, kind: 1059, tags: const [], content: 'x'),
    );
    await pumpEventQueue();
    expect((calls.last.arguments as Map)['text'], 'New message');

    relays.stopWatching(); // panic from the lock screen
    await pumpEventQueue();
    expect(calls.map((c) => c.method), containsAll(['stop', 'clear']));
    bg.dispose();
    relays.dispose();
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

class FakeRelayBackend implements RelayBackend {
  @override
  Stream<Map<String, bool>> get connectivity => const Stream.empty();
  @override
  Future<void> reconnect() async {}
  @override
  Future<void> publish({
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) async {}
  @override
  Future<void> publishSigned(Nip01Event event, {List<String>? relays}) async {}
  @override
  Stream<Nip01Event> giftWraps({required String pubkey, required int since}) =>
      StreamController<Nip01Event>().stream;
  @override
  Future<List<String>> inboxRelaysOf(String pubkey) async => const [];
  @override
  Future<void> dispose() async {}
}

class FakeWatchBackend implements WatchBackend {
  final wraps = StreamController<Nip01Event>.broadcast(sync: true);
  @override
  Stream<Map<String, bool>> get connectivity => const Stream.empty();
  @override
  Future<void> reconnect() async {}
  @override
  Stream<Nip01Event> newGiftWraps(String pubkey) => wraps.stream;
  @override
  Future<void> dispose() async {}
}
