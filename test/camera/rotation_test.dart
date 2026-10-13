import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show InputImageRotation;
import 'package:live_translate/src/camera/rotation.dart';
import 'package:live_translate/src/geometry/image_rotation.dart';

ImageRotation rotate(
  TargetPlatform platform,
  int sensor,
  DeviceOrientation device,
) => frameRotation(
  platform: platform,
  sensorOrientation: sensor,
  deviceOrientation: device,
);

void main() {
  const android = TargetPlatform.android;
  const iOS = TargetPlatform.iOS;

  group('spec scenarios', () {
    test('Android back camera, portrait', () {
      expect(
        rotate(android, 90, DeviceOrientation.portraitUp),
        ImageRotation.deg90,
      );
    });

    test('Android back camera, landscape left', () {
      expect(
        rotate(android, 90, DeviceOrientation.landscapeLeft),
        ImageRotation.deg0,
      );
    });

    test('iOS back camera in landscape', () {
      expect(
        rotate(iOS, 90, DeviceOrientation.landscapeRight),
        ImageRotation.deg0,
      );
    });
  });

  group('Android, every device orientation', () {
    const expectations = {
      DeviceOrientation.portraitUp: ImageRotation.deg90,
      DeviceOrientation.landscapeLeft: ImageRotation.deg0,
      DeviceOrientation.portraitDown: ImageRotation.deg270,
      DeviceOrientation.landscapeRight: ImageRotation.deg180,
    };
    for (final MapEntry(key: device, value: expected) in expectations.entries) {
      test(device.name, () {
        expect(rotate(android, 90, device), expected);
      });
    }
  });

  test('other platforms are unsupported', () {
    expect(
      () => rotate(TargetPlatform.macOS, 0, DeviceOrientation.portraitUp),
      throwsUnsupportedError,
    );
  });

  group('uprightPreviewSize', () {
    test('portrait puts the long side vertical', () {
      for (final device in [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]) {
        expect(
          uprightPreviewSize(const Size(1280, 720), device),
          const Size(720, 1280),
        );
      }
    });

    test('landscape puts the long side horizontal', () {
      for (final device in [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]) {
        expect(
          uprightPreviewSize(const Size(720, 1280), device),
          const Size(1280, 720),
        );
      }
    });
  });

  test('converts to ML Kit rotations', () {
    expect(
      ImageRotation.values.map((r) => r.inputImageRotation),
      InputImageRotation.values,
    );
  });
}
