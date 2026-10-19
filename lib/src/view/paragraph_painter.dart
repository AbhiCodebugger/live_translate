import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show immutable, listEquals, visibleForTesting;
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
/// [lineHeight], rounded down and capped at the style's maximum, shrinking
/// one size at a time until the text fits, but not below the style's
/// minimum.
///
/// [cache], when given, keeps the measurements for later calls.
double fitParagraphFontSize({
  required String text,
  required Size inner,
  required double lineHeight,
  required OverlayStyle style,
  required TextDirection direction,
  LabelLayoutCache? cache,
}) {
  final start = _startSize(lineHeight, style);
  for (var size = start; size > style.minFontSize; size--) {
    if (_fits(text, size.toDouble(), inner, style, direction, cache)) {
      return size.toDouble();
    }
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
  LabelLayoutCache? cache,
) => _height(text, size, inner.width, style, direction, cache) <= inner.height;

/// [width] rounded to a hundredth of a pixel, the width text is laid out
/// at. A label that only moves keeps exactly the same layout width, though
/// the view's scaling can change its exact width by a rounding error.
double _layoutWidth(double width) =>
    width.isFinite ? (width * 100).roundToDouble() / 100 : width;

/// The height of [text] at font [size] wrapped at [maxWidth], from [cache]
/// when it has it.
double _height(
  String text,
  double size,
  double maxWidth,
  OverlayStyle style,
  TextDirection direction,
  LabelLayoutCache? cache,
) {
  final width = _layoutWidth(maxWidth);
  double measure() {
    final painter = _layout(
      text,
      size,
      const Color(0xFF000000),
      style,
      direction,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  return cache == null
      ? measure()
      : cache._height((text, size, width, style, direction), measure);
}

/// Keeps the text layouts of labels from one paint to the next, so labels
/// that only move with the camera aren't fitted and laid out again.
///
/// It holds the measurements made while fitting, and the last [capacity]
/// laid-out translations, which it disposes when it drops them. Call
/// [dispose] when the labels are gone for good.
final class LabelLayoutCache {
  /// Creates a cache keeping up to [capacity] laid-out translations.
  LabelLayoutCache({this.capacity = 64});

  /// How many laid-out translations are kept.
  final int capacity;

  // Both in least recently used order, as map literals keep insertion
  // order.
  final _heights =
      <(String, double, double, OverlayStyle, TextDirection), double>{};
  final _painters =
      <
        (String, double, Color, int, double, OverlayStyle, TextDirection),
        TextPainter
      >{};

  /// How many text layouts the cache has made, for tests.
  @visibleForTesting
  int layouts = 0;

  /// How many laid-out translations the cache holds, for tests.
  @visibleForTesting
  int get painterCount => _painters.length;

  double _height(
    (String, double, double, OverlayStyle, TextDirection) key,
    double Function() measure,
  ) {
    var height = _heights.remove(key);
    if (height == null) {
      layouts++;
      height = measure();
    }
    _heights[key] = height;
    // Measurements are small; keep several per translation.
    if (_heights.length > capacity * 8) _heights.remove(_heights.keys.first);
    return height;
  }

  TextPainter _painter(
    (String, double, Color, int, double, OverlayStyle, TextDirection) key,
    TextPainter Function() layOut,
  ) {
    var painter = _painters.remove(key);
    if (painter == null) {
      layouts++;
      painter = layOut();
    }
    _painters[key] = painter;
    if (_painters.length > capacity) {
      _painters.remove(_painters.keys.first)!.dispose();
    }
    return painter;
  }

  /// Disposes every laid-out translation and forgets every measurement.
  void dispose() {
    for (final painter in _painters.values) {
      painter.dispose();
    }
    _painters.clear();
    _heights.clear();
  }
}

/// The font size a label's translation starts at: 80% of its line height,
/// rounded down, no larger than the style's maximum and at least its
/// minimum.
int _startSize(double lineHeight, OverlayStyle style) => math.max(
  math.min(
    (lineHeight * paragraphFontShare).floor(),
    style.maxFontSize.floor(),
  ),
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
///
/// [cache], when given, keeps the measurements for later calls.
List<Rect> placeParagraphLabels(
  List<ParagraphLabel> labels,
  Size viewSize, {
  required OverlayStyle style,
  required TextDirection direction,
  LabelLayoutCache? cache,
}) {
  final view = Offset.zero & viewSize;
  final original = [for (final label in labels) label.rect.intersect(view)];
  return [
    for (final (i, label) in labels.indexed)
      _grow(i, label, original, view, style, direction, cache),
  ];
}

Rect _grow(
  int index,
  ParagraphLabel label,
  List<Rect> original,
  Rect view,
  OverlayStyle style,
  TextDirection direction,
  LabelLayoutCache? cache,
) {
  var rect = original[index];
  if (rect.isEmpty) return rect;
  final size = _startSize(label.lineHeight, style).toDouble();
  bool fits(Rect r) => _fits(label.text, size, r.size, style, direction, cache);
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
  ///
  /// [layoutCache], when given, keeps text layouts between paints; its
  /// owner disposes it.
  ParagraphPainter({
    required this.labels,
    required this.style,
    required this.textDirection,
    this.layoutCache,
  });

  /// The paragraphs to draw.
  final List<ParagraphLabel> labels;

  /// Supplies the corner radius, padding, minimum font size and weight; the
  /// colours come from each label.
  final OverlayStyle style;

  /// The translations' direction.
  final TextDirection textDirection;

  /// Keeps text layouts between paints, or `null` to lay out every time.
  final LabelLayoutCache? layoutCache;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(style.borderRadius);
    final view = Offset.zero & size;
    final cache = layoutCache;
    final placed = placeParagraphLabels(
      labels,
      size,
      style: style,
      direction: textDirection,
      cache: cache,
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
        cache: cache,
      );
      final lineHeight = _height(
        'M',
        fontSize,
        double.infinity,
        style,
        textDirection,
        cache,
      );
      final maxLines = math.max(1, (inner.height / lineHeight).floor());
      final width = _layoutWidth(inner.width);
      TextPainter layOut() => _layout(
        label.text,
        fontSize,
        ink,
        style,
        textDirection,
        maxLines: maxLines,
      )..layout(maxWidth: width);
      if (cache == null) {
        layOut()
          ..paint(canvas, inner.topLeft)
          ..dispose();
      } else {
        cache
            ._painter((
              label.text,
              fontSize,
              ink,
              maxLines,
              width,
              style,
              textDirection,
            ), layOut)
            .paint(canvas, inner.topLeft);
      }
    }
  }

  @override
  bool shouldRepaint(ParagraphPainter oldDelegate) =>
      !listEquals(oldDelegate.labels, labels) ||
      oldDelegate.style != style ||
      oldDelegate.textDirection != textDirection;
}
