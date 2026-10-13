import 'dart:ui' show Size;

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    show InputImageRotation;

import '../geometry/image_rotation.dart';

/// How far a frame streamed by the back camera on [platform] must be rotated
/// to match the on-screen preview.
///
/// - **Android** streams frames in the sensor's orientation, so the rotation
///   compensates for the [deviceOrientation].
/// - **iOS** streams frames already rotated to the device orientation, so no
///   rotation is applied.
///
/// Throws [UnsupportedError] on other platforms.
ImageRotation frameRotation({
  required TargetPlatform platform,
  required int sensorOrientation,
  required DeviceOrientation deviceOrientation,
}) {
  switch (platform) {
    case TargetPlatform.iOS:
      return ImageRotation.deg0;
    case TargetPlatform.android:
      final device = _degrees(deviceOrientation);
      return _fromDegrees((sensorOrientation - device + 360) % 360);
    case TargetPlatform.fuchsia ||
        TargetPlatform.linux ||
        TargetPlatform.macOS ||
        TargetPlatform.windows:
      throw UnsupportedError('Live camera translation needs Android or iOS.');
  }
}

/// The camera's reported [previewSize] turned to match the screen in
/// [deviceOrientation]: long side vertical in portrait, horizontal in
/// landscape.
///
/// Used to lay out the preview before the first frame arrives. The plugin
/// reports the preview size in the sensor's (landscape) orientation on both
/// platforms.
Size uprightPreviewSize(Size previewSize, DeviceOrientation deviceOrientation) {
  final long = previewSize.longestSide;
  final short = previewSize.shortestSide;
  return switch (deviceOrientation) {
    DeviceOrientation.portraitUp ||
    DeviceOrientation.portraitDown => Size(short, long),
    DeviceOrientation.landscapeLeft ||
    DeviceOrientation.landscapeRight => Size(long, short),
  };
}

int _degrees(DeviceOrientation orientation) => switch (orientation) {
  DeviceOrientation.portraitUp => 0,
  DeviceOrientation.landscapeLeft => 90,
  DeviceOrientation.portraitDown => 180,
  DeviceOrientation.landscapeRight => 270,
};

ImageRotation _fromDegrees(int degrees) => switch (degrees) {
  0 => ImageRotation.deg0,
  90 => ImageRotation.deg90,
  180 => ImageRotation.deg180,
  270 => ImageRotation.deg270,
  _ => throw ArgumentError.value(degrees, 'degrees', 'not a quarter turn'),
};

/// Converts an [ImageRotation] to ML Kit's rotation type.
extension ImageRotationMlKit on ImageRotation {
  /// The matching ML Kit rotation.
  InputImageRotation get inputImageRotation => switch (this) {
    ImageRotation.deg0 => InputImageRotation.rotation0deg,
    ImageRotation.deg90 => InputImageRotation.rotation90deg,
    ImageRotation.deg180 => InputImageRotation.rotation180deg,
    ImageRotation.deg270 => InputImageRotation.rotation270deg,
  };
}
