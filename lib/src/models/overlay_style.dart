import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// The look of the translated labels painted over the camera view.
///
/// Labels take their colours from the page behind each paragraph, and their
/// font size from the original text's line height, shrinking towards
/// [minFontSize] until the translation fits.
@immutable
final class OverlayStyle {
  /// Creates an overlay style. Every field has a default.
  ///
  /// [minFontSize] must be positive and no larger than [maxFontSize].
  const OverlayStyle({
    this.backgroundColor = const Color(0xCC000000),
    this.textColor = const Color(0xFFFFFFFF),
    this.borderRadius = 6,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    this.minFontSize = 10,
    this.maxFontSize = 28,
    this.fontWeight = FontWeight.w600,
  }) : assert(minFontSize > 0, 'minFontSize must be positive'),
       assert(
         minFontSize <= maxFontSize,
         'minFontSize must not exceed maxFontSize',
       );

  /// The fill behind a label whose page colour couldn't be sampled from the
  /// camera frame. Other labels use the page's own colour.
  final Color backgroundColor;

  /// The text colour of a label whose page colours couldn't be sampled.
  /// Other labels use the ink colour sampled from the page.
  final Color textColor;

  /// The corner radius of each label's background, in logical pixels.
  final double borderRadius;

  /// The space between a label's edge and its text.
  final EdgeInsets padding;

  /// The smallest font size a label may shrink to before it is ellipsised.
  final double minFontSize;

  /// Not used by any label: labels start from the original text's size.
  /// Kept until the API is reviewed for release 0.1.0.
  final double maxFontSize;

  /// The weight of the translated text.
  final FontWeight fontWeight;

  @override
  bool operator ==(Object other) =>
      other is OverlayStyle &&
      other.backgroundColor == backgroundColor &&
      other.textColor == textColor &&
      other.borderRadius == borderRadius &&
      other.padding == padding &&
      other.minFontSize == minFontSize &&
      other.maxFontSize == maxFontSize &&
      other.fontWeight == fontWeight;

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    textColor,
    borderRadius,
    padding,
    minFontSize,
    maxFontSize,
    fontWeight,
  );
}
