import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart' show Nip01Event;
import 'package:whisper/data/db.dart';
import 'package:whisper/data/identity_store.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/data/message_store.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/transport.dart';

const aliceWords =
    'leader monkey parrot ring guide accident before fence cannon height naive bean';
const bobWords =
    'what bleak badge arrange retreat wolf trade produce cricket blur garlic '
    'valid proud rude strong choose busy staff weather area salt hollow arm fade';

/// In-memory "relays": keeps every wrap and routes it by its p tag, like a
/// store-and-forward relay would.
class FakeNetwork {
  final stored = <Nip01Event>[];

  /// Plain signed channel events, as relays keep them.
  final channelStored = <Nip01Event>[];
  final _channelSubs = <FakeChannelTransport>[];
  final _inboxes = <String, StreamController<Nip01Event>>{};
  bool down = false;

  FakeTransport transportFor(String pubkey) => FakeTransport(this, pubkey);

  FakeChannelTransport channelTransport() {
    final t = FakeChannelTransport(this);
    _channelSubs.add(t);
    return t;
  }

  void _publishChannel(Nip01Event e) {
    if (down) throw StateError('offline');
    channelStored.add(e);
    for (final t in _channelSubs) {
      if (t._matches(e)) t._events.add(e);
    }
  }

  void _publish(Nip01Event wrap) {
    if (down) throw StateError('offline');
    stored.add(wrap);
    final to = wrap.tags.firstWhere((t) => t[0] == 'p')[1];
    _inboxes[to]?.add(wrap);
  }
}

class FakeTransport implements Transport {
  FakeTransport(this.net, this.pubkey);
  final FakeNetwork net;
  final String pubkey;

  @override
  Stream<Nip01Event> get incoming => net._inboxes
      .putIfAbsent(pubkey, () => StreamController.broadcast(sync: true))
      .stream;

  @override
  Future<void> deliver(Nip01Event giftWrap) async => net._publish(giftWrap);

  /// Delivers one stored wrap to us (custom order / replay tests).
  void push(Nip01Event wrap) => net._inboxes
      .putIfAbsent(pubkey, () => StreamController.broadcast(sync: true))
      .add(wrap);

  /// Replays everything stored for us, as a relay does on a new subscription.
  void replay() {
    for (final w in net.stored) {
      if (w.tags.any((t) => t[0] == 'p' && t[1] == pubkey)) {
        net._inboxes[pubkey]!.add(w);
      }
    }
  }
}

class FakeChannelTransport implements ChannelTransport {
  FakeChannelTransport(this.net);
  final FakeNetwork net;
  final _events = StreamController<Nip01Event>.broadcast(sync: true);
  Set<String> watched = {};
  final published = <Nip01Event>[];

  @override
  Stream<Nip01Event> get channelEvents => _events.stream;

  bool _matches(Nip01Event e) =>
      watched.contains(e.pubKey) ||
      e.tags.any((t) => t.length > 1 && t[0] == 'p' && watched.contains(t[1]));

  @override
  void watchChannels(
    Set<String> channelPks, {
    List<String> relays = const [],
    Set<String> probes = const {},
  }) {
    final all = {...channelPks, ...probes};
    final added = all.difference(watched);
    watched = all;
    if (added.isEmpty) return;
    // A new REQ gets the stored history, like a relay.
    for (final e in [...net.channelStored]) {
      if (_matches(e)) _events.add(e);
    }
  }

  @override
  Future<void> publishChannelEvent(
    Nip01Event event, {
    List<String> relays = const [],
  }) async {
    net._publishChannel(event);
    published.add(event);
  }
}

class Peer {
  Peer(this.identity, this.db, this.transport, this.messages);
  final IdentityStore identity;
  final MemoryDocStore db;
  final FakeTransport transport;
  final MessageStore messages;
  String get pubkey => identity.identity!.publicKey;
}

Future<Peer> makePeer(
  FakeNetwork net,
  String words, {
  MemoryDocStore? db,
  KeyVault? vault,
}) async {
  final identity = IdentityStore(
    vault ?? MemoryKeyVault(),
    derive: (m) async => deriveIdentity(m),
  );
  await identity.restore(words);
  final store = db ?? MemoryDocStore();
  final transport = net.transportFor(identity.identity!.publicKey);
  final messages = MessageStore(
    identity: identity,
    db: store,
    transport: transport,
    chunkPacing: Duration.zero,
  );
  await pumpEventQueue();
  return Peer(identity, store, transport, messages);
}

/// Signature checks run in an isolate, so results land outside the event
/// queue: poll for the expected state instead of pumping.
Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition not met in time');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// For "must NOT happen" checks: give any in-flight isolate work time to land.
Future<void> quiet() => Future<void>.delayed(const Duration(milliseconds: 800));
