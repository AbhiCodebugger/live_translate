import 'dart:ui' show Size;

import 'package:camera/camera.dart' show CameraImage;
import 'package:flutter/foundation.dart' show immutable;

import '../geometry/image_rotation.dart';

/// A streamed camera frame, tagged with what is needed to place its results.
@immutable
final class CameraFrame {
  /// Creates a frame.
  const CameraFrame({
    required this.image,
    required this.rotation,
    required this.generation,
  });

  /// The frame as delivered by the camera.
  final CameraImage image;

  /// How far [image] must be rotated to be upright.
  final ImageRotation rotation;

  /// The capture session this frame belongs to. It changes on every stop and
  /// start, so results from an earlier session can be recognised and dropped.
  final int generation;

  /// The size of [image] as delivered.
  Size get size => Size(image.width.toDouble(), image.height.toDouble());
}
