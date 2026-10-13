import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
// The only package import: everything below must resolve through it.
import 'package:live_translate/live_translate.dart';

void main() {
  test('the entry library exposes the public models', () {
    const line = TranslatedLine(
      id: 'a',
      sourceText: 'Hola',
      translatedText: 'Hello',
      rect: Rect.zero,
    );
    expect(line.opacity, 1.0);
    expect(const OverlayStyle(), isA<OverlayStyle>());
    expect(TextScript.values, hasLength(2));
  });

  test('the entry library exposes every exception subtype', () {
    final errors = <LiveTranslateException>[
      const CameraPermissionDenied(),
      const CameraUnavailable(),
      const ModelNotDownloaded(TranslateLanguage.hindi),
      const UnsupportedLanguagePair(
        source: 'xx',
        target: TranslateLanguage.english,
      ),
      PipelineFailure(Exception('x')),
    ];
    expect(errors, everyElement(isA<Exception>()));
  });

  test('the entry library exposes TranslationModels', () {
    expect(TranslationModels.new, isA<TranslationModels Function()>());
  });

  test('the entry library exposes the view, controller and state', () {
    const view = LiveTranslateView(targetLanguage: TranslateLanguage.english);
    expect(view.targetLanguage, TranslateLanguage.english);
    final controller = LiveTranslateController();
    addTearDown(controller.dispose);
    expect(controller.state, LiveTranslateState.initializing);
    expect(controller.targetLanguage, isNull);
    expect(LiveTranslateState.values, hasLength(4));
  });

  test('the entry library re-exports the dependency types it uses', () {
    expect(TranslateLanguage.english.name, 'english');
    expect(ResolutionPreset.medium.name, 'medium');
  });
}
