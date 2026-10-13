import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_translate/src/camera/camera_session.dart';
import 'package:live_translate/src/errors.dart';

const _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);
const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

void main() {
  group('mapCameraError', () {
    for (final code in [
      'CameraAccessDenied',
      'CameraAccessDeniedWithoutPrompt',
      'CameraAccessRestricted',
    ]) {
      test('maps $code to CameraPermissionDenied', () {
        expect(
          mapCameraError(CameraException(code, null)),
          isA<CameraPermissionDenied>(),
        );
      });
    }

    test('maps any other camera failure to CameraUnavailable', () {
      expect(
        mapCameraError(CameraException('cameraNotFound', null)),
        isA<CameraUnavailable>(),
      );
      expect(mapCameraError(StateError('boom')), isA<CameraUnavailable>());
    });

    test('passes package errors through', () {
      const error = CameraPermissionDenied();
      expect(mapCameraError(error), same(error));
    });
  });

  group('selectBackCamera', () {
    test('picks the back camera when a front camera comes first', () {
      expect(selectBackCamera([_front, _back]), same(_back));
    });

    test('reports CameraUnavailable with only a front camera', () {
      expect(
        () => selectBackCamera([_front]),
        throwsA(isA<CameraUnavailable>()),
      );
    });

    test('reports CameraUnavailable with no cameras', () {
      expect(() => selectBackCamera([]), throwsA(isA<CameraUnavailable>()));
    });
  });

  group('PluginCameraSession', () {
    test('reports CameraUnavailable when the device has no cameras', () async {
      final session = PluginCameraSession(cameras: () async => []);
      await expectLater(session.start(), throwsA(isA<CameraUnavailable>()));
      await session.dispose();
    });

    test('reports CameraUnavailable with only a front camera', () async {
      final session = PluginCameraSession(cameras: () async => [_front]);
      await expectLater(session.start(), throwsA(isA<CameraUnavailable>()));
      await session.dispose();
    });

    test('maps a failure listing cameras', () async {
      final session = PluginCameraSession(
        cameras: () async => throw CameraException('CameraAccessDenied', null),
      );
      await expectLater(
        session.start(),
        throwsA(isA<CameraPermissionDenied>()),
      );
      await session.dispose();
    });

    test('maps any other start failure to CameraUnavailable', () async {
      final session = PluginCameraSession(
        cameras: () async => throw StateError('camera service died'),
      );
      await expectLater(session.start(), throwsA(isA<CameraUnavailable>()));
      await session.dispose();
    });

    test('is idle before starting', () async {
      final session = PluginCameraSession();
      expect(session.uprightPreviewSize, isNull);
      expect(session.buildPreview(), isA<SizedBox>());
      // Pausing, resuming and the torch do nothing without a camera.
      await session.pause();
      await session.resume();
      await session.setTorch(true);
      await session.stop();
      await session.dispose();
    });
  });
}
