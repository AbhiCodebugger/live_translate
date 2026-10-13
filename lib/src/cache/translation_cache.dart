import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;

typedef _Key = (String text, TranslateLanguage from, TranslateLanguage to);

final _whitespace = RegExp(r'\s+');

/// [text] trimmed, with each run of whitespace collapsed to one space.
///
/// Recognition often varies spacing between frames, so text is compared in
/// this form.
String normalizeLineText(String text) =>
    text.trim().replaceAll(_whitespace, ' ');

/// Remembers recent translations, so text seen in many frames is translated
/// once.
///
/// Holds at most [capacity] entries and evicts the least recently used one.
/// Text is compared after trimming it and collapsing runs of whitespace, since
/// recognition often varies spacing between frames.
class TranslationCache {
  /// Creates a cache holding up to [capacity] translations.
  TranslationCache({this.capacity = 200})
    : assert(capacity > 0, 'capacity must be positive');

  /// The most entries the cache holds.
  final int capacity;

  // Map literals are insertion-ordered, which gives the LRU order.
  final _entries = <_Key, String>{};

  /// The number of cached translations.
  int get length => _entries.length;

  /// The cached translation of [text] from [from] into [to], or `null`.
  String? get(
    String text, {
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) {
    final key = _key(text, from, to);
    final translation = _entries.remove(key);
    if (translation != null) _entries[key] = translation;
    return translation;
  }

  /// Caches [translation] as the translation of [text] from [from] into [to].
  void put(
    String text,
    String translation, {
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) {
    final key = _key(text, from, to);
    _entries
      ..remove(key)
      ..[key] = translation;
    if (_entries.length > capacity) _entries.remove(_entries.keys.first);
  }

  static _Key _key(String text, TranslateLanguage from, TranslateLanguage to) =>
      (normalizeLineText(text), from, to);
}
