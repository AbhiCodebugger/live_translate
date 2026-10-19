// Replay frames are built in the camera's own stream formats and handed to
// the package's internal pipeline.
// ignore_for_file: implementation_imports

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

// Only the frame types, to build camera frames from photos.
// ignore: depend_on_referenced_packages
import 'package:camera/camera.dart' show CameraImage, ImageFormatGroup;
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:live_translate/src/camera/camera_frame.dart';
import 'package:live_translate/src/geometry/image_rotation.dart';

/// Android's `ImageFormat.NV21`.
const nv21Raw = 17;

/// iOS's `kCVPixelFormatType_32BGRA`.
const bgraRaw = 1111970369;

/// The long side of the frames [platform]'s camera streams at
/// `ResolutionPreset.medium`: 720 × 480 on Android, 640 × 480 on iOS.
int streamLongSide(TargetPlatform platform) =>
    platform == TargetPlatform.android ? 720 : 640;

/// Decodes [encoded] (a JPEG or PNG) and returns it as an upright camera
/// frame in the format [platform]'s camera streams: NV21 on Android, BGRA
/// on iOS. Odd widths and heights lose their last column or row, as NV21
/// pairs pixels in 2 × 2 blocks.
///
/// With [longSide], a larger photo is first scaled down, keeping its
/// shape, so its long side is [longSide] pixels.
Future<CameraFrame> buildReplayFrame(
  Uint8List encoded,
  TargetPlatform platform, {
  int? longSide,
}) async {
  var codec = await ui.instantiateImageCodec(encoded);
  var image = (await codec.getNextFrame()).image;
  if (longSide != null && math.max(image.width, image.height) > longSide) {
    final portrait = image.height > image.width;
    image.dispose();
    codec.dispose();
    codec = await ui.instantiateImageCodec(
      encoded,
      targetWidth: portrait ? null : longSide,
      targetHeight: portrait ? longSide : null,
    );
    image = (await codec.getNextFrame()).image;
  }
  final rgba = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final sourceWidth = image.width;
  final width = image.width & ~1;
  final height = image.height & ~1;
  image.dispose();
  codec.dispose();

  final android = platform == TargetPlatform.android;
  final (bytes, bytesPerRow, bytesPerPixel) = android
      ? (toNv21(rgba, sourceWidth, width, height), width, 1)
      : (toBgra(rgba, sourceWidth, width, height), width * 4, 4);
  return CameraFrame(
    image: CameraImage.fromPlatformInterface(
      CameraImageData(
        format: CameraImageFormat(
          android ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
          raw: android ? nv21Raw : bgraRaw,
        ),
        width: width,
        height: height,
        planes: [
          CameraImagePlane(
            bytes: bytes,
            bytesPerRow: bytesPerRow,
            bytesPerPixel: bytesPerPixel,
          ),
        ],
      ),
    ),
    rotation: ImageRotation.deg0,
    generation: 1,
  );
}

/// Converts the top-left [width] × [height] pixels of an RGBA image
/// [stride] pixels wide into NV21: full-range BT.601 luma for every pixel,
/// then interleaved V and U for each 2 × 2 block.
Uint8List toNv21(Uint8List rgba, int stride, int width, int height) {
  final out = Uint8List(width * height * 3 ~/ 2);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * stride + x) * 4;
      out[y * width + x] = _clamp(
        0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2],
      );
    }
  }
  var chroma = width * height;
  for (var y = 0; y < height; y += 2) {
    for (var x = 0; x < width; x += 2) {
      var r = 0, g = 0, b = 0;
      for (final (dx, dy) in const [(0, 0), (1, 0), (0, 1), (1, 1)]) {
        final i = ((y + dy) * stride + x + dx) * 4;
        r += rgba[i];
        g += rgba[i + 1];
        b += rgba[i + 2];
      }
      final (rr, gg, bb) = (r / 4, g / 4, b / 4);
      out[chroma++] = _clamp(128 + 0.5 * rr - 0.418688 * gg - 0.081312 * bb);
      out[chroma++] = _clamp(128 - 0.168736 * rr - 0.331264 * gg + 0.5 * bb);
    }
  }
  return out;
}

/// Converts the top-left [width] × [height] pixels of an RGBA image
/// [stride] pixels wide into BGRA.
Uint8List toBgra(Uint8List rgba, int stride, int width, int height) {
  final out = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * stride + x) * 4;
      final o = (y * width + x) * 4;
      out[o] = rgba[i + 2];
      out[o + 1] = rgba[i + 1];
      out[o + 2] = rgba[i];
      out[o + 3] = rgba[i + 3];
    }
  }
  return out;
}

int _clamp(double value) => value.round().clamp(0, 255);
