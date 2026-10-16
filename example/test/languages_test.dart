import 'package:flutter_test/flutter_test.dart';
// The plugin's BCP-47 lookup, which the package doesn't export.
// ignore: depend_on_referenced_packages
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show BCP47Code;
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

  group('sourceStatusLabel', () {
    const spanish = TranslateLanguage.spanish;

    test('names each stage', () {
      expect(sourceStatusLabel(const SourceSearching()), 'Looking for text…');
      expect(sourceStatusLabel(const SourceGuessed(spanish)), 'Spanish?');
      expect(sourceStatusLabel(const SourceDownloading(spanish)), 'Spanish');
      expect(sourceStatusLabel(const SourceReady(spanish)), 'Spanish');
      expect(
        sourceStatusLabel(const SourceUnsupported('la')),
        "Latin can't be translated",
      );
      expect(
        sourceStatusLabel(const SourceNotFound()),
        'No supported text found',
      );
      expect(
        sourceStatusLabel(const SourceDownloadFailed(spanish)),
        'Spanish · download failed',
      );
    });

    test('an unknown tag is shown as it is', () {
      expect(
        sourceStatusLabel(const SourceUnsupported('xx')),
        "xx can't be translated",
      );
    });
  });

  test('untranslatable names are for languages ML Kit cannot translate', () {
    for (final tag in untranslatableNames.keys) {
      expect(BCP47Code.fromRawValue(tag), isNull, reason: tag);
    }
  });
}
