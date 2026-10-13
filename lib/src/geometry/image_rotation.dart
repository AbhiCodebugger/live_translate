import 'dart:ui' show Size;

/// How far a camera frame must be rotated clockwise to appear upright.
///
/// The camera layer converts the recognizer's rotation into this type, so
/// the geometry layer has no dependency on ML Kit.
enum ImageRotation {
  /// Already upright.
  deg0,

  /// Rotate a quarter turn clockwise.
  deg90,

  /// Rotate a half turn.
  deg180,

  /// Rotate three quarter turns clockwise.
  deg270;

  /// Whether this rotation swaps a frame's width and height.
  bool get isQuarterTurn => this == deg90 || this == deg270;

  /// The size of a [delivered] frame once rotated upright.
  Size upright(Size delivered) => isQuarterTurn ? delivered.flipped : delivered;
}
