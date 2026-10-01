import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/identity.dart';
import 'package:whisper/logic/seed_challenge.dart';

void main() {
  group('buildChallenge', () {
    final words = generateMnemonic().split(' ');

    test('asks 3 distinct, ordered positions', () {
      final items = buildChallenge(words, random: Random(1));
      final idx = items.map((i) => i.index).toList();
      expect(idx, hasLength(3));
      expect(idx.toSet(), hasLength(3));
      expect(idx, orderedEquals([...idx]..sort()));
    });

    test('each item has 4 unique options including the answer', () {
      for (var seed = 0; seed < 50; seed++) {
        for (final item in buildChallenge(words, random: Random(seed))) {
          expect(item.options, hasLength(4));
          expect(item.options.toSet(), hasLength(4));
          expect(item.options, contains(words[item.index]));
        }
      }
    });

    test('distractors come from the phrase itself', () {
      for (final item in buildChallenge(words, random: Random(7))) {
        expect(words, containsAll(item.options));
      }
    });
  });

  group('bip39 words', () {
    test('suggests prefix matches, capped', () {
      expect(bip39Suggestions('ab'), hasLength(4));
      expect(bip39Suggestions('ab').every((w) => w.startsWith('ab')), isTrue);
      expect(bip39Suggestions('zoo'), ['zoo']);
      expect(bip39Suggestions(''), isEmpty);
      expect(bip39Suggestions('qqq'), isEmpty);
    });

    test('membership', () {
      expect(isBip39Word('abandon'), isTrue);
      expect(isBip39Word('nostr'), isFalse);
    });
  });
}
