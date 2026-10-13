import 'dart:ui';

import 'package:camera/camera.dart' show CameraImage;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/camera/camera_frame.dart';
import 'package:live_translate/src/geometry/image_rotation.dart';
import 'package:live_translate/src/still/colour_sampler.dart';

import '../support/frames.dart';

const _white = (250, 250, 248);
const _black = (20, 20, 25);
const _blue = (20, 60, 200);

/// Horizontal text-like stripes: 2 of every 8 rows are [ink].
Rgb Function(int, int) _stripes(Rgb page, Rgb ink) =>
    (x, y) => y % 8 < 2 ? ink : page;

CameraFrame _frame(
  CameraImage image, [
  ImageRotation rotation = ImageRotation.deg0,
]) => CameraFrame(image: image, rotation: rotation, generation: 1);

Matcher _near(Rgb expected, {int tolerance = 12}) => predicate<Color>((c) {
  final (r, g, b) = expected;
  int channel(double v) => (v * 255).round();
  return (channel(c.r) - r).abs() <= tolerance &&
      (channel(c.g) - g).abs() <= tolerance &&
      (channel(c.b) - b).abs() <= tolerance;
}, 'a colour near $expected');

/// Samples a frame that can be sampled.
PageColours _sample(CameraFrame frame, Rect box) => sampleColours(frame, box)!;

void main() {
  const box = Rect.fromLTWH(10, 10, 100, 40);

  test('black text on a white page (bgra8888)', () {
    final colours = _sample(
      _frame(bgraImage(120, 60, _stripes(_white, _black))),
      box,
    );
    expect(colours.background, _near(_white));
    expect(colours.ink, _near(_black));
  });

  test('white text on a blue sign (nv21)', () {
    final colours = _sample(
      _frame(nv21Image(120, 60, _stripes(_blue, (255, 255, 255)))),
      box,
    );
    expect(colours.background, _near(_blue, tolerance: 16));
    expect(colours.ink, _near((255, 255, 255), tolerance: 16));
  });

  test('a flat colour falls back to black or white ink', () {
    final light = _sample(_frame(bgraImage(120, 60, (_, _) => _white)), box);
    expect(light.ink, const Color(0xFF000000));
    final dark = _sample(
      _frame(bgraImage(120, 60, (_, _) => (40, 40, 60))),
      box,
    );
    expect(dark.ink, const Color(0xFFFFFFFF));
  });

  test('low-contrast ink falls back to black or white', () {
    // Mid grey on white: different enough to be ink, but only ~3:1.
    final colours = _sample(
      _frame(bgraImage(120, 60, _stripes(_white, (148, 148, 148)))),
      box,
    );
    expect(colours.background, _near(_white));
    expect(colours.ink, const Color(0xFF000000));
  });

  test('samples the raw region of a box on a rotated frame', () {
    // Raw 120 × 60, turned 90° clockwise to an upright 60 × 120. The upright
    // box (0, 0)–(30, 40) is raw x 0–40, y 30–60 (the lower left); only
    // that region is a striped page, the rest is plain red.
    Rgb paint(int x, int y) =>
        x < 40 && y >= 30 ? _stripes(_white, _black)(x, y) : (220, 30, 30);
    final frame = _frame(nv21Image(120, 60, paint), ImageRotation.deg90);

    final page = _sample(frame, const Rect.fromLTWH(0, 0, 30, 40));
    expect(page.background, _near(_white, tolerance: 16));
    expect(page.ink, _near(_black, tolerance: 16));

    final elsewhere = _sample(frame, const Rect.fromLTWH(30, 60, 30, 60));
    expect(elsewhere.background, _near((220, 30, 30), tolerance: 20));
  });

  test('a box outside the frame gives nothing', () {
    final colours = sampleColours(
      _frame(bgraImage(120, 60, (_, _) => _blue)),
      const Rect.fromLTWH(500, 500, 10, 10),
    );
    expect(colours, isNull);
  });
}
