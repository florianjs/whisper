import 'package:flutter_test/flutter_test.dart';

import 'package:whisper/logic/pin.dart';
import 'package:whisper/data/message_store.dart';
import 'support/fake_network.dart';
import 'package:whisper/data/db.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/nip17.dart';
import 'package:whisper/models/message.dart';

void main() {
  late FakeNetwork net;
  setUp(() => net = FakeNetwork());

  test('alice → bob: delivered, decrypted, persisted on both sides', () async {
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);

    await alice.messages.send(bob.pubkey, '  on se voit demain ?  ');
    await until(() => bob.messages.messagesWith(alice.pubkey).isNotEmpty);

    final sent = alice.messages.messagesWith(bob.pubkey).single;
    expect(sent.text, 'on se voit demain ?');
    expect(sent.status, MessageStatus.sent);
    expect(sent.fromMe, isTrue);

    final got = bob.messages.messagesWith(alice.pubkey).single;
    expect(got.text, 'on se voit demain ?');
    expect(got.status, MessageStatus.received);
    expect(got.id, sent.id);
    expect(await bob.db.listDocs('messages'), hasLength(1));

    // The network only saw gift wraps: peer + self-copy, no plaintext.
    expect(net.stored, hasLength(2));
    expect(net.stored.every((w) => w.kind == Nip17.kindGiftWrap), isTrue);
    expect(net.stored.any((w) => w.content.contains('demain')), isFalse);
  });

  test('conversations are grouped by peer, newest first', () async {
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);
    await alice.messages.send(bob.pubkey, 'un');
    await Future<void>.delayed(const Duration(seconds: 1));
    await bob.messages.send(alice.pubkey, 'deux');
    await until(() => alice.messages.messagesWith(bob.pubkey).length == 2);

    final convs = alice.messages.conversations;
    expect(convs, hasLength(1));
    expect(convs.single.peer, bob.pubkey);
    expect(alice.messages.messagesWith(bob.pubkey).map((m) => m.text), [
      'un',
      'deux',
    ]);
  });

  test('duplicates from several relays are shown once', () async {
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);
    await alice.messages.send(bob.pubkey, 'une fois');
    await until(() => bob.messages.messagesWith(alice.pubkey).isNotEmpty);
    bob.transport.replay();
    bob.transport.replay();
    await quiet();
    expect(bob.messages.messagesWith(alice.pubkey), hasLength(1));
  });

  test('offline: message fails, then retry delivers the same id', () async {
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);

    net.down = true;
    await alice.messages.send(bob.pubkey, 'tunnel');
    final failed = alice.messages.messagesWith(bob.pubkey).single;
    expect(failed.status, MessageStatus.failed);

    net.down = false;
    await alice.messages.retryFailed();
    await until(() => bob.messages.messagesWith(alice.pubkey).isNotEmpty);
    expect(
      alice.messages.messagesWith(bob.pubkey).single.status,
      MessageStatus.sent,
    );
    final got = bob.messages.messagesWith(alice.pubkey).single;
    expect(got.id, failed.id);
  });

  test('restored account gets sent and received history back', () async {
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);
    await alice.messages.send(bob.pubkey, 'envoyé');
    // Distinct timestamps so the expected order is deterministic.
    await Future<void>.delayed(const Duration(seconds: 1));
    await bob.messages.send(alice.pubkey, 'reçu');
    await until(() => alice.messages.messagesWith(bob.pubkey).length == 2);

    // Alice on a new phone: empty DB, same words, relays replay history.
    final restored = await makePeer(net, aliceWords);
    restored.transport.replay();
    await until(() => restored.messages.messagesWith(bob.pubkey).length == 2);

    final history = restored.messages.messagesWith(bob.pubkey);
    expect(history.map((m) => (m.text, m.fromMe)), [
      ('envoyé', true),
      ('reçu', false),
    ]);
  });

  test('forged wraps are dropped without crashing', () async {
    final bob = await makePeer(net, bobWords);
    final mallory = deriveIdentity(
      'abandon abandon abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon about',
    );
    final alicePub = deriveIdentity(aliceWords).publicKey;
    final forged = await Nip17.wrap(
      sender: mallory,
      recipientPubkey: bob.pubkey,
      rumor: Nip17.chatRumor(
        senderPubkey: alicePub, // claims to be alice
        recipientPubkey: bob.pubkey,
        text: 'donne-moi ta phrase',
      ),
    );
    await FakeTransport(net, mallory.publicKey).deliver(forged);
    await quiet();
    expect(bob.messages.conversations, isEmpty);
  });

  test('panic: memory cleared, no write after the wipe', () async {
    final vault = MemoryKeyVault();
    final alice = await makePeer(net, aliceWords, vault: vault);
    final bob = await makePeer(net, bobWords);
    await bob.messages.send(alice.pubkey, 'avant');
    await until(() => alice.messages.requests.isNotEmpty);

    final alicePub = alice.pubkey;
    await alice.db.destroy();
    await alice.identity.wipe();
    // A message arriving right after the wipe must not be stored.
    await bob.messages.send(alicePub, 'après');
    await quiet();

    expect(alice.messages.conversations, isEmpty);
    expect(alice.messages.requests, isEmpty);
    expect(await alice.db.listDocs('messages'), isEmpty);
    expect(await alice.db.listDocs('contacts'), isEmpty);
  });

  group('message requests', () {
    test('first message from a stranger is a request, not a chat', () async {
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      await bob.messages.send(alice.pubkey, 'bonjour, on se connaît ?');
      await until(() => alice.messages.requests.isNotEmpty);

      expect(alice.messages.conversations, isEmpty);
      expect(alice.messages.requests.single.peer, bob.pubkey);
      expect(alice.messages.stateOf(bob.pubkey), ContactState.pending);
      expect(alice.messages.isAccepted(bob.pubkey), isFalse);
      // The sender considers it a normal chat.
      expect(bob.messages.conversations.single.peer, alice.pubkey);
    });

    test('accept moves it to chats', () async {
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      await bob.messages.send(alice.pubkey, 'salut');
      await until(() => alice.messages.requests.isNotEmpty);

      await alice.messages.accept(bob.pubkey);
      expect(alice.messages.requests, isEmpty);
      expect(alice.messages.conversations.single.peer, bob.pubkey);
      expect(alice.messages.isAccepted(bob.pubkey), isTrue);
    });

    test('replying is accepting', () async {
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      await bob.messages.send(alice.pubkey, 'salut');
      await until(() => alice.messages.requests.isNotEmpty);
      await alice.messages.send(bob.pubkey, 'oui ?');
      expect(alice.messages.isAccepted(bob.pubkey), isTrue);
    });

    test('refuse deletes everything; a new message is a new request', () async {
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      await bob.messages.send(alice.pubkey, 'spam');
      await until(() => alice.messages.requests.isNotEmpty);

      await alice.messages.refuse(bob.pubkey);
      expect(alice.messages.requests, isEmpty);
      expect(alice.messages.messagesWith(bob.pubkey), isEmpty);
      expect(await alice.db.listDocs('messages'), isEmpty);
      expect(await alice.db.listDocs('contacts'), isEmpty);

      await Future<void>.delayed(const Duration(seconds: 1));
      await bob.messages.send(alice.pubkey, 'encore moi');
      await until(() => alice.messages.requests.isNotEmpty);
      expect(alice.messages.messagesWith(bob.pubkey).single.text, 'encore moi');
    });

    test('block drops everything they send afterwards', () async {
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      await bob.messages.send(alice.pubkey, 'un');
      await until(() => alice.messages.requests.isNotEmpty);

      await alice.messages.block(bob.pubkey);
      expect(alice.messages.requests, isEmpty);
      expect(alice.messages.stateOf(bob.pubkey), ContactState.blocked);

      await bob.messages.send(alice.pubkey, 'deux');
      await bob.messages.send(alice.pubkey, 'trois');
      await quiet();
      expect(alice.messages.messagesWith(bob.pubkey), isEmpty);
      expect(await alice.db.listDocs('messages'), isEmpty);
    });

    test('states survive a restart', () async {
      final db = MemoryDocStore();
      final alice = await makePeer(net, aliceWords, db: db);
      final bob = await makePeer(net, bobWords);
      await bob.messages.send(alice.pubkey, 'salut');
      await until(() => alice.messages.requests.isNotEmpty);
      await alice.messages.block(bob.pubkey);

      final reopened = await makePeer(net, aliceWords, db: db);
      await until(() => reopened.messages.stateOf(bob.pubkey) != null);
      expect(reopened.messages.stateOf(bob.pubkey), ContactState.blocked);
    });

    test('conversations from before tracking are migrated', () async {
      final db = MemoryDocStore();
      final bobPub = deriveIdentity(bobWords).publicKey;
      final carolPub = deriveIdentity(
        'abandon abandon abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon about',
      ).publicKey;
      Map<String, dynamic> msg(String id, String peer, bool fromMe) => Message(
        id: id,
        peer: peer,
        fromMe: fromMe,
        text: id,
        createdAt: 1700000000,
        status: fromMe ? MessageStatus.sent : MessageStatus.received,
      ).toJson();
      await db.putDoc('messages', msg('a', bobPub, true)); // I wrote to bob
      await db.putDoc(
        'messages',
        msg('b', carolPub, false),
      ); // carol wrote only

      final alice = await makePeer(net, aliceWords, db: db);
      await until(() => alice.messages.stateOf(carolPub) != null);
      expect(alice.messages.stateOf(bobPub), ContactState.accepted);
      expect(alice.messages.stateOf(carolPub), ContactState.pending);
    });

    test('restored account: own self-copies mark peers as accepted', () async {
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      await alice.messages.send(bob.pubkey, 'hello');
      await until(() => bob.messages.requests.isNotEmpty);

      final restored = await makePeer(net, aliceWords);
      restored.transport.replay();
      await until(() => restored.messages.isAccepted(bob.pubkey));
      expect(restored.messages.conversations.single.peer, bob.pubkey);
    });
  });

  group('block anytime', () {
    test('blocking an accepted contact drops their next messages', () async {
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      await alice.messages.send(bob.pubkey, 'salut'); // accepted by Alice
      expect(alice.messages.isAccepted(bob.pubkey), isTrue);

      await alice.messages.block(bob.pubkey);
      expect(alice.messages.conversations, isEmpty);
      expect(alice.messages.blockedPeers, [bob.pubkey]);

      await bob.messages.send(alice.pubkey, 'tu es là ?');
      await quiet();
      expect(alice.messages.messagesWith(bob.pubkey), isEmpty);
    });

    test('unblock: their next message is a new request', () async {
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      await alice.messages.send(bob.pubkey, 'salut');
      await alice.messages.block(bob.pubkey);
      await alice.messages.unblock(bob.pubkey);
      expect(alice.messages.blockedPeers, isEmpty);
      expect(await alice.db.listDocs('contacts'), isEmpty);

      await bob.messages.send(alice.pubkey, 'de retour');
      await until(() => alice.messages.requests.isNotEmpty);
      expect(alice.messages.stateOf(bob.pubkey), ContactState.pending);
    });
  });

  test('loaded flips only after the DB has been read', () async {
    final alice = await makePeer(net, aliceWords);
    expect(alice.messages.loaded, isTrue);
    await alice.identity.wipe();
    expect(alice.messages.loaded, isFalse);
  });

  group('contact info', () {
    test('alias and verified are local and persist', () async {
      final db = MemoryDocStore();
      final alice = await makePeer(net, aliceWords, db: db);
      final bobPub = deriveIdentity(bobWords).publicKey;
      await alice.messages.send(bobPub, 'salut');
      expect(alice.messages.displayName(bobPub), usernameFor(bobPub));

      await alice.messages.setAlias(bobPub, '  Bob du boulot ');
      await alice.messages.setVerified(bobPub, true);
      expect(alice.messages.displayName(bobPub), 'Bob du boulot');

      final reopened = await makePeer(net, aliceWords, db: db);
      await until(() => reopened.messages.isVerified(bobPub));
      expect(reopened.messages.aliasOf(bobPub), 'Bob du boulot');
      // Nothing about the alias ever left the phone.
      expect(net.stored.any((w) => w.content.contains('boulot')), isFalse);

      await reopened.messages.setAlias(bobPub, '');
      expect(reopened.messages.displayName(bobPub), usernameFor(bobPub));
    });

    test('blocking forgets the alias', () async {
      final alice = await makePeer(net, aliceWords);
      final bobPub = deriveIdentity(bobWords).publicKey;
      await alice.messages.send(bobPub, 'salut');
      await alice.messages.setAlias(bobPub, 'Bob');
      await alice.messages.block(bobPub);
      expect(alice.messages.aliasOf(bobPub), isNull);
      expect(await alice.db.listDocs('contact_info'), isEmpty);
    });
  });

  group('pinned message', () {
    test('either side pins for both; latest pin or unpin wins', () async {
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      await alice.messages.send(bob.pubkey, 'à retenir');
      await until(() => bob.messages.requests.isNotEmpty);
      await bob.messages.accept(alice.pubkey);
      final id = alice.messages.messagesWith(bob.pubkey).single.id;

      await alice.messages.pin(bob.pubkey, id);
      expect(alice.messages.pinnedWith(bob.pubkey)?.id, id);
      await until(() => bob.messages.pinnedWith(alice.pubkey) != null);
      expect(bob.messages.pinnedWith(alice.pubkey)!.text, 'à retenir');

      await bob.messages.pin(alice.pubkey, null);
      await until(() => alice.messages.pinnedWith(bob.pubkey) == null);
      expect(bob.messages.pinnedWith(alice.pubkey), isNull);
    });

    test(
      'a stranger cannot pin anything, nor open a request by pinning',
      () async {
        final alice = await makePeer(net, aliceWords);
        final bob = await makePeer(net, bobWords);
        final rumor = Pin.rumor(
          sender: alice.pubkey,
          to: [bob.pubkey],
          messageId: 'ab' * 32,
        );
        await alice.transport.deliver(
          await Nip17.wrap(
            sender: alice.identity.identity!,
            recipientPubkey: bob.pubkey,
            rumor: rumor,
          ),
        );
        await quiet();
        expect(bob.messages.requests, isEmpty);
        expect(bob.messages.pinnedWith(alice.pubkey), isNull);
        // Pinning is only for accepted conversations.
        await bob.messages.pin(alice.pubkey, null);
        expect(net.stored, hasLength(1));
      },
    );

    test('offline pin goes out on retry; restore gets it back', () async {
      final alice = await makePeer(net, aliceWords);
      final bob = await makePeer(net, bobWords);
      await alice.messages.send(bob.pubkey, 'note');
      await until(() => bob.messages.requests.isNotEmpty);
      await bob.messages.accept(alice.pubkey);
      final id = alice.messages.messagesWith(bob.pubkey).single.id;

      net.down = true;
      await alice.messages.pin(bob.pubkey, id);
      net.down = false;
      await alice.messages.retryFailed();
      await until(() => bob.messages.pinnedWith(alice.pubkey) != null);

      final restored = await makePeer(net, aliceWords);
      restored.transport.replay();
      await until(() => restored.messages.pinnedWith(bob.pubkey) != null);
      expect(restored.messages.pinnedWith(bob.pubkey)!.id, id);
    });
  });

  test('reply: the quote reference arrives, and survives a retry', () async {
    final alice = await makePeer(net, aliceWords);
    final bob = await makePeer(net, bobWords);
    await alice.messages.send(bob.pubkey, 'on se voit quand ?');
    await until(() => bob.messages.requests.isNotEmpty);
    await bob.messages.accept(alice.pubkey);
    final question = bob.messages.messagesWith(alice.pubkey).single.id;

    net.down = true;
    await bob.messages.send(alice.pubkey, 'demain', replyTo: question);
    final failed = bob.messages.messagesWith(alice.pubkey).last;
    expect(failed.replyTo, question);
    net.down = false;
    await bob.messages.retry(failed.id);
    await until(() => alice.messages.messagesWith(bob.pubkey).length == 2);
    final answer = alice.messages.messagesWith(bob.pubkey).last;
    expect(answer.id, failed.id, reason: 'same rumor, reply included');
    expect(answer.replyTo, question);

    // A reply to a message of another conversation isn't one.
    await bob.messages.send(alice.pubkey, 'x', replyTo: 'ab' * 32);
    expect(bob.messages.messagesWith(alice.pubkey).last.replyTo, isNull);
  });

  test('read marks are local and per conversation', () async {
    final alice = await makePeer(net, aliceWords);
    expect(alice.messages.lastRead('dm:x'), isNull);
    await alice.messages.markRead('dm:x');
    expect(alice.messages.lastRead('dm:x'), isNotNull);
    expect(alice.messages.lastRead('group:x'), isNull);
    expect(net.stored, isEmpty, reason: 'nothing sent');
    final again = MessageStore(
      identity: alice.identity,
      db: alice.db,
      transport: alice.transport,
    );
    await until(() => again.loaded);
    expect(again.lastRead('dm:x'), alice.messages.lastRead('dm:x'));
    again.dispose();
  });
}
