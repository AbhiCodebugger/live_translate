import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show immutable;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show InputImage;

/// One line of text found in a camera frame.
@immutable
final class RecognizedLine {
  /// Creates a recognized line.
  const RecognizedLine({
    required this.text,
    required this.box,
    this.paragraph = 0,
  });

  /// The text of the line.
  final String text;

  /// The line's bounds in upright frame coordinates.
  final Rect box;

  /// The paragraph the line belongs to. Lines of one paragraph share it; it
  /// is unique within one recognition result.
  final int paragraph;

  @override
  bool operator ==(Object other) =>
      other is RecognizedLine &&
      other.text == text &&
      other.box == box &&
      other.paragraph == paragraph;

  @override
  int get hashCode => Object.hash(text, box, paragraph);

  @override
  String toString() => 'RecognizedLine("$text", $box, paragraph $paragraph)';
}

/// Finds lines of text in camera frames.
///
/// The pipeline depends only on this interface, so tests can use a fake and
/// another recognizer can replace ML Kit later.
abstract interface class TextEngine {
  /// Returns the lines of text in [image], read with everything the engine
  /// can read, or an empty list if there are none.
  Future<List<RecognizedLine>> recognize(InputImage image);

  /// Releases the engine's resources. The engine can't be used afterwards.
  Future<void> close();
}
