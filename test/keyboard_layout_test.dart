import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/logic/keyboard_layout.dart';

void main() {
  test('AZERTY for French, QWERTY otherwise', () {
    expect(KeyboardLayout.letters('fr').first.take(2), ['a', 'z']);
    expect(KeyboardLayout.letters('en').first.take(2), ['q', 'w']);
  });

  test('every letter a–z is reachable in both layouts', () {
    for (final lang in ['fr', 'en']) {
      final keys = KeyboardLayout.letters(lang).expand((r) => r).toSet();
      for (var c = 'a'.codeUnitAt(0); c <= 'z'.codeUnitAt(0); c++) {
        expect(keys, contains(String.fromCharCode(c)), reason: lang);
      }
    }
  });

  test('shuffle keeps row shapes and the exact set of keys', () {
    final rows = KeyboardLayout.letters('fr');
    final shuffled = KeyboardLayout.shuffle(rows, Random(42));
    expect(shuffled.map((r) => r.length), rows.map((r) => r.length));
    expect(
      shuffled.expand((r) => r).toList()..sort(),
      rows.expand((r) => r).toList()..sort(),
    );
    expect(shuffled, isNot(rows));
  });

  test('two shuffles differ (positions are not predictable)', () {
    final rows = KeyboardLayout.letters('en');
    final a = KeyboardLayout.shuffle(rows, Random(1));
    final b = KeyboardLayout.shuffle(rows, Random(2));
    expect(a, isNot(b));
  });

  test('French accents available', () {
    final keys = KeyboardLayout.accents.expand((r) => r).toSet();
    expect(keys, containsAll(['é', 'è', 'à', 'ç', 'ù', 'ê', 'ô', 'œ']));
  });

  test('QWERTZ for German, same letters as QWERTY', () {
    expect(KeyboardLayout.letters('de').first.take(6), [
      'q',
      'w',
      'e',
      'r',
      't',
      'z',
    ]);
    expect(KeyboardLayout.letters('de').last.first, 'y');
    expect(
      KeyboardLayout.letters('de').expand((r) => r).toSet(),
      KeyboardLayout.letters('en').expand((r) => r).toSet(),
    );
    expect(KeyboardLayout.letters('es'), KeyboardLayout.letters('en'));
  });

  test('German and Spanish accents, same row shapes for every language', () {
    final de = KeyboardLayout.page(KeyboardPage.accents, 'de').expand((r) => r);
    final es = KeyboardLayout.page(KeyboardPage.accents, 'es').expand((r) => r);
    expect(de, containsAll(['ä', 'ö', 'ü', 'ß']));
    expect(es, containsAll(['ñ', 'á', '¿', '¡']));
    for (final lang in ['fr', 'de', 'es', 'ru', 'en', 'zh']) {
      final rows = KeyboardLayout.page(KeyboardPage.accents, lang);
      expect(rows.map((r) => r.length), [10, 10, 7], reason: lang);
    }
  });

  test('shift gives one character, even for ß', () {
    expect(KeyboardLayout.upper('ß'), 'ẞ');
    expect(KeyboardLayout.upper('ä'), 'Ä');
    expect(KeyboardLayout.upper('ñ'), 'Ñ');
    for (final lang in ['fr', 'de', 'es', 'ru']) {
      for (final key in KeyboardLayout.accentsFor(lang).expand((r) => r)) {
        expect(KeyboardLayout.upper(key).runes, hasLength(1), reason: key);
      }
    }
  });

  test('Russian: all 33 letters reachable, ЙЦУКЕН order', () {
    final letters = KeyboardLayout.letters('ru');
    expect(letters.first.take(6), ['й', 'ц', 'у', 'к', 'е', 'н']);
    final keys = {
      ...letters.expand((r) => r),
      ...KeyboardLayout.accentsFor('ru').expand((r) => r),
    };
    const alphabet = 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя';
    expect(alphabet.length, 33);
    for (final c in alphabet.split('')) {
      expect(keys, contains(c), reason: c);
    }
    expect(KeyboardLayout.upper('ё'), 'Ё');
  });
}
