import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart' show Nip01EventModel;
import 'package:whisper/data/channel_relays.dart';
import 'package:whisper/logic/channel.dart';
import 'package:whisper/logic/identity.dart';

import 'support/fake_network.dart';

/// Minimal relay: records REQ/CLOSE, answers EVENT with OK, can push events
/// and drop connections.
class FakeRelay {
  late HttpServer server;
  final sockets = <WebSocket>[];
  final reqs = <List<Object?>>[];
  final closes = <String>[];
  final published = <Map<String, dynamic>>[];
  bool accept = true;

  String get url => 'ws://127.0.0.1:${server.port}';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final ws = await WebSocketTransformer.upgrade(req);
      sockets.add(ws);
      ws.listen((data) {
        final msg = jsonDecode(data as String) as List;
        switch (msg[0]) {
          case 'REQ':
            reqs.add(msg);
          case 'CLOSE':
            closes.add(msg[1] as String);
          case 'EVENT':
            final e = (msg[1] as Map).cast<String, dynamic>();
            published.add(e);
            ws.add(jsonEncode(['OK', e['id'], accept, '']));
        }
      });
    });
  }

  void push(Map<String, dynamic> event) {
    for (final ws in sockets) {
      ws.add(jsonEncode(['EVENT', 'ch', event]));
    }
  }

  Future<void> dropAll() async {
    for (final ws in sockets) {
      await ws.close();
    }
    sockets.clear();
  }
}

void main() {
  late FakeRelay relay;
  late ChannelRelayPool pool;
  late ChannelKeys keys;

  setUp(() async {
    relay = FakeRelay();
    await relay.start();
    pool = ChannelRelayPool(relays: () => [relay.url]);
    keys = await ChannelKeys.derive(deriveIdentity(aliceWords), 0);
  });

  tearDown(() async {
    pool.dispose();
    await relay.server.close(force: true);
  });

  test('nothing watched, nothing connected', () async {
    await quiet();
    expect(relay.sockets, isEmpty);
  });

  test('subscribes to posts by author and reactions by p tag', () async {
    pool.watchChannels({keys.publicKey});
    await until(() => relay.reqs.isNotEmpty);
    final req = relay.reqs.single;
    expect(req[1], 'ch');
    final posts = req[2] as Map;
    final reactions = req[3] as Map;
    expect(posts['authors'], [keys.publicKey]);
    expect(posts['kinds'], [Channel.kindPost, Channel.kindMeta]);
    expect(reactions['#p'], [keys.publicKey]);
    expect(reactions['kinds'], [Channel.kindReaction]);
  });

  test('delivers pushed events and publishes with OK', () async {
    pool.watchChannels({keys.publicKey});
    await until(() => relay.reqs.isNotEmpty);
    final got = <String>[];
    pool.channelEvents.listen((e) => got.add(e.id));

    final post = await signPost(keys, 'x');
    relay.push(Nip01EventModel.fromEntity(post).toJson());
    await until(() => got.isNotEmpty);
    expect(got.single, post.id);

    await pool.publishChannelEvent(post);
    expect(relay.published.single['id'], post.id);
    expect(relay.published.single['sig'], post.sig);

    relay.accept = false;
    await expectLater(
      pool.publishChannelEvent(await signPost(keys, 'y')),
      throwsStateError,
    );
  });

  test('watch change replaces the subscription', () async {
    pool.watchChannels({keys.publicKey});
    await until(() => relay.reqs.length == 1);
    final other = await ChannelKeys.derive(deriveIdentity(aliceWords), 1);
    pool.watchChannels({keys.publicKey, other.publicKey});
    await until(() => relay.reqs.length == 2);
    expect(relay.closes, ['ch']);
    expect((relay.reqs.last[2] as Map)['authors'], hasLength(2));

    // Same set again: no churn.
    pool.watchChannels({other.publicKey, keys.publicKey});
    await quiet();
    expect(relay.reqs, hasLength(2));
  });

  test('reconnects and resubscribes after the relay drops', () async {
    pool.watchChannels({keys.publicKey});
    await until(() => relay.reqs.length == 1);
    await relay.dropAll();
    await until(() => pool.connected.isEmpty);
    pool.refresh(); // e.g. Tor came back: no need to wait out the backoff
    await until(() => relay.reqs.length == 2);
  });

  test('unwatching everything disconnects', () async {
    pool.watchChannels({keys.publicKey});
    await until(() => pool.connected.isNotEmpty);
    pool.watchChannels({});
    await until(() => pool.connected.isEmpty);
    await expectLater(
      pool.publishChannelEvent(await signPost(keys, 'z')),
      throwsStateError,
    );
  });

  test('uses the injected client (Tor isolation lives there)', () async {
    var created = 0;
    final isolated = ChannelRelayPool(
      relays: () => [relay.url],
      httpClient: () {
        created++;
        return HttpClient();
      },
    );
    isolated.watchChannels({keys.publicKey});
    await until(() => isolated.connected.isNotEmpty);
    expect(created, 1);
    isolated.dispose();
  });
}
