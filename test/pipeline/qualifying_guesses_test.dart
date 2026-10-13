import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/engines/language_engine.dart';
import 'package:live_translate/src/pipeline/line_translator.dart';

void main() {
  const hindiOrMarathi = {TranslateLanguage.hindi, TranslateLanguage.marathi};

  test('confident identification', () {
    expect(
      qualifyingGuesses(const [
        LanguageGuess('es', 0.9),
      ], null).firstOrNull?.tag,
      'es',
    );
  });

  test('undetermined language', () {
    expect(
      qualifyingGuesses(const [LanguageGuess('und', 1)], null).firstOrNull?.tag,
      isNull,
    );
  });

  test('best guess below 0.5 is not trusted', () {
    expect(
      qualifyingGuesses(const [
        LanguageGuess('es', 0.4),
        LanguageGuess('pt', 0.3),
      ], null).firstOrNull?.tag,
      isNull,
    );
  });

  test('exactly 0.5 is trusted', () {
    expect(
      qualifyingGuesses(const [
        LanguageGuess('es', 0.5),
      ], null).firstOrNull?.tag,
      'es',
    );
  });

  test('hint narrows the candidates', () {
    expect(
      qualifyingGuesses(const [
        LanguageGuess('ne', 0.6),
        LanguageGuess('mr', 0.3),
        LanguageGuess('hi', 0.55),
      ], hindiOrMarathi).firstOrNull?.tag,
      'hi',
    );
  });

  test('an unlisted language is ignored', () {
    expect(
      qualifyingGuesses(
        const [LanguageGuess('it', 0.9), LanguageGuess('es', 0.6)],
        {TranslateLanguage.spanish, TranslateLanguage.french},
      ).firstOrNull?.tag,
      'es',
    );
  });

  test('a hinted guess below 0.5 does not qualify', () {
    expect(
      qualifyingGuesses(const [
        LanguageGuess('mr', 0.4),
      ], hindiOrMarathi).firstOrNull?.tag,
      isNull,
    );
  });

  test('no hinted language qualifies', () {
    expect(
      qualifyingGuesses(const [
        LanguageGuess('ne', 0.9),
        LanguageGuess('hi', 0.1),
        LanguageGuess('mr', 0.05),
      ], hindiOrMarathi).firstOrNull?.tag,
      isNull,
    );
  });

  test('returns the chosen guess with its confidence', () {
    expect(
      qualifyingGuesses(const [LanguageGuess('es', 0.9)], null).firstOrNull,
      const LanguageGuess('es', 0.9),
    );
  });

  test('orders guesses most confident first, regardless of input order', () {
    expect(
      qualifyingGuesses(const [
        LanguageGuess('es', 0.6),
        LanguageGuess('pt', 0.8),
      ], null).map((g) => g.tag),
      ['pt', 'es'],
    );
  });
}
