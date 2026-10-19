import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show immutable;
import 'package:google_mlkit_translation/google_mlkit_translation.dart'
    show BCP47Code, TranslateLanguage;

/// One paragraph of camera text and its translation, positioned in the
/// view.
///
/// A paragraph's lines are joined and translated as one text, and [rect]
/// covers all of them.
@immutable
final class TranslatedParagraph {
  /// Creates a translated paragraph.
  ///
  /// [opacity] must be between 0.0 and 1.0 inclusive.
  const TranslatedParagraph({
    required this.id,
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.rect,
    this.opacity = 1.0,
  }) : assert(
         opacity >= 0.0 && opacity <= 1.0,
         'opacity must be between 0.0 and 1.0',
       );

  /// Identifies the paragraph while the view keeps reading it in the same
  /// place.
  ///
  /// A later read of the same scene, such as one after a download, a change
  /// of target language, a small pan or a freeze, gives the paragraph found
  /// in the same place the same id, so it can key a widget. A new scene
  /// gives every paragraph a new id. The format is opaque.
  final String id;

  /// The text as recognised in the camera frame.
  final String sourceText;

  /// The translation of [sourceText] into the target language.
  final String translatedText;

  /// The language [sourceText] was translated from.
  final TranslateLanguage sourceLanguage;

  /// The paragraph's bounds in the view's coordinate space.
  final Rect rect;

  /// How visible the paragraph is, from 0.0 (hidden) to 1.0 (fully visible).
  ///
  /// Drops below 1.0 as the labels fade out after a fast movement or a new
  /// scene.
  final double opacity;

  @override
  bool operator ==(Object other) =>
      other is TranslatedParagraph &&
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
      'TranslatedParagraph(id: $id, sourceText: "$sourceText", '
      'translatedText: "$translatedText", '
      'sourceLanguage: ${sourceLanguage.bcpCode}, '
      'rect: $rect, opacity: $opacity)';
}
