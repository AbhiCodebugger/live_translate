import 'package:flutter/foundation.dart' show immutable;

/// A candidate language for a piece of text.
@immutable
final class LanguageGuess {
  /// Creates a guess that [text] is in [tag] with [confidence].
  const LanguageGuess(this.tag, this.confidence);

  /// The language as a BCP-47 tag, such as "hi" or "es". "und" means
  /// undetermined.
  final String tag;

  /// How likely the guess is, from 0 to 1.
  final double confidence;

  @override
  bool operator ==(Object other) =>
      other is LanguageGuess &&
      other.tag == tag &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(tag, confidence);

  @override
  String toString() => 'LanguageGuess($tag, $confidence)';
}

/// Identifies the language a piece of text is written in.
abstract interface class LanguageEngine {
  /// Returns the candidate languages for [text], most likely first.
  Future<List<LanguageGuess>> identify(String text);

  /// Releases the engine's resources. The engine can't be used afterwards.
  Future<void> close();
}
