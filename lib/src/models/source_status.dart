import 'package:flutter/foundation.dart' show immutable;
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show BCP47Code, TranslateLanguage;

/// Where the live view stands in finding the language it translates from.
///
/// Model downloads don't report their progress, so the status names the
/// stage rather than a percentage. The hierarchy is closed, so a `switch`
/// over it can be exhaustive:
///
/// ```dart
/// final label = switch (controller.sourceStatus) {
///   SourceSearching() => 'Looking for text…',
///   SourceGuessed(:final language) => '${language.name}?',
///   SourceDownloading(:final language) => 'Downloading ${language.name}…',
///   SourceReady(:final language) => language.name,
///   SourceUnsupported(:final tag) => "$tag can't be translated",
///   SourceNotFound() => 'No supported text found',
///   SourceDownloadFailed(:final language) =>
///     "${language.name} didn't download",
/// };
/// ```
@immutable
sealed class SourceStatus {
  const SourceStatus();
}

/// No read of the current scene has found a language yet.
final class SourceSearching extends SourceStatus {
  /// Creates the searching status.
  const SourceSearching();

  @override
  bool operator ==(Object other) => other is SourceSearching;

  @override
  int get hashCode => (SourceSearching).hashCode;

  @override
  String toString() => 'SourceSearching()';
}

/// Text was identified as [language], whose model is missing, but the
/// language isn't confirmed yet, so its model doesn't download.
final class SourceGuessed extends SourceStatus {
  /// Creates a status guessing [language].
  const SourceGuessed(this.language);

  /// The guessed language.
  final TranslateLanguage language;

  @override
  bool operator ==(Object other) =>
      other is SourceGuessed && other.language == language;

  @override
  int get hashCode => Object.hash(SourceGuessed, language);

  @override
  String toString() => 'SourceGuessed(${language.bcpCode})';
}

/// The model for [language] is downloading.
final class SourceDownloading extends SourceStatus {
  /// Creates a status downloading [language].
  const SourceDownloading(this.language);

  /// The language whose model is downloading.
  final TranslateLanguage language;

  @override
  bool operator ==(Object other) =>
      other is SourceDownloading && other.language == language;

  @override
  int get hashCode => Object.hash(SourceDownloading, language);

  @override
  String toString() => 'SourceDownloading(${language.bcpCode})';
}

/// Text in [language] is translated: its model is on the device. When the
/// text is already in the target language, [language] is the target.
final class SourceReady extends SourceStatus {
  /// Creates a status ready for [language].
  const SourceReady(this.language);

  /// The language text is translated from.
  final TranslateLanguage language;

  @override
  bool operator ==(Object other) =>
      other is SourceReady && other.language == language;

  @override
  int get hashCode => Object.hash(SourceReady, language);

  @override
  String toString() => 'SourceReady(${language.bcpCode})';
}

/// Text was confirmed as [tag], a language with no on-device translation.
final class SourceUnsupported extends SourceStatus {
  /// Creates a status for the untranslatable language [tag].
  const SourceUnsupported(this.tag);

  /// The language as a BCP-47 tag, such as "la".
  ///
  /// A `String` rather than a [TranslateLanguage], because language
  /// identification knows languages that on-device translation does not.
  final String tag;

  @override
  bool operator ==(Object other) =>
      other is SourceUnsupported && other.tag == tag;

  @override
  int get hashCode => Object.hash(SourceUnsupported, tag);

  @override
  String toString() => 'SourceUnsupported($tag)';
}

/// Three reads of the current scene found no language: there is no text,
/// or it is in a script the view doesn't read, or it can't be identified.
final class SourceNotFound extends SourceStatus {
  /// Creates the not found status.
  const SourceNotFound();

  @override
  bool operator ==(Object other) => other is SourceNotFound;

  @override
  int get hashCode => (SourceNotFound).hashCode;

  @override
  String toString() => 'SourceNotFound()';
}

/// The download of [language]'s model failed. A later read retries it.
final class SourceDownloadFailed extends SourceStatus {
  /// Creates a status for the failed download of [language].
  const SourceDownloadFailed(this.language);

  /// The language whose model didn't download.
  final TranslateLanguage language;

  @override
  bool operator ==(Object other) =>
      other is SourceDownloadFailed && other.language == language;

  @override
  int get hashCode => Object.hash(SourceDownloadFailed, language);

  @override
  String toString() => 'SourceDownloadFailed(${language.bcpCode})';
}
