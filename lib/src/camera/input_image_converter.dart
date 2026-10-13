import 'dart:ui' show Size;

import 'package:camera/camera.dart' show CameraImage;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../geometry/image_rotation.dart';
import 'rotation.dart';

/// Converts a streamed camera frame into an ML Kit [InputImage].
///
/// Supports the single-plane formats the camera streams for recognition:
/// nv21 on Android and bgra8888 on iOS. Returns `null` for any other frame,
/// which callers skip.
InputImage? toInputImage(CameraImage image, ImageRotation rotation) {
  final raw = image.format.raw;
  if (raw is! int || image.planes.length != 1) return null;
  final format = InputImageFormatValue.fromRawValue(raw);
  if (format == null) return null;
  final plane = image.planes.single;
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation.inputImageRotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}
