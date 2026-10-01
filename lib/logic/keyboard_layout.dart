import 'dart:math';

enum KeyboardPage { letters, symbols, accents }

/// Character grids for Whisper's in-app keyboard. Pure data: the widget only
/// renders these rows.
class KeyboardLayout {
  KeyboardLayout._();

  static const _azerty = [
    ['a', 'z', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['q', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm'],
    ['w', 'x', 'c', 'v', 'b', 'n', "'"],
  ];

  static const _qwerty = [
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
  ];

  static const _qwertz = [
    ['q', 'w', 'e', 'r', 't', 'z', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['y', 'x', 'c', 'v', 'b', 'n', 'm'],
  ];

  /// ЙЦУКЕН, as on Russian phones: ё and ъ sit on the second page.
  static const _jcuken = [
    ['й', 'ц', 'у', 'к', 'е', 'н', 'г', 'ш', 'щ', 'з', 'х'],
    ['ф', 'ы', 'в', 'а', 'п', 'р', 'о', 'л', 'д', 'ж', 'э'],
    ['я', 'ч', 'с', 'м', 'и', 'т', 'ь', 'б', 'ю'],
  ];

  static const symbols = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['@', '#', '€', '_', '&', '-', '+', '(', ')', '/'],
    ['*', '"', "'", ':', ';', '!', '?'],
  ];

  /// French accents (also the default page).
  static const accents = [
    ['é', 'è', 'ê', 'ë', 'à', 'â', 'ç', 'ù', 'û', 'ü'],
    ['î', 'ï', 'ô', 'œ', 'æ', 'ÿ', '«', '»', '…', '–'],
    ['€', '£', '\$', '%', '°', '=', '~'],
  ];

  static const _germanAccents = [
    ['ä', 'ö', 'ü', 'ß', 'é', 'è', 'à', 'ç', 'ñ', 'ê'],
    ['„', '“', '‚', '‘', '«', '»', '…', '–', '§', '°'],
    ['€', '£', '\$', '%', '&', '=', '~'],
  ];

  static const _russianExtras = [
    ['ё', 'ъ', '«', '»', '„', '“', '…', '–', '№', '°'],
    ['é', 'è', 'à', 'ç', 'ü', 'ö', 'ä', 'ñ', 'ß', 'ê'],
    ['€', '₽', '\$', '%', '&', '=', '~'],
  ];

  static const _spanishAccents = [
    ['á', 'é', 'í', 'ó', 'ú', 'ñ', 'ü', '¿', '¡', 'ç'],
    ['à', 'è', 'ò', 'ï', 'º', 'ª', '«', '»', '…', '–'],
    ['€', '£', '\$', '%', '°', '=', '~'],
  ];

  /// AZERTY for French, QWERTZ for German, ЙЦУКЕН for Russian, QWERTY
  /// otherwise.
  static List<List<String>> letters(String languageCode) =>
      switch (languageCode) {
        'fr' => _azerty,
        'de' => _qwertz,
        'ru' => _jcuken,
        _ => _qwerty,
      };

  static List<List<String>> accentsFor(String languageCode) =>
      switch (languageCode) {
        'de' => _germanAccents,
        'es' => _spanishAccents,
        'ru' => _russianExtras,
        _ => accents,
      };

  static List<List<String>> page(KeyboardPage page, String languageCode) =>
      switch (page) {
        KeyboardPage.letters => letters(languageCode),
        KeyboardPage.symbols => symbols,
        KeyboardPage.accents => accentsFor(languageCode),
      };

  /// Shifted key: one character in, one out (`'ß'.toUpperCase()` is "SS").
  static String upper(String key) => key == 'ß' ? 'ẞ' : key.toUpperCase();

  /// Same row shapes, keys permuted across the whole grid, so a logged touch
  /// position says nothing about which character was typed.
  static List<List<String>> shuffle(List<List<String>> rows, Random random) {
    final keys = rows.expand((r) => r).toList()..shuffle(random);
    var i = 0;
    return [
      for (final row in rows) [for (var j = 0; j < row.length; j++) keys[i++]],
    ];
  }
}
