import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart' show immutable;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show InputImageFormat, InputImageFormatValue;

import '../camera/camera_frame.dart';
import '../geometry/image_rotation.dart';
import '../still/colour_sampler.dart' show uprightToRaw;

/// How the picture moved between two frames.
@immutable
final class Motion {
  /// Creates a measured motion.
  const Motion(this.shift, this.change);

  /// No previous frame to compare with, or the frame changed size,
  /// rotation or format; counts as moving.
  static const unknown = Motion(Offset.zero, double.infinity);

  /// How far the picture's content moved, in upright frame pixels.
  final Offset shift;

  /// How much the picture still differs once the shift is undone: the mean
  /// absolute brightness difference, from 0 (identical) to 255.
  final double change;

  /// Whether this motion was measured.
  bool get isKnown => change.isFinite;

  @override
  bool operator ==(Object other) =>
      other is Motion && other.shift == shift && other.change == change;

  @override
  int get hashCode => Object.hash(shift, change);

  @override
  String toString() => 'Motion($shift, change $change)';
}

/// Samples along the thumbnail's long side.
const thumbnailSize = 64;

const _coarseRange = 6;
const _fineRange = 2;

/// Measures how the picture moves from frame to frame, from a small
/// brightness thumbnail of each frame.
///
/// Each thumbnail has its mean brightness removed, so exposure changes don't
/// count as change. The shift is found coarse to fine: at half size within
/// ±6 samples, then at full size within ±2 of that.
final class MotionEstimator {
  _Thumbnail? _previous;

  /// Measures how [frame] moved since the previous frame measured.
  Motion measure(CameraFrame frame) {
    final current = _Thumbnail.of(frame);
    final previous = _previous;
    _previous = current;
    if (current == null ||
        previous == null ||
        previous.width != current.width ||
        previous.height != current.height ||
        previous.source != current.source) {
      return Motion.unknown;
    }

    final coarse = _search(
      current.halved(),
      previous.halved(),
      centre: (0, 0),
      range: _coarseRange,
    );
    final fine = _search(
      current,
      previous,
      centre: (coarse.dx * 2, coarse.dy * 2),
      range: _fineRange,
    );
    if (!fine.score.isFinite) return Motion.unknown;

    // Refine to a fraction of a sample with a parabola through the scores
    // either side, then measure the change at that fractional shift.
    double vertex(double before, double at, double after) {
      final curvature = before - 2 * at + after;
      if (!before.isFinite || !after.isFinite || curvature <= 0) return 0;
      return ((before - after) / (2 * curvature)).clamp(-0.5, 0.5);
    }

    final dx =
        fine.dx +
        vertex(
          _difference(current, previous, fine.dx - 1, fine.dy),
          fine.score,
          _difference(current, previous, fine.dx + 1, fine.dy),
        );
    final dy =
        fine.dy +
        vertex(
          _difference(current, previous, fine.dx, fine.dy - 1),
          fine.score,
          _difference(current, previous, fine.dx, fine.dy + 1),
        );
    return Motion(
      Offset(dx * current.step, dy * current.step),
      math.min(fine.score, _fractionalDifference(current, previous, dx, dy)),
    );
  }

  /// Forgets the previous frame, so the next one measures as unknown.
  void reset() => _previous = null;
}

({int dx, int dy, double score}) _search(
  _Thumbnail current,
  _Thumbnail previous, {
  required (int, int) centre,
  required int range,
}) {
  var best = (dx: 0, dy: 0, score: double.infinity);
  final (cx, cy) = centre;
  for (var dy = cy - range; dy <= cy + range; dy++) {
    for (var dx = cx - range; dx <= cx + range; dx++) {
      final score = _difference(current, previous, dx, dy);
      if (score < best.score) best = (dx: dx, dy: dy, score: score);
    }
  }
  return best;
}

/// The mean absolute difference where [current] overlaps [previous] with
/// content moved by ([dx], [dy]): current(x, y) against previous(x − dx,
/// y − dy).
double _difference(_Thumbnail current, _Thumbnail previous, int dx, int dy) {
  final w = current.width;
  final h = current.height;
  final x0 = math.max(0, dx);
  final x1 = math.min(w, w + dx);
  final y0 = math.max(0, dy);
  final y1 = math.min(h, h + dy);
  // Too little overlap to judge.
  if ((x1 - x0) * 2 < w || (y1 - y0) * 2 < h) return double.infinity;
  var sum = 0.0;
  for (var y = y0; y < y1; y++) {
    final row = y * w;
    final previousRow = (y - dy) * w - dx;
    for (var x = x0; x < x1; x++) {
      sum += (current.values[row + x] - previous.values[previousRow + x]).abs();
    }
  }
  return sum / ((x1 - x0) * (y1 - y0));
}

