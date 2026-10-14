import 'dart:async';

import 'package:camera/camera.dart' show CameraImage;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/camera/camera_frame.dart';
import 'package:live_translate/src/controller/live_translate_controller.dart';
import 'package:live_translate/src/controller/live_translate_state.dart';
import 'package:live_translate/src/engines/language_engine.dart';
import 'package:live_translate/src/engines/text_engine.dart';
import 'package:live_translate/src/errors.dart';
import 'package:live_translate/src/geometry/image_rotation.dart';
import 'package:live_translate/src/models/overlay_style.dart';
import 'package:live_translate/src/models/text_script.dart';
import 'package:live_translate/src/models/translated_line.dart';
import 'package:live_translate/src/pipeline/pipeline_metrics.dart';
import 'package:live_translate/src/view/debug_hud.dart';
import 'package:live_translate/src/view/live_translate_view.dart';
import 'package:live_translate/src/view/paragraph_painter.dart';

import '../support/fakes.dart';
import '../support/frames.dart';

// Frames are 1280 × 720, turned 90° clockwise to an upright 720 × 1280, and
// shown in a 360 × 800 view at scale 0.625, offset -45 horizontally. Raw +x
// is upright +y.
const _box = Rect.fromLTRB(100, 200, 300, 260);
const _mappedBox = Rect.fromLTRB(17.5, 125, 142.5, 162.5);
const _below = Rect.fromLTRB(100, 270, 300, 330);

/// A Hindi paragraph long enough to confirm its language in one read.
const _hindi = 'मेरा नाम राम है और मैं दिल्ली में रहता हूँ यहाँ';

// Building a textured frame is slow, so each is built once.
final _images = <(double, double, int), CameraImage>{};

CameraImage _image({double dx = 0, double dy = 0, int seed = 1}) =>
    _images.putIfAbsent((
      dx,
      dy,
      seed,
    ), () => texturedImage(dx: dx, dy: dy, seed: seed));

/// Records every engine the view builds, so tests can inspect and drive
/// them.
final class _Engines {
  final texts = <FakeTextEngine>[];
  final scripts = <Set<TextScript>>[];
  final languages = <FakeLanguageEngine>[];
  final translators = <FakeTranslateEngine>[];
  final models = FakeModelStore()
    ..present.addAll({
      TranslateLanguage.english,
      TranslateLanguage.french,
      TranslateLanguage.german,
      TranslateLanguage.spanish,
      TranslateLanguage.hindi,
    });
  final guesses = <String, List<LanguageGuess>>{
    'Salida': const [LanguageGuess('es', 0.9)],
    'Entrada': const [LanguageGuess('es', 0.9)],
    'Salida de emergencia': const [LanguageGuess('es', 0.9)],
    'नमस्ते': const [LanguageGuess('hi', 0.9)],
    _hindi: const [LanguageGuess('hi', 0.95)],
  };
  List<RecognizedLine> _lines = const [];

  /// When set, every text engine built from now on waits for it.
  Completer<void>? textGate;

  /// Sets the lines every text engine, current and future, recognizes.
  set lines(List<RecognizedLine> lines) {
    _lines = lines;
    for (final text in texts) {
      text.lines = lines;
    }
  }

  /// How many reads all text engines have made.
  int get reads => texts.fold(0, (sum, text) => sum + text.calls);

  LiveTranslateEngines build() => (
    text: (scripts) {
      this.scripts.add(scripts);
      final text = FakeTextEngine()
        ..lines = _lines
        ..gate = textGate;
      texts.add(text);
      return text;
    },
    language: () {
      final language = FakeLanguageEngine()..guesses.addAll(guesses);
      languages.add(language);
      return language;
    },
    translate: () {
      final translator = FakeTranslateEngine();
      translators.add(translator);
      return translator;
    },
    models: models,
  );
}

/// A one-line paragraph; lines in different boxes are separate paragraphs.
RecognizedLine _line(String text, [Rect box = _box]) =>
    RecognizedLine(text: text, box: box, paragraph: box.top.round());

