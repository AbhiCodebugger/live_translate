# Tasks

## 1. Frame throttle

- [x] 1.1 Add `lib/src/pipeline/frame_throttle.dart`: `FrameThrottle({minInterval = 200 ms, DateTime Function() now = DateTime.now})` with `Future<bool> run(Future<void> Function() work)`. It drops work while busy or too soon, measures the interval from the start of the last run, and releases the busy flag in `finally` (design D4). Verify with `test/pipeline/frame_throttle_test.dart`, using a fake clock and a `Completer`: a frame during processing is dropped; one 100 ms after the previous start is dropped; one 200 ms after is processed; work that throws releases the flag and the next frame after the interval runs.

## 2. Orientation and conversion

- [x] 2.1 Add `lib/src/camera/rotation.dart`: `frameOrientation({platform, sensorOrientation, deviceOrientation, lens})` returning `(ImageRotation, bool mirror)` per design D3, plus an `ImageRotation` → `InputImageRotation` extension. Verify with `test/camera/rotation_test.dart`: every spec scenario (Android back portrait 90/not mirrored, Android back landscape-left 0, Android front portrait 270/mirrored, iOS back landscape 0/not mirrored, iOS front 0/not mirrored), all four device orientations for an Android back and front camera, and `UnsupportedError` for another platform.
- [x] 2.2 Add `lib/src/camera/input_image_converter.dart`: `InputImage? toInputImage(CameraImage image, ImageRotation rotation)` from the plan's snippet, returning `null` unless there is one plane in a known format. Verify with `test/camera/input_image_converter_test.dart`, building frames with `CameraImage.fromPlatformInterface`: a single-plane nv21 frame (raw 17) converts with the right size, rotation, format and bytes per row; a three-plane frame and an unknown raw format return `null`.

## 3. Text engine

- [x] 3.1 Add `lib/src/engines/text_engine.dart`: an `abstract interface class TextEngine` with `recognize(InputImage)` and `close()`, and an `@immutable final class RecognizedLine(text, box)` with value equality (design D1). Add `lib/src/engines/mlkit/mlkit_text_engine.dart`: `MlKitTextEngine({TextRecognizer Function()? createRecognizer})`, Latin by default. It creates the recognizer on the first `recognize`, flattens blocks into lines, closes the recognizer at most once, and throws `StateError` from `recognize` after `close`. Verify with `test/engines/mlkit/mlkit_text_engine_test.dart`, using a fake `TextRecognizer` (`implements`): no recognizer before the first call, lines flattened with text and boxes, an empty result gives `[]`, close happens exactly once, and recognizing after close throws.

## 4. Pipeline

- [x] 4.1 Add `lib/src/pipeline/pipeline.dart`: `Pipeline({required TextEngine engine, FrameThrottle? throttle})` with `onFrame(CameraFrame)`, `Stream<PipelineResult> results`, `Stream<LiveTranslateException> errors` and `dispose()`. `PipelineResult` holds the lines, frame size, rotation, mirror and generation (design D5). Engine errors become `PipelineFailure`, unsupported frames are skipped quietly, and nothing is emitted after `dispose`. Verify with `test/pipeline/pipeline_test.dart`, using `FakeTextEngine`, a fake clock and synthetic `CameraFrame`s: a result carries the frame's lines, size, rotation, mirror and generation; a frame arriving while busy is dropped; a throwing engine produces exactly one `PipelineFailure` and the next frame still produces a result; a three-plane frame produces neither a result nor an error; an in-flight frame after `dispose` emits nothing.

## 5. Camera session

- [x] 5.1 Add `lib/src/camera/camera_session.dart`: the `CameraSession` interface; `CameraFrame` (image, rotation, mirror, generation); `mapCameraError(Object) -> LiveTranslateException`; and `PluginCameraSession`. `PluginCameraSession` uses `availableCameras()`, a `CameraController` with nv21 on Android and bgra8888 on iOS and audio off, `startImageStream` tagging each frame via `frameOrientation`, a generation increment on every `start` and `stop`, `buildPreview()` → `CameraPreview`, and `stop()` that tolerates an already-disposed controller (design D1, D2, D6, D11). Verify with `test/camera/camera_session_test.dart`, covering `mapCameraError`: the three `CameraAccess*` codes → `CameraPermissionDenied`, another `CameraException` code → `CameraUnavailable`. Also verify that `flutter analyze` is clean. The plugin adapter itself is verified on device in group 9.

