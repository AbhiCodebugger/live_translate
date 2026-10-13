import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show immutable;

/// One line of camera text and its translation, positioned in the view.
@immutable
final class TranslatedLine {
  /// Creates a translated line.
  ///
  /// [opacity] must be between 0.0 and 1.0 inclusive.
  const TranslatedLine({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.rect,
    this.sourceLanguage,
    this.opacity = 1.0,
  }) : assert(
         opacity >= 0.0 && opacity <= 1.0,
         'opacity must be between 0.0 and 1.0',
       );

  /// An identifier that stays the same while the line is tracked across
  /// frames.
  final String id;

  /// The text as recognised in the camera frame.
  final String sourceText;

  /// The translation of [sourceText] into the target language.
  final String translatedText;

  /// The detected language of [sourceText] as a BCP-47 code, or `null` if it
  /// could not be determined.
  final String? sourceLanguage;

  /// The line's bounds in the view's coordinate space.
  final Rect rect;

  /// How visible the line is, from 0.0 (hidden) to 1.0 (fully visible).
  ///
  /// Drops below 1.0 as the line fades out after leaving the camera frame.
  final double opacity;

  @override
  bool operator ==(Object other) =>
      other is TranslatedLine &&
      other.id == id &&
      other.sourceText == sourceText &&
      other.translatedText == translatedText &&
      other.sourceLanguage == sourceLanguage &&
      other.rect == rect &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(
    id,
    sourceText,
    translatedText,
    sourceLanguage,
    rect,
    opacity,
  );

  @override
  String toString() =>
      'TranslatedLine(id: $id, sourceText: "$sourceText", '
      'translatedText: "$translatedText", sourceLanguage: $sourceLanguage, '
      'rect: $rect, opacity: $opacity)';
}
