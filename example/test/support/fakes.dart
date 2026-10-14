// The fakes implement the package's internal interfaces and pass them to
// the view's internal test seams.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:async';
import 'dart:typed_data';

// Only the frame types, to build fake camera frames.
// ignore: depend_on_referenced_packages
import 'package:camera/camera.dart' show CameraImage, ImageFormatGroup;
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';
// Only the type, which the package's text engine interface names.
// ignore: depend_on_referenced_packages
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show InputImage;
import 'package:live_translate/live_translate.dart';
import 'package:live_translate/src/camera/camera_frame.dart';
import 'package:live_translate/src/camera/camera_session.dart';
import 'package:live_translate/src/engines/language_engine.dart';
import 'package:live_translate/src/engines/model_store.dart';
import 'package:live_translate/src/engines/text_engine.dart';
import 'package:live_translate/src/engines/translate_engine.dart';
import 'package:live_translate/src/geometry/image_rotation.dart';
import 'package:live_translate/src/view/live_translate_view.dart'
    show LiveTranslateEngines;
import 'package:live_translate_example/camera_screen.dart' show ViewBuilder;

/// A [ModelStore] whose models and downloads the test controls.
final class FakeModelStore implements ModelStore {
  /// The languages whose models are on the device.
  final present = <TranslateLanguage>{};

  /// Every download request, in order.
  final downloads = <TranslateLanguage>[];

  /// The `wifiOnly` flag of each download in [downloads].
  final wifiOnly = <bool>[];

  /// When set, [download] throws this after waiting for [downloadGate].
  Object? downloadError;

  /// Downloads wait for this, so they stay running until the test
  /// completes it; then the test marks the model [present] itself.
  final downloadGate = Completer<void>();

  @override
  Future<bool> isDownloaded(TranslateLanguage language) async =>
      present.contains(language);

  @override
  Future<void> download(
    TranslateLanguage language, {
    required bool wifiOnly,
  }) async {
    downloads.add(language);
    this.wifiOnly.add(wifiOnly);
    await downloadGate.future;
    if (downloadError case final error?) throw error;
  }

  @override
  Future<void> delete(TranslateLanguage language) async =>
      present.remove(language);
}

/// A [CameraSession] that starts at once and records what is asked of it.
final class FakeCameraSession implements CameraSession {
  final _frames = StreamController<CameraFrame>.broadcast();

  /// How many times [start] was called.
  int starts = 0;

  /// How many times [pause] was called.
  int pauses = 0;

  /// How many times [resume] was called.
  int resumes = 0;

  /// Whether the torch is on. Every start turns it off, as a real camera
  /// restart does.
  bool torch = false;

  @override
  int generation = 0;

  @override
  Size? uprightPreviewSize = const Size(720, 1280);

  @override
  Stream<CameraFrame> get frames => _frames.stream;

  /// Delivers a blank frame as if the camera produced it.
  /// Delivers a frame of [scene] as if the camera produced it. Frames of
  /// one scene are identical, so they count as a steady picture; a different
  /// scene counts as pointing the camera somewhere else.
  void emit({int scene = 0}) => _frames.add(
    CameraFrame(
      image: CameraImage.fromPlatformInterface(
        CameraImageData(
          format: const CameraImageFormat(ImageFormatGroup.nv21, raw: 17),
          width: 1280,
          height: 720,
          planes: [
            CameraImagePlane(
              bytes: _sceneBytes.putIfAbsent(scene, () => _texture(scene)),
              bytesPerRow: 1280,
              bytesPerPixel: 1,
            ),
          ],
        ),
      ),
      rotation: ImageRotation.deg90,
      generation: generation,
    ),
  );

  static final _sceneBytes = <int, Uint8List>{};

  /// A blocky brightness pattern, different for each scene.
  static Uint8List _texture(int scene) {
    final bytes = Uint8List(1280 * 720 * 3 ~/ 2)
      ..fillRange(1280 * 720, 1280 * 720 * 3 ~/ 2, 128);
    for (var y = 0; y < 720; y++) {
      for (var x = 0; x < 1280; x++) {
        final block = (x ~/ 40) * 7919 + (y ~/ 40) * 104729 + scene * 15485863;
        bytes[y * 1280 + x] = 20 + (block * 2654435761 >> 7) % 200;
      }
    }
    return bytes;
  }

  @override
  Future<void> start() async {
    starts++;
    generation++;
    torch = false;
  }

  @override
  Future<void> stop() async => generation++;

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;

  @override
  Future<void> setTorch(bool on) async => torch = on;

  @override
  Widget buildPreview() => const ColoredBox(color: Color(0xFF000000));

  @override
  Future<void> dispose() => _frames.close();
}

/// What the fake camera sees: the lines of every frame and the language
/// guesses for each line's text. Tests may change it between frames.
final class FakeScene {
  /// The lines every frame shows.
  List<String> lines = const [];

  /// Guesses for each text; a text without an entry is undetermined.
  Map<String, List<LanguageGuess>> guesses = const {};

  /// When set, recognition waits for it.
  Completer<void>? gate;
}

/// Fake engines sharing the given model store, showing [scene].
LiveTranslateEngines fakeEngines(ModelStore models, [FakeScene? scene]) {
  final shown = scene ?? FakeScene();
  return (
    text: (_) => _FakeText(shown),
    language: () => _FakeLanguage(shown),
    translate: _TaggingTranslation.new,
    models: models,
  );
}

final class _FakeText implements TextEngine {
  _FakeText(this.scene);

  final FakeScene scene;

  /// Each line is its own paragraph.
  @override
  Future<List<RecognizedLine>> recognize(InputImage image) async {
    await scene.gate?.future;
    return _lines();
  }

  List<RecognizedLine> _lines() => [
    for (final (i, text) in scene.lines.indexed)
      RecognizedLine(
        text: text,
        box: Rect.fromLTWH(100, 100 + 60.0 * i, 400, 40),
        paragraph: i,
      ),
  ];

  @override
  Future<void> close() async {}
}

final class _FakeLanguage implements LanguageEngine {
  _FakeLanguage(this.scene);

  final FakeScene scene;

  @override
  Future<List<LanguageGuess>> identify(String text) async =>
      scene.guesses[text] ?? const [LanguageGuess('und', 1)];

  @override
  Future<void> close() async {}
}

/// Tags text with its target, so every line gets a label: the view hides
/// translations identical to their line.
final class _TaggingTranslation implements TranslateEngine {
  @override
  Future<String> translate(
    String text, {
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) async => '[${to.name}] $text';

  @override
  Future<void> close() async {}
}

/// Builds the camera screen's view on [session] and [engines] instead of the
/// device camera and ML Kit.
ViewBuilder fakeView(
  CameraSession session,
  LiveTranslateEngines Function() engines,
) =>
    ({
      required controller,
      required targetLanguage,
      required sourceLanguages,
      required scripts,
      required resolution,
      required onError,
      required onFrozen,
      required showDebugHud,
    }) => LiveTranslateView(
      controller: controller,
      targetLanguage: targetLanguage,
      sourceLanguages: sourceLanguages,
      scripts: scripts,
      resolution: resolution,
      onError: onError,
      onFrozen: onFrozen,
      showDebugHud: showDebugHud,
      createSession: (_) => session,
      createEngines: engines,
    );
