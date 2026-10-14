import 'dart:ui' show Color, Rect, Size;

import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../geometry/image_rotation.dart';

/// One translated paragraph of a read frame.
@immutable
final class ReadParagraph {
  /// Creates a paragraph.
  const ReadParagraph({
    required this.box,
    required this.lineBoxes,
    required this.sourceText,
    required this.translatedText,
    required this.background,
    required this.ink,
    this.sourceLanguage,
  });

  /// The box around all of the paragraph's lines, in upright frame
  /// coordinates.
  final Rect box;

  /// Each line's box, in reading order, in upright frame coordinates.
  final List<Rect> lineBoxes;

  /// The paragraph's lines joined into one text.
  final String sourceText;

  /// The paragraph's language as a BCP-47 tag, or `null` if undetermined.
  final String? sourceLanguage;

  /// The translation of [sourceText].
  final String translatedText;

  /// The page colour behind the paragraph, or `null` if it couldn't be
  /// sampled.
  final Color? background;

  /// The colour to draw the translation in, or `null` if it couldn't be
  /// sampled.
  final Color? ink;

  @override
  bool operator ==(Object other) =>
      other is ReadParagraph &&
      other.box == box &&
      listEquals(other.lineBoxes, lineBoxes) &&
      other.sourceText == sourceText &&
      other.sourceLanguage == sourceLanguage &&
      other.translatedText == translatedText &&
      other.background == background &&
      other.ink == ink;

  @override
  int get hashCode => Object.hash(
    box,
    Object.hashAll(lineBoxes),
    sourceText,
    sourceLanguage,
    translatedText,
    background,
    ink,
  );

  @override
  String toString() =>
      'ReadParagraph("$sourceText" [$sourceLanguage] -> "$translatedText", '
      '$box)';
}

/// How long each stage of one read took.
typedef ReadTimings = ({
  Duration recognition,
  Duration translation,
  Duration sampling,
  Duration total,
});

/// The translated paragraphs of one read frame, with what is needed to
/// place them.
@immutable
final class ReadResult {
  /// Creates a result.
  const ReadResult({
    required this.paragraphs,
    required this.imageSize,
    required this.rotation,
    this.untranslatedLanguages = const {},
    this.timings = (
      recognition: Duration.zero,
      translation: Duration.zero,
      sampling: Duration.zero,
      total: Duration.zero,
    ),
  });

  /// The translated paragraphs, in reading order. Paragraphs without a
  /// translation, or already in the target language, are left out.
  final List<ReadParagraph> paragraphs;

  /// The frame's size as delivered by the camera.
  final Size imageSize;

  /// How far the frame had to be rotated to be upright.
  final ImageRotation rotation;

  /// The BCP-47 tags of the languages that kept paragraphs from being
  /// translated: their source languages, and every model, source or target,
  /// that wasn't ready yet.
  final Set<String> untranslatedLanguages;

  /// How long each stage of the read took.
  final ReadTimings timings;
}
