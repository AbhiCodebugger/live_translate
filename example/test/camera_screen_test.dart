// The tests read the view's painted labels and fake language guesses from
// src/, and fake models through the package's internal test seams.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/live_translate.dart';
import 'package:live_translate/src/engines/language_engine.dart';
import 'package:live_translate/src/view/debug_hud.dart';
import 'package:live_translate/src/view/paragraph_painter.dart';
import 'package:live_translate_example/camera_screen.dart';
import 'package:live_translate_example/models_screen.dart';

import 'support/fakes.dart';

void main() {
  late FakeModelStore store;
  late FakeCameraSession session;
  late FakeScene scene;

  setUp(() {
    store = FakeModelStore()..present.add(TranslateLanguage.english);
    session = FakeCameraSession();
    scene = FakeScene();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(400, 860)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: CameraScreen(
          models: TranslationModels.withStore(store),
          buildView: fakeView(session, () => fakeEngines(store, scene)),
        ),
      ),
    );
    // The camera starts, then the controller hears about it after a frame.
    await tester.pump();
    await tester.pump();
  }

  LiveTranslateView view(WidgetTester tester) =>
      tester.widget(find.byType(LiveTranslateView));

  Finder chip(String key) => find.byKey(Key(key));

  Finder spinnerIn(String key) => find.descendant(
    of: chip(key),
    matching: find.byType(CircularProgressIndicator),
  );

  /// Lets a page transition finish. A download spinner keeps animating, so
  /// `pumpAndSettle` would never return.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Opens the picker from [key]'s chip and chooses [name].
  Future<void> choose(WidgetTester tester, String key, String name) async {
    await tester.tap(chip(key));
    await settle(tester);
    await tester.enterText(find.byType(TextField), name);
    await tester.pump();
    await tester.tap(find.widgetWithText(ListTile, name));
    await settle(tester);
  }

  /// Delivers three camera frames, spaced past the view's frame throttle,
  /// which reads the real clock.
  /// Holds the camera still over [scene] for 4 frames, 210 ms apart in real
  /// time: long enough to settle (300 ms) and read once.
  Future<void> deliverFrames(
    WidgetTester tester, {
    int count = 4,
    int scene = 0,
  }) async {
    for (var i = 0; i < count; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 210)),
      );
      session.emit(scene: scene);
      await tester.pump();
      await tester.pump();
    }
    // The read's result is drawn, then published to the controller after a
    // frame, then shown on the chips.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the Lens-style controls over the camera', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Live Translate'), findsOneWidget);
    expect(find.byTooltip('Torch on'), findsOneWidget);
    expect(
      find.descendant(
        of: chip('source-chip'),
        matching: find.text('Looking for text…'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chip('target-chip'), matching: find.text('English')),
      findsOneWidget,
    );
    expect(find.byTooltip('Freeze'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('streams at high resolution', (tester) async {
    await pumpScreen(tester);
    expect(view(tester).resolution, ResolutionPreset.high);
  });

  /// Holds one Spanish line still and returns its label, which the fake
  /// translator tags with the target language.
  Future<String> heldLabel(WidgetTester tester) async {
    store.present.add(TranslateLanguage.spanish);
    scene
      ..lines = ['Salida']
      ..guesses = {
        'Salida': const [LanguageGuess('es', 0.9)],
      };
    await deliverFrames(tester);
    final labels = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ParagraphPainter,
      ),
    );
    return (labels.painter! as ParagraphPainter).labels.single.text;
  }

  group('starting target', () {
    testWidgets('a French phone translates into French', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('fr', 'FR');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      store.present.add(TranslateLanguage.french);
      await pumpScreen(tester);
      expect(
        find.descendant(of: chip('target-chip'), matching: find.text('French')),
        findsOneWidget,
      );
      expect(await heldLabel(tester), '[french] Salida');
    });

    testWidgets('a language without a model falls back to English', (
      tester,
    ) async {
      tester.platformDispatcher.localeTestValue = const Locale('am', 'ET');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await pumpScreen(tester);
      expect(
        find.descendant(
          of: chip('target-chip'),
          matching: find.text('English'),
        ),
        findsOneWidget,
      );
      expect(await heldLabel(tester), '[english] Salida');
    });
  });

  group('target picker', () {
    testWidgets('choosing German translates into German', (tester) async {
      store.present.add(TranslateLanguage.german);
      await pumpScreen(tester);
      await choose(tester, 'target-chip', 'German');

      expect(
        find.descendant(of: chip('target-chip'), matching: find.text('German')),
        findsOneWidget,
      );
      expect(await heldLabel(tester), '[german] Salida');
      expect(session.starts, 1);
    });

    testWidgets('going back changes nothing', (tester) async {
      await pumpScreen(tester);
      await tester.tap(chip('target-chip'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: chip('target-chip'),
          matching: find.text('English'),
        ),
        findsOneWidget,
      );
      expect(await heldLabel(tester), '[english] Salida');
    });
  });

  group('source picker', () {
    testWidgets('Hindi reads only Devanagari', (tester) async {
      await pumpScreen(tester);
      await choose(tester, 'source-chip', 'Hindi');
      expect(
        find.descendant(of: chip('source-chip'), matching: find.text('Hindi')),
        findsOneWidget,
      );
      expect(view(tester).sourceLanguages, {TranslateLanguage.hindi});
      expect(view(tester).scripts, {TextScript.devanagari});
      expect(session.starts, 1);
    });

    testWidgets('Spanish reads only Latin', (tester) async {
      await pumpScreen(tester);
      await choose(tester, 'source-chip', 'Spanish');
      expect(view(tester).sourceLanguages, {TranslateLanguage.spanish});
      expect(view(tester).scripts, {TextScript.latin});
    });

    testWidgets('Detect language reads both scripts', (tester) async {
      await pumpScreen(tester);
      await choose(tester, 'source-chip', 'Spanish');
      await choose(tester, 'source-chip', 'Detect language');
      expect(view(tester).sourceLanguages, isNull);
      expect(view(tester).scripts, {TextScript.latin, TextScript.devanagari});
    });
  });

  testWidgets('the shutter freezes and shows the still result, then resumes', (
    tester,
  ) async {
    store.present.add(TranslateLanguage.french);
    scene
      ..lines = ['Pourquoi l’utiliser ?']
      ..guesses = {
        'Pourquoi l’utiliser ?': const [LanguageGuess('fr', 0.9)],
      };
    await pumpScreen(tester);
    // Held still, so the labels are already showing when the shutter keeps
    // them.
    await deliverFrames(tester);
    await tester.tap(find.byTooltip('Freeze'));
    await tester.pump();
    await tester.pump();
    expect(session.pauses, 1);
    expect(find.byTooltip('Resume'), findsOneWidget);
    final still = tester.widget<CustomPaint>(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ParagraphPainter,
      ),
    );
    expect(
      (still.painter! as ParagraphPainter).labels.single.text,
      '[english] Pourquoi l’utiliser ?',
    );

    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    await tester.pump();
    expect(session.resumes, 1);
    expect(find.byTooltip('Freeze'), findsOneWidget);
  });

  testWidgets('the flash toggle resets when the camera restarts', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('Torch on'));
    await tester.pump();
    expect(session.torch, isTrue);
    expect(find.byTooltip('Torch off'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(session.starts, 2);
    expect(session.torch, isFalse);
    expect(find.byTooltip('Torch on'), findsOneWidget);
  });

  group('detected language', () {
    Finder sourceChipReads(String name) =>
        find.descendant(of: chip('source-chip'), matching: find.text(name));

    /// A French page, with both models present.
    void frenchPage() {
      store.present.add(TranslateLanguage.french);
      scene
        ..lines = ['Pourquoi l’utiliser ?', 'Elle a pour avantage']
        ..guesses = {
          'Pourquoi l’utiliser ?': const [LanguageGuess('fr', 0.9)],
          'Elle a pour avantage': const [LanguageGuess('fr', 0.9)],
        };
    }

    testWidgets('names the language of the shown lines', (tester) async {
      frenchPage();
      await pumpScreen(tester);
      expect(sourceChipReads('Looking for text…'), findsOneWidget);

      await deliverFrames(tester);
      expect(sourceChipReads('French'), findsOneWidget);
      expect(
        find.descendant(
          of: chip('source-chip'),
          matching: find.byIcon(Icons.auto_awesome),
        ),
        findsOneWidget,
      );
    });

    testWidgets('mixed lines name the most common language', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('fr', 'FR');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      store.present.addAll({TranslateLanguage.french, TranslateLanguage.hindi});
      scene
        ..lines = ['दवा की दुकान', 'मेरा नाम', 'नमस्ते दुनिया', 'Pharmacy']
        ..guesses = {
          'दवा की दुकान': const [LanguageGuess('hi', 0.9)],
          'मेरा नाम': const [LanguageGuess('hi', 0.9)],
          'नमस्ते दुनिया': const [LanguageGuess('hi', 0.9)],
          'Pharmacy': const [LanguageGuess('en', 0.9)],
        };
      await pumpScreen(tester);
      await deliverFrames(tester);
      expect(sourceChipReads('Hindi'), findsOneWidget);
    });

    testWidgets('goes back to looking for text when the lines leave', (
      tester,
    ) async {
      frenchPage();
      await pumpScreen(tester);
      await deliverFrames(tester);
      expect(sourceChipReads('French'), findsOneWidget);

      // Pointing the camera somewhere else fades the labels out.
      scene.lines = const [];
      await deliverFrames(tester, count: 1, scene: 1);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      await tester.pump();
      expect(sourceChipReads('Looking for text…'), findsOneWidget);
    });

    testWidgets('a guess is shown before it is confirmed', (tester) async {
      scene
        ..lines = ['Salida']
        ..guesses = {
          'Salida': const [LanguageGuess('es', 0.9)],
        };
      await pumpScreen(tester);
      await deliverFrames(tester);
      expect(sourceChipReads('Spanish?'), findsOneWidget);
      expect(store.downloads, isEmpty);
    });

    testWidgets('a confirmed language shows its download', (tester) async {
      const text = 'Salida de emergencia por la escalera';
      scene
        ..lines = [text]
        ..guesses = {
          text: const [LanguageGuess('es', 0.95)],
        };
      await pumpScreen(tester);
      await deliverFrames(tester);
      expect(sourceChipReads('Spanish'), findsOneWidget);
      expect(spinnerIn('source-chip'), findsOneWidget);
    });

    testWidgets('a failed download says so', (tester) async {
      const text = 'Salida de emergencia por la escalera';
      store.downloadError = const ModelNotDownloaded(TranslateLanguage.spanish);
      scene
        ..lines = [text]
        ..guesses = {
          text: const [LanguageGuess('es', 0.95)],
        };
      await pumpScreen(tester);
      await deliverFrames(tester);
      // The download started in the real async zone the frames are
      // delivered from, so it fails there.
      await tester.runAsync(() async {
        store.downloadGate.complete();
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(sourceChipReads('Spanish · download failed'), findsOneWidget);
    });

    testWidgets('nothing readable is not found after three reads', (
      tester,
    ) async {
      scene.lines = const [];
      await pumpScreen(tester);
      await deliverFrames(tester, count: 14);
      expect(sourceChipReads('No supported text found'), findsOneWidget);
    });

    testWidgets('an untranslatable language is named', (tester) async {
      scene
        ..lines = ['Lorem ipsum']
        ..guesses = {
          'Lorem ipsum': const [LanguageGuess('la', 0.9)],
        };
      await pumpScreen(tester);
      await deliverFrames(tester, count: 14);
      expect(sourceChipReads("Latin can't be translated"), findsOneWidget);
    });

    testWidgets('keeps the language while frozen', (tester) async {
      frenchPage();
      await pumpScreen(tester);
      await deliverFrames(tester);
      await tester.tap(find.byTooltip('Freeze'));
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Resume'), findsOneWidget);
      expect(sourceChipReads('French'), findsOneWidget);
    });

    testWidgets('a chosen language replaces the detected one', (tester) async {
      frenchPage();
      await pumpScreen(tester);
      await deliverFrames(tester);
      await choose(tester, 'source-chip', 'Spanish');
      expect(sourceChipReads('Spanish'), findsOneWidget);
      expect(
        find.descendant(
          of: chip('source-chip'),
          matching: find.byIcon(Icons.auto_awesome),
        ),
        findsNothing,
      );
    });

    testWidgets('the picker still has Detect language selected', (
      tester,
    ) async {
      frenchPage();
      await pumpScreen(tester);
      await deliverFrames(tester);
      expect(sourceChipReads('French'), findsOneWidget);

      await tester.tap(chip('source-chip'));
      await settle(tester);
      final selected = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Detect language'),
      );
      expect(selected.selected, isTrue);
    });
  });

  group('downloads', () {
    testWidgets('a missing target model shows on the target chip', (
      tester,
    ) async {
      await pumpScreen(tester);
      await choose(tester, 'target-chip', 'German');
      expect(store.downloads, [TranslateLanguage.german]);
      expect(spinnerIn('target-chip'), findsOneWidget);
      expect(spinnerIn('source-chip'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);

      // Not there yet on the first check.
      await tester.pump(modelPollInterval);
      expect(spinnerIn('target-chip'), findsOneWidget);

      store.present.add(TranslateLanguage.german);
      await tester.pump(modelPollInterval);
      await tester.pump();
      expect(spinnerIn('target-chip'), findsNothing);
    });

    testWidgets('a detected language shows on the source chip', (tester) async {
      // Long enough (20 letters or more) to confirm Hindi in one read.
      const hindi = 'मेरा नाम राम है और मैं दिल्ली में रहता हूँ यहाँ';
      scene
        ..lines = [hindi]
        ..guesses = {
          hindi: const [LanguageGuess('hi', 0.9)],
        };
      await pumpScreen(tester);
      await deliverFrames(tester);
      expect(store.downloads, [TranslateLanguage.hindi]);
      expect(spinnerIn('source-chip'), findsOneWidget);
      expect(spinnerIn('target-chip'), findsNothing);

      store.present.add(TranslateLanguage.hindi);
      await tester.pump(modelPollInterval);
      await tester.pump();
      expect(spinnerIn('source-chip'), findsNothing);
    });

    testWidgets('changing the target moves its download to the source chip', (
      tester,
    ) async {
      store.present.add(TranslateLanguage.french);
      await pumpScreen(tester);
      await choose(tester, 'target-chip', 'German');
      expect(spinnerIn('target-chip'), findsOneWidget);

      await choose(tester, 'target-chip', 'French');
      expect(spinnerIn('target-chip'), findsNothing);
      expect(spinnerIn('source-chip'), findsOneWidget);

      store.present.add(TranslateLanguage.german);
      await tester.pump(modelPollInterval);
      await tester.pump();
      expect(spinnerIn('source-chip'), findsNothing);
    });

    testWidgets('leaving the screen mid-download stops checking', (
      tester,
    ) async {
      await pumpScreen(tester);
      await choose(tester, 'target-chip', 'German');
      expect(spinnerIn('target-chip'), findsOneWidget);

      // The test fails if the polling timer outlives the screen.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(modelPollInterval);
    });

    testWidgets('other problems show a message', (tester) async {
      scene
        ..lines = ['Quod erat demonstrandum']
        ..guesses = {
          'Quod erat demonstrandum': const [LanguageGuess('la', 0.9)],
        };
      await pumpScreen(tester);
      await deliverFrames(tester);
      expect(
        find.text("Can't translate from 'la' on this device."),
        findsOneWidget,
      );
    });
  });

  group('text sheet', () {
    void twoSpanishLines() {
      store.present.add(TranslateLanguage.spanish);
      scene
        ..lines = ['Salida', 'Entrada']
        ..guesses = {
          'Salida': const [LanguageGuess('es', 0.9)],
          'Entrada': const [LanguageGuess('es', 0.9)],
        };
    }

    Finder textButton() => find.byTooltip('Show text');

    Future<void> tapShutter(WidgetTester tester, String tooltip) async {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('appears once the frozen translation is shown', (tester) async {
      twoSpanishLines();
      await pumpScreen(tester);
      await deliverFrames(tester);
      expect(textButton(), findsNothing);
      await tapShutter(tester, 'Freeze');
      expect(textButton(), findsOneWidget);
    });

    testWidgets('is hidden while the frozen picture is read', (tester) async {
      twoSpanishLines();
      await pumpScreen(tester);
      // One frame isn't enough to settle, so freezing reads it.
      await deliverFrames(tester, count: 1);
      scene.gate = Completer<void>();
      await tapShutter(tester, 'Freeze');
      expect(textButton(), findsNothing);

      scene.gate!.complete();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(textButton(), findsOneWidget);
    });

    testWidgets('is hidden when nothing was translated', (tester) async {
      await pumpScreen(tester);
      await deliverFrames(tester);
      await tapShutter(tester, 'Freeze');
      expect(find.byTooltip('Resume'), findsOneWidget);
      expect(textButton(), findsNothing);
    });

    testWidgets('is hidden after resuming', (tester) async {
      twoSpanishLines();
      await pumpScreen(tester);
      await deliverFrames(tester);
      await tapShutter(tester, 'Freeze');
      expect(textButton(), findsOneWidget);
      await tapShutter(tester, 'Resume');
      expect(textButton(), findsNothing);
    });

    testWidgets('keeps the shutter centred', (tester) async {
      twoSpanishLines();
      await pumpScreen(tester);
      await deliverFrames(tester);
      final before = tester.getCenter(find.byTooltip('Freeze')).dx;
      await tapShutter(tester, 'Freeze');
      expect(textButton(), findsOneWidget);
      expect(tester.getCenter(find.byTooltip('Resume')).dx, before);
    });

    testWidgets('opens the sheet, which follows a new target', (tester) async {
      twoSpanishLines();
      store.present.add(TranslateLanguage.german);
      await pumpScreen(tester);
      await deliverFrames(tester);
      await tapShutter(tester, 'Freeze');
      await tester.tap(textButton());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('[english] Salida'), findsWidgets);
      expect(find.text('Copy all'), findsOneWidget);

      await view(
        tester,
      ).controller!.setTargetLanguage(TranslateLanguage.german);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      final sheetTiles = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListTile),
      );
      expect(
        [
          for (final tile in tester.widgetList<ListTile>(sheetTiles))
            (tile.title! as Text).data,
        ],
        ['[german] Salida', '[german] Entrada'],
      );
    });
  });

  group('menu', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('offers the model manager and the HUD toggle', (tester) async {
      await pumpScreen(tester);
      await openMenu(tester);
      expect(find.text('Languages on this phone'), findsOneWidget);
      final hud = tester.widget<CheckedPopupMenuItem<Object?>>(
        find.byWidgetPredicate((w) => w is CheckedPopupMenuItem),
      );
      expect((hud.child! as Text).data, 'Debug HUD');
      expect(hud.checked, isFalse);
    });

    testWidgets('opens the model manager', (tester) async {
      await pumpScreen(tester);
      await openMenu(tester);
      await tester.tap(find.text('Languages on this phone'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ModelsScreen), findsOneWidget);
      expect(find.text('On this phone'), findsOneWidget);
    });
  });

  group('debug HUD', () {
    Future<void> toggleHud(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Debug HUD'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('is off at start', (tester) async {
      await pumpScreen(tester);
      expect(view(tester).showDebugHud, isFalse);
      expect(find.byType(DebugHud), findsNothing);
    });

    testWidgets('turns on, and the menu shows it checked', (tester) async {
      await pumpScreen(tester);
      await toggleHud(tester);
      expect(find.byType(DebugHud), findsOneWidget);

      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final item = tester.widget<CheckedPopupMenuItem<Object?>>(
        find.byWidgetPredicate((w) => w is CheckedPopupMenuItem),
      );
      expect(item.checked, isTrue);
    });

    testWidgets('turns off again', (tester) async {
      await pumpScreen(tester);
      await toggleHud(tester);
      await toggleHud(tester);
      expect(find.byType(DebugHud), findsNothing);
    });

    testWidgets('sits below the language pill', (tester) async {
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.resetPadding);
      await pumpScreen(tester);
      await toggleHud(tester);
      final hudPanel = find.descendant(
        of: find.byType(DebugHud),
        matching: find.byType(DecoratedBox),
      );
      final pillBottom = tester
          .getRect(
            find
                .ancestor(
                  of: chip('source-chip'),
                  matching: find.byType(Container),
                )
                .first,
          )
          .bottom;
      expect(tester.getRect(hudPanel).top, greaterThanOrEqualTo(pillBottom));
    });
  });
}
