import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable, listEquals;
import 'package:flutter/rendering.dart';

import '../models/overlay_style.dart';

/// A still-result paragraph, ready to draw: where its text was, how tall its
/// lines were, and its translation in the page's colours.
@immutable
final class ParagraphLabel {
  /// Creates a label.
  const ParagraphLabel({
    required this.rect,
    required this.lineHeight,
    required this.text,
    required this.background,
    required this.ink,
    this.opacity = 1,
  });

  /// The area of the paragraph's original text, in view coordinates.
  final Rect rect;

  /// The median height of the paragraph's lines, in view coordinates.
  final double lineHeight;

  /// The translation.
  final String text;

  /// The page colour to cover the original with.
  final Color background;

  /// The colour to draw the translation in.
  final Color ink;

  /// How visible the label is, from 0 (hidden) to 1, multiplying both
  /// colours' alpha.
  final double opacity;

  @override
  bool operator ==(Object other) =>
      other is ParagraphLabel &&
      other.rect == rect &&
      other.lineHeight == lineHeight &&
      other.text == text &&
      other.background == background &&
      other.ink == ink &&
      other.opacity == opacity;

  @override
  int get hashCode =>
      Object.hash(rect, lineHeight, text, background, ink, opacity);
}

/// The share of a line's height that its font size starts at.
const paragraphFontShare = 0.8;

/// The font size for [text] laid out wrapping inside [inner]: 80% of
/// [lineHeight], rounded down, shrinking one size at a time until the text
/// fits, but not below the style's minimum.
double fitParagraphFontSize({
  required String text,
  required Size inner,
  required double lineHeight,
  required OverlayStyle style,
  required TextDirection direction,
}) {
  final start = _startSize(lineHeight, style);
  for (var size = start; size > style.minFontSize; size--) {
    final painter = _layout(
      text,
      size.toDouble(),
      const Color(0xFF000000),
      style,
      direction,
    )..layout(maxWidth: inner.width);
    final fits = painter.height <= inner.height && !painter.didExceedMaxLines;
    painter.dispose();
    if (fits) return size.toDouble();
  }
  return style.minFontSize;
}

/// Whether [text] fits [inner] wrapped at font [size].
bool _fits(
  String text,
  double size,
  Size inner,
  OverlayStyle style,
  TextDirection direction,
) {
  final painter = _layout(text, size, const Color(0xFF000000), style, direction)
    ..layout(maxWidth: inner.width);
  final fits = painter.height <= inner.height;
  painter.dispose();
  return fits;
}

/// The font size a label's translation starts at: 80% of its line height,
/// rounded down, and at least the style's minimum.
int _startSize(double lineHeight, OverlayStyle style) => math.max(
  (lineHeight * paragraphFontShare).floor(),
  style.minFontSize.ceil(),
);

/// Where each of [labels] is drawn in a view of [viewSize].
///
/// Each label is first limited to the view. A label whose translation
/// doesn't fit at its starting size then grows to the right, up to the
/// view's edge or the nearest label beside it, and if it still doesn't fit,
/// downwards by up to its own height, stopping at the nearest label below
/// and the view's bottom. Labels grow against the others' original
/// rectangles, so two labels never grow into each other.
List<Rect> placeParagraphLabels(
  List<ParagraphLabel> labels,
  Size viewSize, {
  required OverlayStyle style,
  required TextDirection direction,
}) {
  final view = Offset.zero & viewSize;
  final original = [for (final label in labels) label.rect.intersect(view)];
  return [
    for (final (i, label) in labels.indexed)
      _grow(i, label, original, view, style, direction),
  ];
}

Rect _grow(
  int index,
  ParagraphLabel label,
  List<Rect> original,
  Rect view,
  OverlayStyle style,
  TextDirection direction,
) {
  var rect = original[index];
  if (rect.isEmpty) return rect;
  final size = _startSize(label.lineHeight, style).toDouble();
  bool fits(Rect r) => _fits(label.text, size, r.size, style, direction);
  if (fits(rect)) return rect;

  final others = [
    for (final (i, other) in original.indexed)
      if (i != index && !other.isEmpty) other,
  ];

  var right = view.right;
  for (final other in others) {
    final beside = other.top < rect.bottom && other.bottom > rect.top;
    if (beside && other.left >= rect.right) right = math.min(right, other.left);
  }
  rect = Rect.fromLTRB(rect.left, rect.top, right, rect.bottom);
  if (fits(rect)) return rect;

  var bottom = math.min(view.bottom, rect.bottom + original[index].height);
  for (final other in others) {
    final below = other.left < rect.right && other.right > rect.left;
    if (below && other.top >= rect.bottom) bottom = math.min(bottom, other.top);
  }
  return Rect.fromLTRB(rect.left, rect.top, rect.right, bottom);
}

TextPainter _layout(
  String text,
  double size,
  Color ink,
  OverlayStyle style,
  TextDirection direction, {
  int? maxLines,
}) => TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(color: ink, fontSize: size, fontWeight: style.fontWeight),
  ),
  textDirection: direction,
  maxLines: maxLines,
  ellipsis: maxLines == null ? null : '…',
);

/// Draws still-result paragraphs: each covers its original text with the
/// page colour and lays the translation out across it.
class ParagraphPainter extends CustomPainter {
  /// Creates a painter for [labels].
  ParagraphPainter({
    required this.labels,
    required this.style,
    required this.textDirection,
  });

  /// The paragraphs to draw.
  final List<ParagraphLabel> labels;

  /// Supplies the corner radius, padding, minimum font size and weight; the
  /// colours come from each label.
  final OverlayStyle style;

  /// The translations' direction.
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(style.borderRadius);
    final view = Offset.zero & size;
    final placed = placeParagraphLabels(
      labels,
      size,
      style: style,
      direction: textDirection,
    );
    for (final (i, label) in labels.indexed) {
      final inner = placed[i];
      if (inner.isEmpty || label.opacity <= 0) continue;
      final ink = label.ink.withValues(alpha: label.ink.a * label.opacity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          style.padding.inflateRect(inner).intersect(view),
          radius,
        ),
        Paint()..color = label.background.withValues(alpha: label.opacity),
      );
      final fontSize = fitParagraphFontSize(
        text: label.text,
        inner: inner.size,
        lineHeight: label.lineHeight,
        style: style,
        direction: textDirection,
      );
      final probe = _layout('M', fontSize, ink, style, textDirection)..layout();
      final maxLines = math.max(1, (inner.height / probe.height).floor());
      probe.dispose();
      final text = _layout(
        label.text,
        fontSize,
        ink,
        style,
        textDirection,
        maxLines: maxLines,
      )..layout(maxWidth: inner.width);
      text
        ..paint(canvas, inner.topLeft)
        ..dispose();
    }
  }

  @override
  bool shouldRepaint(ParagraphPainter oldDelegate) =>
      !listEquals(oldDelegate.labels, labels) ||
      oldDelegate.style != style ||
      oldDelegate.textDirection != textDirection;
}
