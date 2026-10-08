import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart' show Bip340EventVerifier, Nip01Event;
import 'package:whisper/data/channel_store.dart';
import 'package:whisper/data/db.dart';
import 'package:whisper/logic/channel.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/nip17.dart';

import 'support/fake_network.dart';

class Viewer {
  Viewer(this.peer, this.channels, this.transport);
  final Peer peer;
  final ChannelStore channels;
  final FakeChannelTransport transport;
  String get pubkey => peer.pubkey;
}

Future<Viewer> viewer(
  FakeNetwork net,
  String words, {
  MemoryDocStore? db,
}) async {
  final p = await makePeer(net, words, db: db);
  final t = net.channelTransport();
  final c = ChannelStore(
    identity: p.identity,
    db: p.db,
    transport: t,
    giftTransport: p.transport,
    messages: p.messages,
  );
  await until(() => c.loaded);
  return Viewer(p, c, t);
}

Future<void> befriend(Viewer a, Viewer b) async {
  await a.peer.messages.send(b.pubkey, 'hi');
  await until(() => b.peer.messages.requests.isNotEmpty);
  await b.peer.messages.accept(a.pubkey);
  await until(() => a.peer.messages.isAccepted(b.pubkey));
}

void main() {
  setUpAll(() => Nip17.verifier = Bip340EventVerifier(useIsolate: false));

  late FakeNetwork net;
  late Viewer admin, bob, carol;

  setUp(() async {
    net = FakeNetwork();
    admin = await viewer(net, aliceWords);
    bob = await viewer(net, bobWords);
    carol = await viewer(net, generateMnemonic());
  });

  Future<String> makeChannel({bool public = true}) async =>
      (await admin.channels.create(
        name: 'Infos',
        public: public,
        relays: const ['wss://r.example'],
      ))!;

  test('followers get posts; relays only see ciphertext', () async {
    final pk = await makeChannel();
    await admin.channels.post(pk, 'premier');
    final code = admin.channels.channel(pk)!.invite.encode();

    await bob.channels.join(ChannelInvite.parse(code)!);
    await until(() => bob.channels.postsIn(pk).isNotEmpty);
    expect(bob.channels.postsIn(pk).single.text, 'premier');
    expect(bob.channels.channel(pk)!.meta.name, 'Infos');

    await admin.channels.post(pk, 'second');
    await until(() => bob.channels.postsIn(pk).length == 2);
    expect(admin.channels.postsIn(pk).map((p) => p.status), [
      PostStatus.sent,
      PostStatus.sent,
    ]);
    for (final e in net.channelStored) {
      expect(e.content, isNot(contains('premier')));
      expect(e.content, isNot(contains('Infos')));
    }
  });

  test('viewers cannot post; forged posts are ignored', () async {
    final pk = await makeChannel();
    final invite = admin.channels.channel(pk)!.invite;
    await bob.channels.join(invite);
    await carol.channels.join(invite);

    await bob.channels.post(pk, 'je poste');
    expect(bob.channels.postsIn(pk), isEmpty);

    // Bob knows the content key and signs a post with his own key,
    // claiming to be the channel: signature check fails.
    final bobId = bob.peer.identity.identity!;
    final forged = Nip01Event(
      pubKey: pk,
      kind: Channel.kindPost,
      tags: const [],
      content: await encryptFor(invite.contentKey, pk, Channel.kindPost, {
        't': 'faux',
      }),
      createdAt: 1700000000,
      sig: 'ab' * 64,
    );
    await bob.transport.publishChannelEvent(forged);
    // Or signs with his key and his pubkey: not the channel's author.
    final own = await signPost(
      ChannelKeys(
        privateKey: bobId.privateKey,
        publicKey: bobId.publicKey,
        contentKey: invite.contentKey,
      ),
      'faux 2',
    );
    await bob.transport.publishChannelEvent(own);
    await quiet();
    expect(carol.channels.postsIn(pk), isEmpty);
  });

  test(
    'reactions aggregate, latest per viewer wins, same emoji retracts',
    () async {
      final pk = await makeChannel();
      await admin.channels.post(pk, 'sondage');
      final invite = admin.channels.channel(pk)!.invite;
      await bob.channels.join(invite);
      await carol.channels.join(invite);
      await until(() => carol.channels.postsIn(pk).isNotEmpty);
      await until(() => bob.channels.postsIn(pk).isNotEmpty);
      final post = admin.channels.postsIn(pk).single.id;

      await bob.channels.react(pk, post, '❤️');
      await carol.channels.react(pk, post, '❤️');
      await until(() => admin.channels.reactionsOf(post)['❤️'] == 2);

      await bob.channels.react(pk, post, '👍');
      await until(() => admin.channels.reactionsOf(post)['👍'] == 1);
      expect(admin.channels.reactionsOf(post), {'❤️': 1, '👍': 1});
      await until(() => carol.channels.reactionsOf(post)['👍'] == 1);

      await bob.channels.react(pk, post, '👍'); // toggle off
      await until(() => admin.channels.reactionsOf(post)['👍'] == null);
      expect(bob.channels.myReactionOn(pk, post), isNull);
      expect(carol.channels.myReactionOn(pk, post), '❤️');

      // Nobody's identity appears on a reaction.
      final reactors = net.channelStored
          .where((e) => e.kind == Channel.kindReaction)
          .map((e) => e.pubKey)
          .toSet();
      expect(reactors, hasLength(2));
      expect(reactors.contains(bob.pubkey), isFalse);
      expect(reactors.contains(carol.pubkey), isFalse);
    },
  );

  test('free-form or foreign reactions are dropped', () async {
    final pk = await makeChannel();
    await admin.channels.post(pk, 'x');
    final c = admin.channels.channel(pk)!;
    final post = admin.channels.postsIn(pk).single.id;
    final key = await reactionKey(bob.peer.identity.identity!, pk);
    final spam = await signReaction(
      key: key,
      channelPk: pk,
      contentKey: c.contentKey,
      postId: post,
      emoji: 'buy my stuff',
    );
    await bob.transport.publishChannelEvent(spam);
    await quiet();
    expect(admin.channels.reactionsOf(post), isEmpty);
  });

  test('private invite reaches accepted contacts only', () async {
    await befriend(admin, bob);
    final pk = await makeChannel(public: false);
    await admin.channels.inviteContacts(pk, {bob.pubkey, carol.pubkey});
    await until(() => bob.channels.channel(pk) != null);
    expect(bob.channels.channel(pk)!.status, ChannelStatus.pending);
    expect(bob.channels.channel(pk)!.meta.public, isFalse);
    await quiet();
    expect(carol.channels.channel(pk), isNull, reason: 'not a contact');

    await admin.channels.post(pk, 'secret');
    await quiet();
    expect(bob.channels.postsIn(pk), isEmpty, reason: 'not accepted yet');
    await bob.channels.accept(pk);
    await until(() => bob.channels.postsIn(pk).isNotEmpty);
  });

  test('leaving forgets everything locally and sends nothing', () async {
    final pk = await makeChannel();
    await admin.channels.post(pk, 'x');
    await bob.channels.join(admin.channels.channel(pk)!.invite);
    await until(() => bob.channels.postsIn(pk).isNotEmpty);
    final before = net.channelStored.length;
    await bob.channels.leave(pk);
    expect(bob.channels.channel(pk), isNull);
    expect(bob.channels.postsIn(pk), isEmpty);
    expect(await bob.peer.db.listDocs('channel_posts'), isEmpty);
    expect(net.channelStored.length, before);
    expect(bob.transport.watched.contains(pk), isFalse);
  });

  test('admin restoring the account gets its channel back', () async {
    final pk = await makeChannel();
    await admin.channels.post(pk, 'avant');
    await until(() => admin.channels.channel(pk)!.metaUnsent == false);

    final fresh = await viewer(net, aliceWords); // new phone, same seed
    await until(() => fresh.channels.channel(pk) != null);
    final c = fresh.channels.channel(pk)!;
    expect(c.mine, isTrue);
    expect(c.meta.name, 'Infos');
    await until(() => fresh.channels.postsIn(pk).isNotEmpty);
    await fresh.channels.post(pk, 'après');
    expect(fresh.channels.postsIn(pk).last.status, PostStatus.sent);

    // Next channel doesn't reuse the restored slot.
    final other = (await fresh.channels.create(
      name: 'Autre',
      public: true,
      relays: const [],
    ))!;
    expect(other, isNot(pk));
  });

  test('offline post fails, then goes out on retry with the same id', () async {
    final pk = await makeChannel();
    net.down = true;
    await admin.channels.post(pk, 'plus tard');
    final p = admin.channels.postsIn(pk).single;
    expect(p.status, PostStatus.failed);

    net.down = false;
    await admin.channels.retryFailed();
    expect(admin.channels.postsIn(pk).single.status, PostStatus.sent);
    expect(net.channelStored.any((e) => e.id == p.id), isTrue);
  });

  test('persists across restart', () async {
    final pk = await makeChannel();
    await admin.channels.post(pk, 'x');
    final again = ChannelStore(
      identity: admin.peer.identity,
      db: admin.peer.db,
      transport: net.channelTransport(),
      giftTransport: admin.peer.transport,
      messages: admin.peer.messages,
    );
    await until(() => again.loaded);
    expect(again.channel(pk)!.mine, isTrue);
    expect(again.postsIn(pk).single.text, 'x');
    again.dispose();
  });

  group('editing', () {
    test('followers get the new text, marked edited', () async {
      final pk = await makeChannel();
      await admin.channels.post(pk, 'premeir');
      await bob.channels.join(admin.channels.channel(pk)!.invite);
      await until(() => bob.channels.postsIn(pk).isNotEmpty);
      final id = admin.channels.postsIn(pk).single.id;

      await admin.channels.edit(id, 'premier');
      expect(admin.channels.postsIn(pk).single.text, 'premier');
      expect(admin.channels.postsIn(pk).single.editUnsent, isFalse);
      await until(() => bob.channels.postsIn(pk).single.edited);
      final seen = bob.channels.postsIn(pk).single;
      expect(seen.text, 'premier');
      expect(seen.id, id, reason: 'same post, reactions stay on it');
      for (final e in net.channelStored) {
        expect(e.content, isNot(contains('premier')));
      }
    });

    test('latest edit wins, whatever order relays send them in', () async {
      final pk = await makeChannel();
      await admin.channels.post(pk, 'v1');
      final id = admin.channels.postsIn(pk).single.id;
      await admin.channels.edit(id, 'v2');
      await admin.channels.edit(id, 'v3');
      // Newest first for a late follower: v2 must not undo v3.
      net.channelStored.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      await bob.channels.join(admin.channels.channel(pk)!.invite);
      await until(() => bob.channels.postsIn(pk).isNotEmpty);
      await until(() => bob.channels.postsIn(pk).single.text == 'v3');
      await quiet();
      expect(bob.channels.postsIn(pk).single.text, 'v3');
    });

    test('only the admin edits, and only posts of that channel', () async {
      final pk = await makeChannel();
      final other = (await admin.channels.create(
        name: 'Autre',
        public: true,
        relays: const [],
      ))!;
      await admin.channels.post(pk, 'ici');
      await admin.channels.post(other, 'là-bas');
      final otherPost = admin.channels.postsIn(other).single.id;
      await bob.channels.join(admin.channels.channel(pk)!.invite);
      await until(() => bob.channels.postsIn(pk).isNotEmpty);

      // Bob can't edit: not his channel.
      await bob.channels.edit(bob.channels.postsIn(pk).single.id, 'pirate');
      // An edit from the other channel naming this channel's post.
      final otherKeys = await ChannelKeys.derive(deriveIdentity(aliceWords), 1);
      await admin.transport.publishChannelEvent(
        await signEdit(otherKeys, bob.channels.postsIn(pk).single.id, 'x'),
      );
      // And the reverse: this channel's key on the other channel's post.
      final keys = await ChannelKeys.derive(deriveIdentity(aliceWords), 0);
      await admin.transport.publishChannelEvent(
        await signEdit(keys, otherPost, 'y'),
      );
      await quiet();
      expect(bob.channels.postsIn(pk).single.text, 'ici');
      expect(bob.channels.postsIn(pk).single.edited, isFalse);
      expect(admin.channels.postsIn(other).single.text, 'là-bas');
    });

    test('offline edit goes out with retryFailed', () async {
      final pk = await makeChannel();
      await admin.channels.post(pk, 'a');
      final id = admin.channels.postsIn(pk).single.id;
      net.down = true;
      await admin.channels.edit(id, 'b');
      expect(admin.channels.postsIn(pk).single.editUnsent, isTrue);
      net.down = false;
      await admin.channels.retryFailed();
      expect(admin.channels.postsIn(pk).single.editUnsent, isFalse);
      final edits = net.channelStored.where((e) => e.kind == Channel.kindEdit);
      expect(edits.map((e) => e.id).toSet(), hasLength(1));
    });
  });

  group('history', () {
    test('full history: the admin sends posts again when relays lost '
        'them, at most once a day', () async {
      final pk = await makeChannel();
      await admin.channels.post(pk, 'ancien');
      final id = admin.channels.postsIn(pk).single.id;
      await admin.channels.edit(id, 'ancien, corrigé');

      net.channelStored.clear(); // the relay purged everything
      await admin.channels.retryFailed();
      expect(net.channelStored.map((e) => e.id), contains(id));
      expect(net.channelStored.map((e) => e.kind), contains(Channel.kindEdit));

      // A late follower gets it from the relays, not from the admin.
      await bob.channels.join(admin.channels.channel(pk)!.invite);
      await until(() => bob.channels.postsIn(pk).isNotEmpty);
      await until(() => bob.channels.postsIn(pk).single.edited);
      expect(bob.channels.postsIn(pk).single.text, 'ancien, corrigé');

      net.channelStored.clear();
      await admin.channels.retryFailed();
      expect(net.channelStored, isEmpty, reason: 'done today already');
    });

    test(
      'from when they follow: earlier posts hidden, never re-sent',
      () async {
        final pk = (await admin.channels.create(
          name: 'Infos',
          public: true,
          fullHistory: false,
          relays: const [],
        ))!;
        final keys = await ChannelKeys.derive(deriveIdentity(aliceWords), 0);
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await admin.transport.publishChannelEvent(
          await signPost(keys, 'avant', createdAt: now - 3600),
        );
        await until(() => admin.channels.postsIn(pk).isNotEmpty);

        final invite = ChannelInvite.parse(
          admin.channels.channel(pk)!.invite.encode(),
        )!;
        expect(invite.fullHistory, isFalse, reason: 'known before the meta');
        await bob.channels.join(invite);
        expect(bob.channels.postsIn(pk), isEmpty);
        await until(() => bob.channels.channel(pk)!.metaAt > 0);
        await quiet();
        expect(bob.channels.postsIn(pk), isEmpty);
        expect(admin.channels.postsIn(pk), hasLength(1), reason: 'admin sees');

        await admin.channels.post(pk, 'après');
        await until(() => bob.channels.postsIn(pk).isNotEmpty);
        expect(bob.channels.postsIn(pk).single.text, 'après');

        net.channelStored.clear();
        await admin.channels.retryFailed();
        expect(
          net.channelStored.where((e) => e.kind == Channel.kindPost),
          isEmpty,
        );
      },
    );

    test('the admin can switch modes later', () async {
      final pk = await makeChannel();
      await admin.channels.editMeta(pk, fullHistory: false);
      await bob.channels.join(admin.channels.channel(pk)!.invite);
      await until(() => bob.channels.channel(pk)!.metaAt > 0);
      expect(bob.channels.channel(pk)!.meta.fullHistory, isFalse);
    });

    test(
      'a restored admin keeps the signed posts, to send them again',
      () async {
        final pk = await makeChannel();
        await admin.channels.post(pk, 'gardé');
        final fresh = await viewer(net, aliceWords);
        await until(() => fresh.channels.postsIn(pk).isNotEmpty);
        final p = fresh.channels.postsIn(pk).single;
        expect(p.event, isNotNull);

        net.channelStored.removeWhere((e) => e.kind == Channel.kindPost);
        await fresh.channels.retryFailed();
        expect(net.channelStored.map((e) => e.id), contains(p.id));
      },
    );
  });

  test(
    'the admin pins a post for every follower, kept on the relays',
    () async {
      final pk = await makeChannel();
      await admin.channels.post(pk, 'règles du canal');
      await admin.channels.post(pk, 'autre');
      final rules = admin.channels.postsIn(pk).first.id;
      await admin.channels.pin(pk, rules);
      expect(admin.channels.pinnedIn(pk)?.id, rules);

      // Purged relay: the daily re-send brings the pin back with the posts.
      net.channelStored.clear();
      await admin.channels.retryFailed();
      await bob.channels.join(admin.channels.channel(pk)!.invite);
      await until(() => bob.channels.pinnedIn(pk) != null);
      expect(bob.channels.pinnedIn(pk)!.text, 'règles du canal');
      for (final e in net.channelStored) {
        expect(e.content, isNot(contains(rules)), reason: 'id is encrypted');
      }

      // Followers can't pin.
      await bob.channels.pin(pk, null);
      expect(bob.channels.pinnedIn(pk)?.id, rules);

      await admin.channels.pin(pk, null);
      await until(() => bob.channels.pinnedIn(pk) == null);
    },
  );
}