/// [_difference] at a fractional shift, reading [previous] by bilinear
/// interpolation.
double _fractionalDifference(
  _Thumbnail current,
  _Thumbnail previous,
  double dx,
  double dy,
) {
  final w = current.width;
  final h = current.height;
  final x0 = math.max(0, dx.ceil());
  final x1 = math.min(w, (w + dx).floor() - 1);
  final y0 = math.max(0, dy.ceil());
  final y1 = math.min(h, (h + dy).floor() - 1);
  if ((x1 - x0) * 2 < w || (y1 - y0) * 2 < h) return double.infinity;
  var sum = 0.0;
  for (var y = y0; y < y1; y++) {
    final py = y - dy;
    final j = py.floor();
    final fy = py - j;
    for (var x = x0; x < x1; x++) {
      final px = x - dx;
      final i = px.floor();
      final fx = px - i;
      final a = j * w + i;
      final top = previous.values[a] * (1 - fx) + previous.values[a + 1] * fx;
      final bottom =
          previous.values[a + w] * (1 - fx) + previous.values[a + w + 1] * fx;
      sum += (current.values[y * w + x] - (top * (1 - fy) + bottom * fy)).abs();
    }
  }
  return sum / ((x1 - x0) * (y1 - y0));
}

final class _Thumbnail {
  _Thumbnail(this.width, this.height, this.values, this.step, this.source);

  final int width;
  final int height;

  /// Brightness minus the mean, row by row.
  final Float32List values;

  /// Upright frame pixels per sample.
  final double step;

  /// The frame's size and rotation, so frames that can't be compared are
  /// told apart.
  final (Size, ImageRotation) source;

  static _Thumbnail? of(CameraFrame frame) {
    final luma = _lumaReader(frame);
    if (luma == null) return null;
    final image = frame.image;
    final upright = frame.rotation.upright(frame.size);
    final long = math.max(upright.width, upright.height);
    if (long <= 0) return null;
    final step = long / thumbnailSize;
    final width = math.max(1, (upright.width / step).round());
    final height = math.max(1, (upright.height / step).round());
    final values = Float32List(width * height);
    var total = 0.0;
    for (var j = 0; j < height; j++) {
      for (var i = 0; i < width; i++) {
        final (x, y) = uprightToRaw(
          frame.rotation,
          (i + 0.5) * step,
          (j + 0.5) * step,
          image.width,
          image.height,
        );
        final value = luma(
          x.clamp(0, image.width - 1),
          y.clamp(0, image.height - 1),
        ).toDouble();
        values[j * width + i] = value;
        total += value;
      }
    }
    final mean = total / values.length;
    for (var k = 0; k < values.length; k++) {
      values[k] -= mean;
    }
    return _Thumbnail(width, height, values, step, (
      frame.size,
      frame.rotation,
    ));
  }

  /// This thumbnail at half size, each sample the mean of a 2 × 2 block.
  _Thumbnail halved() {
    final w = width ~/ 2;
    final h = height ~/ 2;
    final out = Float32List(w * h);
    for (var j = 0; j < h; j++) {
      for (var i = 0; i < w; i++) {
        final a = (2 * j) * width + 2 * i;
        out[j * w + i] =
            (values[a] +
                values[a + 1] +
                values[a + width] +
                values[a + width + 1]) /
            4;
      }
    }
    return _Thumbnail(w, h, out, step * 2, source);
  }
}

int Function(int x, int y)? _lumaReader(CameraFrame frame) {
  final image = frame.image;
  final raw = image.format.raw;
  if (raw is! int || image.planes.length != 1) return null;
  final plane = image.planes.single;
  final bytes = plane.bytes;
  final stride = plane.bytesPerRow;
  return switch (InputImageFormatValue.fromRawValue(raw)) {
    InputImageFormat.nv21 => (x, y) => bytes[y * stride + x],
    InputImageFormat.bgra8888 => (x, y) {
      final i = y * stride + x * 4;
      return (0.114 * bytes[i] + 0.587 * bytes[i + 1] + 0.299 * bytes[i + 2])
          .round();
    },
    _ => null,
  };
}
