// Times the package's hot paths on the host, for before/after comparisons
// on one machine. The numbers come from the JIT and are not published.
//
//   flutter test --tags benchmark --run-skipped
@Tags(['benchmark'])
library;

import 'dart:ui' as ui;

import 'package:camera/camera.dart' show CameraImage;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/camera/camera_frame.dart';
import 'package:live_translate/src/geometry/image_rotation.dart';
import 'package:live_translate/src/models/overlay_style.dart';
import 'package:live_translate/src/motion/motion_estimator.dart';
import 'package:live_translate/src/still/colour_sampler.dart';
import 'package:live_translate/src/view/paragraph_painter.dart';

import '../support/frames.dart';

/// Runs [body] [warmUp] times, then [iterations] times, and prints the mean
/// time per run in microseconds.
void _time(
  String name,
  void Function() body, {
  int warmUp = 50,
  int iterations = 500,
}) {
  for (var i = 0; i < warmUp; i++) {
    body();
  }
  final watch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    body();
  }
  final micros = watch.elapsedMicroseconds / iterations;
  // ignore: avoid_print
  print('${name.padRight(44)} ${micros.toStringAsFixed(1).padLeft(9)} µs');
}

CameraFrame _frame(CameraImage image, ImageRotation rotation) =>
    CameraFrame(image: image, rotation: rotation, generation: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('motion estimate per frame', () {
    for (final (name, width, height, bgra) in [
      ('720 × 480 nv21', 720, 480, false),
      ('640 × 480 bgra', 640, 480, true),
    ]) {
      final still = texturedImage(width: width, height: height, bgra: bgra);
      final moved = texturedImage(
        width: width,
        height: height,
        dx: 3,
        dy: 2,
        bgra: bgra,
      );
      for (final rotation in ImageRotation.values) {
        test('$name ${rotation.name}', () {
          final estimator = MotionEstimator();
          final frames = [_frame(still, rotation), _frame(moved, rotation)];
          var i = 0;
          _time(
            'motion $name ${rotation.name}',
            () => estimator.measure(frames[i++ % 2]),
          );
        });
      }
    }
  });

  test('colour sampling of 5 paragraphs', () {
    final image = nv21Image(
      720,
      480,
      (x, y) => (x ~/ 6 + y ~/ 4).isEven ? (240, 236, 220) : (30, 30, 40),
    );
    final frame = _frame(image, ImageRotation.deg90);
    final boxes = [
      for (var i = 0; i < 5; i++) Rect.fromLTWH(20, 40.0 + i * 120, 400, 80),
    ];
    _time('colours 5 paragraphs, 720 × 480 nv21', () {
      for (final box in boxes) {
        sampleColours(frame, box);
      }
    }, iterations: 200);
  });

  test('label painting while held labels follow the camera', () {
    const style = OverlayStyle();
    final labels = [
      for (var i = 0; i < 5; i++)
        ParagraphLabel(
          rect: Rect.fromLTWH(24, 80.0 + i * 140, 300, 60),
          lineHeight: 24,
          text:
              'The translated paragraph number $i, long enough to wrap '
              'onto a second line',
          background: const Color(0xFFF0ECDC),
          ink: const Color(0xFF1E1E28),
        ),
    ];
    const size = Size(390, 844);
    // One cache for the whole pan, as the view keeps one.
    final cache = LabelLayoutCache();
    addTearDown(cache.dispose);
    var frame = 0;
    _time('paint 5 labels, one shifted frame', () {
      // 60 frames of a slow pan, then back.
      final shift = Offset((frame % 60) * 1.5, (frame % 60) * 0.5);
      frame++;
      final recorder = ui.PictureRecorder();
      ParagraphPainter(
        labels: [
          for (final label in labels)
            ParagraphLabel(
              rect: label.rect.shift(shift),
              lineHeight: label.lineHeight,
              text: label.text,
              background: label.background,
              ink: label.ink,
            ),
        ],
        style: style,
        textDirection: TextDirection.ltr,
        layoutCache: cache,
      ).paint(Canvas(recorder), size);
      recorder.endRecording().dispose();
    }, iterations: 300);
  });
}
