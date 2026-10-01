import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart' show Nip01Event, Nip01Utils;
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/nip17.dart';

Identity randomIdentity() {
  final priv = Bip340.generatePrivateKey().privateKey!;
  return Identity(privateKey: priv, publicKey: Bip340.getPublicKey(priv));
}

void main() {
  final alice = randomIdentity();
  final bob = randomIdentity();
  final mallory = randomIdentity();

  Nip01Event rumorFrom(Identity from, Identity to, [String text = 'salut']) =>
      Nip17.chatRumor(
        senderPubkey: from.publicKey,
        recipientPubkey: to.publicKey,
        text: text,
      );

  test('round trip: bob reads what alice sent', () async {
    final rumor = rumorFrom(alice, bob, 'rendez-vous à 18h');
    final wrap = await Nip17.wrap(
      sender: alice,
      recipientPubkey: bob.publicKey,
      rumor: rumor,
    );
    final opened = await Nip17.unwrap(me: bob, giftWrap: wrap);

    expect(opened.content, 'rendez-vous à 18h');
    expect(opened.pubKey, alice.publicKey);
    expect(opened.id, rumor.id);
    expect(Nip01Utils.isIdValid(rumor), isTrue);
  });

  test(
    'what relays see reveals neither sender, content nor send time',
    () async {
      final rumor = rumorFrom(alice, bob, 'secret');
      final wrap = await Nip17.wrap(
        sender: alice,
        recipientPubkey: bob.publicKey,
        rumor: rumor,
      );

      expect(wrap.kind, Nip17.kindGiftWrap);
      expect(wrap.pubKey, isNot(alice.publicKey));
      expect(wrap.content, isNot(contains('secret')));
      expect(wrap.tags, [
        ['p', bob.publicKey],
      ]);
      expect(wrap.createdAt, lessThan(rumor.createdAt));
      expect(
        wrap.createdAt,
        greaterThanOrEqualTo(rumor.createdAt - 2 * 24 * 3600 - 1),
      );
    },
  );

  test('each wrap uses a fresh one-time key', () async {
    final rumor = rumorFrom(alice, bob);
    final a = await Nip17.wrap(
      sender: alice,
      recipientPubkey: bob.publicKey,
      rumor: rumor,
    );
    final b = await Nip17.wrap(
      sender: alice,
      recipientPubkey: bob.publicKey,
      rumor: rumor,
    );
    expect(a.pubKey, isNot(b.pubKey));
  });

  test('a third party cannot open it', () async {
    final wrap = await Nip17.wrap(
      sender: alice,
      recipientPubkey: bob.publicKey,
      rumor: rumorFrom(alice, bob),
    );
    await expectLater(
      Nip17.unwrap(me: mallory, giftWrap: wrap),
      throwsA(isA<Nip17Exception>()),
    );
  });

  test('impersonation: mallory claiming to be alice is rejected', () async {
    // Rumor says "from alice" but the seal is signed with mallory's key.
    final forged = await Nip17.wrap(
      sender: mallory,
      recipientPubkey: bob.publicKey,
      rumor: rumorFrom(alice, bob, 'envoie-moi ta phrase'),
    );
    await expectLater(
      Nip17.unwrap(me: bob, giftWrap: forged),
      throwsA(
        isA<Nip17Exception>().having(
          (e) => e.reason,
          'reason',
          contains('does not match'),
        ),
      ),
    );
  });

  test('tampered wrap is rejected', () async {
    final wrap = await Nip17.wrap(
      sender: alice,
      recipientPubkey: bob.publicKey,
      rumor: rumorFrom(alice, bob),
    );
    // Flip one base64 char — always to a *different* one, or the test would
    // silently pass unmodified content 1 time in 64.
    final c = wrap.content;
    final flipped = c[20] == 'A' ? 'B' : 'A';
    final tampered = wrap.copyWith(
      content: '${c.substring(0, 20)}$flipped${c.substring(21)}',
    );
    await expectLater(
      Nip17.unwrap(me: bob, giftWrap: tampered),
      throwsA(isA<Nip17Exception>()),
    );
  });

  test('wrong kind is rejected before any crypto', () async {
    final notAWrap = Nip01Event(
      pubKey: alice.publicKey,
      kind: 1,
      tags: const [],
      content: 'hello',
      createdAt: 1700000000,
    );
    await expectLater(
      Nip17.unwrap(me: bob, giftWrap: notAWrap),
      throwsA(isA<Nip17Exception>()),
    );
  });

  test('sender can open the self-copy', () async {
    final rumor = rumorFrom(alice, bob, 'copie');
    final selfCopy = await Nip17.wrap(
      sender: alice,
      recipientPubkey: alice.publicKey,
      rumor: rumor,
    );
    final opened = await Nip17.unwrap(me: alice, giftWrap: selfCopy);
    expect(opened.id, rumor.id);
    expect(opened.tags.first, ['p', bob.publicKey]);
  });
}
