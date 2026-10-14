import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/camera/camera_frame.dart';
import 'package:live_translate/src/engines/language_engine.dart';
import 'package:live_translate/src/engines/text_engine.dart';
import 'package:live_translate/src/errors.dart';
import 'package:live_translate/src/geometry/image_rotation.dart';
import 'package:live_translate/src/pipeline/line_translator.dart';
import 'package:live_translate/src/pipeline/pipeline.dart';

import '../support/fakes.dart';
import '../support/frames.dart';

CameraFrame frame({int planes = 1, int generation = 1}) => CameraFrame(
  image: cameraImage(planes: planes),
  rotation: ImageRotation.deg90,
  generation: generation,
);

RecognizedLine line(String text) =>
    RecognizedLine(text: text, box: const Rect.fromLTRB(10, 10, 60, 30));

void main() {
  late FakeTextEngine text;
  late FakeLanguageEngine languages;
  late FakeTranslateEngine translator;
  late FakeModelStore models;
  late Pipeline pipeline;
  late List<LiveTranslateException> errors;
  late List<TranslateLanguage> ready;

  Pipeline build(TranslateLanguage target) => Pipeline(
    textEngine: text,
    createTranslator: (onError, onModelReady) => LineTranslator(
      languageEngine: languages,
      translateEngine: translator,
      modelStore: models,
      onError: onError,
      onModelReady: onModelReady,
    ),
    target: target,
  );

  setUp(() {
    text = FakeTextEngine();
    languages = FakeLanguageEngine()
      ..guesses['Salida'] = const [LanguageGuess('es', 0.9)]
      ..guesses['Exit'] = const [LanguageGuess('en', 0.9)]
      ..guesses['नमस्ते'] = const [LanguageGuess('hi', 0.9)];
    translator = FakeTranslateEngine();
    models = FakeModelStore()
      ..present.addAll({TranslateLanguage.english, TranslateLanguage.spanish});
    pipeline = build(TranslateLanguage.english);
    errors = [];
    ready = [];
    pipeline.errors.listen(errors.add);
    pipeline.modelsReady.listen(ready.add);
  });

  tearDown(() => pipeline.dispose());

  test('a new pipeline downloads a missing target straight away', () async {
    models.downloadGate = Completer<void>();
    final french = build(TranslateLanguage.french);
    final frenchErrors = <LiveTranslateException>[];
    final frenchReady = <TranslateLanguage>[];
    french.errors.listen(frenchErrors.add);
    french.modelsReady.listen(frenchReady.add);
    await pumpEventQueue();
    expect(models.downloads, [(TranslateLanguage.french, false)]);
    expect(
      (frenchErrors.single as ModelNotDownloaded).language,
      TranslateLanguage.french,
    );

    models.downloadGate!.complete();
    await pumpEventQueue();
    expect(frenchReady, [TranslateLanguage.french]);
    await french.dispose();
  });

  test('a paragraph waiting for its model is listed as untranslated', () async {
    models.downloadGate = Completer<void>();
    text.lines = [line('नमस्ते')];
    // Three reads confirm a short Hindi line and start its download.
    for (var i = 0; i < 3; i++) {
      final result = (await pipeline.read(frame()))!;
      expect(result.paragraphs, isEmpty);
      expect(result.untranslatedLanguages, {'hi'});
    }
    await pumpEventQueue();
    expect(models.downloads.map((d) => d.$1), [TranslateLanguage.hindi]);
  });

  test('a paragraph waiting for the target model lists the target', () async {
    models.downloadGate = Completer<void>();
    final german = build(TranslateLanguage.german);
    text.lines = [line('Salida')];
    final result = (await german.read(frame()))!;
    expect(result.paragraphs, isEmpty);
    expect(result.untranslatedLanguages, containsAll(['es', 'de']));
    await german.dispose();
  });

  test('a fully translated read lists nothing untranslated', () async {
    text.lines = [line('Salida')];
    final result = (await pipeline.read(frame()))!;
    expect(result.paragraphs, hasLength(1));
    expect(result.untranslatedLanguages, isEmpty);
  });

  group('read', () {
    const first = Rect.fromLTRB(10, 10, 300, 30);
    const second = Rect.fromLTRB(10, 34, 260, 54);

    setUp(() {
      languages.guesses['On sait depuis avec du texte'] = const [
        LanguageGuess('fr', 0.9),
      ];
      languages.guesses['Pourquoi'] = const [LanguageGuess('fr', 0.9)];
      models.present.add(TranslateLanguage.french);
    });

    test('translates a paragraph as one joined text', () async {
      text.lines = const [
        RecognizedLine(text: 'On sait depuis', box: first, paragraph: 3),
        RecognizedLine(text: 'avec du texte', box: second, paragraph: 3),
      ];
      final result = (await pipeline.read(frame()))!;

      final paragraph = result.paragraphs.single;
      expect(paragraph.sourceText, 'On sait depuis avec du texte');
      expect(paragraph.translatedText, '[en] On sait depuis avec du texte');
      expect(paragraph.sourceLanguage, 'fr');
      expect(paragraph.box, first.expandToInclude(second));
      expect(paragraph.lineBoxes, [first, second]);
      expect(result.imageSize, const Size(1280, 720));
      expect(result.rotation, ImageRotation.deg90);
      expect(text.calls, 1);
    });

    test('keeps separate paragraphs apart', () async {
      text.lines = const [
        RecognizedLine(text: 'Pourquoi', box: first),
        RecognizedLine(text: 'Salida', box: second, paragraph: 1),
      ];
      final result = (await pipeline.read(frame()))!;
      expect(result.paragraphs.map((p) => p.sourceText), [
        'Pourquoi',
        'Salida',
      ]);
    });

    test('leaves out a paragraph already in the target language', () async {
      text.lines = const [
        RecognizedLine(text: 'Exit', box: first),
        RecognizedLine(text: 'Salida', box: second, paragraph: 1),
      ];
      final result = (await pipeline.read(frame()))!;
      expect(result.paragraphs.map((p) => p.sourceText), ['Salida']);
    });

    test('throws when recognition fails', () async {
      text.error = StateError('recognizer crashed');
      await expectLater(pipeline.read(frame()), throwsStateError);
      expect(errors, isEmpty);
    });

    test('gives nothing for an unsupported frame', () async {
      expect(await pipeline.read(frame(planes: 3)), isNull);
    });
  });

  group('timings', () {
    const first = Rect.fromLTRB(10, 10, 300, 30);
    const second = Rect.fromLTRB(10, 34, 260, 54);
    late DateTime clock;
    late Pipeline timed;

    setUp(() {
      clock = DateTime(2026);
      timed = Pipeline(
        textEngine: text,
        createTranslator: (onError, onModelReady) => LineTranslator(
          languageEngine: languages,
          translateEngine: translator,
          modelStore: models,
          onError: onError,
          onModelReady: onModelReady,
        ),
        target: TranslateLanguage.english,
        now: () => clock,
      );
    });

    tearDown(() => timed.dispose());

    test('times recognition and translation', () async {
      text.lines = [line('Salida')];
      text.gate = Completer<void>();
      translator.gate = Completer<void>();
      final reading = timed.read(frame());
      await pumpEventQueue();
      clock = clock.add(const Duration(milliseconds: 120));
      text.gate!.complete();
      await pumpEventQueue();
      clock = clock.add(const Duration(milliseconds: 80));
      translator.gate!.complete();
      final timings = (await reading)!.timings;

      expect(timings.recognition, const Duration(milliseconds: 120));
      expect(timings.translation, const Duration(milliseconds: 80));
      expect(timings.sampling, Duration.zero);
      expect(timings.total, const Duration(milliseconds: 200));
    });

    test('adds up the sampling of every paragraph', () async {
      // Every reading of the clock moves it on 5 ms.
      final ticking = Pipeline(
        textEngine: text,
        createTranslator: (onError, onModelReady) => LineTranslator(
          languageEngine: languages,
          translateEngine: translator,
          modelStore: models,
          onError: onError,
          onModelReady: onModelReady,
        ),
        target: TranslateLanguage.english,
        now: () => clock = clock.add(const Duration(milliseconds: 5)),
      );
      addTearDown(ticking.dispose);
      languages.guesses['Entrada'] = const [LanguageGuess('es', 0.9)];
      text.lines = const [
        RecognizedLine(text: 'Salida', box: first),
        RecognizedLine(text: 'Entrada', box: second, paragraph: 1),
      ];
      final result = (await ticking.read(frame()))!;
      final timings = result.timings;

      expect(result.paragraphs, hasLength(2));
      // Two paragraphs, each sampled between two readings 5 ms apart.
      expect(timings.sampling, const Duration(milliseconds: 10));
      expect(
        timings.total,
        greaterThanOrEqualTo(
          timings.recognition + timings.translation + timings.sampling,
        ),
      );
    });

    test('a read without text spends nothing on translation', () async {
      text.gate = Completer<void>();
      final reading = timed.read(frame());
      await pumpEventQueue();
      clock = clock.add(const Duration(milliseconds: 40));
      text.gate!.complete();
      final timings = (await reading)!.timings;

      expect(timings.recognition, const Duration(milliseconds: 40));
      expect(timings.translation, Duration.zero);
      expect(timings.sampling, Duration.zero);
      expect(timings.total, greaterThanOrEqualTo(timings.recognition));
    });
  });
}
