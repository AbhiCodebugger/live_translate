import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show TranslateLanguage;

/// Translates text between languages on the device.
///
/// Callers must make sure both languages' models are downloaded first; see
/// `ModelStore`.
abstract interface class TranslateEngine {
  /// Translates [text] from [from] into [to].
  Future<String> translate(
    String text, {
    required TranslateLanguage from,
    required TranslateLanguage to,
  });

  /// Releases the engine's resources. The engine can't be used afterwards.
  Future<void> close();
}
