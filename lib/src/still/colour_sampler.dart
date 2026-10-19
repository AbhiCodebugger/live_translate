import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color, Offset, Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show InputImageFormat, InputImageFormatValue;

import '../camera/camera_frame.dart';
import '../geometry/image_rotation.dart';

/// The page and ink colours behind and of a paragraph's text.
typedef PageColours = ({Color background, Color ink});

/// The lowest contrast ratio accepted between the sampled ink and page.
const minInkContrast = 4.5;

const _columns = 48;
const _rows = 16;

/// Samples the page colour and ink colour inside [uprightBox] of [frame],
/// or returns `null` when the frame's format can't be read or the box lies
/// outside the frame.
///
/// The page is the most common colour in the box, since text covers only a
/// minority of a paragraph's area. The ink is the mean of the samples
/// farthest from the page in brightness. When the two contrast by less than
/// [minInkContrast], black or white ink is used instead, whichever contrasts
/// more with the page.
PageColours? sampleColours(CameraFrame frame, Rect uprightBox) {
  final read = _pixelReader(frame);
  if (read == null) return null;
  final width = frame.image.width;
  final height = frame.image.height;
  final upright = frame.rotation.upright(frame.size);
  final box = uprightBox.intersect(Offset.zero & upright);
  if (box.width < 1 || box.height < 1) return null;

  final samples = <_Rgb>[];
  final columns = math.min(_columns, box.width.floor());
  final rows = math.min(_rows, box.height.floor());
  for (var row = 0; row < rows; row++) {
    for (var column = 0; column < columns; column++) {
      final u = box.left + (column + 0.5) * box.width / columns;
      final v = box.top + (row + 0.5) * box.height / rows;
      final (x, y) = uprightToRaw(frame.rotation, u, v, width, height);
      samples.add(read(x.clamp(0, width - 1), y.clamp(0, height - 1)));
    }
  }
  return _pageAndInk(samples);
}

PageColours _pageAndInk(List<_Rgb> samples) {
  // The most common colour, at 4 bits per channel, is the page.
  final buckets = <int, List<_Rgb>>{};
  for (final sample in samples) {
    buckets.putIfAbsent(sample.bucket, () => []).add(sample);
  }
  final page = _mean(
    buckets.values.reduce((a, b) => b.length > a.length ? b : a),
  );
  final pageLuminance = page.luminance;

  final distinct =
      [
        for (final sample in samples)
          if ((sample.luminance - pageLuminance).abs() > 0.25) sample,
      ]..sort(
        (a, b) => (b.luminance - pageLuminance).abs().compareTo(
          (a.luminance - pageLuminance).abs(),
        ),
      );
  final background = page.colour;
  if (distinct.isEmpty) return (background: background, ink: _readable(page));
  final ink = _mean(distinct.take(math.max(1, distinct.length ~/ 5)).toList());
  return (
    background: background,
    ink: _contrast(page, ink) >= minInkContrast ? ink.colour : _readable(page),
  );
}

/// Black or white, whichever contrasts more with [page].
Color _readable(_Rgb page) =>
    _contrast(page, _Rgb.black) >= _contrast(page, _Rgb.white)
    ? const Color(0xFF000000)
    : const Color(0xFFFFFFFF);

double _contrast(_Rgb a, _Rgb b) {
  final lighter = math.max(a.luminance, b.luminance);
  final darker = math.min(a.luminance, b.luminance);
  return (lighter + 0.05) / (darker + 0.05);
}

_Rgb _mean(List<_Rgb> samples) {
  var r = 0, g = 0, b = 0;
  for (final sample in samples) {
    r += sample.r;
    g += sample.g;
    b += sample.b;
  }
  final n = samples.length;
  return _Rgb((r / n).round(), (g / n).round(), (b / n).round());
}

/// The raw buffer position of the upright point ([u], [v]) in a frame of
/// [width] × [height] that must be turned [rotation] clockwise to be upright.
(int, int) uprightToRaw(
  ImageRotation rotation,
  double u,
  double v,
  int width,
  int height,
) {
  final (x, y) = switch (rotation) {
    ImageRotation.deg0 => (u, v),
    ImageRotation.deg90 => (v, height - u),
    ImageRotation.deg180 => (width - u, height - v),
    ImageRotation.deg270 => (width - v, u),
  };
  return (x.floor(), y.floor());
}

_Rgb Function(int x, int y)? _pixelReader(CameraFrame frame) {
  final image = frame.image;
  final raw = image.format.raw;
  if (raw is! int || image.planes.length != 1) return null;
  final plane = image.planes.single;
  final bytes = plane.bytes;
  final stride = plane.bytesPerRow;
  return switch (InputImageFormatValue.fromRawValue(raw)) {
    InputImageFormat.nv21 => (x, y) => _nv21(bytes, stride, image.height, x, y),
    InputImageFormat.bgra8888 => (x, y) {
      final i = y * stride + x * 4;
      return _Rgb(bytes[i + 2], bytes[i + 1], bytes[i]);
    },
    _ => null,
  };
}

_Rgb _nv21(Uint8List bytes, int stride, int height, int x, int y) {
  final luma = bytes[y * stride + x];
  // Interleaved V then U, one pair per 2 × 2 block, after the Y plane.
  final chroma = stride * height + (y ~/ 2) * stride + (x ~/ 2) * 2;
  final v = bytes[chroma] - 128;
  final u = bytes[chroma + 1] - 128;
  // BT.601, full range.
  return _Rgb(
    (luma + 1.402 * v).round().clamp(0, 255),
    (luma - 0.344136 * u - 0.714136 * v).round().clamp(0, 255),
    (luma + 1.772 * u).round().clamp(0, 255),
  );
}

final class _Rgb {
  _Rgb(this.r, this.g, this.b);

  static final black = _Rgb(0, 0, 0);
  static final white = _Rgb(255, 255, 255);

  final int r;
  final int g;
  final int b;

  int get bucket => (r >> 4) << 8 | (g >> 4) << 4 | b >> 4;

  /// WCAG relative luminance, from 0 (black) to 1 (white). Computed once,
  /// as sorting the samples compares it many times.
  late final double luminance =
      0.2126 * _linear(r) + 0.7152 * _linear(g) + 0.0722 * _linear(b);

  Color get colour => Color.fromARGB(0xFF, r, g, b);

  static double _linear(int channel) {
    final c = channel / 255;
    return c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }
}
