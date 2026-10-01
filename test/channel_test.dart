import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart' show Bip340EventVerifier;
import 'package:whisper/logic/channel.dart';
import 'package:whisper/logic/identity.dart';

import 'support/fake_network.dart';

void main() {
  late Identity alice, bob;
  final verifier = Bip340EventVerifier(useIsolate: false);

  setUpAll(() async {
    alice = deriveIdentity(aliceWords);
    bob = deriveIdentity(bobWords);
  });

  test('channel keys are deterministic per owner and index', () async {
    final a0 = await ChannelKeys.derive(alice, 0);
    final again = await ChannelKeys.derive(alice, 0);
    final a1 = await ChannelKeys.derive(alice, 1);
    final b0 = await ChannelKeys.derive(bob, 0);
    expect(again.publicKey, a0.publicKey);
    expect(again.contentKey, a0.contentKey);
    expect(a1.publicKey, isNot(a0.publicKey));
    expect(b0.publicKey, isNot(a0.publicKey));
    expect(a0.publicKey, isNot(alice.publicKey));
    expect(a0.contentKey, hasLength(64));
  });

  test(
    'posts are signed by the channel and only readable with its key',
    () async {
      final keys = await ChannelKeys.derive(alice, 0);
      final post = await signPost(keys, 'bonjour');
      expect(post.pubKey, keys.publicKey);
      expect(post.content, isNot(contains('bonjour')));
      expect(await verifier.verify(post), isTrue);

      final clear = await decryptFor(
        keys.contentKey,
        keys.publicKey,
        Channel.kindPost,
        post.content,
      );
      expect(clear?['t'], 'bonjour');

      final other = await ChannelKeys.derive(alice, 1);
      expect(
        await decryptFor(
          other.contentKey,
          keys.publicKey,
          Channel.kindPost,
          post.content,
        ),
        isNull,
        reason: 'wrong key',
      );
      expect(
        await decryptFor(
          keys.contentKey,
          keys.publicKey,
          Channel.kindMeta,
          post.content,
        ),
        isNull,
        reason: 'post replayed as metadata (AAD)',
      );
      expect(
        await decryptFor(
          keys.contentKey,
          other.publicKey,
          Channel.kindPost,
          post.content,
        ),
        isNull,
        reason: 'post replayed in another channel (AAD)',
      );
    },
  );

  test(
    'reaction keys are stable per channel and unlinkable to identity',
    () async {
      final c0 = (await ChannelKeys.derive(alice, 0)).publicKey;
      final c1 = (await ChannelKeys.derive(alice, 1)).publicKey;
      final k0 = await reactionKey(bob, c0);
      expect((await reactionKey(bob, c0)).publicKey, k0.publicKey);
      expect((await reactionKey(bob, c1)).publicKey, isNot(k0.publicKey));
      expect(k0.publicKey, isNot(bob.publicKey));
    },
  );

  test('reaction hides the post id from relays', () async {
    final keys = await ChannelKeys.derive(alice, 0);
    final post = await signPost(keys, 'x');
    final r = await signReaction(
      key: await reactionKey(bob, keys.publicKey),
      channelPk: keys.publicKey,
      contentKey: keys.contentKey,
      postId: post.id,
      emoji: '❤️',
    );
    expect(r.tags, [
      ['p', keys.publicKey],
    ]);
    expect(r.content, isNot(contains(post.id)));
    final clear = await decryptFor(
      keys.contentKey,
      keys.publicKey,
      Channel.kindReaction,
      r.content,
    );
    expect(clear, {'e': post.id, 'r': '❤️'});
  });

  test('invite round-trips and rejects junk', () async {
    final keys = await ChannelKeys.derive(alice, 0);
    final invite = ChannelInvite(
      channelPk: keys.publicKey,
      contentKey: keys.contentKey,
      name: 'Nouvelles',
      public: true,
      relays: const ['wss://nos.lol'],
    );
    final code = invite.encode();
    expect(code, startsWith('whisper-channel:'));
    final back = ChannelInvite.parse('  $code\n')!;
    expect(back.channelPk, keys.publicKey);
    expect(back.contentKey, keys.contentKey);
    expect(back.name, 'Nouvelles');
    expect(back.relays, ['wss://nos.lol']);

    expect(ChannelInvite.parse('whisper-channel:%%%'), isNull);
    expect(ChannelInvite.parse(keys.publicKey), isNull);
    expect(ChannelInvite.fromJson({...invite.toJson(), 'k': 'short'}), isNull);
    expect(ChannelInvite.fromJson({...invite.toJson(), 'v': 2}), isNull);
  });

  test('metadata validation', () {
    expect(ChannelMeta.fromJson({'n': 'x', 'p': true})?.name, 'x');
    expect(ChannelMeta.fromJson({'n': ' ', 'p': true}), isNull);
    expect(ChannelMeta.fromJson({'n': 'x' * 61, 'p': true}), isNull);
    expect(ChannelMeta.fromJson({'n': 'x'}), isNull);
  });

  test('reaction counting: latest per reactor, retract drops it', () {
    expect(
      countReactions({
        'a': (emoji: '❤️', at: 1),
        'b': (emoji: '❤️', at: 2),
        'c': (emoji: '👍', at: 3),
        'd': (emoji: '', at: 4),
      }),
      {'❤️': 2, '👍': 1},
    );
    expect(newerReaction(null, 1), isTrue);
    expect(newerReaction((emoji: '❤️', at: 5), 4), isFalse);
    expect(newerReaction((emoji: '❤️', at: 5), 6), isTrue);
  });
}
