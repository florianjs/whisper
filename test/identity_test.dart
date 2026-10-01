import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/identity.dart';

void main() {
  group('NIP-06 test vectors', () {
    test('12-word vector', () {
      final id = deriveIdentity(
        'leader monkey parrot ring guide accident before fence cannon height naive bean',
      );
      expect(
        id.privateKey,
        '7f7ff03d123792d6ac594bfa67bf6d0c0ab55b6b1fdb6249303fe861f1ccba9a',
      );
      expect(
        id.publicKey,
        '17162c921dc4d2518f9a101db33695df1afb56ab82f5ff3e5da6eec3ca5cd917',
      );
      expect(
        id.nsec,
        'nsec10allq0gjx7fddtzef0ax00mdps9t2kmtrldkyjfs8l5xruwvh2dq0lhhkp',
      );
      expect(
        id.npub,
        'npub1zutzeysacnf9rru6zqwmxd54mud0k44tst6l70ja5mhv8jjumytsd2x7nu',
      );
    });

    test('24-word vector', () {
      final id = deriveIdentity(
        'what bleak badge arrange retreat wolf trade produce cricket blur '
        'garlic valid proud rude strong choose busy staff weather area '
        'salt hollow arm fade',
      );
      expect(
        id.privateKey,
        'c15d739894c81a2fcfd3a2df85a0d2c0dbc47a280d092799f144d73d7ae78add',
      );
      expect(
        id.publicKey,
        'd41b22899549e1f3d335a31002cfd382174006e166d3e658e3a5eecdb6463573',
      );
      expect(
        id.npub,
        'npub16sdj9zv4f8sl85e45vgq9n7nsgt5qphpvmf7vk8r5hhvmdjxx4es8rq74h',
      );
    });
  });

  group('mnemonic', () {
    test('generates 24 valid, distinct words', () {
      final a = generateMnemonic();
      final b = generateMnemonic();
      expect(a.split(' '), hasLength(24));
      expect(isValidMnemonic(a), isTrue);
      expect(a, isNot(b));
    });

    test('normalizes case and whitespace on restore', () {
      const messy =
          '  Leader MONKEY parrot\nring guide  accident before fence cannon height naive bean ';
      expect(isValidMnemonic(messy), isTrue);
      expect(
        deriveIdentity(messy).publicKey,
        '17162c921dc4d2518f9a101db33695df1afb56ab82f5ff3e5da6eec3ca5cd917',
      );
    });

    test('rejects bad checksum and unknown words', () {
      const badChecksum =
          'leader monkey parrot ring guide accident before fence cannon height naive leader';
      expect(isValidMnemonic(badChecksum), isFalse);
      expect(isValidMnemonic('hello world notaword'), isFalse);
      expect(() => deriveIdentity(badChecksum), throwsArgumentError);
    });
  });

  group('username', () {
    test('is deterministic across restore', () {
      final m = generateMnemonic();
      expect(deriveIdentity(m).username, deriveIdentity(m).username);
    });

    test('has adjective-animal-NNNN shape', () {
      final name = usernameFor(
        '17162c921dc4d2518f9a101db33695df1afb56ab82f5ff3e5da6eec3ca5cd917',
      );
      expect(name, matches(RegExp(r'^[a-z]+-[a-z]+-\d{4}$')));
    });

    test('differs for different keys', () {
      final a = usernameFor(
        '17162c921dc4d2518f9a101db33695df1afb56ab82f5ff3e5da6eec3ca5cd917',
      );
      final b = usernameFor(
        'd41b22899549e1f3d335a31002cfd382174006e166d3e658e3a5eecdb6463573',
      );
      expect(a, isNot(b));
    });
  });

  group('parsePubkey', () {
    const hex =
        '17162c921dc4d2518f9a101db33695df1afb56ab82f5ff3e5da6eec3ca5cd917';
    const npub =
        'npub1zutzeysacnf9rru6zqwmxd54mud0k44tst6l70ja5mhv8jjumytsd2x7nu';

    test('accepts npub, nostr: URI, hex, any case/whitespace', () {
      expect(parsePubkey(npub), hex);
      expect(parsePubkey('  nostr:$npub\n'), hex);
      expect(parsePubkey(hex.toUpperCase()), hex);
    });

    test('rejects typos, nsec and non-curve points', () {
      final typo = npub.replaceRange(20, 21, npub[20] == 'q' ? 'p' : 'q');
      expect(parsePubkey(typo), isNull, reason: 'bech32 checksum');
      expect(
        parsePubkey(
          'nsec10allq0gjx7fddtzef0ax00mdps9t2kmtrldkyjfs8l5xruwvh2dq0lhhkp',
        ),
        isNull,
      );
      expect(parsePubkey('abc'), isNull);
      // x = p (field prime) is not a valid coordinate.
      expect(
        parsePubkey(
          'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f',
        ),
        isNull,
      );
    });
  });
}
