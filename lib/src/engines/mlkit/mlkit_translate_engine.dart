import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../translate_engine.dart';

/// A [TranslateEngine] backed by ML Kit's on-device translator.
///
/// One translator is created per language pair, on first use, and reused.
///
/// ML Kit downloads a missing model, over any network, whenever it is asked
/// to translate. Callers must check that both models are present first.
final class MlKitTranslateEngine implements TranslateEngine {
  /// Creates an engine.
  ///
  /// [createTranslator] builds a translator for a language pair and exists
  /// so tests can substitute a fake.
  MlKitTranslateEngine({
    OnDeviceTranslator Function(TranslateLanguage from, TranslateLanguage to)?
    createTranslator,
  }) : _createTranslator =
           createTranslator ??
           ((from, to) =>
               OnDeviceTranslator(sourceLanguage: from, targetLanguage: to));

  final OnDeviceTranslator Function(TranslateLanguage, TranslateLanguage)
  _createTranslator;
  final _translators =
      <(TranslateLanguage, TranslateLanguage), OnDeviceTranslator>{};
  bool _closed = false;

  @override
  Future<String> translate(
    String text, {
    required TranslateLanguage from,
    required TranslateLanguage to,
  }) async {
    if (_closed) throw StateError('MlKitTranslateEngine used after close.');
    final translator = _translators.putIfAbsent((
      from,
      to,
    ), () => _createTranslator(from, to));
    return translator.translateText(text);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final translators = _translators.values.toList();
    _translators.clear();
    await Future.wait(translators.map((translator) => translator.close()));
  }
}