## 6. Debug view

- [x] 6.1 Add `lib/src/view/overlay_painter.dart`: `DebugBoxPainter(List<Rect> rects)`, which strokes each rectangle and repaints only when the list changes. Verify with `test/view/overlay_painter_test.dart`: `shouldRepaint` is false for an equal list and true for a different one, and painting onto a recording canvas draws one rectangle per box.
- [x] 6.2 Add `lib/src/view/live_translate_view.dart`: the internal `LiveTranslateView` (`cameraLensDirection`, `resolution`, `minFrameInterval`, plus `@visibleForTesting` session and engine factories). It handles placeholder, error and running states; the layout per design D8 (clipped `Stack`, preview at `previewRect`, `DebugBoxPainter` with mapped boxes, `previewSize` before the first result); lifecycle per design D7; lens switching in `didUpdateWidget` (D9); dropping stale generations (D6); and disposing the pipeline, engine and session. Verify with `test/view/live_translate_view_test.dart`, using `FakeCameraSession` and `FakeTextEngine`:
  - placeholder while starting;
  - `CameraPermissionDenied` shows the error;
  - in a 360×800 view, a 1280×720 frame at 90° puts the preview at (-45, 0)–(405, 800) and the box (100, 200)–(300, 260) at (17.5, 125)–(142.5, 162.5);
  - `inactive` stops the session and `resumed` restarts it with the same lens;
  - a result from an older generation is not drawn;
  - changing the lens stops and restarts with `front`;
  - dispose closes the engine and disposes the session.
- [x] 6.3 Check coverage of the pipeline layer. Run `flutter test --coverage` and add up `LH`/`LF` for the `SF:lib/src/pipeline/` entries in `coverage/lcov.info`. Verify that the total is at least 90%, and report the figure.

## 7. Example app

- [x] 7.1 Replace `example/lib/main.dart` with the Week 1 debug screen: full-screen internal `LiveTranslateView` plus a floating button to switch lenses, inside `SafeArea`-aware controls, with `// ignore_for_file: implementation_imports` and a comment explaining why (design D10). Update `example/test/widget_test.dart` to a smoke test that builds the app shell without the camera. Verify that `flutter analyze` and `flutter test` pass in `example/`, and that `flutter build apk --debug` and `flutter build ios --debug --no-codesign` succeed.

## 8. Package checks

- [x] 8.1 Run the package checks. Verify that `dart format --set-exit-if-changed .` makes no changes, `flutter analyze` reports no issues, `flutter test` passes, and `grep -nE "src/(camera|pipeline|view|engines/text_engine|engines/mlkit/mlkit_text_engine)" lib/live_translate_overlay.dart` finds nothing (no new exports). *Corrected during implementation:* the original pattern also matched the existing `package:camera/camera.dart` re-export.

## 9. On-device exit check

- [x] 9.1 **Manual, on the Samsung Galaxy (Android 15) and the iPhone 14 (iOS 26.6.1):** run the example, point the back camera at printed English text, and check that the rectangles stay on the lines in portrait, after rotating to landscape and back, and after switching to the front camera and back. On the iPhone, front-camera recognition is a known limitation: check alignment of anything detected only. Also check that backgrounding and returning restarts the preview. Verify by collecting pass/fail per device for: back portrait, back landscape, front camera, background/resume, plus any constant offset between the preview and the boxes.
- [x] 9.2 Record the results from 9.1 under "On-device results" in `design.md`, and resolve the Open Question about the preview's field of view versus the stream's. Verify that the section lists both devices with every check, and either notes no offset or describes the offset with a follow-up.
