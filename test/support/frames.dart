import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';

/// Android's raw code for nv21 frames.
const nv21Raw = 17;

/// Builds a streamed camera frame for tests.
CameraImage cameraImage({
  int width = 1280,
  int height = 720,
  int raw = nv21Raw,
  int planes = 1,
}) => CameraImage.fromPlatformInterface(
  CameraImageData(
    format: CameraImageFormat(ImageFormatGroup.nv21, raw: raw),
    width: width,
    height: height,
    planes: [
      for (var i = 0; i < planes; i++)
        CameraImagePlane(
          bytes: Uint8List(width * height * 3 ~/ 2),
          bytesPerRow: width,
          bytesPerPixel: 1,
        ),
    ],
  ),
);

/// iOS's raw code for bgra8888 frames.
const bgraRaw = 1111970369;

/// An RGB colour as three channels from 0 to 255.
typedef Rgb = (int, int, int);

/// A bgra8888 frame whose pixel at raw (x, y) is [paint]'s colour.
CameraImage bgraImage(int width, int height, Rgb Function(int x, int y) paint) {
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final (r, g, b) = paint(x, y);
      final i = (y * width + x) * 4;
      bytes
        ..[i] = b
        ..[i + 1] = g
        ..[i + 2] = r
        ..[i + 3] = 255;
    }
  }
  return CameraImage.fromPlatformInterface(
    CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.bgra8888, raw: bgraRaw),
      width: width,
      height: height,
      planes: [
        CameraImagePlane(
          bytes: bytes,
          bytesPerRow: width * 4,
          bytesPerPixel: 4,
        ),
      ],
    ),
  );
}

/// An nv21 frame whose pixel at raw (x, y) is [paint]'s colour. Each 2 × 2
/// block takes its chroma from its top-left pixel.
CameraImage nv21Image(int width, int height, Rgb Function(int x, int y) paint) {
  final bytes = Uint8List(width * height * 3 ~/ 2);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final (r, g, b) = paint(x, y);
      bytes[y * width + x] = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(
        0,
        255,
      );
      if (x.isEven && y.isEven) {
        final chroma = width * height + (y ~/ 2) * width + x;
        bytes
          ..[chroma] = (0.5 * r - 0.418688 * g - 0.081312 * b + 128)
              .round()
              .clamp(0, 255)
          ..[chroma + 1] = (-0.168736 * r - 0.331264 * g + 0.5 * b + 128)
              .round()
              .clamp(0, 255);
      }
    }
  }
  return CameraImage.fromPlatformInterface(
    CameraImageData(
      format: const CameraImageFormat(ImageFormatGroup.nv21, raw: nv21Raw),
      width: width,
      height: height,
      planes: [
        CameraImagePlane(bytes: bytes, bytesPerRow: width, bytesPerPixel: 1),
      ],
    ),
  );
}

/// A frame of smooth random texture, the same for the same [seed], with its
/// content moved by ([dx], [dy]) raw pixels. A different [seed] is a
/// different scene; [brightness] is added to every pixel.
CameraImage texturedImage({
  int width = 1280,
  int height = 720,
  double dx = 0,
  double dy = 0,
  int seed = 1,
  int brightness = 0,
  bool bgra = false,
}) {
  int level(int x, int y) {
    // Bilinear value noise on a 40-pixel grid.
    final u = (x - dx) / 40;
    final v = (y - dy) / 40;
    final x0 = u.floor();
    final y0 = v.floor();
    final fx = u - x0;
    final fy = v - y0;
    double cell(int cx, int cy) {
      var h =
          (cx * 374761393 + cy * 668265263 + seed * 2147483647) & 0x7fffffff;
      h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff;
      return (h & 0xff).toDouble();
    }

    final top = cell(x0, y0) * (1 - fx) + cell(x0 + 1, y0) * fx;
    final bottom = cell(x0, y0 + 1) * (1 - fx) + cell(x0 + 1, y0 + 1) * fx;
    return ((top * (1 - fy) + bottom * fy) * 0.8 + 20 + brightness)
        .round()
        .clamp(0, 255);
  }

  if (bgra) {
    return bgraImage(width, height, (x, y) {
      final l = level(x, y);
      return (l, l, l);
    });
  }
  return nv21Image(width, height, (x, y) {
    final l = level(x, y);
    return (l, l, l);
  });
}