void main() {
  late FakeCameraSession session;
  late _Engines engines;
  late List<LiveTranslateException> errors;
  late DateTime clock;

  setUp(() {
    session = FakeCameraSession();
    engines = _Engines();
    errors = [];
    clock = DateTime(2026);
  });

  Widget app({
    TranslateLanguage target = TranslateLanguage.english,
    bool deviceTarget = false,
    Set<TextScript>? scripts,
    Set<TranslateLanguage>? sourceLanguages,
    LiveTranslateController? controller,
    OverlayStyle style = const OverlayStyle(),
    OverlayBuilder? overlayBuilder,
    ValueChanged<List<TranslatedLine>>? onLinesChanged,
    ValueChanged<List<TranslatedLine>>? onFrozen,
    WidgetBuilder? placeholderBuilder,
    bool showDebugHud = false,
  }) => MaterialApp(
    home: LiveTranslateView(
      targetLanguage: deviceTarget ? null : target,
      scripts: scripts ?? const {TextScript.latin, TextScript.devanagari},
      sourceLanguages: sourceLanguages,
      style: style,
      onError: errors.add,
      overlayBuilder: overlayBuilder,
      onLinesChanged: onLinesChanged,
      onFrozen: onFrozen,
      placeholderBuilder: placeholderBuilder,
      showDebugHud: showDebugHud,
      controller: controller,
      createSession: (_) => session,
      createEngines: engines.build,
      now: () => clock,
    ),
  );

  Future<void> pumpView(WidgetTester tester, [Widget? widget]) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget ?? app());
    await tester.pump();
  }

  /// Delivers one frame 33 ms after the previous one, with its content moved
  /// by ([dx], [dy]) raw pixels from the first scene, or a different scene.
  Future<void> deliver(
    WidgetTester tester, {
    double dx = 0,
    double dy = 0,
    int seed = 1,
    int? generation,
  }) async {
    clock = clock.add(const Duration(milliseconds: 33));
    session.emit(
      CameraFrame(
        image: _image(dx: dx, dy: dy, seed: seed),
        rotation: ImageRotation.deg90,
        generation: generation ?? session.generation,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Holds the camera still for about 400 ms, long enough to settle and
  /// read, and lets the read finish.
  Future<void> settle(
    WidgetTester tester, {
    double dx = 0,
    double dy = 0,
    int seed = 1,
  }) async {
    for (var i = 0; i < 13; i++) {
      await deliver(tester, dx: dx, dy: dy, seed: seed);
    }
    await tester.pump();
  }

  List<ParagraphLabel> labels(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ParagraphPainter,
      ),
    );
    return (paint.painter! as ParagraphPainter).labels;
  }

  Finder spinner() => find.byType(CircularProgressIndicator);

  group('translation', () {
    testWidgets("a paragraph's label covers its text", (tester) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      await settle(tester);
      final label = labels(tester).single;
      expect(label.rect, _mappedBox);
      expect(label.text, '[en] Salida');
      expect(label.opacity, 1);
    });

    testWidgets('an untranslated line has no label', (tester) async {
      engines.lines = [_line('OK')];
      await pumpView(tester);
      await settle(tester);
      expect(labels(tester), isEmpty);
    });

    testWidgets('a translation equal to the line draws no label', (
      tester,
    ) async {
      // Paragraphs are trimmed when their lines are joined.
      engines.guesses['एला'] = const [LanguageGuess('hi', 0.9)];
      engines.lines = [_line(' एला '), _line('Salida', _below)];
      await pumpView(tester);
      engines.translators.single.unchanged.add('एला');
      await settle(tester);
      // The line was translated, but only back to itself.
      expect(engines.translators.single.translated, contains('एला'));
      expect(labels(tester).map((l) => l.text), ['[en] Salida']);
    });

    testWidgets('reads Latin and Devanagari by default', (tester) async {
      await pumpView(tester);
      expect(engines.scripts.single, {TextScript.latin, TextScript.devanagari});
    });

    testWidgets('reads only Latin when asked to', (tester) async {
      await pumpView(tester, app(scripts: const {TextScript.latin}));
      expect(engines.scripts.single, {TextScript.latin});
    });

    testWidgets('both scripts are read in one read', (tester) async {
      engines.lines = [_line('Salida'), _line('नमस्ते', _below)];
      await pumpView(tester);
      await settle(tester);
      expect(engines.reads, 1);
      expect(labels(tester).map((l) => l.text), ['[en] Salida', '[en] नमस्ते']);
    });

    testWidgets('a single source language skips identification', (
      tester,
    ) async {
      engines.lines = [_line('नमस्ते')];
      await pumpView(
        tester,
        app(sourceLanguages: const {TranslateLanguage.hindi}),
      );
      await settle(tester);
      expect(labels(tester).single.text, '[en] नमस्ते');
      expect(engines.languages.single.identified, isEmpty);
    });

    testWidgets("an unsampled page uses the style's colours", (tester) async {
      // A box outside the frame can't be sampled.
      engines.lines = [
        _line('Salida', const Rect.fromLTRB(900, 1500, 1000, 1540)),
      ];
      await pumpView(
        tester,
        app(
          style: const OverlayStyle(
            backgroundColor: Color(0xFFFFEB3B),
            textColor: Color(0xFF000000),
          ),
        ),
      );
      await settle(tester);
      final label = labels(tester).single;
      expect(label.background, const Color(0xFFFFEB3B));
      expect(label.ink, const Color(0xFF000000));
    });
  });

  group('settling', () {
    testWidgets('nothing is read while the camera sweeps', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      for (var i = 0; i < 20; i++) {
        await deliver(tester, dx: i * 20.0);
      }
      expect(engines.reads, 0);
      expect(labels(tester), isEmpty);
    });

    testWidgets('200 ms steady reads nothing; 300 ms reads once', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      for (var i = 0; i < 7; i++) {
        await deliver(tester);
      }
      expect(engines.reads, 0);
      await settle(tester);
      expect(engines.reads, 1);
      expect(labels(tester).single.text, '[en] Salida');
    });

    testWidgets('holding still reads nothing more', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      await settle(tester);
      for (var i = 0; i < 60; i++) {
        await deliver(tester);
      }
      expect(engines.reads, 1);
    });

    testWidgets('held labels follow a drift', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      await settle(tester);
      for (var dx = 10.0; dx <= 30; dx += 10) {
        await deliver(tester, dx: dx);
      }
      // 30 raw pixels right is 30 upright pixels down: 18.75 in the view.
      final rect = labels(tester).single.rect;
      expect(rect.top, closeTo(_mappedBox.top + 18.75, 2));
      expect(rect.left, closeTo(_mappedBox.left, 2));
      expect(engines.reads, 1);
    });

    testWidgets("movement during a read moves that read's labels", (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      engines.texts.single.gate = Completer<void>();
      await settle(tester);
      expect(engines.reads, 1);
      await deliver(tester, dx: 10);
      engines.texts.single.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(labels(tester).single.rect.top, closeTo(_mappedBox.top + 6.25, 2));
    });

    testWidgets('a fast swing fades the labels out', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      await settle(tester);
      await deliver(tester, dx: 150);
      await tester.pump(const Duration(milliseconds: 100));
      expect(labels(tester).single.opacity, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 150));
      expect(labels(tester), isEmpty);
    });

    testWidgets('a new scene fades the labels out', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      await settle(tester);
      await deliver(tester, seed: 7);
      await tester.pump(const Duration(milliseconds: 250));
      expect(labels(tester), isEmpty);
    });

    testWidgets('after a pan the new area is read; old labels stay meanwhile', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      await settle(tester);
      // 256 raw pixels right is 20% of the upright height.
      for (var dx = 32.0; dx <= 256; dx += 32) {
        await deliver(tester, dx: dx);
      }
      engines.lines = [_line('Entrada')];
      engines.texts.single.gate = Completer<void>();
      await settle(tester, dx: 256);
      expect(engines.reads, 2);
      expect(labels(tester).single.text, '[en] Salida');

      engines.texts.single.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(labels(tester).single.text, '[en] Entrada');
    });

    testWidgets('a small drift does not read again', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      await settle(tester);
      // 28 raw pixels down is 4% of the upright width.
      await deliver(tester, dy: 14);
      await deliver(tester, dy: 28);
      await settle(tester, dy: 28);
      expect(engines.reads, 1);
    });

    testWidgets('a completed download reads the held frame again', (
      tester,
    ) async {
      engines.models.present.remove(TranslateLanguage.hindi);
      engines.models.downloadGate = Completer<void>();
      engines.lines = [_line(_hindi)];
      await pumpView(tester);
      await settle(tester);
      expect(engines.models.downloads.map((d) => d.$1), [
        TranslateLanguage.hindi,
      ]);
      expect(labels(tester), isEmpty);

      engines.models.downloadGate!.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(engines.reads, 2);
      expect(labels(tester).single.text, '[en] $_hindi');
    });

    testWidgets('a completed target download reads the held frame again', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      await settle(tester);
      expect(labels(tester).single.text, '[en] Salida');

      engines.models.present.remove(TranslateLanguage.german);
      engines.models.downloadGate = Completer<void>();
      await tester.pumpWidget(app(target: TranslateLanguage.german));
      await tester.pump();
      await tester.pump();
      expect(engines.reads, 2);
      expect(labels(tester), isEmpty);

      // No frames arrive: the camera hasn't moved.
      engines.models.downloadGate!.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(engines.reads, 3);
      expect(labels(tester).single.text, '[de] Salida');
    });

    testWidgets('a download completing during a read reads again after it', (
      tester,
    ) async {
      engines.models.present.remove(TranslateLanguage.hindi);
      engines.models.downloadGate = Completer<void>();
      engines.lines = [
        _line(_hindi),
        _line('Salida', const Rect.fromLTRB(100, 300, 300, 360)),
      ];
      await pumpView(tester);
      final translation = Completer<void>();
      engines.translators.single.gate = translation;
      await settle(tester);
      expect(engines.models.downloads.map((d) => d.$1), [
        TranslateLanguage.hindi,
      ]);

      // The Hindi model arrives while the Spanish paragraph is translated.
      engines.models.downloadGate!.complete();
      await tester.pump();
      translation.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(engines.reads, 2);
      expect(labels(tester).map((label) => label.text), [
        '[en] $_hindi',
        '[en] Salida',
      ]);
    });

    testWidgets('a completed target download reads a frozen frame again', (
      tester,
    ) async {
      final controller = LiveTranslateController();
      addTearDown(controller.dispose);
      engines.lines = [_line('Salida')];
      await pumpView(tester, app(controller: controller));
      await settle(tester);
      await controller.freeze();
      await tester.pump();

      engines.models.present.remove(TranslateLanguage.german);
      engines.models.downloadGate = Completer<void>();
      await controller.setTargetLanguage(TranslateLanguage.german);
      await tester.pump();
      await tester.pump();
      expect(labels(tester), isEmpty);

      engines.models.downloadGate!.complete();
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(labels(tester).single.text, '[de] Salida');
      expect(controller.state, LiveTranslateState.frozen);
    });

    testWidgets('no second read starts while one runs', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      engines.texts.single.gate = Completer<void>();
      await settle(tester);
      for (var i = 0; i < 30; i++) {
        await deliver(tester);
      }
      expect(engines.reads, 1);
      engines.texts.single.gate!.complete();
    });

    testWidgets('a read that ends after backgrounding is not shown', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      engines.texts.single.gate = Completer<void>();
      await settle(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      engines.texts.single.gate!.complete();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(labels(tester), isEmpty);
    });

    testWidgets('a failed read is reported and retried after moving', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      engines.texts.single.error = StateError('recognizer crashed');
      await settle(tester);
      expect(errors.whereType<PipelineFailure>(), hasLength(1));
      expect(labels(tester), isEmpty);

      engines.texts.single.error = null;
      await settle(tester);
      expect(engines.reads, 1);

      await deliver(tester, dx: 40);
      await settle(tester, dx: 40);
      expect(engines.reads, 2);
      expect(labels(tester).single.text, '[en] Salida');
    });

    testWidgets('ignores frames from an older session', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      for (var i = 0; i < 13; i++) {
        await deliver(tester, generation: session.generation - 1);
      }
      expect(engines.reads, 0);
    });
  });

  group('device language', () {
    Future<void> pumpOnDevice(WidgetTester tester, Locale locale) async {
      tester.platformDispatcher.localeTestValue = locale;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await pumpView(tester, app(deviceTarget: true));
    }

    testWidgets('no target on an English phone translates into English', (
      tester,
    ) async {
      engines.lines = [_line('नमस्ते')];
      await pumpOnDevice(tester, const Locale('en', 'US'));
      await settle(tester);
      expect(labels(tester).single.text, '[en] नमस्ते');
    });

    testWidgets('no target on a French phone translates into French', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpOnDevice(tester, const Locale('fr', 'FR'));
      // The French model is checked before any frame arrives.
      expect(engines.models.checks, contains(TranslateLanguage.french));
      await settle(tester);
      expect(labels(tester).single.text, '[fr] Salida');
    });

    testWidgets('a device language without a model falls back to English', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpOnDevice(tester, const Locale('am', 'ET'));
      await settle(tester);
      expect(labels(tester).single.text, '[en] Salida');
    });

    testWidgets('the controller still wins over the device language', (
      tester,
    ) async {
      final controller = LiveTranslateController();
      addTearDown(controller.dispose);
      tester.platformDispatcher.localeTestValue = const Locale('fr', 'FR');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      engines.lines = [_line('Salida')];
      await pumpView(tester, app(deviceTarget: true, controller: controller));
      await controller.setTargetLanguage(TranslateLanguage.german);
      await tester.pump();
      await settle(tester);
      expect(labels(tester).single.text, '[de] Salida');
    });
  });

  group('settings changes', () {
    testWidgets('a new target re-reads the held frame without a restart', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      await settle(tester);
      expect(labels(tester).single.text, '[en] Salida');

      await tester.pumpWidget(app(target: TranslateLanguage.french));
      await tester.pump();
      await tester.pump();

      expect(engines.texts.first.closes, 1);
      expect(engines.languages.first.closes, 1);
      expect(engines.translators.first.closes, 1);
      expect(session.starts, 1);
      expect(labels(tester).single.text, '[fr] Salida');
    });

    testWidgets('a read from before the change is not shown', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      engines.texts.single.gate = Completer<void>();
      await settle(tester);
      await tester.pumpWidget(app(target: TranslateLanguage.french));
      await tester.pump();
      engines.texts.first.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(labels(tester), isEmpty);

      await deliver(tester, dx: 40);
      await settle(tester, dx: 40);
      expect(labels(tester).single.text, '[fr] Salida');
    });

    testWidgets('equal settings keep the engines', (tester) async {
      await pumpView(
        tester,
        app(scripts: const {TextScript.latin, TextScript.devanagari}),
      );
      await tester.pumpWidget(
        app(scripts: {TextScript.devanagari, TextScript.latin}),
      );
      await tester.pump();
      expect(engines.texts, hasLength(1));
      expect(engines.texts.single.closes, 0);
    });

    testWidgets('a new source-language hint replaces the engines', (
      tester,
    ) async {
      await pumpView(tester);
      await tester.pumpWidget(
        app(sourceLanguages: const {TranslateLanguage.hindi}),
      );
      await tester.pump();
      expect(engines.texts, hasLength(2));
      expect(engines.texts.first.closes, 1);
    });
  });

  group('errors', () {
    testWidgets('a camera permission error is reported and shown', (
      tester,
    ) async {
      session.startError = const CameraPermissionDenied();
      await pumpView(tester);
      expect(errors.single, isA<CameraPermissionDenied>());
      expect(find.textContaining('CameraPermissionDenied'), findsOneWidget);
    });

    testWidgets('a missing model is reported once', (tester) async {
      engines.models.present.remove(TranslateLanguage.hindi);
      engines.models.downloadGate = Completer<void>();
      engines.lines = [_line(_hindi)];
      await pumpView(tester);
      await settle(tester);
      // A pan of 160 raw pixels (12.5% of the upright height) reads again.
      for (var dx = 32.0; dx <= 160; dx += 32) {
        await deliver(tester, dx: dx);
      }
      await settle(tester, dx: 160);
      expect(engines.reads, 2);
      expect(engines.models.downloads, hasLength(1));
      final error = errors.single as ModelNotDownloaded;
      expect(error.language, TranslateLanguage.hindi);
      expect(labels(tester), isEmpty);
    });
  });

  group('camera', () {
    testWidgets('shows a placeholder while the camera starts', (tester) async {
      session.startGate = Completer<void>();
      await pumpView(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(FakeCameraSession.previewKey), findsNothing);

      session.startGate!.complete();
      await tester.pump();
      expect(find.byKey(FakeCameraSession.previewKey), findsOneWidget);
    });

    testWidgets('lays out the preview with the shared layout', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester);
      await settle(tester);
      expect(
        tester.getRect(find.byKey(FakeCameraSession.previewKey)),
        const Rect.fromLTRB(-45, 0, 405, 800),
      );
    });

    testWidgets('uses the reported preview size before the first frame', (
      tester,
    ) async {
      await pumpView(tester);
      expect(
        tester.getRect(find.byKey(FakeCameraSession.previewKey)),
        const Rect.fromLTRB(-45, 0, 405, 800),
      );
      expect(labels(tester), isEmpty);
    });

    testWidgets('stops when inactive and restarts the camera', (tester) async {
      await pumpView(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(session.stops, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(session.starts, 2);
      expect(find.byKey(FakeCameraSession.previewKey), findsOneWidget);
    });

    testWidgets('releases every engine and the session on dispose', (
      tester,
    ) async {
      await pumpView(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(engines.texts.single.closes, 1);
      expect(engines.languages.single.closes, 1);
      expect(engines.translators.single.closes, 1);
      expect(session.disposes, 1);
    });
  });

  group('controller', () {
    late LiveTranslateController controller;
    late List<LiveTranslateState> states;

    setUp(() {
      controller = LiveTranslateController();
      states = [];
      controller.addListener(() {
        if (states.isEmpty || states.last != controller.state) {
          states.add(controller.state);
        }
      });
    });

    Future<void> pumpControlled(
      WidgetTester tester, {
      TranslateLanguage target = TranslateLanguage.english,
    }) => pumpView(tester, app(target: target, controller: controller));

    Future<void> freeze(WidgetTester tester) async {
      await controller.freeze();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('reports initializing, then running', (tester) async {
      session.startGate = Completer<void>();
      await pumpControlled(tester);
      expect(controller.state, LiveTranslateState.initializing);
      session.startGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(controller.state, LiveTranslateState.running);
      expect(states, contains(LiveTranslateState.running));
    });

    testWidgets('reports error when permission is denied', (tester) async {
      session.startError = const CameraPermissionDenied();
      await pumpControlled(tester);
      await tester.pump();
      expect(controller.state, LiveTranslateState.error);
    });

    testWidgets('reports any other start failure as CameraUnavailable', (
      tester,
    ) async {
      session.startError = const CameraUnavailable();
      await pumpControlled(tester);
      await tester.pump();
      expect(errors.single, isA<CameraUnavailable>());
      expect(controller.state, LiveTranslateState.error);
      expect(find.text('${const CameraUnavailable()}'), findsOneWidget);
    });

    testWidgets('a failed pause is reported and the view stays frozen', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await settle(tester);
      session.pauseError = const CameraUnavailable();
      await controller.freeze(); // Completes without throwing.
      await tester.pump();
      await tester.pump();
      expect(errors.single, isA<CameraUnavailable>());
      expect(controller.state, LiveTranslateState.frozen);
      expect(labels(tester).single.text, '[en] Salida');
    });

    testWidgets('a failed resume is reported and shows the error state', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await settle(tester);
      await freeze(tester);
      session.resumeError = const CameraUnavailable();
      await controller.resume(); // Completes without throwing.
      await tester.pump();
      await tester.pump();
      expect(errors.single, isA<CameraUnavailable>());
      expect(controller.state, LiveTranslateState.error);
    });

    testWidgets('exposes the shown paragraphs', (tester) async {
      await pumpControlled(tester);
      await tester.pump();
      expect(controller.lines, isEmpty);

      engines.lines = [_line('Salida')];
      await settle(tester);
      await tester.pump();
      final line = controller.lines.single;
      expect(line.rect, _mappedBox);
      expect(line.translatedText, '[en] Salida');
    });

    testWidgets('lines follow the labels', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await settle(tester);
      await deliver(tester, dx: 16);
      await tester.pump();
      // 16 raw pixels right is 10 view pixels down.
      expect(controller.lines.single.rect.top, closeTo(_mappedBox.top + 10, 2));
    });

    testWidgets('lines hold a paragraph as one entry', (tester) async {
      engines.lines = const [
        RecognizedLine(text: 'Salida de', box: _box),
        RecognizedLine(text: 'emergencia', box: _below),
      ];
      await pumpControlled(tester);
      await settle(tester);
      await tester.pump();
      final line = controller.lines.single;
      expect(line.sourceText, 'Salida de emergencia');
      expect(line.translatedText, '[en] Salida de emergencia');
      expect(line.rect, const Rect.fromLTRB(17.5, 125, 142.5, 206.25));
    });

    testWidgets('freezing a held view keeps it without reading', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await settle(tester);
      await deliver(tester, dx: 6);
      await freeze(tester);
      expect(controller.state, LiveTranslateState.frozen);
      expect(session.pauses, 1);
      expect(engines.reads, 1);
      expect(spinner(), findsNothing);
      expect(controller.lines.single.translatedText, '[en] Salida');

      // Frames that still arrive are ignored.
      engines.lines = [_line('Entrada')];
      await deliver(tester, seed: 7);
      expect(controller.lines.single.translatedText, '[en] Salida');
    });

    testWidgets('freezing while moving reads the last frame', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      for (var i = 0; i < 5; i++) {
        await deliver(tester, dx: i * 40.0);
      }
      expect(engines.reads, 0);
      engines.texts.single.gate = Completer<void>();
      await freeze(tester);
      expect(engines.reads, 1);
      expect(spinner(), findsOneWidget);
      expect(controller.lines, isEmpty);

      engines.texts.single.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(spinner(), findsNothing);
      expect(controller.lines.single.translatedText, '[en] Salida');
      expect(controller.lines.single.opacity, 1);
    });

    testWidgets('freezing after a pan reads the last frame', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await settle(tester);
      // 154 raw pixels right is 12% of the upright height.
      for (var dx = 22.0; dx <= 154; dx += 22) {
        await deliver(tester, dx: dx);
      }
      await freeze(tester);
      expect(engines.reads, 2);
      expect(controller.lines.single.rect, _mappedBox);
    });

    testWidgets('freezing while labels fade shows only the frozen frame', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await settle(tester);
      engines.lines = [_line('Entrada', _below)];
      await deliver(tester, seed: 7);
      await tester.pump(const Duration(milliseconds: 100));
      await freeze(tester);
      expect(controller.lines.single.translatedText, '[en] Entrada');
      expect(controller.lines.single.opacity, 1);
    });

    testWidgets('freezing before any frame shows nothing', (tester) async {
      await pumpControlled(tester);
      await freeze(tester);
      expect(controller.state, LiveTranslateState.frozen);
      expect(controller.lines, isEmpty);
      expect(spinner(), findsNothing);
      expect(errors, isEmpty);
    });

    testWidgets('a live read in flight when freezing is not shown', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      engines.texts.single.gate = Completer<void>();
      await settle(tester);
      expect(engines.reads, 1);
      await freeze(tester);
      // The frozen frame is read; the live read's result is dropped.
      expect(engines.reads, 2);
      engines.texts.single.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(controller.lines, hasLength(1));
    });

    testWidgets('a new target while frozen reads the frozen frame again', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await settle(tester);
      await freeze(tester);
      await controller.setTargetLanguage(TranslateLanguage.german);
      await tester.pump();
      await tester.pump();
      expect(controller.lines.single.translatedText, '[de] Salida');
      expect(session.starts, 1);
    });

    testWidgets('resume returns to live translation', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await settle(tester);
      await freeze(tester);
      await controller.resume();
      await tester.pump();
      expect(controller.state, LiveTranslateState.running);
      expect(session.resumes, 1);
      expect(controller.lines, isEmpty);

      engines.lines = [_line('Entrada')];
      await settle(tester);
      await tester.pump();
      expect(controller.lines.single.translatedText, '[en] Entrada');
    });

    testWidgets('resuming mid-read drops that read', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      for (var i = 0; i < 3; i++) {
        await deliver(tester, dx: i * 40.0);
      }
      engines.texts.single.gate = Completer<void>();
      await freeze(tester);
      await controller.resume();
      await tester.pump();
      engines.texts.single.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(controller.lines, isEmpty);
      expect(spinner(), findsNothing);
    });

    testWidgets('a failed frozen read is reported and shows nothing', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await deliver(tester);
      engines.texts.single.error = StateError('recognizer crashed');
      await freeze(tester);
      expect(errors.whereType<PipelineFailure>(), hasLength(1));
      expect(spinner(), findsNothing);
      expect(controller.lines, isEmpty);
      expect(controller.state, LiveTranslateState.frozen);
    });

    testWidgets('freezing twice or resuming while running does nothing', (
      tester,
    ) async {
      await pumpControlled(tester);
      await controller.resume();
      await controller.freeze();
      await controller.freeze();
      await tester.pump();
      expect(session.resumes, 0);
      expect(session.pauses, 1);
    });

    testWidgets('returning from the background while frozen runs live', (
      tester,
    ) async {
      await pumpControlled(tester);
      await controller.freeze();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(controller.state, LiveTranslateState.running);
    });

    testWidgets('setTargetLanguage translates into French without a restart', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await controller.setTargetLanguage(TranslateLanguage.french);
      await tester.pump();
      await settle(tester);
      await tester.pump();
      expect(controller.lines.single.translatedText, '[fr] Salida');
      expect(session.starts, 1);
      expect(engines.translators.first.closes, 1);
    });

    testWidgets('a later widget change wins over the controller', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await controller.setTargetLanguage(TranslateLanguage.french);
      await tester.pumpWidget(
        app(target: TranslateLanguage.german, controller: controller),
      );
      await settle(tester);
      await tester.pump();
      expect(controller.lines.single.translatedText, '[de] Salida');
    });

    testWidgets('an unchanged widget keeps the controller\'s choice', (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpControlled(tester);
      await controller.setTargetLanguage(TranslateLanguage.french);
      await tester.pumpWidget(app(controller: controller));
      await settle(tester);
      await tester.pump();
      expect(controller.lines.single.translatedText, '[fr] Salida');
    });

    testWidgets('setScripts rebuilds the text engine', (tester) async {
      await pumpControlled(tester);
      await controller.setScripts({TextScript.latin});
      await tester.pump();
      expect(engines.scripts.last, {TextScript.latin});
      expect(engines.texts.first.closes, 1);
    });

    testWidgets('setTorch reaches the camera; restarts turn it off', (
      tester,
    ) async {
      await pumpControlled(tester);
      await controller.setTorch(true);
      expect(session.torch, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(session.starts, 2);
      expect(session.torch, isFalse);
    });

    testWidgets('a camera without a torch keeps running', (tester) async {
      session.hasTorch = false;
      await pumpControlled(tester);
      await controller.setTorch(true);
      await tester.pump();
      expect(session.torch, isFalse);
      expect(controller.state, LiveTranslateState.running);
    });

    testWidgets('disposing the view detaches the controller', (tester) async {
      await pumpControlled(tester);
      await tester.pumpWidget(const SizedBox());
      expect(controller.state, LiveTranslateState.initializing);
      await controller.freeze(); // Ignored: no view.
      expect(session.pauses, 0);
    });

    group('target language', () {
      late List<TranslateLanguage?> targets;

      setUp(() {
        targets = [];
        controller.addListener(() {
          if (targets.isEmpty || targets.last != controller.targetLanguage) {
            targets.add(controller.targetLanguage);
          }
        });
      });

      testWidgets('is the device default on a French phone', (tester) async {
        tester.platformDispatcher.localeTestValue = const Locale('fr', 'FR');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        expect(controller.targetLanguage, isNull);
        await pumpView(tester, app(deviceTarget: true, controller: controller));
        expect(controller.targetLanguage, TranslateLanguage.french);
        expect(targets, [TranslateLanguage.french]);
      });

      testWidgets('is the explicit target', (tester) async {
        await pumpControlled(tester, target: TranslateLanguage.german);
        expect(controller.targetLanguage, TranslateLanguage.german);
      });

      testWidgets('follows setTargetLanguage', (tester) async {
        await pumpControlled(tester);
        await controller.setTargetLanguage(TranslateLanguage.french);
        await tester.pump();
        expect(controller.targetLanguage, TranslateLanguage.french);
        expect(targets, [TranslateLanguage.english, TranslateLanguage.french]);
      });

      testWidgets('follows the widget', (tester) async {
        await pumpControlled(tester);
        await tester.pumpWidget(
          app(target: TranslateLanguage.german, controller: controller),
        );
        await tester.pump();
        expect(controller.targetLanguage, TranslateLanguage.german);
        expect(targets, [TranslateLanguage.english, TranslateLanguage.german]);
      });

      testWidgets('is null once the view is removed', (tester) async {
        await pumpControlled(tester);
        await tester.pumpWidget(const SizedBox());
        expect(controller.targetLanguage, isNull);
      });
    });
  });

  group('callbacks', () {
    late List<List<TranslatedLine>> changes;

    setUp(() => changes = []);

    group('onLinesChanged', () {
      testWidgets('reports a translated paragraph without a controller', (
        tester,
      ) async {
        engines.lines = [_line('Salida')];
        await pumpView(tester, app(onLinesChanged: changes.add));
        await settle(tester);
        final line = changes.single.single;
        expect(line.rect, _mappedBox);
        expect(line.translatedText, '[en] Salida');
      });

      testWidgets('reports labels following a shift', (tester) async {
        engines.lines = [_line('Salida')];
        await pumpView(tester, app(onLinesChanged: changes.add));
        await settle(tester);
        await deliver(tester, dx: 16);
        await tester.pump();
        // 16 raw pixels right is 10 view pixels down.
        expect(changes.last.single.rect.top, closeTo(_mappedBox.top + 10, 2));
      });

      testWidgets('reports a fade, then empty lines', (tester) async {
        engines.lines = [_line('Salida')];
        await pumpView(tester, app(onLinesChanged: changes.add));
        await settle(tester);
        await deliver(tester, seed: 7);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(changes.last, isEmpty);
        final opacities = [
          for (final lines in changes)
            if (lines.isNotEmpty) lines.single.opacity,
        ];
        expect(opacities.first, 1);
        expect(opacities.where((o) => o > 0 && o < 1), isNotEmpty);
        for (var i = 1; i < opacities.length; i++) {
          expect(opacities[i], lessThanOrEqualTo(opacities[i - 1]));
        }
      });

      testWidgets('is not called while nothing changes', (tester) async {
        engines.lines = [_line('Salida')];
        await pumpView(tester, app(onLinesChanged: changes.add));
        await tester.pump();
        expect(changes, isEmpty);
        await settle(tester);
        final calls = changes.length;
        for (var i = 0; i < 30; i++) {
          await deliver(tester);
        }
        expect(changes, hasLength(calls));
      });

      testWidgets("matches the controller's lines", (tester) async {
        final controller = LiveTranslateController();
        addTearDown(controller.dispose);
        final notified = <List<TranslatedLine>>[];
        controller.addListener(() {
          if (notified.isEmpty && controller.lines.isEmpty) return;
          if (notified.isEmpty ||
              !listEquals(notified.last, controller.lines)) {
            notified.add(controller.lines);
          }
        });
        engines.lines = [_line('Salida')];
        await pumpView(
          tester,
          app(
            controller: controller,
            onLinesChanged: (lines) {
              expect(lines, controller.lines);
              changes.add(lines);
            },
          ),
        );
        await settle(tester);
        await deliver(tester, dx: 16);
        await deliver(tester, seed: 7);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(changes, hasLength(greaterThan(2)));
        expect(changes, notified);
      });
    });

    group('onFrozen', () {
      late LiveTranslateController controller;
      late List<List<TranslatedLine>> frozen;

      setUp(() {
        controller = LiveTranslateController();
        frozen = [];
      });

      tearDown(() => controller.dispose());

      Future<void> pumpFrozenView(WidgetTester tester) =>
          pumpView(tester, app(controller: controller, onFrozen: frozen.add));

      Future<void> freeze(WidgetTester tester) async {
        await controller.freeze();
        await tester.pump();
        await tester.pump();
      }

      Future<void> move(WidgetTester tester) async {
        for (var i = 0; i < 5; i++) {
          await deliver(tester, dx: i * 40.0);
        }
      }

      testWidgets('reports the kept labels at once', (tester) async {
        engines.lines = [_line('Salida')];
        await pumpFrozenView(tester);
        await settle(tester);
        await freeze(tester);
        final line = frozen.single.single;
        expect(line.translatedText, '[en] Salida');
        expect(line.opacity, 1);
      });

      testWidgets('reports a frozen read once it finishes', (tester) async {
        engines.lines = [_line('Salida')];
        await pumpFrozenView(tester);
        await move(tester);
        engines.texts.single.gate = Completer<void>();
        await freeze(tester);
        expect(frozen, isEmpty);

        engines.texts.single.gate!.complete();
        await tester.pump();
        await tester.pump();
        expect(frozen.single.single.translatedText, '[en] Salida');
      });

      testWidgets('reports empty lines when nothing is found', (tester) async {
        await pumpFrozenView(tester);
        await move(tester);
        await freeze(tester);
        await tester.pump();
        expect(frozen, [isEmpty]);
      });

      testWidgets('reports empty lines when there is no frame', (tester) async {
        await pumpFrozenView(tester);
        await freeze(tester);
        expect(frozen, [isEmpty]);
      });

      testWidgets('is not called when the read fails', (tester) async {
        engines.lines = [_line('Salida')];
        await pumpFrozenView(tester);
        await deliver(tester);
        engines.texts.single.error = StateError('recognizer crashed');
        await freeze(tester);
        await tester.pump();
        expect(frozen, isEmpty);
        expect(errors.whereType<PipelineFailure>(), hasLength(1));
      });

      testWidgets('reports again after a new target', (tester) async {
        engines.lines = [_line('Salida')];
        await pumpFrozenView(tester);
        await settle(tester);
        await freeze(tester);
        expect(frozen, hasLength(1));
        await controller.setTargetLanguage(TranslateLanguage.french);
        await tester.pump();
        await tester.pump();
        expect(frozen, hasLength(2));
        expect(frozen.last.single.translatedText, '[fr] Salida');
      });

      testWidgets('is not called when resumed before the read finishes', (
        tester,
      ) async {
        engines.lines = [_line('Salida')];
        await pumpFrozenView(tester);
        await move(tester);
        engines.texts.single.gate = Completer<void>();
        await freeze(tester);
        await controller.resume();
        await tester.pump();
        engines.texts.single.gate!.complete();
        await tester.pump();
        await tester.pump();
        expect(frozen, isEmpty);
      });
    });

    group('placeholderBuilder', () {
      Widget placeholderApp() =>
          app(placeholderBuilder: (context) => const Text('Starting…'));

      testWidgets('is shown while the camera starts', (tester) async {
        session.startGate = Completer<void>();
        await pumpView(tester, placeholderApp());
        expect(find.text('Starting…'), findsOneWidget);
        expect(spinner(), findsNothing);
        expect(
          tester.getRect(
            find.ancestor(
              of: find.text('Starting…'),
              matching: find.byType(SizedBox),
            ),
          ),
          const Rect.fromLTRB(0, 0, 360, 800),
        );
      });

      testWidgets('is replaced by the preview once started', (tester) async {
        session.startGate = Completer<void>();
        await pumpView(tester, placeholderApp());
        session.startGate!.complete();
        await tester.pump();
        await tester.pump();
        expect(find.byKey(FakeCameraSession.previewKey), findsOneWidget);
        expect(find.text('Starting…'), findsNothing);
      });

      testWidgets('is shown while the camera restarts', (tester) async {
        await pumpView(tester, placeholderApp());
        expect(find.text('Starting…'), findsNothing);
        session.startGate = Completer<void>();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(find.text('Starting…'), findsOneWidget);

        session.startGate!.complete();
        await tester.pump();
        await tester.pump();
        expect(find.text('Starting…'), findsNothing);
        expect(find.byKey(FakeCameraSession.previewKey), findsOneWidget);
      });

      testWidgets('gives way to a camera error', (tester) async {
        session.startError = const CameraPermissionDenied();
        await pumpView(tester, placeholderApp());
        expect(find.textContaining('CameraPermissionDenied'), findsOneWidget);
        expect(find.text('Starting…'), findsNothing);
      });

      // Without a placeholderBuilder, see the camera group's "shows a
      // placeholder while the camera starts".
    });

    group('overlayBuilder', () {
      const overlayKey = Key('overlay');
      late List<List<TranslatedLine>> built;

      setUp(() => built = []);

      Widget overlayApp({LiveTranslateController? controller}) => app(
        controller: controller,
        overlayBuilder: (context, lines) {
          built.add(lines);
          return const SizedBox(key: overlayKey);
        },
      );

      Finder painter() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ParagraphPainter,
      );

      testWidgets('replaces the built-in labels', (tester) async {
        engines.lines = [_line('Salida')];
        await pumpView(tester, overlayApp());
        await settle(tester);
        expect(painter(), findsNothing);
        final line = built.last.single;
        expect(line.rect, _mappedBox);
        expect(line.translatedText, '[en] Salida');
      });

      testWidgets('fills the view, above the preview', (tester) async {
        await pumpView(tester, overlayApp());
        expect(
          tester.getRect(find.byKey(overlayKey)),
          const Rect.fromLTRB(0, 0, 360, 800),
        );
        final stack = tester.widget<Stack>(
          find.ancestor(
            of: find.byKey(overlayKey),
            matching: find.byType(Stack),
          ),
        );
        final keys = [
          for (final child in stack.children)
            if (child is Positioned) child.child.key,
        ];
        expect(keys, [FakeCameraSession.previewKey, overlayKey]);
      });

      testWidgets('is rebuilt as labels follow a shift', (tester) async {
        engines.lines = [_line('Salida')];
        await pumpView(tester, overlayApp());
        await settle(tester);
        await deliver(tester, dx: 16);
        expect(built.last.single.rect.top, closeTo(_mappedBox.top + 10, 2));
      });

      testWidgets('receives fading lines, then none', (tester) async {
        engines.lines = [_line('Salida')];
        await pumpView(tester, overlayApp());
        await settle(tester);
        await deliver(tester, seed: 7);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(
          built.where((l) => l.isNotEmpty && l.single.opacity < 1),
          isNotEmpty,
        );
        expect(built.last, isEmpty);
      });

      testWidgets('does not receive a line translated to itself', (
        tester,
      ) async {
        engines.guesses['एला'] = const [LanguageGuess('hi', 0.9)];
        engines.lines = [_line(' एला '), _line('Salida', _below)];
        await pumpView(tester, overlayApp());
        engines.translators.single.unchanged.add('एला');
        await settle(tester);
        expect(built.last.map((l) => l.translatedText), ['[en] Salida']);
      });

      testWidgets('sits under the frozen-read indicator', (tester) async {
        final controller = LiveTranslateController();
        addTearDown(controller.dispose);
        engines.lines = [_line('Salida')];
        await pumpView(tester, overlayApp(controller: controller));
        for (var i = 0; i < 5; i++) {
          await deliver(tester, dx: i * 40.0);
        }
        engines.texts.single.gate = Completer<void>();
        await controller.freeze();
        await tester.pump();
        expect(built.last, isEmpty);
        expect(spinner(), findsOneWidget);
        final stack = tester.widget<Stack>(
          find.ancestor(of: spinner(), matching: find.byType(Stack)).first,
        );
        expect(stack.children.last, isA<Center>());
        expect(
          stack.children[stack.children.length - 2],
          isA<Positioned>().having((p) => p.child.key, 'key', overlayKey),
        );
        engines.texts.single.gate!.complete();
        await tester.pump();
        await tester.pump();
        expect(built.last.single.translatedText, '[en] Salida');
      });

      // Without an overlayBuilder, the translation group's tests cover the
      // built-in labels.
    });
  });

  group('metrics', () {
    late LiveTranslateController controller;
    late List<PipelineMetrics> metrics;

    setUp(() {
      controller = LiveTranslateController();
      metrics = [];
      controller.metrics.listen(metrics.add);
    });

    tearDown(() => controller.dispose());

    Future<void> pumpMeasured(WidgetTester tester) =>
        pumpView(tester, app(controller: controller));

    Future<void> freeze(WidgetTester tester) async {
      await controller.freeze();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a settled read is reported once', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpMeasured(tester);
      await settle(tester);
      expect(metrics.single.paragraphs, 1);
      expect(metrics.single.frozen, isFalse);
    });

    testWidgets('holding still reports nothing more', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpMeasured(tester);
      await settle(tester);
      for (var i = 0; i < 60; i++) {
        await deliver(tester);
      }
      expect(metrics, hasLength(1));
    });

    testWidgets('a failed read reports nothing', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpMeasured(tester);
      engines.texts.single.error = StateError('recognizer crashed');
      await settle(tester);
      expect(errors.whereType<PipelineFailure>(), isNotEmpty);
      expect(metrics, isEmpty);
    });

    testWidgets('a superseded read reports nothing', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpMeasured(tester);
      await settle(tester);
      engines.textGate = Completer<void>();
      await controller.setTargetLanguage(TranslateLanguage.french);
      await tester.pump();
      await controller.setTargetLanguage(TranslateLanguage.german);
      await tester.pump();
      engines.textGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(controller.lines.single.translatedText, '[de] Salida');
      expect(metrics, hasLength(2));
    });

    testWidgets('freezing a held view reports nothing', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpMeasured(tester);
      await settle(tester);
      await freeze(tester);
      expect(metrics, hasLength(1));
    });

    testWidgets('a live read counts its paragraphs', (tester) async {
      engines.lines = [_line('Salida'), _line('Entrada', _below)];
      await pumpMeasured(tester);
      await settle(tester);
      expect(metrics.single.paragraphs, 2);
      expect(metrics.single.frozen, isFalse);
    });

    testWidgets('a frozen read says so', (tester) async {
      engines.lines = [_line('Salida')];
      await pumpMeasured(tester);
      for (var i = 0; i < 5; i++) {
        await deliver(tester, dx: i * 40.0);
      }
      await freeze(tester);
      await tester.pump();
      expect(metrics.single.frozen, isTrue);
      expect(metrics.single.paragraphs, 1);
    });
  });

  group('debug HUD', () {
    Finder hud() => find.byType(DebugHud);

    String hudText(WidgetTester tester) => tester
        .widget<Text>(find.descendant(of: hud(), matching: find.byType(Text)))
        .data!;

    testWidgets('is off by default', (tester) async {
      await pumpView(tester);
      expect(hud(), findsNothing);
    });

    testWidgets('says when nothing has been read', (tester) async {
      await pumpView(tester, app(showDebugHud: true));
      await deliver(tester);
      expect(hudText(tester), startsWith('no read yet\n'));
      expect(hudText(tester), endsWith(' fps'));
    });

    testWidgets("shows the latest read's times, without a controller", (
      tester,
    ) async {
      engines.lines = [_line('Salida')];
      await pumpView(tester, app(showDebugHud: true));
      engines.texts.single.gate = Completer<void>();
      engines.translators.single.gate = Completer<void>();
      // Hold still until the read starts, then let each stage take time.
      for (var i = 0; i < 20 && engines.reads == 0; i++) {
        await deliver(tester);
      }
      expect(engines.reads, 1);
      clock = clock.add(const Duration(milliseconds: 120));
      engines.texts.single.gate!.complete();
      await tester.pump();
      clock = clock.add(const Duration(milliseconds: 80));
      engines.translators.single.gate!.complete();
      await tester.pump();
      await tester.pump();

      final lines = hudText(tester).split('\n');
      expect(lines[0], 'read 200 ms');
      expect(lines[1], 'ocr 120 · translate 80 · colours 0');
      expect(lines[2], startsWith('1 paragraph · '));
    });

    testWidgets('counts the live frames of the last second', (tester) async {
      await pumpView(tester, app(showDebugHud: true));
      for (var i = 0; i < 60; i++) {
        await deliver(tester);
      }
      final fps = int.parse(
        RegExp(r'(\d+) fps').firstMatch(hudText(tester))!.group(1)!,
      );
      expect(fps, inInclusiveRange(29, 31));
    });

    testWidgets('falls to 0 fps while frozen', (tester) async {
      final controller = LiveTranslateController();
      addTearDown(controller.dispose);
      await pumpView(tester, app(controller: controller, showDebugHud: true));
      for (var i = 0; i < 30; i++) {
        await deliver(tester);
      }
      await controller.freeze();
      await tester.pump();
      clock = clock.add(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(hudText(tester), endsWith('· 0 fps'));
    });

    testWidgets('is drawn above a custom overlay', (tester) async {
      const overlayKey = Key('overlay');
      await pumpView(
        tester,
        app(
          showDebugHud: true,
          overlayBuilder: (context, lines) => const SizedBox(key: overlayKey),
        ),
      );
      final stack = tester.widget<Stack>(
        find.ancestor(of: hud(), matching: find.byType(Stack)).first,
      );
      expect(stack.children.last, isA<DebugHud>());
      expect(
        stack.children.indexWhere(
          (child) => child is Positioned && child.child.key == overlayKey,
        ),
        lessThan(stack.children.length - 1),
      );
    });

    testWidgets('is not shown while the camera starts', (tester) async {
      session.startGate = Completer<void>();
      await pumpView(tester, app(showDebugHud: true));
      expect(hud(), findsNothing);
      expect(spinner(), findsOneWidget);
      session.startGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(hud(), findsOneWidget);
    });

    testWidgets('leaves no timer running once removed', (tester) async {
      await pumpView(tester, app(showDebugHud: true));
      await tester.pumpWidget(const SizedBox());
      // The test framework fails the test if the HUD's timer is still
      // pending once the view is gone.
    });

    testWidgets('turning it off removes it and its timer', (tester) async {
      await pumpView(tester, app(showDebugHud: true));
      expect(hud(), findsOneWidget);
      await tester.pumpWidget(app());
      expect(hud(), findsNothing);
    });
  });
}
