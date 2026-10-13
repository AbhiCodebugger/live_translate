import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:live_translate/src/camera/input_image_converter.dart';
import 'package:live_translate/src/geometry/image_rotation.dart';

import '../support/frames.dart';

void main() {
  test('converts a single-plane nv21 frame', () {
    final image = cameraImage();
    final input = toInputImage(image, ImageRotation.deg90);

    expect(input, isNotNull);
    final metadata = input!.metadata!;
    expect(metadata.size, const Size(1280, 720));
    expect(metadata.rotation, InputImageRotation.rotation90deg);
    expect(metadata.format, InputImageFormat.nv21);
    expect(metadata.bytesPerRow, 1280);
    expect(input.bytes, same(image.planes.single.bytes));
  });

  test('skips a three-plane frame', () {
    expect(toInputImage(cameraImage(planes: 3), ImageRotation.deg0), isNull);
  });

  test('skips an unknown format', () {
    expect(toInputImage(cameraImage(raw: 12345), ImageRotation.deg0), isNull);
  });
}
