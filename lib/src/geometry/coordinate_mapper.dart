import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter/foundation.dart' show immutable;

import 'image_rotation.dart';

/// How an upright camera frame is scaled and positioned to fill a view.
///
/// The frame is scaled uniformly by the smallest factor that covers the whole
/// view, then centred, so any overflow is cropped equally on both sides. The
/// preview and the overlay must both use this layout, or boxes drift away
/// from the text they belong to.
@immutable
final class CoverLayout {
  const CoverLayout._({
    required this.scale,
    required this.offset,
    required this.previewRect,
  });

  /// Lays out a frame of [uprightSize] to fill a view of [viewSize].
  ///
  /// If either size is empty, returns a layout with a [scale] of 0 and an
  /// empty [previewRect] at the origin.
  factory CoverLayout.fit({required Size uprightSize, required Size viewSize}) {
    if (uprightSize.isEmpty || viewSize.isEmpty) return _empty;
    final scale = math.max(
      viewSize.width / uprightSize.width,
      viewSize.height / uprightSize.height,
    );
    final scaled = uprightSize * scale;
    final offset = Offset(
      (viewSize.width - scaled.width) / 2,
      (viewSize.height - scaled.height) / 2,
    );
    return CoverLayout._(
      scale: scale,
      offset: offset,
      previewRect: offset & scaled,
    );
  }

  static const _empty = CoverLayout._(
    scale: 0,
    offset: Offset.zero,
    previewRect: Rect.zero,
  );

  /// The factor from frame pixels to view pixels.
  final double scale;

  /// Where the frame's top-left corner lands in the view. Negative on an axis
  /// that is cropped.
  final Offset offset;

  /// The scaled frame's bounds in the view, which cover the view entirely.
  final Rect previewRect;

  @override
  bool operator ==(Object other) =>
      other is CoverLayout &&
      other.scale == scale &&
      other.offset == offset &&
      other.previewRect == previewRect;

  @override
  int get hashCode => Object.hash(scale, offset, previewRect);

  @override
  String toString() =>
      'CoverLayout(scale: $scale, offset: $offset, previewRect: $previewRect)';
}

/// Maps text boxes from an upright camera frame into the view showing it.
///
/// Create one mapper per frame configuration and reuse it for every box in
/// the frame. The preview should be positioned from [layout] so it matches
/// the boxes exactly.
final class CoordinateMapper {
  /// Creates a mapper for frames of [imageSize], as delivered by the camera,
  /// that need [rotation] to be upright and are shown in a view of
  /// [viewSize].
  CoordinateMapper({
    required Size imageSize,
    required ImageRotation rotation,
    required this.viewSize,
  }) : layout = CoverLayout.fit(
         uprightSize: rotation.upright(imageSize),
         viewSize: viewSize,
       );

  /// The size of the view the boxes are mapped into.
  final Size viewSize;

  /// How the upright frame fills the view.
  final CoverLayout layout;

  /// Maps [box], given in upright frame coordinates, into view coordinates.
  ///
  /// The result is not clipped to the view. Returns [Rect.zero] if the frame
  /// or the view is empty.
  Rect mapToView(Rect box) {
    if (layout.scale == 0) return Rect.zero;
    return (box.topLeft * layout.scale + layout.offset) &
        box.size * layout.scale;
  }
}
