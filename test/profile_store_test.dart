import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/data/db.dart';
import 'package:whisper/data/key_vault.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/data/message_store.dart';
import 'package:whisper/data/identity_store.dart';
import 'package:whisper/data/profile_store.dart';
import 'package:whisper/logic/photo.dart';

import 'support/fake_network.dart';

/// Delays reads, like a real encrypted DB on a phone.
class SlowDocStore implements DocStore {
  SlowDocStore(this.inner);
  final DocStore inner;
  static const _delay = Duration(milliseconds: 300);

  @override
  Future<Map<String, dynamic>?> getDoc(String c, String id) async {
    await Future<void>.delayed(_delay);
    return inner.getDoc(c, id);
  }

  @override
  Future<List<Map<String, dynamic>>> listDocs(String c) async {
    await Future<void>.delayed(_delay);
    return inner.listDocs(c);
  }

  @override
  Future<void> putDoc(String c, Map<String, dynamic> doc, {int? updatedAt}) =>
      inner.putDoc(c, doc, updatedAt: updatedAt);

  @override
  Future<void> deleteDoc(String c, String id) => inner.deleteDoc(c, id);

  @override
  Future<void> destroy() => inner.destroy();
}

class P {
  P(this.peer, this.profile);
  final Peer peer;
  final ProfileStore profile;
  String get pubkey => peer.pubkey;
}

Future<P> makeProfilePeer(
  FakeNetwork net,
  String words, {
  MemoryDocStore? db,
  MemoryKeyVault? vault,
}) async {
  final peer = await makePeer(net, words, db: db, vault: vault);
  final profile = ProfileStore(
    identity: peer.identity,
    db: peer.db,
    transport: peer.transport,
    messages: peer.messages,
    // The real pipeline is covered by photo_test; keep bytes as-is here.
    processPhoto: (raw) async => raw,
  );
  await pumpEventQueue();
  return P(peer, profile);
}

Uint8List photo(int seed) =>
    Uint8List.fromList(List.generate(300, (i) => (i * seed) % 256));

int cardsOnNetwork(FakeNetwork net) => net.stored.length;

/// Alice and Bob who both accepted each other (Bob wrote, Alice replied).
Future<(P, P)> friends(FakeNetwork net) async {
  final alice = await makeProfilePeer(net, aliceWords);
  final bob = await makeProfilePeer(net, bobWords);
  await bob.peer.messages.send(alice.pubkey, 'salut');
  await until(() => alice.peer.messages.requests.isNotEmpty);
  await alice.peer.messages.send(bob.pubkey, 'salut toi');
  await until(() => bob.peer.messages.messagesWith(alice.pubkey).length == 2);
  return (alice, bob);
}

