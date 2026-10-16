import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/engines/language_engine.dart';
import 'package:live_translate/src/engines/text_engine.dart';
import 'package:live_translate/src/errors.dart';
import 'package:live_translate/src/models/source_status.dart';
import 'package:live_translate/src/pipeline/line_translator.dart';

import '../support/fakes.dart';

const en = TranslateLanguage.english;
const es = TranslateLanguage.spanish;
const fr = TranslateLanguage.french;
const hi = TranslateLanguage.hindi;

RecognizedLine line(String text) =>
    RecognizedLine(text: text, box: const Rect.fromLTWH(0, 0, 10, 10));

void main() {
  late FakeLanguageEngine languages;
  late FakeTranslateEngine translator;
  late FakeModelStore models;
  late List<LiveTranslateException> errors;
  late LineTranslator lineTranslator;

  setUp(() {
    languages = FakeLanguageEngine();
    translator = FakeTranslateEngine();
    models = FakeModelStore()..present.addAll({en, es, fr});
    errors = [];
    lineTranslator = LineTranslator(
      languageEngine: languages,
      translateEngine: translator,
      modelStore: models,
      onError: errors.add,
    );
  });

  Future<List<LineTranslation>> translate(
    List<String> texts, {
    TranslateLanguage target = en,
    Set<TranslateLanguage>? sourceLanguages,
  }) => lineTranslator.translateLines(
    [for (final text in texts) line(text)],
    target: target,
    sourceLanguages: sourceLanguages,
  );

  void identifyAs(String text, String tag, [double confidence = 0.9]) =>
      languages.guesses[text] = [LanguageGuess(tag, confidence)];

  group('translate spec', () {
    test('Spanish line to English', () async {
      identifyAs('Salida', 'es');
      final result = await translate(['Salida']);
      expect(result.single.sourceLanguage, 'es');
      expect(result.single.translatedText, '[en] Salida');
    });

    test('no source language leaves the line untranslated', () async {
      final result = await translate(['OK']);
      expect(result.single.sourceLanguage, isNull);
      expect(result.single.translatedText, isNull);
      expect(translator.translated, isEmpty);
    });

    test('same text over ten frames is translated once', () async {
      identifyAs('Salida', 'es');
      for (var i = 0; i < 10; i++) {
        final result = await translate(['Salida']);
        expect(result.single.translatedText, '[en] Salida');
      }
      expect(translator.translated, ['Salida']);
    });

    test('whitespace differences share a translation', () async {
      identifyAs(' Salida  de emergencia', 'es');
      identifyAs('Salida de emergencia', 'es');
      await translate([' Salida  de emergencia']);
      await translate(['Salida de emergencia']);
      expect(translator.translated, hasLength(1));
    });

    test('Hindi model missing: one download on the third frame', () async {
      models.downloadGate = Completer<void>();
      for (var i = 1; i <= 3; i++) {
        final result = await translate(['नमस्ते'], sourceLanguages: {hi});
        expect(result.single.translatedText, isNull);
        if (i == 2) expect(models.downloads, isEmpty);
      }
      expect(models.downloads, [(hi, false)]);
      // A missing model isn't checked again on every frame.
      expect(models.checks.where((l) => l == hi), hasLength(1));
      expect((errors.single as ModelNotDownloaded).language, hi);
      expect(translator.translated, isEmpty);
    });
    test('lines translate once the download completes', () async {
      models.downloadGate = Completer<void>();
      for (var i = 0; i < 3; i++) {
        await translate(['नमस्ते'], sourceLanguages: {hi});
      }
      models.downloadGate!.complete();
      await pumpEventQueue();

      final result = await translate(['नमस्ते'], sourceLanguages: {hi});
      expect(result.single.translatedText, '[en] नमस्ते');
      expect(errors, hasLength(1));
    });
    test('a failed download is retried on the next confirmed frame', () async {
      final firstAttempt = models.downloadGate = Completer<void>();
      for (var i = 0; i < 3; i++) {
        await translate(['नमस्ते'], sourceLanguages: {hi});
      }
      firstAttempt.completeError(const ModelNotDownloaded(hi));
      await pumpEventQueue();
      models.downloadGate = Completer<void>();

      await translate(['नमस्ते'], sourceLanguages: {hi});
      await translate(['नमस्ते'], sourceLanguages: {hi});
      expect(models.downloads, [(hi, false), (hi, false)]);
      // Each download started is reported, including the retry.
      expect(errors, hasLength(2));
      expect(errors.map((e) => (e as ModelNotDownloaded).language), [hi, hi]);
    });
    test('five Hindi lines in one frame share one model check', () async {
      models.downloadGate = Completer<void>();
      await translate(
        ['एक', 'दो', 'तीन', 'चार', 'पांच'],
        sourceLanguages: {hi},
      );
      expect(models.checks.where((l) => l == hi), hasLength(1));
      // One frame doesn't confirm a language, however many lines it has.
      expect(models.downloads, isEmpty);
      expect(errors, isEmpty);
    });
    test('a missing target model is downloaded too', () async {
      models.present.remove(en);
      models.downloadGate = Completer<void>();
      identifyAs('Salida', 'es');
      final result = await translate(['Salida']);
      expect(result.single.translatedText, isNull);
      expect(models.downloads, [(en, false)]);
    });

    test('an unsupported language is reported once', () async {
      identifyAs('Lorem ipsum', 'la-Latn');
      for (var i = 0; i < 3; i++) {
        final result = await translate(['Lorem ipsum']);
        expect(result.single.translatedText, isNull);
        expect(result.single.sourceLanguage, 'la-Latn');
      }
      final error = errors.single as UnsupportedLanguagePair;
      expect(error.source, 'la-Latn');
      expect(error.target, en);
    });

    test('one failing line does not stop the others', () async {
      identifyAs('Salida', 'es');
      identifyAs('Entrada', 'es');
      translator.failing.add('Salida');
      final result = await translate(['Salida', 'Entrada']);
      expect(result[0].translatedText, isNull);
      expect(result[1].translatedText, '[en] Entrada');
      expect(errors.single, isA<PipelineFailure>());
    });
  });

  group('download rules', () {
    const sw = TranslateLanguage.swahili;
    const mr = TranslateLanguage.marathi;
    const hindiOrMarathi = {hi, mr};

    Future<void> frames(
      int count,
      List<String> texts, {
      Set<TranslateLanguage>? hint,
    }) async {
      for (var i = 0; i < count; i++) {
        await translate(texts, sourceLanguages: hint);
      }
    }

    test('detected but not expected: downloaded once confirmed', () async {
      models.downloadGate = Completer<void>();
      identifyAs('Tea Ho', 'sw', 0.9);
      await frames(2, ['Tea Ho']);
      expect(models.downloads, isEmpty);
      expect(errors, isEmpty);
      await frames(3, ['Tea Ho']);
      expect(models.downloads, [(sw, false)]);
      expect((errors.single as ModelNotDownloaded).language, sw);
    });

    test('Hindi seen on an English phone downloads Hindi, then translates '
        'it', () async {
      final download = models.downloadGate = Completer<void>();
      identifyAs('नमस्ते', 'hi', 0.9);
      await frames(2, ['नमस्ते']);
      expect(models.downloads, isEmpty);
      await frames(1, ['नमस्ते']);
      expect(models.downloads, [(hi, false)]);

      download.complete();
      await pumpEventQueue();
      final result = await translate(['नमस्ते']);
      expect(result.single.translatedText, '[en] नमस्ते');
    });

    test('automatic downloads use any network and are reported', () async {
      models.present.remove(en);
      models.downloadGate = Completer<void>();
      identifyAs('Salida', 'es');
      await translate(['Salida']);
      expect(models.downloads, [(en, false)]);
      expect((errors.single as ModelNotDownloaded).language, en);
    });

    test('one stray detection starts nothing', () async {
      identifyAs('नमस्कार', 'mr', 0.9);
      await frames(1, ['नमस्कार'], hint: hindiOrMarathi);
      expect(models.downloads, isEmpty);
      expect(errors, isEmpty);
    });

    test('repeated low-confidence detection starts nothing', () async {
      identifyAs('नमस्कार', 'mr', 0.7);
      await frames(5, ['नमस्कार'], hint: hindiOrMarathi);
      expect(models.downloads, isEmpty);
    });

    test('detections too far apart start nothing', () async {
      identifyAs('नमस्कार', 'mr', 0.9);
      for (var frame = 1; frame <= 13; frame++) {
        await translate([
          if (frame == 1 || frame == 7 || frame == 13) 'नमस्कार',
        ], sourceLanguages: hindiOrMarathi);
      }
      expect(models.downloads, isEmpty);
    });

    test('three confident frames within the window start a download', () async {
      models.downloadGate = Completer<void>();
      identifyAs('नमस्कार', 'mr', 0.9);
      for (var frame = 1; frame <= 9; frame++) {
        await translate([
          if (frame == 1 || frame == 5 || frame == 9) 'नमस्कार',
        ], sourceLanguages: hindiOrMarathi);
      }
      expect(models.downloads, [(mr, false)]);
    });

    test('a missing target model downloads at once', () async {
      models.present.remove(en);
      models.downloadGate = Completer<void>();
      identifyAs('Salida', 'es');
      await translate(['Salida']);
      expect(models.downloads, [(en, false)]);
    });

    test(
      'a missing target downloads on the first frame, reported once',
      () async {
        models.present
          ..remove(en)
          ..add(hi);
        models.downloadGate = Completer<void>();
        await translate(['नमस्ते'], sourceLanguages: {hi});
        expect(models.downloads, [(en, false)]);
        expect((errors.single as ModelNotDownloaded).language, en);

        // Later frames neither restart nor re-report the running download.
        await translate(['नमस्ते'], sourceLanguages: {hi});
        expect(models.downloads, hasLength(1));
        expect(errors, hasLength(1));
      },
    );

    test('only one source download runs at a time', () async {
      models.present.remove(es);
      identifyAs('नमस्ते', 'hi');
      identifyAs('Salida', 'es');
      final hindiDownload = models.downloadGate = Completer<void>();
      await frames(3, ['नमस्ते', 'Salida']);
      expect(models.downloads, [(hi, false)]);

      models.downloadGate = Completer<void>();
      hindiDownload.complete();
      await pumpEventQueue();
      await frames(1, ['नमस्ते', 'Salida']);
      expect(models.downloads, [(hi, false), (es, false)]);
    });

    test('stray Marathi on Hindi text downloads only Hindi', () async {
      identifyAs('नमस्ते', 'hi', 0.9);
      identifyAs('धन्यवाद', 'hi', 0.9);
      identifyAs('नमस्कार', 'mr', 0.9);
      await frames(5, ['नमस्ते', 'धन्यवाद', 'नमस्कार']);
      expect(models.downloads, [(hi, false)]);
    });

    test(
      'two languages competing in one script confirm only the leader',
      () async {
        models.present.add(hi);
        identifyAs('नमस्ते', 'hi', 0.9);
        identifyAs('नमस्कार', 'mr', 0.9);
        // Hindi leads 4 frames to Marathi's 3, and is never behind: Hindi is
        // confirmed, Marathi isn't, even on a tie.
        for (final text in [
          'नमस्ते',
          'नमस्ते',
          'नमस्कार',
          'नमस्ते',
          'नमस्कार',
          'नमस्ते',
          'नमस्कार',
        ]) {
          await translate([text]);
        }
        expect(models.downloads, isEmpty);
        final result = await translate(['नमस्कार']);
        expect(result.single.sourceLanguage, 'mr');
        expect(models.downloads, isEmpty);
      },
    );

    test('a stray unsupported tag reports nothing', () async {
      identifyAs('Tea Ho', 'hi-Latn', 0.9);
      await frames(1, ['Tea Ho']);
      expect(errors, isEmpty);
    });

    test('a model the app downloads is used within 10 frames', () async {
      // Too unsure to download automatically, so only the app can fetch it.
      identifyAs('Habari', 'sw', 0.7);
      await frames(3, ['Habari']);
      expect(models.downloads, isEmpty);

      // The app downloads Swahili itself, for example via TranslationModels.
      models.present.add(sw);
      List<LineTranslation> result = const [];
      var waited = 0;
      while (waited < 10) {
        waited++;
        result = await translate(['Habari']);
        if (result.single.translatedText != null) break;
      }
      expect(result.single.translatedText, '[en] Habari');
      expect(waited, lessThanOrEqualTo(10));
      // Only one platform check per 10 frames while it was missing.
      expect(models.checks.where((l) => l == sw), hasLength(2));
    });
  });

  group('long text confirms at once', () {
    const french =
        'On sait depuis longtemps que travailler avec du texte '
        'lisible et contenant du sens est source de distractions';

    test('one read of a long French paragraph starts its download', () async {
      models.present.remove(fr);
      models.downloadGate = Completer<void>();
      identifyAs(french, 'fr', 0.95);
      await translate([french]);
      await pumpEventQueue();
      expect(models.downloads.map((d) => d.$1), [fr]);
      expect(errors.whereType<ModelNotDownloaded>().single.language, fr);
    });

    test('a short line still needs repeated sightings', () async {
      identifyAs('Karibu sana', 'sw');
      await translate(['Karibu sana']);
      await pumpEventQueue();
      expect(models.downloads, isEmpty);
    });

    test('a long line below 0.8 confidence does not confirm', () async {
      models.present.remove(fr);
      identifyAs(french, 'fr', 0.7);
      await translate([french]);
      await pumpEventQueue();
      expect(models.downloads, isEmpty);
    });

    test('the translator says when its own download completes', () async {
      final ready = <TranslateLanguage>[];
      lineTranslator = LineTranslator(
        languageEngine: languages,
        translateEngine: translator,
        modelStore: models,
        onError: errors.add,
        onModelReady: ready.add,
      );
      models.downloadGate = Completer<void>();
      const hindi = 'मेरा नाम राम है और मैं दिल्ली में रहता हूँ यहाँ';
      identifyAs(hindi, 'hi', 0.95);
      await translate([hindi]);
      await pumpEventQueue();
      expect(ready, isEmpty);
      models.downloadGate!.complete();
      await pumpEventQueue();
      expect(ready, [hi]);
    });
  });

  group('prepare', () {
    test('a missing target starts downloading before any frame', () async {
      models.present
        ..remove(en)
        ..add(hi);
      models.downloadGate = Completer<void>();
      lineTranslator.prepare(en);
      await pumpEventQueue();
      expect(models.downloads, [(en, false)]);
      expect((errors.single as ModelNotDownloaded).language, en);

      // The first frame shares the running download instead of starting or
      // reporting another.
      await translate(['नमस्ते'], sourceLanguages: {hi});
      expect(models.downloads, hasLength(1));
      expect(errors, hasLength(1));
    });

    test('a failed check is reported, not thrown', () async {
      models.checkError = StateError('no plugin');
      lineTranslator.prepare(en);
      await pumpEventQueue();
      expect(errors.single, isA<PipelineFailure>());
    });

    test('a present target starts nothing and reports nothing', () async {
      lineTranslator.prepare(en);
      await pumpEventQueue();
      expect(models.checks, [en]);
      expect(models.downloads, isEmpty);
      expect(errors, isEmpty);
    });
  });

  group('one language per script', () {
    test('a stray Marathi guess among Hindi lines follows them', () async {
      models.present.add(hi);
      identifyAs('नमस्ते', 'hi', 0.9);
      identifyAs('धन्यवाद', 'hi', 0.85);
      identifyAs('नमस्कार', 'mr', 0.9);
      final result = await translate(['नमस्ते', 'धन्यवाद', 'नमस्कार']);
      expect(result.map((r) => r.sourceLanguage), ['hi', 'hi', 'hi']);
    });

    test('a line without a qualifying guess stays undetermined', () async {
      identifyAs('Salida', 'es');
      final result = await translate(['Salida', 'OK']);
      expect(result.map((r) => r.sourceLanguage), ['es', null]);
    });

    test('a target-language line is still dropped', () async {
      identifyAs('Salida', 'es', 0.9);
      identifyAs('Entrada', 'es', 0.8);
      identifyAs('Exit', 'en', 0.95);
      final result = await translate(['Salida', 'Entrada', 'Exit']);
      expect(result.map((r) => r.line.text), ['Salida', 'Entrada']);
      expect(result.map((r) => r.sourceLanguage), ['es', 'es']);
    });

    test('scripts are decided separately', () async {
      models.present.add(hi);
      identifyAs('नमस्ते', 'hi');
      identifyAs('Salida', 'es');
      final result = await translate(['नमस्ते', 'Salida']);
      expect(result.map((r) => r.sourceLanguage), ['hi', 'es']);
    });

    test('lorem ipsum beside a Spanish heading', () async {
      identifyAs('Qué es Lorem Ipsum', 'es', 0.9);
      for (final text in ['Lorem ipsum', 'dolor sit', 'amet', 'elit sed']) {
        identifyAs(text, 'la', 0.8);
      }
      final result = await translate([
        'Qué es Lorem Ipsum',
        'Lorem ipsum',
        'dolor sit',
        'amet',
        'elit sed',
      ]);
      expect(result.map((r) => r.sourceLanguage), [
        'es',
        'la',
        'la',
        'la',
        'la',
      ]);
      expect(result.first.translatedText, '[en] Qué es Lorem Ipsum');
    });

    test('only untranslatable guesses still share one language', () async {
      for (final text in ['Lorem ipsum', 'dolor sit', 'amet']) {
        identifyAs(text, 'la');
      }
      final result = await translate(['Lorem ipsum', 'dolor sit', 'amet']);
      expect(result.map((r) => r.sourceLanguage), ['la', 'la', 'la']);
    });

    test('lorem ipsum does not hold back a Spanish download', () async {
      models.present.remove(es);
      models.downloadGate = Completer<void>();
      identifyAs('Salida', 'es', 0.9);
      identifyAs('Lorem ipsum', 'la', 0.9);
      for (var i = 0; i < 3; i++) {
        await translate(['Salida', 'Lorem ipsum']);
      }
      expect(models.downloads, [(es, false)]);
    });
  });

  group('detect-language spec', () {
    test('a single hinted language skips identification', () async {
      final result = await translate(['नमस्ते'], sourceLanguages: {hi});
      expect(result.single.sourceLanguage, 'hi');
      expect(languages.identified, isEmpty);
    });

    test('a single hint skips lines in another script', () async {
      final result = await translate(
        ['en.wikipedia.org/wiki'],
        sourceLanguages: {hi},
      );
      expect(result.single.sourceLanguage, isNull);
      expect(result.single.translatedText, isNull);
      expect(languages.identified, isEmpty);
      expect(models.checks, isEmpty);
    });

    test('a Spanish hint assigns a Latin line without identifying', () async {
      final result = await translate(['Salida'], sourceLanguages: {es});
      expect(result.single.sourceLanguage, 'es');
      expect(languages.identified, isEmpty);
    });

    test('a Spanish hint skips a Devanagari line', () async {
      final result = await translate(['नमस्ते'], sourceLanguages: {es});
      expect(result.single.sourceLanguage, isNull);
      expect(languages.identified, isEmpty);
    });

    test('a single hint accepts a mixed-script line', () async {
      final result = await translate(['दवा 500mg'], sourceLanguages: {hi});
      expect(result.single.sourceLanguage, 'hi');
    });

    test('a single hint in an unread script skips the check', () async {
      final result = await translate(
        ['Exit'],
        sourceLanguages: {TranslateLanguage.arabic},
      );
      expect(result.single.sourceLanguage, 'ar');
    });

    test('several hinted languages run identification', () async {
      identifyAs('नमस्ते', 'hi', 0.55);
      models.present.add(hi);
      final result = await translate(
        ['नमस्ते'],
        sourceLanguages: {hi, TranslateLanguage.marathi},
      );
      expect(languages.identified, ['नमस्ते']);
      expect(result.single.sourceLanguage, 'hi');
    });

    test('a line already in the target language is dropped', () async {
      identifyAs('Exit', 'en');
      identifyAs('Salida', 'es');
      final result = await translate(['Exit', 'Salida']);
      expect(result.map((t) => t.line.text), ['Salida']);
      expect(translator.translated, ['Salida']);
    });
  });

  group('Devanagari fallback', () {
    const mr = TranslateLanguage.marathi;
    const caution = 'सावधान! आगे गहरा पानी है';
    const parking = 'कृपया येथे वाहन उभे करू नये';

    void identify(String text, List<LanguageGuess> guesses) =>
        languages.guesses[text] = guesses;

    test(
      'a Hindi sign identified as Nepali is translated from Hindi',
      () async {
        models.present.add(hi);
        identify(caution, const [
          LanguageGuess('ne', 0.7),
          LanguageGuess('hi', 0.2),
        ]);
        final result = await translate([caution]);
        expect(result.single.sourceLanguage, 'hi');
        expect(result.single.translatedText, '[en] $caution');
      },
    );

    test('Marathi ranked above Hindi gives Marathi', () async {
      identify(parking, const [
        LanguageGuess('ne', 0.6),
        LanguageGuess('mr', 0.3),
        LanguageGuess('hi', 0.1),
      ]);
      final result = await translate([parking]);
      expect(result.single.sourceLanguage, 'mr');
    });

    test('Nepali alone gives Hindi', () async {
      identify(caution, const [LanguageGuess('ne', 0.9)]);
      final result = await translate([caution]);
      expect(result.single.sourceLanguage, 'hi');
    });

    test('a long line confirms Hindi and starts its download', () async {
      models.downloadGate = Completer<void>();
      const notice = 'पुस्तकालय रविवार को बंद रहेगा कृपया किताबें लौटाएँ';
      identify(notice, const [
        LanguageGuess('ne', 0.9),
        LanguageGuess('hi', 0.05),
      ]);
      await translate([notice]);
      await pumpEventQueue();
      expect(models.downloads, [(hi, false)]);
    });

    test('a qualifying translatable guess is used as before', () async {
      models.present.add(hi);
      identify(caution, const [
        LanguageGuess('ne', 0.6),
        LanguageGuess('hi', 0.55),
      ]);
      final frame = await lineTranslator.translateFrame([
        line(caution),
      ], target: en);
      expect(frame.lines.single.sourceLanguage, 'hi');
      // Hindi qualifies on its own, so Nepali is outvoted, not replaced.
      expect(frame.status, const SourceReady(hi));
      expect(models.downloads, isEmpty);
    });

    test('Latin lines do not fall back', () async {
      for (final text in ['Lorem ipsum', 'dolor sit', 'amet']) {
        identifyAs(text, 'la');
      }
      final result = await translate(['Lorem ipsum', 'dolor sit', 'amet']);
      expect(result.map((r) => r.sourceLanguage), ['la', 'la', 'la']);
    });

    test('an undetermined Devanagari line stays undetermined', () async {
      identify(caution, const [
        LanguageGuess('ne', 0.4),
        LanguageGuess('hi', 0.3),
      ]);
      final result = await translate([caution]);
      expect(result.single.sourceLanguage, isNull);
    });

    test('no fallback when the hint has no Devanagari language', () async {
      identify(caution, const [LanguageGuess('ne', 0.9)]);
      final result = await translate([caution], sourceLanguages: {es, fr});
      expect(result.single.sourceLanguage, isNull);
    });

    test('a Hindi and Marathi hint falls back to Hindi', () async {
      identify(caution, const [
        LanguageGuess('ne', 0.9),
        LanguageGuess('hi', 0.1),
        LanguageGuess('mr', 0.05),
      ]);
      final result = await translate([caution], sourceLanguages: {hi, mr});
      expect(result.single.sourceLanguage, 'hi');
    });

    test('a Marathi and Spanish hint falls back to Marathi', () async {
      identify(caution, const [
        LanguageGuess('ne', 0.9),
        LanguageGuess('hi', 0.3),
      ]);
      final result = await translate([caution], sourceLanguages: {mr, es});
      expect(result.single.sourceLanguage, 'mr');
    });
  });

  group('source status', () {
    Future<SourceStatus?> statusOf(
      List<String> texts, {
      TranslateLanguage target = en,
      Set<TranslateLanguage>? sourceLanguages,
      String? current,
    }) async => (await lineTranslator.translateFrame(
      [for (final text in texts) line(text)],
      target: target,
      sourceLanguages: sourceLanguages,
      current: current,
    )).status;

    test('no language gives no status', () async {
      expect(await statusOf(['OK']), isNull);
      expect(await statusOf([]), isNull);
    });

    test('guessed before confirmation', () async {
      models.present.remove(es);
      identifyAs('Salida', 'es');
      expect(await statusOf(['Salida']), const SourceGuessed(es));
      expect(models.downloads, isEmpty);
    });

    test('downloading once confirmed', () async {
      models.present.remove(es);
      models.downloadGate = Completer<void>();
      identifyAs('Salida', 'es');
      await statusOf(['Salida']);
      await statusOf(['Salida']);
      expect(await statusOf(['Salida']), const SourceDownloading(es));
    });

    test('a long paragraph downloads after one read', () async {
      models.present.remove(fr);
      models.downloadGate = Completer<void>();
      const text = 'Il était une fois une princesse très gentille';
      identifyAs(text, 'fr', 0.95);
      expect(await statusOf([text]), const SourceDownloading(fr));
    });

    test('ready when the model is present', () async {
      identifyAs('Salida', 'es');
      expect(await statusOf(['Salida']), const SourceReady(es));
    });

    test('ready for the target when every line is in it', () async {
      identifyAs('Exit', 'en');
      identifyAs('Entrance', 'en');
      expect(await statusOf(['Exit', 'Entrance']), const SourceReady(en));
    });

    test('lines in the target language are not counted', () async {
      identifyAs('Exit', 'en');
      identifyAs('Entrance', 'en');
      identifyAs('नमस्ते', 'hi');
      models.present.add(hi);
      expect(
        await statusOf(['Exit', 'Entrance', 'नमस्ते']),
        const SourceReady(hi),
      );
    });

    test('a Hindi sign identified as Nepali names Hindi, never "ne"', () async {
      models.downloadGate = Completer<void>();
      const caution = 'सावधान! आगे गहरा पानी है';
      languages.guesses[caution] = const [
        LanguageGuess('ne', 0.9),
        LanguageGuess('hi', 0.1),
      ];
      final statuses = [
        for (var i = 0; i < 3; i++) await statusOf([caution]),
      ];
      expect(statuses, [
        const SourceGuessed(hi),
        const SourceGuessed(hi),
        const SourceDownloading(hi),
      ]);
    });

    test('unsupported only once confirmed', () async {
      identifyAs('Lorem ipsum', 'la');
      expect(await statusOf(['Lorem ipsum']), const SourceSearching());
      expect(await statusOf(['Lorem ipsum']), const SourceSearching());
      expect(await statusOf(['Lorem ipsum']), const SourceUnsupported('la'));
    });

    test('download failed, then downloading on the retry', () async {
      models.present.remove(es);
      final first = models.downloadGate = Completer<void>();
      identifyAs('Salida', 'es');
      for (var i = 0; i < 3; i++) {
        await statusOf(['Salida']);
      }
      first.completeError(const ModelNotDownloaded(es));
      await pumpEventQueue();
      models.downloadGate = Completer<void>();
      // The missing model is checked again after confirmWindow frames.
      SourceStatus? status;
      for (var i = 0; i < LineTranslator.confirmWindow; i++) {
        status = await statusOf(['Salida']);
        if (status is SourceDownloading) break;
        expect(status, const SourceDownloadFailed(es));
      }
      expect(status, const SourceDownloading(es));
    });

    test('names the language of the most lines', () async {
      models.present.add(hi);
      for (final text in ['नमस्ते', 'धन्यवाद', 'नमस्कार']) {
        identifyAs(text, 'hi');
      }
      identifyAs('Salida', 'es');
      expect(
        await statusOf(['नमस्ते', 'धन्यवाद', 'नमस्कार', 'Salida']),
        const SourceReady(hi),
      );
    });

    test('a tie keeps the current language', () async {
      models.present.add(hi);
      identifyAs('नमस्ते', 'hi');
      identifyAs('Salida', 'es');
      expect(
        await statusOf(['नमस्ते', 'Salida'], current: 'es'),
        const SourceReady(es),
      );
      expect(await statusOf(['नमस्ते', 'Salida']), const SourceReady(hi));
    });

    test('a single hinted language uses the same stages', () async {
      models.downloadGate = Completer<void>();
      expect(
        await statusOf(['नमस्ते'], sourceLanguages: {hi}),
        const SourceGuessed(hi),
      );
      await statusOf(['नमस्ते'], sourceLanguages: {hi});
      expect(
        await statusOf(['नमस्ते'], sourceLanguages: {hi}),
        const SourceDownloading(hi),
      );
    });

    test('download events are reported', () async {
      final events = <({TranslateLanguage language, ModelEvent event})>[];
      lineTranslator.modelEvents.listen(events.add);
      models.present.remove(es);
      final gate = models.downloadGate = Completer<void>();
      identifyAs('Salida', 'es');
      for (var i = 0; i < 3; i++) {
        await statusOf(['Salida']);
      }
      gate.complete();
      await pumpEventQueue();
      expect(events, [
        (language: es, event: ModelEvent.started),
        (language: es, event: ModelEvent.ready),
      ]);
    });
  });

  group('LineTranslation', () {
    test('has value equality', () {
      LineTranslation make([String? text]) => LineTranslation(
        line: line('Salida'),
        sourceLanguage: 'es',
        translatedText: text,
      );
      expect(make('Exit'), make('Exit'));
      expect(make('Exit').hashCode, make('Exit').hashCode);
      expect(make('Exit'), isNot(make()));
    });

    test('describes itself', () {
      expect(
        LineTranslation(
          line: line('Salida'),
          sourceLanguage: 'es',
          translatedText: 'Exit',
        ).toString(),
        'LineTranslation(Salida [es] -> Exit)',
      );
    });
  });
}
