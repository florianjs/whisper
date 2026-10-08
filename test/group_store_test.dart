import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart' show Nip01Event;
import 'package:whisper/data/group_store.dart';
import 'package:whisper/logic/group.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/nip17.dart';
import 'package:whisper/models/message.dart';

import 'package:whisper/logic/pin.dart';
import 'support/fake_network.dart';

class Member {
  Member(this.peer, this.groups);
  final Peer peer;
  final GroupStore groups;
  String get pubkey => peer.pubkey;
}

Future<Member> member(FakeNetwork net, String words) async {
  final p = await makePeer(net, words);
  final g = GroupStore(
    identity: p.identity,
    db: p.db,
    transport: p.transport,
    messages: p.messages,
  );
  await pumpEventQueue();
  return Member(p, g);
}

/// Makes [a] and [b] accepted contacts of each other.
Future<void> befriend(Member a, Member b) async {
  await a.peer.messages.send(b.pubkey, 'hi');
  await until(() => b.peer.messages.requests.isNotEmpty);
  await b.peer.messages.accept(a.pubkey);
  await until(() => a.peer.messages.isAccepted(b.pubkey));
}

Future<Nip01Event> wrapFor(Member from, String to, Nip01Event rumor) =>
    Nip17.wrap(
      sender: from.peer.identity.identity!,
      recipientPubkey: to,
      rumor: rumor,
    );

