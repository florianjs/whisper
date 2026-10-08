import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/channel.dart';
import 'package:whisper/logic/contact_code.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/links.dart';

import 'support/fake_network.dart';

void main() {
  final bob = deriveIdentity(bobWords);

  test('npub, nprofile and nostr: in the middle of a sentence', () {
    final nprofile = encodeContactCode(bob.publicKey, ['wss://r.example']);
    final text = 'Écris à ${bob.npub}, ou $nprofile.';
    final links = findLinks(text);
    expect(links, hasLength(2));
    final first = links[0] as ContactLink;
    expect(text.substring(first.start, first.end), bob.npub);
    expect(first.contact.pubkey, bob.publicKey);
    final second = links[1] as ContactLink;
    expect(text.substring(second.start, second.end), nprofile);
    expect(second.contact.relays, ['wss://r.example']);
    expect(text.substring(second.end), '.');
  });

  test('channel invite and group link', () async {
    final keys = await ChannelKeys.derive(deriveIdentity(aliceWords), 0);
    final code = ChannelInvite(
      channelPk: keys.publicKey,
      contentKey: keys.contentKey,
      name: 'Infos',
      public: true,
    ).encode();
    final group = GroupLink.encode('ab' * 16);
    final links = findLinks('Suis $code\net viens dans $group !');
    expect(links, hasLength(2));
    expect((links[0] as ChannelLink).invite.channelPk, keys.publicKey);
    expect((links[1] as GroupLink).groupId, 'ab' * 16);
  });

  test('broken or glued look-alikes stay plain text', () {
    final npub = bob.npub;
    final typo = npub.replaceRange(npub.length - 1, null, 'q');
    expect(findLinks(typo), isEmpty, reason: 'bad checksum');
    expect(findLinks('x$npub'), isEmpty, reason: 'part of another word');
    expect(findLinks('whisper-channel:nope'), isEmpty);
    expect(findLinks('whisper-group:abc'), isEmpty);
    expect(findLinks('whisper-group:${'ab' * 16}ff'), isEmpty);
    expect(findLinks('https://example.com npub nothing'), isEmpty);
    expect(findLinks(''), isEmpty);
  });
}
