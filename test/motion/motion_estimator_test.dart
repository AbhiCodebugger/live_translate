import 'package:camera/camera.dart' show CameraImage;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/camera/camera_frame.dart';
import 'package:live_translate/src/geometry/image_rotation.dart';
import 'package:live_translate/src/motion/motion_estimator.dart';

import '../support/frames.dart';

CameraFrame _frame(
  CameraImage image, [
  ImageRotation rotation = ImageRotation.deg0,
]) => CameraFrame(image: image, rotation: rotation, generation: 1);

// One thumbnail sample of a 1280-wide frame is 20 pixels; the fractional
// refinement measures to within a few pixels.
const _tolerance = 4.0;

Matcher _near(Offset expected) => predicate<Offset>(
  (o) =>
      (o.dx - expected.dx).abs() <= _tolerance &&
      (o.dy - expected.dy).abs() <= _tolerance,
  'within $_tolerance of $expected',
);

void main() {
  late MotionEstimator estimator;

  setUp(() => estimator = MotionEstimator());

  Motion between(CameraFrame a, CameraFrame b) {
    estimator.measure(a);
    return estimator.measure(b);
  }

  test('the first frame is unknown', () {
    expect(estimator.measure(_frame(texturedImage())), Motion.unknown);
  });

  test('the same picture has no shift and no change', () {
    final motion = between(_frame(texturedImage()), _frame(texturedImage()));
    expect(motion.shift, Offset.zero);
    expect(motion.change, lessThan(1));
  });

  for (final bgra in [false, true]) {
    final format = bgra ? 'bgra8888' : 'nv21';

    test('measures a move to the right ($format)', () {
      final motion = between(
        _frame(texturedImage(bgra: bgra)),
        _frame(texturedImage(dx: 40, bgra: bgra)),
      );
      expect(motion.shift, _near(const Offset(40, 0)));
      expect(motion.change, lessThan(10));
    });

    test('measures a move up ($format)', () {
      final motion = between(
        _frame(texturedImage(bgra: bgra)),
        _frame(texturedImage(dy: -24, bgra: bgra)),
      );
      expect(motion.shift, _near(const Offset(0, -24)));
    });
  }

  test('measures the shift upright on a rotated frame', () {
    // Turned 90° clockwise to be upright, raw +x is upright +y.
    final motion = between(
      _frame(texturedImage(), ImageRotation.deg90),
      _frame(texturedImage(dx: 60), ImageRotation.deg90),
    );
    expect(motion.shift, _near(const Offset(0, 60)));
  });

  test('a brighter exposure is not a change', () {
    final motion = between(
      _frame(texturedImage()),
      _frame(texturedImage(brightness: 30)),
    );
    expect(motion.shift, Offset.zero);
    expect(motion.change, lessThan(10));
  });

  test('a drift smaller than one sample is measured', () {
    final motion = between(
      _frame(texturedImage()),
      _frame(texturedImage(dx: 7)),
    );
    expect(motion.shift, _near(const Offset(7, 0)));
    expect(motion.change, lessThan(10));
  });

  test('a different scene is a strong change', () {
    final motion = between(
      _frame(texturedImage()),
      _frame(texturedImage(seed: 7)),
    );
    expect(motion.change, greaterThan(18));
  });

  test('a frame of another size is unknown', () {
    final motion = between(
      _frame(texturedImage()),
      _frame(texturedImage(width: 640, height: 480)),
    );
    expect(motion, Motion.unknown);
  });

  test('reports how long a measurement takes', () {
    final frames = [
      for (var i = 0; i < 4; i++) _frame(texturedImage(dx: i * 8.0)),
    ];
    final watch = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      estimator.measure(frames[i % frames.length]);
    }
    // Not asserted: CI machines vary. Profile on a device instead.
    // ignore: avoid_print
    print('MotionEstimator.measure: ${watch.elapsedMicroseconds / 100} µs');
  });
}