Nip01Event chatIn(String id, String author, List<String> to, String text) =>
    Nip01Event(
      pubKey: author,
      kind: Nip17.kindChat,
      tags: [
        for (final p in to) ['p', p],
        [GroupState.groupTag, id],
      ],
      content: text,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

void main() {
  late FakeNetwork net;
  late Member alice, bob, carol;

  setUp(() async {
    net = FakeNetwork();
    alice = await member(net, aliceWords);
    bob = await member(net, bobWords);
    carol = await member(net, generateMnemonic());
    await befriend(alice, bob);
  });

  test('members receive the group and each other\'s messages', () async {
    await befriend(alice, carol);
    final id = (await alice.groups.create('Famille', {
      bob.pubkey,
      carol.pubkey,
    }))!;
    await until(() => bob.groups.group(id) != null);
    await until(() => carol.groups.group(id) != null);
    expect(bob.groups.group(id)!.status, GroupStatus.active);
    expect(bob.groups.group(id)!.state.members, hasLength(3));

    await bob.groups.send(id, 'salut');
    await until(() => carol.groups.messagesIn(id).isNotEmpty);
    await until(() => alice.groups.messagesIn(id).isNotEmpty);
    final m = carol.groups.messagesIn(id).single;
    expect(m.text, 'salut');
    expect(m.peer, bob.pubkey);
    expect(bob.groups.messagesIn(id).single.status, MessageStatus.sent);
    // Groups never leak into 1:1 conversations.
    expect(carol.peer.messages.requests, isEmpty);
  });

  test('invitation from a stranger is pending until accepted', () async {
    final id = (await bob.groups.create('Inconnus', {carol.pubkey}))!;
    await until(() => carol.groups.group(id) != null);
    expect(carol.groups.group(id)!.status, GroupStatus.pending);
    expect(carol.peer.messages.requests, isEmpty);

    await carol.groups.accept(id);
    expect(carol.groups.group(id)!.status, GroupStatus.active);
  });

  test('refusing an invitation forgets it without telling anyone', () async {
    final id = (await bob.groups.create('Spam', {carol.pubkey}))!;
    await until(() => carol.groups.group(id) != null);
    final before = net.stored.length;
    await carol.groups.leave(id);
    expect(carol.groups.group(id), isNull);
    expect(net.stored.length, before, reason: 'no leave sent when pending');
  });

  test('non-members cannot post, and forged states are ignored', () async {
    await befriend(alice, carol);
    final id = (await alice.groups.create('Duo', {bob.pubkey}))!;
    await until(() => bob.groups.group(id) != null);

    // Carol learns the id somehow and tries to post and to take over.
    final forgedState = GroupState(
      id: id,
      name: 'Pwned',
      admin: carol.pubkey,
      members: {carol.pubkey, bob.pubkey},
      version: 99,
    );
    await carol.peer.transport.deliver(
      await wrapFor(
        carol,
        bob.pubkey,
        forgedState.toRumor(recipient: bob.pubkey),
      ),
    );
    await carol.peer.transport.deliver(
      await wrapFor(
        carol,
        bob.pubkey,
        chatIn(id, carol.pubkey, [bob.pubkey], 'intrus'),
      ),
    );
    await quiet();
    expect(bob.groups.group(id)!.state.name, 'Duo');
    expect(bob.groups.messagesIn(id), isEmpty);
  });

  test('admin removes a member; they become read-only', () async {
    await befriend(alice, carol);
    final id = (await alice.groups.create('Trio', {bob.pubkey, carol.pubkey}))!;
    await until(() => carol.groups.group(id) != null);

    await alice.groups.removeMember(id, carol.pubkey);
    await until(() => carol.groups.group(id)!.status == GroupStatus.removed);
    await until(() => bob.groups.group(id)!.state.members.length == 2);

    await carol.groups.send(id, 'encore là ?');
    await alice.groups.send(id, 'sans carol');
    await until(() => bob.groups.messagesIn(id).isNotEmpty);
    await quiet();
    expect(carol.groups.messagesIn(id), isEmpty);
    expect(bob.groups.messagesIn(id).map((m) => m.text), ['sans carol']);
  });

  test('a member leaving is removed by the admin for everyone', () async {
    await befriend(alice, carol);
    final id = (await alice.groups.create('Trio', {bob.pubkey, carol.pubkey}))!;
    await until(() => carol.groups.group(id) != null);
    await until(() => bob.groups.group(id) != null);

    await carol.groups.leave(id);
    expect(carol.groups.group(id), isNull);
    await until(
      () => !alice.groups.group(id)!.state.members.contains(carol.pubkey),
    );
    await until(() => bob.groups.group(id)!.state.members.length == 2);
  });

  test('messages arriving before the state are kept and replayed', () async {
    final id = (await alice.groups.create('Ordre', {bob.pubkey}))!;
    await until(() => bob.groups.group(id) != null);
    await alice.groups.send(id, 'premier');
    await until(() => bob.groups.messagesIn(id).isNotEmpty);

    // Fresh device for Bob, relays hand back the chat before the state.
    final bob2 = await member(FakeNetwork(), bobWords);
    final wraps = net.stored
        .where((w) => w.tags.any((t) => t[0] == 'p' && t[1] == bob.pubkey))
        .toList()
        .reversed;
    for (final w in wraps) {
      bob2.peer.transport.push(w);
    }
    await until(() => bob2.groups.messagesIn(id).isNotEmpty);
    expect(bob2.groups.messagesIn(id).single.text, 'premier');
  });

  test('rename bumps the version everywhere', () async {
    final id = (await alice.groups.create('Old', {bob.pubkey}))!;
    await until(() => bob.groups.group(id) != null);
    await alice.groups.rename(id, 'New');
    await until(() => bob.groups.group(id)!.state.name == 'New');
    expect(bob.groups.group(id)!.state.version, 2);

    // Only the admin can rename.
    await bob.groups.rename(id, 'Mine');
    expect(bob.groups.group(id)!.state.name, 'New');
  });

  test('groups survive a restart', () async {
    final id = (await alice.groups.create('Persist', {bob.pubkey}))!;
    await alice.groups.send(id, 'hello');
    final again = GroupStore(
      identity: alice.peer.identity,
      db: alice.peer.db,
      transport: alice.peer.transport,
      messages: alice.peer.messages,
    );
    await until(() => again.loaded);
    expect(again.group(id)!.state.name, 'Persist');
    expect(again.messagesIn(id).single.text, 'hello');
    again.dispose();
  });

  test('limits: 20 members max, need at least one other', () async {
    expect(await alice.groups.create('Solo', {}), isNull);
    final many = {
      for (var i = 1; i <= 20; i++) i.toRadixString(16).padLeft(64, '0'),
    };
    expect(await alice.groups.create('Foule', many), isNull);
  });

  test('early-message buffer is bounded for unknown groups', () async {
    // 40 bogus group ids, then the real state + message: must still work.
    for (var i = 0; i < 40; i++) {
      await bob.peer.transport.deliver(
        await wrapFor(
          bob,
          alice.pubkey,
          chatIn(GroupState.newId(), bob.pubkey, [alice.pubkey], 'x'),
        ),
      );
    }
    final id = (await alice.groups.create('Réel', {bob.pubkey}))!;
    await until(() => bob.groups.group(id) != null);
    await bob.groups.send(id, 'ok');
    await until(() => alice.groups.messagesIn(id).isNotEmpty);
  });

  test('invitation sent while offline goes out when back online', () async {
    net.down = true;
    final id = (await alice.groups.create('Hors ligne', {bob.pubkey}))!;
    await until(() => alice.groups.group(id)!.unsent.isNotEmpty);
    expect(alice.groups.group(id)!.unsent, {bob.pubkey});

    net.down = false;
    await alice.groups.retryFailed();
    await until(() => bob.groups.group(id) != null);
    expect(alice.groups.group(id)!.unsent, isEmpty);
  });

  test('only the admin pins, for every member', () async {
    await befriend(alice, carol);
    final id = (await alice.groups.create('Famille', {
      bob.pubkey,
      carol.pubkey,
    }))!;
    await until(() => bob.groups.group(id) != null);
    await until(() => carol.groups.group(id) != null);
    await bob.groups.send(id, 'rendez-vous à 8h');
    await until(() => alice.groups.messagesIn(id).isNotEmpty);
    await until(() => carol.groups.messagesIn(id).isNotEmpty);
    final msg = alice.groups.messagesIn(id).single.id;

    await alice.groups.pin(id, msg);
    await until(() => carol.groups.pinnedIn(id) != null);
    await until(() => bob.groups.pinnedIn(id) != null);
    expect(carol.groups.pinnedIn(id)!.text, 'rendez-vous à 8h');

    // A member can't: not through the store, nor with a crafted rumor.
    await bob.groups.pin(id, null);
    final forged = Pin.rumor(
      sender: bob.pubkey,
      to: [carol.pubkey],
      messageId: null,
      extraTags: [
        [GroupState.groupTag, id],
      ],
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60,
    );
    await bob.peer.transport.deliver(await wrapFor(bob, carol.pubkey, forged));
    await quiet();
    expect(carol.groups.pinnedIn(id)?.id, msg);
    expect(carol.peer.messages.requests, isEmpty);

    await alice.groups.pin(id, null);
    await until(() => carol.groups.pinnedIn(id) == null);
  });

  group('photos and replies', () {
    late String id;

    setUp(() async {
      await befriend(alice, carol);
      id = (await alice.groups.create('Famille', {bob.pubkey, carol.pubkey}))!;
      await until(() => bob.groups.group(id) != null);
      await until(() => carol.groups.group(id) != null);
    });

    test('a photo reaches every member, intact', () async {
      final bytes = Uint8List.fromList(
        List.generate(30000, (i) => i * 7 % 256),
      );
      await bob.groups.sendImage(id, (bytes: bytes, width: 40, height: 30));
      final sent = bob.groups.messagesIn(id).single;
      expect(sent.status, MessageStatus.sent);
      expect(sent.image!.chunks, 3);

      for (final m in [alice, carol]) {
        await until(
          () =>
              m.groups.messagesIn(id).singleOrNull?.status ==
              MessageStatus.received,
        );
        final got = m.groups.messagesIn(id).single;
        expect(got.peer, bob.pubkey);
        expect(await m.peer.messages.imageFor(got), bytes);
      }
      // Carol and Bob aren't contacts: still no 1:1 request.
      expect(carol.peer.messages.requests, isEmpty);
    });

    test('offline photo fails, then retry sends the same message', () async {
      final bytes = Uint8List.fromList(List.filled(5000, 3));
      net.down = true;
      await alice.groups.sendImage(id, (bytes: bytes, width: 1, height: 1));
      final m = alice.groups.messagesIn(id).single;
      expect(m.status, MessageStatus.failed);
      net.down = false;
      await alice.groups.retry(m.id);
      expect(alice.groups.messagesIn(id).single.status, MessageStatus.sent);
      await until(() => carol.groups.messagesIn(id).isNotEmpty);
      expect(carol.groups.messagesIn(id).single.id, m.id);
    });

    test('a pending invitation stores no photo', () async {
      final dave = await member(net, generateMnemonic());
      final other = (await bob.groups.create('Inconnus', {dave.pubkey}))!;
      await until(() => dave.groups.group(other) != null);
      expect(dave.groups.group(other)!.status, GroupStatus.pending);
      await bob.groups.sendImage(other, (
        bytes: Uint8List.fromList(List.filled(100, 1)),
        width: 1,
        height: 1,
      ));
      await until(() => dave.groups.messagesIn(other).isNotEmpty);
      await quiet();
      final m = dave.groups.messagesIn(other).single;
      expect(m.status, MessageStatus.receiving);
      expect(await dave.peer.messages.imageFor(m), isNull);
    });

    test('replies carry the quoted message', () async {
      await alice.groups.send(id, 'qui vient samedi ?');
      await until(() => bob.groups.messagesIn(id).isNotEmpty);
      final q = bob.groups.messagesIn(id).single.id;
      await bob.groups.send(id, 'moi', replyTo: q);
      await until(() => carol.groups.messagesIn(id).length == 2);
      expect(carol.groups.messagesIn(id).last.replyTo, q);
    });
  });
}
