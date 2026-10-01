import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/contact_code.dart';

const alice =
    '17162c921dc4d2518f9a101db33695df1afb56ab82f5ff3e5da6eec3ca5cd917';
const bob = 'd41b22899549e1f3d335a31002cfd382174006e166d3e658e3a5eecdb6463573';
const aliceNpub =
    'npub1zutzeysacnf9rru6zqwmxd54mud0k44tst6l70ja5mhv8jjumytsd2x7nu';

void main() {
  group('contact codes', () {
    test('nprofile round trip keeps pubkey and relays', () {
      final code = encodeContactCode(alice, [
        'wss://nos.lol',
        'wss://relay.damus.io',
      ]);
      expect(code, startsWith('nostr:nprofile1'));
      final parsed = parsePubkeyCode(code);
      expect(parsed.pubkey, alice);
      expect(parsed.relays, ['wss://nos.lol', 'wss://relay.damus.io']);
    });

    test('npub, hex and nostr: prefix still work (no relays)', () {
      expect(parseContactCode(aliceNpub)!.pubkey, alice);
      expect(parseContactCode('nostr:$aliceNpub')!.relays, isEmpty);
      expect(parseContactCode(alice)!.pubkey, alice);
    });

    test('hostile relay hints are dropped', () {
      final code = encodeContactCode(alice, [
        'ws://plain.example',
        'https://not-a-relay.example',
        'wss://ok.example',
      ]);
      expect(parsePubkeyCode(code).relays, ['wss://ok.example']);
    });

    test('garbage is rejected', () {
      expect(parseContactCode('nprofile1qqqq'), isNull);
      expect(parseContactCode('hello'), isNull);
      expect(parseContactCode(''), isNull);
    });
  });

  group('safety number', () {
    test('same on both sides, 12 groups of 5 digits', () {
      final ab = safetyNumber(alice, bob);
      expect(ab, safetyNumber(bob, alice));
      expect(ab, matches(RegExp(r'^(\d{5} ){11}\d{5}$')));
    });

    test('changes if either key changes', () {
      const carol =
          'aaaa22899549e1f3d335a31002cfd382174006e166d3e658e3a5eecdb6463573';
      expect(safetyNumber(alice, bob), isNot(safetyNumber(alice, carol)));
    });
  });
}

ContactCode parsePubkeyCode(String code) => parseContactCode(code)!;
