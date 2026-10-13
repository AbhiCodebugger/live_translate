import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show InputImage;
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show BCP47Code, TranslateLanguage;
import 'package:live_translate/src/camera/camera_frame.dart';
import 'package:live_translate/src/camera/camera_session.dart';
import 'package:live_translate/src/engines/language_engine.dart';
import 'package:live_translate/src/engines/model_store.dart';
import 'package:live_translate/src/engines/text_engine.dart';
import 'package:live_translate/src/engines/translate_engine.dart';
import 'package:live_translate/src/errors.dart';

/// A [TextEngine] that returns scripted lines and records how it is used.
final class FakeTextEngine implements TextEngine {
  /// The lines every call returns.
  List<RecognizedLine> lines = const [];

  /// When set, [recognize] throws this instead of returning [lines].
  Object? error;

  /// When set, [recognize] waits for this before returning.
  Completer<void>? gate;

  /// How many times [recognize] was called.
  int calls = 0;

  /// How many times [close] was called.
  int closes = 0;

  @override
  Future<List<RecognizedLine>> recognize(InputImage image) async {
    calls++;
    await gate?.future;
    if (error case final error?) throw error;
    return lines;
  }

  @override
  Future<void> close() async => closes++;
}

/// A [CameraSession] driven by the test.
final class FakeCameraSession implements CameraSession {
  /// The key of the widget [buildPreview] returns.
  static const previewKey = Key('fake-preview');

  final _frames = StreamController<CameraFrame>.broadcast();

  /// How many times [start] was called.
  int starts = 0;

  /// How many times [stop] was called.
  int stops = 0;

  /// How many times [dispose] was called.
  int disposes = 0;

  /// When set, [start] throws this.
  LiveTranslateException? startError;

  /// When set, [start] waits for this before finishing.
  Completer<void>? startGate;

  /// How many times [pause] was called.
  int pauses = 0;

  /// When set, [pause] throws this.
  LiveTranslateException? pauseError;

  /// When set, [resume] throws this.
  LiveTranslateException? resumeError;

  /// How many times [resume] was called.
  int resumes = 0;

  /// Whether the torch is on. Every start turns it off, as a real camera
  /// restart does.
  bool torch = false;

  /// Whether this camera has a torch; without one, [setTorch] does nothing.
  bool hasTorch = true;

  @override
  int generation = 0;

  @override
  Size? uprightPreviewSize = const Size(720, 1280);

  @override
  Stream<CameraFrame> get frames => _frames.stream;

  /// Delivers [frame] as if the camera produced it.
  void emit(CameraFrame frame) => _frames.add(frame);

  @override
  Future<void> start() async {
    starts++;
    generation++;
    torch = false;
    await startGate?.future;
    if (startError case final error?) throw error;
  }

  @override
  Future<void> stop() async {
    stops++;
    generation++;
  }

  @override
  Future<void> pause() async {
    pauses++;
    if (pauseError case final error?) throw error;
  }

  @override
  Future<void> resume() async {
    resumes++;
    if (resumeError case final error?) throw error;
  }

  @override
  Future<void> setTorch(bool on) async {
    if (hasTorch) torch = on;
  }

  @override
  Widget buildPreview() =>
      const ColoredBox(key: previewKey, color: Color(0xFF000000));

  @override
  Future<void> dispose() async {
    disposes++;
    await _frames.close();
  }
}

/// A [LanguageEngine] that returns scripted guesses per text.
final class FakeLanguageEngine implements LanguageEngine {
  /// Guesses returned for each text. Unknown text gives "und".
  final guesses = <String, List<LanguageGuess>>{};

  /// Every text identified, in order.
  final identified = <String>[];

  /// How many times [close] was called.
  int closes = 0;

  /// When set, [identify] waits for this first.
  Completer<void>? gate;

  /// When set, [identify] throws this.
  Object? error;

  @override
  Future<List<LanguageGuess>> identify(String text) async {
    identified.add(text);
    await gate?.future;
    if (error case final error?) throw error;
    return guesses[text] ?? const [LanguageGuess('und', 1)];
  }

  @override
  Future<void> close() async => closes++;
}

/// A [TranslateEngine] that tags text with its target language.
final class FakeTranslateEngine implements TranslateEngine {
  /// Every text translated, in order.
  final translated = <String>[];

  /// Texts whose translation throws.
  final failing = <String>{};

  /// Texts the translator returns unchanged, as ML Kit does for names it
  /// can't translate.
  final unchanged = <String>{};

  /// How many times [close] was called.
  int closes = 0;

  /// When set, [translate] waits for this first.
  Completer<void>? gate;

  @override
  Future<String> translate(
    String text, {
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) async {
    translated.add(text);
    await gate?.future;
    if (failing.contains(text)) throw StateError('cannot translate "$text"');
    if (unchanged.contains(text.trim())) return text;
    return '[${to.bcpCode}] $text';
  }

  @override
  Future<void> close() async => closes++;
}

/// A [ModelStore] whose models and downloads the test controls.
final class FakeModelStore implements ModelStore {
  /// The languages whose models are on the device.
  final present = <TranslateLanguage>{};

  /// Every `isDownloaded` call, in order.
  final checks = <TranslateLanguage>[];

  /// Every download request as (language, wifiOnly), in order.
  final downloads = <(TranslateLanguage, bool)>[];

  /// When set, downloads wait for this; complete it with an error to fail.
  Completer<void>? downloadGate;

  /// When set, `isDownloaded` throws this.
  Object? checkError;

  @override
  Future<bool> isDownloaded(TranslateLanguage language) async {
    checks.add(language);
    if (checkError case final error?) throw error;
    return present.contains(language);
  }

  @override
  Future<void> download(
    TranslateLanguage language, {
    required bool wifiOnly,
  }) async {
    downloads.add((language, wifiOnly));
    await downloadGate?.future;
    present.add(language);
  }

  @override
  Future<void> delete(TranslateLanguage language) async =>
      present.remove(language);
}
