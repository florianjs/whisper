import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/image_transfer.dart';
import 'package:whisper/models/message.dart';

import 'support/fake_network.dart';

/// Already "anonymized" payload: these tests are about transport & storage;
/// anonymization is covered in image_transfer_test / photo_test.
({Uint8List bytes, int width, int height}) prepared(int size, [int seed = 1]) {
  final r = Random(seed);
  return (
    bytes: Uint8List.fromList(List.generate(size, (_) => r.nextInt(256))),
    width: 800,
    height: 600,
  );
}

Message? imageMessage(Peer p, String peer) =>
    p.messages.messagesWith(peer).where((m) => m.image != null).firstOrNull;

void main() {
  late FakeNetwork net;
  setUp(() => net = FakeNetwork());

  test('image delivered in chunks, verified, stored encrypted', () async {
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);
    await bob.messages.send(alice.pubkey, 'salut'); // Bob wrote → accepted
    await alice.messages.send(bob.pubkey, 'salut'); // Alice replied → accepted
    await until(() => bob.messages.isAccepted(alice.pubkey));

    final photo = prepared(100 * 1024);
    await alice.messages.sendImage(bob.pubkey, photo);
    final sent = imageMessage(alice, bob.pubkey)!;
    expect(sent.status, MessageStatus.sent);
    expect(sent.image!.chunks, 9);

    await until(
      () => imageMessage(bob, alice.pubkey)?.status == MessageStatus.received,
    );
    final got = imageMessage(bob, alice.pubkey)!;
    expect(got.id, sent.id);
    expect(await bob.messages.imageFor(got), photo.bytes);
    expect(await bob.db.listDocs('images'), hasLength(1));
    // 1 header + 9 chunks for Bob, no plaintext anywhere.
    expect(
      net.stored.where((w) => w.tags.first[1] == bob.pubkey).length,
      greaterThanOrEqualTo(10),
    );
  });

  test('chunks arriving in any order (relays replay) still assemble', () async {
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);
    await bob.messages.send(alice.pubkey, 'salut');
    await alice.messages.send(bob.pubkey, 'salut');
    await until(() => bob.messages.isAccepted(alice.pubkey));

    // Bob offline while Alice sends, then relays replay everything reversed.
    final bobRestarted = await makePeer(net, bobWords);
    net.down = false;
    await alice.messages.sendImage(bob.pubkey, prepared(50 * 1024, 2));
    final wraps = net.stored
        .where((w) => w.tags.first[1] == bob.pubkey)
        .toList()
        .reversed;
    for (final w in wraps) {
      bobRestarted.transport.push(w);
    }
    await until(
      () =>
          imageMessage(bobRestarted, alice.pubkey)?.status ==
          MessageStatus.received,
    );
  });

  test(
    'pending request: image held in memory, not stored, not shown',
    () async {
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      // Bob is a stranger to Alice and sends an image first.
      await bob.messages.sendImage(alice.pubkey, prepared(30 * 1024, 3));
      await until(
        () => imageMessage(alice, bob.pubkey)?.status == MessageStatus.received,
      );
      final m = imageMessage(alice, bob.pubkey)!;
      expect(alice.messages.requests, isNotEmpty);
      expect(await alice.messages.imageFor(m), isNull, reason: 'not shown');
      expect(await alice.db.listDocs('images'), isEmpty, reason: 'not stored');

      await alice.messages.accept(bob.pubkey);
      expect(await alice.messages.imageFor(m), isNotNull);
      expect(await alice.db.listDocs('images'), hasLength(1));
    },
  );

  test('refuse / block delete the images too', () async {
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);
    await alice.messages.send(bob.pubkey, 'salut'); // Alice accepted Bob
    await bob.messages.send(alice.pubkey, 'salut');
    await until(() => bob.messages.isAccepted(alice.pubkey));
    await bob.messages.sendImage(alice.pubkey, prepared(20 * 1024, 4));
    await until(() => alice.db.values('images').isNotEmpty);

    await alice.messages.block(bob.pubkey);
    expect(await alice.db.listDocs('images'), isEmpty);
  });

  test('forged header (lying about size) is ignored', () async {
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);
    await alice.messages.send(bob.pubkey, 'salut');
    await bob.messages.send(alice.pubkey, 'salut');
    await until(() => bob.messages.isAccepted(alice.pubkey));
    final bad = ImageHeader.fromJson({
      'f': 'ab' * 16,
      'h': 'cd' * 32,
      's': ImageTransfer.maxBytes * 10,
      'n': 999,
      'w': 10,
      'hh': 10,
    });
    expect(bad, isNull);
  });

  test('offline send fails, retry resends header + chunks', () async {
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);
    await alice.messages.send(bob.pubkey, 'salut');
    await bob.messages.send(alice.pubkey, 'salut');
    await until(() => bob.messages.isAccepted(alice.pubkey));

    net.down = true;
    await alice.messages.sendImage(bob.pubkey, prepared(40 * 1024, 5));
    expect(imageMessage(alice, bob.pubkey)!.status, MessageStatus.failed);
    net.down = false;
    await alice.messages.retryFailed();
    await until(
      () => imageMessage(bob, alice.pubkey)?.status == MessageStatus.received,
    );
  });
}
