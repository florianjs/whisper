import 'dart:math';

import 'package:blockchain_utils/blockchain_utils.dart';

/// One "which word is #n?" question shown after the seed is revealed.
class ChallengeItem {
  const ChallengeItem({required this.index, required this.options});

  /// Zero-based position in the mnemonic.
  final int index;

  /// Shuffled candidates; exactly one equals the word at [index].
  final List<String> options;
}

/// Picks [count] distinct positions and, for each, [optionCount] candidates.
/// Distractors come from the user's own phrase so the check proves they know
/// the order, not just which words appeared.
List<ChallengeItem> buildChallenge(
  List<String> words, {
  Random? random,
  int count = 3,
  int optionCount = 4,
}) {
  final rng = random ?? Random.secure();
  final unique = words.toSet().toList();
  final positions = List<int>.generate(words.length, (i) => i)..shuffle(rng);
  final picked = positions.take(count).toList()..sort();
  return [
    for (final index in picked)
      ChallengeItem(
        index: index,
        options: (<String>[
          words[index],
          ...(unique.where((w) => w != words[index]).toList()..shuffle(rng))
              .take(optionCount - 1),
        ]..shuffle(rng)),
      ),
  ];
}

final _english = Bip39Languages.english.wordList;
final _englishSet = _english.toSet();

bool isBip39Word(String word) => _englishSet.contains(word);

/// BIP39 words starting with [prefix], for the restore keyboard strip.
List<String> bip39Suggestions(String prefix, {int limit = 4}) {
  if (prefix.isEmpty) return const [];
  final p = prefix.toLowerCase();
  return _english.where((w) => w.startsWith(p)).take(limit).toList();
}
