import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/live_translate.dart';
import 'package:live_translate_example/languages.dart';

void main() {
  group('readingFor', () {
    test('Detect language reads both scripts without a hint', () {
      final reading = readingFor(null);
      expect(reading.sourceLanguages, isNull);
      expect(reading.scripts, {TextScript.latin, TextScript.devanagari});
    });

    test('Hindi reads only Devanagari', () {
      final reading = readingFor(TranslateLanguage.hindi);
      expect(reading.sourceLanguages, {TranslateLanguage.hindi});
      expect(reading.scripts, {TextScript.devanagari});
    });

    test('Spanish reads only Latin', () {
      final reading = readingFor(TranslateLanguage.spanish);
      expect(reading.sourceLanguages, {TranslateLanguage.spanish});
      expect(reading.scripts, {TextScript.latin});
    });
  });

  test('display names', () {
    expect(displayName(TranslateLanguage.german), 'German');
    expect(displayName(TranslateLanguage.haitian), 'Haitian Creole');
    expect(sourceName(null), 'Detect language');
  });

  test('every language is in exactly one script set', () {
    for (final language in TranslateLanguage.values) {
      final sets = [
        latinLanguages,
        devanagariLanguages,
        otherScriptLanguages,
      ].where((set) => set.contains(language));
      expect(sets, hasLength(1), reason: language.name);
    }
  });

  test('source options hold only readable languages', () {
    expect(sourceOptions.first, isNull);
    expect(sourceOptions, hasLength(1 + 2 + 37));
    expect(
      sourceOptions,
      containsAll([
        TranslateLanguage.hindi,
        TranslateLanguage.marathi,
        TranslateLanguage.english,
        TranslateLanguage.french,
      ]),
    );
    for (final language in [
      TranslateLanguage.japanese,
      TranslateLanguage.arabic,
      TranslateLanguage.russian,
    ]) {
      expect(sourceOptions, isNot(contains(language)));
    }
  });

  group('detectedLanguage', () {
    var id = 0;
    TranslatedLine from(String? tag) => TranslatedLine(
      id: '${id++}',
      sourceText: 'text',
      translatedText: 'translation',
      sourceLanguage: tag,
      rect: Rect.zero,
    );

    test('French lines give French', () {
      expect(
        detectedLanguage([from('fr'), from('fr')], null),
        TranslateLanguage.french,
      );
    });

    test('the most common language wins', () {
      expect(
        detectedLanguage([
          from('hi'),
          from('en'),
          from('hi'),
          from('hi'),
        ], null),
        TranslateLanguage.hindi,
      );
    });

    test('a tie keeps the current language', () {
      expect(
        detectedLanguage([from('fr'), from('es')], TranslateLanguage.spanish),
        TranslateLanguage.spanish,
      );
    });

    test('otherwise a tie takes the first in line order', () {
      expect(
        detectedLanguage([from('fr'), from('es')], TranslateLanguage.german),
        TranslateLanguage.french,
      );
    });

    test('unknown and missing tags are skipped', () {
      expect(
        detectedLanguage([
          from('la'),
          from(null),
          from('la'),
          from('de'),
        ], null),
        TranslateLanguage.german,
      );
    });

    test('no lines give nothing', () {
      expect(detectedLanguage(const [], TranslateLanguage.french), isNull);
      expect(detectedLanguage([from(null)], null), isNull);
    });
  });
}
