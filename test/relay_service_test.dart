import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart' show Nip01Event;
import 'package:whisper/data/db.dart';
import 'package:whisper/data/identity_store.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/data/relay_service.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/relays.dart';

const vector12 =
    'leader monkey parrot ring guide accident before fence cannon height naive bean';

class FakeBackend implements RelayBackend {
  FakeBackend(this.relays);
  final List<String> relays;
  final controller = StreamController<Map<String, bool>>.broadcast(sync: true);
  int reconnects = 0;
  int subscriptions = 0;
  bool disposed = false;
  bool failPublish = false;
  final published = <(int, List<List<String>>)>[];

  /// Relays each signed event was sent to (null = our own).
  final signed = <List<String>?>[];

  /// Relays refusing every event (dead).
  final down = <String>{};

  /// Published inbox lists (kind 10050) by pubkey.
  final inboxes = <String, List<String>>{};

  @override
  Stream<Map<String, bool>> get connectivity => controller.stream;

  @override
  Future<void> reconnect() async => reconnects++;

  @override
  Future<void> publish({
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) async {
    if (failPublish) throw StateError('rejected');
    published.add((kind, tags));
  }

  @override
  Future<void> publishSigned(Nip01Event event, {List<String>? relays}) async {
    signed.add(relays);
    if ((relays ?? this.relays).every(down.contains)) {
      throw StateError('no relay accepted the event');
    }
  }

  @override
  Stream<Nip01Event> giftWraps({required String pubkey, required int since}) {
    subscriptions++;
    // A real controller: cancelling a `Stream.empty()` subscription returns a
    // root-zone future that never resolves inside fakeAsync.
    return StreamController<Nip01Event>().stream;
  }

  @override
  Future<List<String>> inboxRelaysOf(String pubkey) async =>
      inboxes[pubkey] ?? const [];

  @override
  Future<void> dispose() async => disposed = true;

  void emit(Map<String, bool> m) => controller.add(m);
}

void main() {
  late IdentityStore identity;
  late MemoryDocStore db;
  late List<FakeBackend> backends;

  RelayService makeService() => RelayService(
    identity: identity,
    db: db,
    random: Random(0),
    backendFactory: (id, urls) {
      final b = FakeBackend(urls);
      backends.add(b);
      return b;
    },
  );

  setUp(() {
    identity = IdentityStore(
      MemoryKeyVault(),
      derive: (m) async => deriveIdentity(m),
    );
    db = MemoryDocStore();
    backends = [];
  });

  test('no identity, no connection', () {
    fakeAsync((async) {
      final s = makeService();
      async.flushMicrotasks();
      expect(backends, isEmpty);
      expect(s.relays, isEmpty);
    });
  });

  test('connects to default relays once an identity exists', () {
    fakeAsync((async) {
      final s = makeService();
      identity.restore(vector12);
      async.flushMicrotasks();

      expect(backends, hasLength(1));
      expect(backends.single.relays, defaultRelays);
      expect(s.health, RelayHealth.connecting);

      backends.single.emit({defaultRelays.first: true});
      expect(s.health, RelayHealth.online);
      expect(s.connectedCount, 1);
    });
  });

  test('uses the relay list saved in settings', () {
    fakeAsync((async) {
      db.putDoc('settings', {
        'id': 'relays',
        'urls': ['wss://mine.example'],
      });
      makeService();
      identity.restore(vector12);
      async.flushMicrotasks();
      expect(backends.single.relays, ['wss://mine.example']);
    });
  });

  test('goes offline after the settle timeout, then retries with backoff', () {
    fakeAsync((async) {
      final s = makeService();
      identity.restore(vector12);
      async.flushMicrotasks();
      final b = backends.single;

      async.elapse(const Duration(seconds: 10));
      expect(s.health, RelayHealth.offline);
      expect(b.reconnects, 0);

      async.elapse(const Duration(milliseconds: 2400)); // attempt 0: ~2s
      expect(b.reconnects, 1);
      async.elapse(const Duration(milliseconds: 4800)); // attempt 1: ~4s
      expect(b.reconnects, 2);

      b.emit({defaultRelays[1]: true});
      expect(s.health, RelayHealth.online);
      async.elapse(const Duration(minutes: 5));
      expect(b.reconnects, 2, reason: 'no retries while online');
    });
  });

  test('network loss after being online triggers retries', () {
    fakeAsync((async) {
      final s = makeService();
      identity.restore(vector12);
      async.flushMicrotasks();
      final b = backends.single;
      b.emit({defaultRelays.first: true});
      b.emit({defaultRelays.first: false});
      expect(s.health, RelayHealth.offline);
      async.elapse(const Duration(seconds: 3));
      expect(b.reconnects, 1);
    });
  });

  test('reconnectNow skips the backoff wait', () {
    fakeAsync((async) {
      final s = makeService();
      identity.restore(vector12);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      s.reconnectNow();
      async.flushMicrotasks();
      expect(backends.single.reconnects, 1);
    });
  });

  test('publishes inbox relays once, and not again next launch', () {
    fakeAsync((async) {
      makeService();
      identity.restore(vector12);
      async.flushMicrotasks();
      backends.single.emit({defaultRelays.first: true});
      backends.single.emit({defaultRelays[1]: true});
      async.flushMicrotasks();

      final published = backends.single.published;
      expect(published, hasLength(1));
      expect(published.single.$1, RelayService.inboxRelaysKind);
      expect(
        published.single.$2,
        containsAll([
          for (final u in defaultRelays) ['relay', u],
        ]),
      );

      // Same relay set on a later start: nothing re-published.
      makeService();
      async.flushMicrotasks();
      backends.last.emit({defaultRelays.first: true});
      async.flushMicrotasks();
      expect(backends.last.published, isEmpty);
    });
  });

  test('failed inbox publish is retried on the next connection', () {
    fakeAsync((async) {
      makeService();
      identity.restore(vector12);
      async.flushMicrotasks();
      final b = backends.single..failPublish = true;
      b.emit({defaultRelays.first: true});
      async.flushMicrotasks();
      expect(b.published, isEmpty);

      b.failPublish = false;
      b.emit({defaultRelays.first: false});
      b.emit({defaultRelays.first: true});
      async.flushMicrotasks();
      expect(b.published, hasLength(1));
    });
  });

  test('wiping the identity disconnects and stops retrying', () {
    fakeAsync((async) {
      final s = makeService();
      identity.restore(vector12);
      async.flushMicrotasks();
      final b = backends.single;
      async.elapse(const Duration(seconds: 10));

      identity.wipe();
      async.flushMicrotasks();
      expect(b.disposed, isTrue);
      expect(s.relays, isEmpty);

      async.elapse(const Duration(minutes: 5));
      expect(b.reconnects, 0);
    });
  });

  test('subscription is recreated when relays come up after start', () {
    fakeAsync((async) {
      makeService();
      identity.restore(vector12);
      async.flushMicrotasks();
      final b = backends.single;
      expect(b.subscriptions, 1, reason: 'opened at start, no relay yet');

      // Tor finishes bootstrapping: relays connect one after another.
      b.emit({defaultRelays[0]: true});
      b.emit({defaultRelays[1]: true});
      async
        ..elapse(const Duration(seconds: 3))
        ..flushMicrotasks();
      expect(b.subscriptions, 2, reason: 'one debounced resubscription');

      // Nothing new → no churn.
      b.emit({defaultRelays[0]: true});
      async
        ..elapse(const Duration(seconds: 3))
        ..flushMicrotasks();
      expect(b.subscriptions, 2);

      // A relay drops and comes back → needs the REQ again.
      b.emit({defaultRelays[1]: false});
      b.emit({defaultRelays[1]: true});
      async
        ..elapse(const Duration(seconds: 3))
        ..flushMicrotasks();
      expect(b.subscriptions, 3);
    });
  });

  test('relays outside our list do not count as ours', () {
    fakeAsync((async) {
      final s = makeService();
      identity.restore(vector12);
      async.flushMicrotasks();
      backends.single.emit({'wss://extra.example': true});
      expect(s.relays.containsKey('wss://extra.example'), isFalse);
      expect(s.connectedCount, 0);
    });
  });

  test('vanish request: kind 62 to all relays, refused when offline', () {
    fakeAsync((async) {
      final s = makeService();
      identity.restore(vector12);
      async.flushMicrotasks();
      Object? error;
      s.requestVanish().catchError((Object e) => error = e);
      async.flushMicrotasks();
      expect(error, isA<StateError>());

      final b = backends.single;
      b.emit({defaultRelays.first: true});
      s.requestVanish();
      async.flushMicrotasks();
      final vanish = b.published.where((p) => p.$1 == 62).single;
      expect(vanish.$2, [
        ['relay', 'ALL_RELAYS'],
      ]);
    });
  });

  group('spare relays', () {
    const tick = Duration(minutes: 10);
    final dead = defaultRelays[1];

    /// Everything up but [dead].
    Map<String, bool> allBut(String relay) => {
      for (final u in defaultRelays) u: u != relay,
    };

    test('a relay dead for 6h while others work is swapped for a spare', () {
      fakeAsync((async) {
        final s = makeService();
        identity.restore(vector12);
        async.flushMicrotasks();
        backends.single.emit(allBut(dead));

        async.elapse(deadRelayAfter - tick);
        expect(backends, hasLength(1));
        async.elapse(tick);
        async.flushMicrotasks();

        expect(backends, hasLength(2));
        final relays = backends.last.relays;
        expect(relays[1], spareRelays.first);
        expect(relays, isNot(contains(dead)));
        expect(s.relays.keys, relays);
        final saved = db.getDoc('settings', 'relays');
        async.flushMicrotasks();
        saved.then((doc) {
          expect(doc!['auto'], isTrue);
          expect((doc['spares'] as List).last, dead);
        });
        async.flushMicrotasks();

        // New list → new inbox list (10050) published for senders.
        backends.last.emit({relays.first: true});
        async.flushMicrotasks();
        final inbox = backends.last.published.single;
        expect(inbox.$1, RelayService.inboxRelaysKind);
        expect(inbox.$2.map((t) => t[1]), contains(spareRelays.first));
      });
    });

    test('phone offline (every relay down) never kills a relay', () {
      fakeAsync((async) {
        makeService();
        identity.restore(vector12);
        async.flushMicrotasks();
        async.elapse(deadRelayAfter * 2);
        expect(backends, hasLength(1));
      });
    });

    test('a relay coming back resets its downtime', () {
      fakeAsync((async) {
        makeService();
        identity.restore(vector12);
        async.flushMicrotasks();
        final b = backends.single;
        b.emit(allBut(dead));
        async.elapse(deadRelayAfter - tick);
        b.emit({dead: true});
        async.elapse(tick);
        b.emit({dead: false});
        async.elapse(deadRelayAfter - tick);
        expect(backends, hasLength(1));
      });
    });

    test('the reset is saved too: a restart does not revive old downtime', () {
      fakeAsync((async) {
        var s = makeService();
        identity.restore(vector12);
        async.flushMicrotasks();
        backends.single.emit(allBut(dead));
        async.elapse(deadRelayAfter - tick);
        backends.single.emit({dead: true});
        async.flushMicrotasks();
        s.dispose();

        s = makeService();
        async.flushMicrotasks();
        backends.last.emit(allBut(dead));
        async.elapse(tick * 3);
        expect(backends.last.relays, contains(dead));
        s.dispose();
      });
    });

    test('downtime survives a restart', () {
      fakeAsync((async) {
        var s = makeService();
        identity.restore(vector12);
        async.flushMicrotasks();
        backends.single.emit(allBut(dead));
        async.elapse(deadRelayAfter - tick);
        s.dispose();

        s = makeService();
        async.flushMicrotasks();
        backends.last.emit(allBut(dead));
        async.elapse(tick);
        async.flushMicrotasks();
        expect(backends.last.relays, isNot(contains(dead)));
        s.dispose();
      });
    });

    test("the user's own list is never replaced", () {
      fakeAsync((async) {
        final s = makeService();
        identity.restore(vector12);
        async.flushMicrotasks();
        s.setRelays(defaultRelays);
        async.flushMicrotasks();
        backends.last.emit(allBut(dead));
        async.elapse(deadRelayAfter * 2);
        expect(backends.last.relays, defaultRelays);
      });
    });
  });

  group('delivery follows a contact to new relays', () {
    final peer = 'b' * 64;
    Nip01Event wrap() => Nip01Event(
      pubKey: 'a' * 64,
      kind: 1059,
      tags: [
        ['p', peer],
      ],
      content: '',
    );

    test('QR hint first, then their published list wins', () {
      fakeAsync((async) {
        final s = makeService();
        identity.restore(vector12);
        async.flushMicrotasks();
        final b = backends.single;
        b.inboxes[peer] = ['wss://new.example'];
        s.rememberInboxRelays(peer, ['wss://old.example']);

        s.deliver(wrap());
        async.flushMicrotasks();
        s.deliver(wrap());
        async.flushMicrotasks();
        expect(b.signed, [
          ['wss://old.example'],
          ['wss://new.example'],
        ]);
      });
    });

    test('all their relays refuse: look again past the cache, retry once', () {
      fakeAsync((async) {
        final s = makeService();
        identity.restore(vector12);
        async.flushMicrotasks();
        final b = backends.single;
        b.inboxes[peer] = ['wss://old.example'];
        s.deliver(wrap());
        async.flushMicrotasks();

        // They failed over; our cached list is stale.
        b.down.add('wss://old.example');
        b.inboxes[peer] = ['wss://spare.example'];
        Object? error;
        s.deliver(wrap()).catchError((Object e) => error = e);
        async.flushMicrotasks();
        expect(error, isNull);
        expect(b.signed.last, ['wss://spare.example']);
      });
    });

    test('same list after the lookup: the failure stands', () {
      fakeAsync((async) {
        final s = makeService();
        identity.restore(vector12);
        async.flushMicrotasks();
        final b = backends.single;
        b.inboxes[peer] = ['wss://old.example'];
        b.down.add('wss://old.example');
        Object? error;
        s.deliver(wrap()).catchError((Object e) => error = e);
        async.flushMicrotasks();
        expect(error, isA<StateError>());
        expect(b.signed, hasLength(1));
      });
    });
  });
}
