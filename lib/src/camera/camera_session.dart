import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';

import '../errors.dart';
import 'camera_frame.dart';
import 'rotation.dart' as rotation;

/// A live camera that streams frames for recognition.
///
/// The view depends only on this interface, so tests can drive it with a
/// fake.
abstract interface class CameraSession {
  /// Frames from the running camera, tagged with [generation].
  Stream<CameraFrame> get frames;

  /// Increases on every [start] and [stop]. Results from frames of an earlier
  /// generation are stale.
  int get generation;

  /// The preview's size turned to the device's current orientation, or
  /// `null` while the camera isn't running.
  Size? get uprightPreviewSize;

  /// Starts the back camera, restarting it if it is already running.
  ///
  /// Throws [CameraPermissionDenied] or [CameraUnavailable] on failure,
  /// including when the device has no back camera.
  Future<void> start();

  /// Stops streaming and releases the camera. Safe to call when stopped.
  Future<void> stop();

  /// Freezes the preview on its current picture and stops streaming frames,
  /// keeping the camera open. Has no effect when the camera isn't running.
  Future<void> pause();

  /// Undoes [pause]: the preview goes live and frames stream again, with the
  /// same [generation].
  Future<void> resume();

  /// Turns the torch on or off. Has no effect on a camera without a torch.
  Future<void> setTorch(bool on);

  /// The live preview, or an empty box while the camera isn't running.
  Widget buildPreview();

  /// Stops the camera for good.
  Future<void> dispose();
}

/// Maps a camera plugin failure to the package's error type.
LiveTranslateException mapCameraError(Object error) => switch (error) {
  LiveTranslateException() => error,
  CameraException(
    code: 'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted',
  ) =>
    const CameraPermissionDenied(),
  _ => const CameraUnavailable(),
};

/// The first back camera in [cameras].
///
/// Throws [CameraUnavailable] when there is none: another camera's preview
/// would not line up with the labels.
CameraDescription selectBackCamera(List<CameraDescription> cameras) {
  for (final camera in cameras) {
    if (camera.lensDirection == CameraLensDirection.back) return camera;
  }
  throw const CameraUnavailable();
}

/// A [CameraSession] backed by the `camera` plugin.
final class PluginCameraSession implements CameraSession {
  /// Creates a session that streams at [resolution].
  ///
  /// `cameras` lists the device's cameras and exists so tests can substitute
  /// it.
  PluginCameraSession({
    this.resolution = ResolutionPreset.medium,
    this._cameras = availableCameras,
  });

  /// The capture resolution.
  final ResolutionPreset resolution;

  final Future<List<CameraDescription>> Function() _cameras;
  final _frames = StreamController<CameraFrame>.broadcast();
  CameraController? _controller;
  CameraDescription? _description;
  int _generation = 0;
  Future<void> _pending = Future.value();

  @override
  Stream<CameraFrame> get frames => _frames.stream;

  @override
  int get generation => _generation;

  @override
  Size? get uprightPreviewSize {
    final value = _controller?.value;
    final previewSize = value?.previewSize;
    if (value == null || previewSize == null) return null;
    return rotation.uprightPreviewSize(previewSize, value.deviceOrientation);
  }

  @override
  Future<void> start() => _serially(() => _mapped(_start));

  @override
  Future<void> stop() => _serially(_stop);

  @override
  Future<void> pause() => _serially(
    () => _mapped(() async {
      final controller = _controller;
      if (controller == null || controller.value.isPreviewPaused) return;
      await controller.pausePreview();
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    }),
  );

  @override
  Future<void> resume() => _serially(
    () => _mapped(() async {
      final controller = _controller;
      final description = _description;
      if (controller == null ||
          description == null ||
          !controller.value.isPreviewPaused) {
        return;
      }
      await controller.resumePreview();
      await _startStream(controller, description, _generation);
    }),
  );

  @override
  Future<void> setTorch(bool on) => _serially(() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    } on CameraException {
      // This camera has no torch; leave it as it is.
    }
  });

  @override
  Widget buildPreview() => switch (_controller) {
    final controller? when controller.value.isInitialized => CameraPreview(
      controller,
    ),
    _ => const SizedBox.shrink(),
  };

  @override
  Future<void> dispose() async {
    await stop();
    await _frames.close();
  }

  /// Runs camera operations one at a time, so a quick stop-then-start (for
  /// example when the app flickers between inactive and resumed) can't
  /// interleave.
  Future<void> _serially(Future<void> Function() operation) {
    final next = _pending.then((_) => operation());
    _pending = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  /// Runs [operation], rethrowing any failure as the package's error type,
  /// so no camera plugin exception reaches the app.
  static Future<void> _mapped(Future<void> Function() operation) async {
    try {
      await operation();
    } on Object catch (error) {
      throw mapCameraError(error);
    }
  }

  Future<void> _start() async {
    await _stop();
    final description = selectBackCamera(await _cameras());

    final platform = defaultTargetPlatform;
    final controller = CameraController(
      description,
      resolution,
      enableAudio: false,
      imageFormatGroup: platform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
    } on Object {
      await _disposeQuietly(controller);
      rethrow;
    }

    _controller = controller;
    _description = description;
    await _startStream(controller, description, ++_generation);
  }

  /// Streams [controller]'s frames, tagged with [generation] and their
  /// orientation, until the generation changes.
  Future<void> _startStream(
    CameraController controller,
    CameraDescription description,
    int generation,
  ) {
    final platform = defaultTargetPlatform;
    return controller.startImageStream((image) {
      if (generation != _generation || _frames.isClosed) return;
      _frames.add(
        CameraFrame(
          image: image,
          rotation: rotation.frameRotation(
            platform: platform,
            sensorOrientation: description.sensorOrientation,
            deviceOrientation: controller.value.deviceOrientation,
          ),
          generation: generation,
        ),
      );
    });
  }

  Future<void> _stop() async {
    _generation++;
    final controller = _controller;
    _controller = null;
    _description = null;
    if (controller != null) await _disposeQuietly(controller);
  }

  static Future<void> _disposeQuietly(CameraController controller) async {
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    } on CameraException {
      // The camera is already gone, for example after the app was
      // backgrounded. There is nothing left to release.
    }
  }
}
