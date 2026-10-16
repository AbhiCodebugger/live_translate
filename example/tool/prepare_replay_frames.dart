// Prepares photos as replay frames: upright, at most 1280 px on the longer
// side, re-encoded as JPEG without any EXIF data (so no location either).
//
//   dart run tool/prepare_replay_frames.dart <photo>... [--out <dir>]
//
// Run from example/. Each photo is written to the output folder,
// assets/replay_frames/ by default, as <name>.jpg, where <name> is the
// photo's file name in lowercase with anything but letters, digits and
// underscores replaced by underscores.

import 'dart:io';

import 'package:image/image.dart' as img;

/// The longer side of a prepared frame, matching the camera stream.
const maxSide = 1280;

/// A prepared frame larger than this is reported.
const maxFileBytes = 300 * 1024;

/// A frame folder larger than this is reported.
const maxFolderBytes = 3 * 1024 * 1024;

void main(List<String> args) {
  var out = 'assets/replay_frames';
  final photos = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--out' && i + 1 < args.length) {
      out = args[++i];
    } else {
      photos.add(args[i]);
    }
  }
  if (photos.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/prepare_replay_frames.dart <photo>... '
      '[--out <dir>]',
    );
    exitCode = 64;
    return;
  }
  Directory(out).createSync(recursive: true);
  for (final photo in photos) {
    final decoded = img.decodeImage(File(photo).readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('$photo: not an image');
      exitCode = 1;
      continue;
    }
    final file = File('$out/${frameName(photo)}.jpg')
      ..writeAsBytesSync(prepare(decoded));
    final size = file.lengthSync();
    final note = size > maxFileBytes
        ? '  (over ${maxFileBytes ~/ 1024} KB)'
        : '';
    stdout.writeln('${file.path}: ${size ~/ 1024} KB$note');
  }
  final total = Directory(
    out,
  ).listSync().whereType<File>().fold<int>(0, (sum, f) => sum + f.lengthSync());
  if (total > maxFolderBytes) {
    stdout.writeln(
      '$out is ${total ~/ 1024} KB, over ${maxFolderBytes ~/ 1024} KB',
    );
  }
}

/// [image] upright, scaled so its longer side is at most [maxSide], and
/// encoded as JPEG without EXIF data.
List<int> prepare(img.Image image) {
  var upright = img.bakeOrientation(image);
  final longer = upright.width > upright.height
      ? upright.width
      : upright.height;
  if (longer > maxSide) {
    upright = upright.width >= upright.height
        ? img.copyResize(upright, width: maxSide)
        : img.copyResize(upright, height: maxSide);
  }
  upright.exif = img.ExifData();
  return img.encodeJpg(upright, quality: 75);
}

/// The frame name for the photo at [path].
String frameName(String path) {
  final base = path.split(Platform.pathSeparator).last;
  final stem = base.contains('.')
      ? base.substring(0, base.lastIndexOf('.'))
      : base;
  return stem.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '_');
}
