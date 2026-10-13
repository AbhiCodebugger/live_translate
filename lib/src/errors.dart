import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show BCP47Code, TranslateLanguage;

/// The base type of every error this package reports.
///
/// The hierarchy is closed, so a `switch` over it can be exhaustive:
///
/// ```dart
/// final message = switch (error) {
///   CameraPermissionDenied() => 'Allow camera access to translate.',
///   CameraUnavailable() => 'No camera available.',
///   ModelNotDownloaded(:final language) => 'Download ${language.name} first.',
///   UnsupportedLanguagePair() => 'This language pair is not supported.',
///   PipelineFailure() => 'Something went wrong.',
/// };
/// ```
sealed class LiveTranslateException implements Exception {
  const LiveTranslateException();
}

/// The user denied access to the camera.
final class CameraPermissionDenied extends LiveTranslateException {
  /// Creates a camera permission error.
  const CameraPermissionDenied();

  @override
  String toString() => 'CameraPermissionDenied: camera access was denied';
}

/// No camera is available on the device, or the camera failed to start.
final class CameraUnavailable extends LiveTranslateException {
  /// Creates a camera unavailable error.
  const CameraUnavailable();

  @override
  String toString() => 'CameraUnavailable: no usable camera was found';
}

/// A translation model needed for [language] has not been downloaded.
final class ModelNotDownloaded extends LiveTranslateException {
  /// Creates an error for the missing model of [language].
  const ModelNotDownloaded(this.language);

  /// The language whose translation model is missing.
  final TranslateLanguage language;

  @override
  String toString() =>
      'ModelNotDownloaded: the translation model for ${language.name} '
      '(${language.bcpCode}) is not downloaded';
}

/// On-device translation from [source] to [target] is not supported.
final class UnsupportedLanguagePair extends LiveTranslateException {
  /// Creates an error for the unsupported pair [source] → [target].
  const UnsupportedLanguagePair({required this.source, required this.target});

  /// The detected source language, as a BCP-47 code.
  ///
  /// A `String` rather than a [TranslateLanguage], because language detection
  /// can return languages that on-device translation does not cover.
  final String source;

  /// The requested target language.
  final TranslateLanguage target;

  @override
  String toString() =>
      'UnsupportedLanguagePair: cannot translate from $source to '
      '${target.bcpCode}';
}

/// An unexpected error occurred while processing camera frames.
final class PipelineFailure extends LiveTranslateException {
  /// Creates an error wrapping [cause], with its [stackTrace] if known.
  const PipelineFailure(this.cause, [this.stackTrace]);

  /// The underlying error.
  final Object cause;

  /// Where [cause] was thrown, if known.
  final StackTrace? stackTrace;

  @override
  String toString() => 'PipelineFailure: $cause';
}
