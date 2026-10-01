import 'package:flutter/widgets.dart' show StringCharacters;

/// Longest nickname, in user-perceived characters (an emoji counts as one).
const maxNicknameLength = 32;

/// Invisible or text-direction characters: a nickname made of them could
/// look empty, or reorder what's displayed around it to pass for someone
/// else (a right-to-left override turns "evil[U+202E]ecila" into
/// "evilalice" on screen).
final _hidden = RegExp(
  r'[\u0000-\u001F\u007F-\u009F\u00AD\u061C\u180E\u200B-\u200F'
  r'\u2028-\u202E\u2060-\u206F\uFEFF]',
  unicode: true,
);

/// Clean nickname, or null when nothing readable is left. Applied to my own
/// input and to every nickname coming from the network.
String? sanitizeNickname(String? input) {
  if (input == null) return null;
  // Whitespace first: a newline between two words is a space, not nothing.
  final text = input
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(_hidden, '')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .trim();
  if (text.isEmpty) return null;
  final chars = text.characters;
  return chars.length <= maxNicknameLength
      ? text
      : chars.take(maxNicknameLength).toString().trimRight();
}
