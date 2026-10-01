import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart' show Nip01Event;
import 'package:whisper/logic/nickname.dart';
import 'package:whisper/logic/photo.dart';

String ch(int code) => String.fromCharCode(code);

void main() {
  group('sanitizeNickname', () {
    test('trims and collapses spaces', () {
      expect(sanitizeNickname('  Léa   la   brave '), 'Léa la brave');
      expect(sanitizeNickname('a\n\tb'), 'a b');
    });

    test('blank or invisible-only is no nickname', () {
      expect(sanitizeNickname(null), isNull);
      expect(sanitizeNickname('   '), isNull);
      expect(sanitizeNickname(ch(0x200B) + ch(0x2060) + ch(0xFEFF)), isNull);
    });

    test('strips direction overrides and zero-width characters', () {
      // "evil" + RLO + "ecila" would render as "evilalice".
      expect(sanitizeNickname('evil${ch(0x202E)}ecila'), 'evilecila');
      expect(sanitizeNickname('al${ch(0x200D)}ice${ch(0x2066)}'), 'alice');
      expect(sanitizeNickname('a${ch(0x00)}b${ch(0x7F)}c'), 'abc');
    });

    test('keeps letters of any script and emoji', () {
      expect(sanitizeNickname('Олег 🦊'), 'Олег 🦊');
      expect(sanitizeNickname('سارا'), 'سارا');
    });

    test('caps at 32 user-perceived characters', () {
      expect(sanitizeNickname('x' * 40), 'x' * maxNicknameLength);
      final flags = '🇫🇷' * 40;
      expect(sanitizeNickname(flags), '🇫🇷' * maxNicknameLength);
    });
  });

  group('ProfileCard name', () {
    Nip01Event rumor(Map<String, Object?> json) => Nip01Event(
      pubKey: 'a' * 64,
      kind: ProfileCard.kind,
      tags: const [],
      content: jsonEncode(json),
    );

    test('round-trips', () {
      final card = ProfileCard(
        version: 3,
        image: Uint8List.fromList([1, 2]),
        name: 'Léa',
      );
      final back = ProfileCard.fromRumor(
        card.toRumor(sender: 'a' * 64, recipient: 'b' * 64),
      )!;
      expect(back.name, 'Léa');
      expect(back.image, [1, 2]);
    });

    test('older cards without a name still read', () {
      final back = ProfileCard.fromRumor(rumor({'v': 1, 'image': null}))!;
      expect(back.name, isNull);
    });

    test('hostile names are cleaned or dropped, the card survives', () {
      expect(
        ProfileCard.fromRumor(
          rumor({'v': 1, 'name': 'x' * 5000}),
        )!.name!.length,
        maxNicknameLength,
      );
      expect(ProfileCard.fromRumor(rumor({'v': 1, 'name': 42}))!.name, isNull);
      expect(
        ProfileCard.fromRumor(
          rumor({'v': 1, 'name': 'evil${ch(0x202E)}ecila'}),
        )!.name,
        'evilecila',
      );
    });
  });
}
