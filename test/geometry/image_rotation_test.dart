import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/geometry/image_rotation.dart';

void main() {
  const delivered = Size(1280, 720);

  group('ImageRotation.upright', () {
    test('swaps the dimensions for a quarter turn', () {
      expect(ImageRotation.deg90.upright(delivered), const Size(720, 1280));
      expect(ImageRotation.deg270.upright(delivered), const Size(720, 1280));
    });

    test('keeps the dimensions for no turn or a half turn', () {
      expect(ImageRotation.deg0.upright(delivered), delivered);
      expect(ImageRotation.deg180.upright(delivered), delivered);
    });
  });

  test('isQuarterTurn is true only for 90 and 270 degrees', () {
    expect(ImageRotation.values.where((r) => r.isQuarterTurn), [
      ImageRotation.deg90,
      ImageRotation.deg270,
    ]);
  });
}