void main() {
  late FakeNetwork net;
  setUp(() => net = FakeNetwork());

  test('photo reaches an accepted contact and is cached there', () async {
    final (alice, bob) = await friends(net);
    await alice.profile.setPhoto(photo(3));
    await until(() => bob.profile.photoOf(alice.pubkey) != null);

    expect(bob.profile.photoOf(alice.pubkey), photo(3));
    expect(await bob.peer.db.listDocs('avatars'), hasLength(1));
    expect(alice.profile.photoOf(alice.pubkey), photo(3));
  });

  test('never sent to a pending contact', () async {
    final alice = await makeProfilePeer(net, aliceWords);
    final bob = await makeProfilePeer(net, bobWords);
    await alice.profile.setPhoto(photo(5));

    // Bob writes first: Alice has him pending and doesn't answer.
    await bob.peer.messages.send(alice.pubkey, 'salut');
    await until(() => alice.peer.messages.requests.isNotEmpty);
    await quiet();

    expect(bob.profile.photoOf(alice.pubkey), isNull);
    expect(await bob.peer.db.listDocs('avatars'), isEmpty);

    // Accepting sends it.
    await alice.peer.messages.accept(bob.pubkey);
    await until(() => bob.profile.photoOf(alice.pubkey) != null);
    expect(bob.profile.photoOf(alice.pubkey), photo(5));
  });

  test('pending sender\'s photo is kept but only shown after accept', () async {
    final alice = await makeProfilePeer(net, aliceWords);
    final bob = await makeProfilePeer(net, bobWords);
    await bob.profile.setPhoto(photo(7));
    // Bob starts the chat → accepted on his side → his card goes out.
    await bob.peer.messages.send(alice.pubkey, 'coucou');
    await until(() => alice.peer.messages.requests.isNotEmpty);
    await until(() => alice.peer.db.values('avatars').isNotEmpty);

    expect(alice.profile.photoOf(bob.pubkey), isNull, reason: 'pending');
    await alice.peer.messages.accept(bob.pubkey);
    expect(alice.profile.photoOf(bob.pubkey), photo(7));
  });

  test('unchanged photo is not re-sent', () async {
    final (alice, bob) = await friends(net);
    await alice.profile.setPhoto(photo(3));
    await until(() => bob.profile.photoOf(alice.pubkey) != null);
    final before = cardsOnNetwork(net);

    // Lots of activity, same photo.
    await alice.peer.messages.send(bob.pubkey, 'un');
    await alice.peer.messages.send(bob.pubkey, 'deux');
    alice.profile.retry();
    await quiet();
    // Only the chat messages (+ self-copies) were added.
    expect(cardsOnNetwork(net) - before, 4);
  });

  test('changing the photo updates contacts; removing deletes it', () async {
    final (alice, bob) = await friends(net);
    await alice.profile.setPhoto(photo(3));
    await until(() => bob.profile.photoOf(alice.pubkey) != null);

    await alice.profile.setPhoto(photo(9));
    await until(() => bob.profile.photoOf(alice.pubkey)?[1] == photo(9)[1]);
    expect(bob.profile.photoOf(alice.pubkey), photo(9));

    await alice.profile.removePhoto();
    await until(() => bob.profile.photoOf(alice.pubkey) == null);
  });

  test('older card versions are ignored (replayed relays)', () async {
    final (alice, bob) = await friends(net);
    await alice.profile.setPhoto(photo(3));
    await until(() => bob.profile.photoOf(alice.pubkey) != null);
    await alice.profile.setPhoto(photo(9));
    await until(() => bob.profile.photoOf(alice.pubkey)?[1] == photo(9)[1]);

    bob.peer.transport.replay(); // v1 arrives again
    await quiet();
    expect(bob.profile.photoOf(alice.pubkey), photo(9));
  });

  test('blocked contact\'s card is dropped', () async {
    final alice = await makeProfilePeer(net, aliceWords);
    final bob = await makeProfilePeer(net, bobWords);
    await bob.peer.messages.send(alice.pubkey, 'salut');
    await until(() => alice.peer.messages.requests.isNotEmpty);
    await alice.peer.messages.block(bob.pubkey);

    await bob.profile.setPhoto(photo(4));
    await quiet();
    expect(await alice.peer.db.listDocs('avatars'), isEmpty);
  });

  test('accepting someone whose card I missed asks for it', () async {
    final alice = await makeProfilePeer(net, aliceWords);
    final bob = await makeProfilePeer(net, bobWords);
    // Bob's card went out before Alice had any contact state for him, so
    // she dropped it (strangers can't make her store anything).
    await bob.profile.setPhoto(photo(6));
    await bob.peer.messages.accept(alice.pubkey);
    await quiet();
    expect(await alice.peer.db.listDocs('avatars'), isEmpty);

    await alice.peer.messages.accept(bob.pubkey);
    await until(() => alice.profile.photoOf(bob.pubkey) != null);
    expect(alice.profile.photoOf(bob.pubkey), photo(6));
  });

  test('panic: photos cleared from memory, nothing written after', () async {
    final vault = MemoryKeyVault();
    final alice = await makeProfilePeer(net, aliceWords, vault: vault);
    final bob = await makeProfilePeer(net, bobWords);
    await alice.peer.messages.send(bob.pubkey, 'salut');
    await bob.peer.messages.send(alice.pubkey, 'salut');
    await bob.profile.setPhoto(photo(2));
    await until(() => alice.profile.photoOf(bob.pubkey) != null);

    await alice.peer.db.destroy();
    await alice.peer.identity.wipe();
    await bob.profile.setPhoto(photo(8));
    await quiet();

    expect(alice.profile.photoOf(bob.pubkey), isNull);
    expect(await alice.peer.db.listDocs('avatars'), isEmpty);
    expect(await alice.peer.db.listDocs('profile'), isEmpty);
  });

  test('max-size photo passes through a real wrap', () async {
    final (alice, bob) = await friends(net);
    await alice.profile.setPhoto(Uint8List(maxPhotoBytes));
    await until(() => bob.profile.photoOf(alice.pubkey) != null);
    expect(bob.profile.photoOf(alice.pubkey)!.length, maxPhotoBytes);
  });

  test('refusing a request also deletes their photo', () async {
    final alice = await makeProfilePeer(net, aliceWords);
    final bob = await makeProfilePeer(net, bobWords);
    await bob.profile.setPhoto(photo(7));
    await bob.peer.messages.send(alice.pubkey, 'coucou');
    await until(() => alice.peer.db.values('avatars').isNotEmpty);

    await alice.peer.messages.refuse(bob.pubkey);
    await until(() => alice.peer.db.values('avatars').isEmpty);
  });

  test('restart: nothing is re-sent before state is loaded', () async {
    final db = MemoryDocStore();
    final vault = MemoryKeyVault();
    final alice = await makeProfilePeer(net, aliceWords, db: db, vault: vault);
    final bob = await makeProfilePeer(net, bobWords);
    await bob.peer.messages.send(alice.pubkey, 'salut');
    await until(() => alice.peer.messages.requests.isNotEmpty);
    await alice.peer.messages.send(bob.pubkey, 'salut');
    await alice.profile.setPhoto(photo(3));
    await until(() => bob.profile.photoOf(alice.pubkey) != null);
    await quiet();
    final before = net.stored.length;

    // App restart: same DB and vault, fresh stores. Reads are slow like
    // SQLCipher on a phone, so MessageStore finishes loading first.
    alice.profile.dispose();
    alice.peer.messages.dispose();
    // Built together, as in main.dart (not via makePeer, which waits for
    // MessageStore to finish loading first).
    final identity = IdentityStore(
      vault,
      derive: (m) async => deriveIdentity(m),
    );
    await identity.hydrate();
    final transport = net.transportFor(identity.identity!.publicKey);
    final messages = MessageStore(
      identity: identity,
      db: db,
      transport: transport,
    );
    ProfileStore(
      identity: identity,
      db: SlowDocStore(db),
      transport: transport,
      messages: messages,
      processPhoto: (raw) async => raw,
    );
    await quiet();
    expect(net.stored.length, before, reason: 'no card re-sent on launch');
  });

  test('photo changed while a card is in flight still goes out', () async {
    final (alice, bob) = await friends(net);
    // Two quick changes: the second happens while the first is being sent.
    final first = alice.profile.setPhoto(photo(3));
    await alice.profile.setPhoto(photo(9));
    await first;
    await until(() => bob.profile.photoOf(alice.pubkey)?[1] == photo(9)[1]);
    expect(bob.profile.photoOf(alice.pubkey), photo(9));
  });

  group('nicknames', () {
    test(
      'reaches an accepted contact and becomes their display name',
      () async {
        final (alice, bob) = await friends(net);
        await alice.profile.setName('  Alice   la brave ');
        expect(alice.profile.myName, 'Alice la brave');
        await until(() => bob.peer.messages.nicknameOf(alice.pubkey) != null);

        expect(bob.peer.messages.displayName(alice.pubkey), 'Alice la brave');
        expect(
          (await bob.peer.db.listDocs('avatars')).single['name'],
          'Alice la brave',
        );
      },
    );

    test('my own alias for them wins over their nickname', () async {
      final (alice, bob) = await friends(net);
      await alice.profile.setName('Alice');
      await until(() => bob.peer.messages.nicknameOf(alice.pubkey) != null);
      await bob.peer.messages.setAlias(alice.pubkey, 'Maman');
      expect(bob.peer.messages.displayName(alice.pubkey), 'Maman');
      await bob.peer.messages.setAlias(alice.pubkey, null);
      expect(bob.peer.messages.displayName(alice.pubkey), 'Alice');
    });

    test('a stranger\'s nickname is not shown until accepted', () async {
      final alice = await makeProfilePeer(net, aliceWords);
      final bob = await makeProfilePeer(net, bobWords);
      await bob.profile.setName('Your Bank');
      await bob.peer.messages.send(alice.pubkey, 'coucou');
      await until(() => alice.peer.messages.requests.isNotEmpty);
      await until(() => alice.peer.db.values('avatars').isNotEmpty);

      expect(
        alice.peer.messages.displayName(bob.pubkey),
        usernameFor(bob.pubkey),
        reason: 'pending: derived name only',
      );
      await alice.peer.messages.accept(bob.pubkey);
      expect(alice.peer.messages.displayName(bob.pubkey), 'Your Bank');
    });

    test('never sent to a pending contact', () async {
      final alice = await makeProfilePeer(net, aliceWords);
      final bob = await makeProfilePeer(net, bobWords);
      await alice.profile.setName('Alice');
      await bob.peer.messages.send(alice.pubkey, 'salut');
      await until(() => alice.peer.messages.requests.isNotEmpty);
      await quiet();
      expect(bob.peer.messages.nicknameOf(alice.pubkey), isNull);
      expect(await bob.peer.db.listDocs('avatars'), isEmpty);
    });

    test('clearing it goes back to the derived name, photo kept', () async {
      final (alice, bob) = await friends(net);
      await alice.profile.setPhoto(photo(3));
      await alice.profile.setName('Alice');
      await until(() => bob.peer.messages.nicknameOf(alice.pubkey) != null);
      await alice.profile.setName('   ');
      await until(() => bob.peer.messages.nicknameOf(alice.pubkey) == null);
      expect(alice.profile.myName, isNull);
      expect(
        bob.peer.messages.displayName(alice.pubkey),
        usernameFor(alice.pubkey),
      );
      expect(bob.profile.photoOf(alice.pubkey), photo(3));
    });

    test('same name again sends nothing', () async {
      final (alice, bob) = await friends(net);
      await alice.profile.setName('Alice');
      await until(() => bob.peer.messages.nicknameOf(alice.pubkey) != null);
      await quiet();
      final before = net.stored.length;
      await alice.profile.setName(' Alice ');
      await quiet();
      expect(net.stored.length, before);
    });

    test('blocking them forgets their nickname', () async {
      final (alice, bob) = await friends(net);
      await bob.profile.setName('Bob');
      await until(() => alice.peer.messages.nicknameOf(bob.pubkey) != null);
      await alice.peer.messages.block(bob.pubkey);
      await quiet();
      expect(alice.peer.messages.nicknameOf(bob.pubkey), isNull);
      expect(await alice.peer.db.listDocs('avatars'), isEmpty);
    });

    test('survives a restart on both sides', () async {
      final aliceDb = MemoryDocStore();
      final aliceVault = MemoryKeyVault();
      final alice = await makeProfilePeer(
        net,
        aliceWords,
        db: aliceDb,
        vault: aliceVault,
      );
      final bob = await makeProfilePeer(net, bobWords);
      await bob.peer.messages.send(alice.pubkey, 'salut');
      await until(() => alice.peer.messages.requests.isNotEmpty);
      await alice.peer.messages.send(bob.pubkey, 'salut');
      await alice.profile.setName('Alice');
      await bob.profile.setName('Bob');
      await until(() => alice.peer.messages.nicknameOf(bob.pubkey) != null);

      alice.profile.dispose();
      alice.peer.messages.dispose();
      final again = await makeProfilePeer(
        net,
        aliceWords,
        db: aliceDb,
        vault: aliceVault,
      );
      await until(() => again.profile.myName != null);
      expect(again.profile.myName, 'Alice');
      await until(() => again.peer.messages.nicknameOf(bob.pubkey) != null);
      expect(again.peer.messages.displayName(bob.pubkey), 'Bob');
    });
  });
}
