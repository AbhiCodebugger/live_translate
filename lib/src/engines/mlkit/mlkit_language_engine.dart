import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

import '../language_engine.dart';

/// A [LanguageEngine] backed by ML Kit's on-device language identification.
///
/// It asks for every candidate above a very low threshold, so callers can
/// apply their own confidence rule and choose among lower-ranked candidates.
final class MlKitLanguageEngine implements LanguageEngine {
  /// Creates an engine.
  ///
  /// [createIdentifier] builds the underlying identifier and exists so tests
  /// can substitute a fake.
  MlKitLanguageEngine({LanguageIdentifier Function()? createIdentifier})
    : _createIdentifier =
          createIdentifier ??
          (() => LanguageIdentifier(confidenceThreshold: candidateThreshold));

  /// The lowest confidence ML Kit reports a candidate for.
  static const candidateThreshold = 0.01;

  final LanguageIdentifier Function() _createIdentifier;
  LanguageIdentifier? _identifier;
  bool _closed = false;

  @override
  Future<List<LanguageGuess>> identify(String text) async {
    if (_closed) throw StateError('MlKitLanguageEngine used after close.');
    final identifier = _identifier ??= _createIdentifier();
    final candidates = await identifier.identifyPossibleLanguages(text);
    return [
      for (final candidate in candidates)
        LanguageGuess(candidate.languageTag, candidate.confidence),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final identifier = _identifier;
    _identifier = null;
    await identifier?.close();
  }
}
