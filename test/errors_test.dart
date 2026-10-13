import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;
import 'package:live_translate/src/errors.dart';

/// Compiles only while the switch covers every subtype, so adding a subtype
/// without updating it fails the build.
String describe(LiveTranslateException error) => switch (error) {
  CameraPermissionDenied() => 'permission',
  CameraUnavailable() => 'camera',
  ModelNotDownloaded() => 'model',
  UnsupportedLanguagePair() => 'pair',
  PipelineFailure() => 'pipeline',
};

void main() {
  group('LiveTranslateException', () {
    test('every subtype is matched by an exhaustive switch', () {
      final errors = <LiveTranslateException>[
        const CameraPermissionDenied(),
        const CameraUnavailable(),
        const ModelNotDownloaded(TranslateLanguage.hindi),
        const UnsupportedLanguagePair(
          source: 'xx',
          target: TranslateLanguage.english,
        ),
        PipelineFailure(StateError('boom')),
      ];
      expect(errors.map(describe), [
        'permission',
        'camera',
        'model',
        'pair',
        'pipeline',
      ]);
    });

    test('every subtype is an Exception', () {
      expect(const CameraUnavailable(), isA<Exception>());
    });
  });

  test('ModelNotDownloaded names the missing language', () {
    const error = ModelNotDownloaded(TranslateLanguage.hindi);
    expect(error.language, TranslateLanguage.hindi);
    expect(error.toString(), contains('ModelNotDownloaded'));
    expect(error.toString(), contains('hindi'));
  });

  test('UnsupportedLanguagePair names both languages', () {
    const error = UnsupportedLanguagePair(
      source: 'xx',
      target: TranslateLanguage.english,
    );
    expect(error.source, 'xx');
    expect(error.target, TranslateLanguage.english);
    expect(error.toString(), contains('from xx to en'));
  });

  test('PipelineFailure keeps its cause and stack trace', () {
    final cause = StateError('recognizer closed');
    final stackTrace = StackTrace.current;
    final error = PipelineFailure(cause, stackTrace);
    expect(error.cause, same(cause));
    expect(error.stackTrace, same(stackTrace));
    expect(error.toString(), contains('PipelineFailure'));
    expect(error.toString(), contains('recognizer closed'));
  });

  test('PipelineFailure stack trace is optional', () {
    expect(PipelineFailure(Exception('x')).stackTrace, isNull);
  });
}
