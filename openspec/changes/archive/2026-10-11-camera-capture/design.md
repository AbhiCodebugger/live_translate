# Design

## Context

See proposal.md for the motivation. This is the second Week 1 change and builds on `overlay-geometry` (`ImageRotation`, `CoverLayout`, `CoordinateMapper`, all in `lib/src/geometry/`). Decided while exploring Week 1:
- The debug view lives in the package (Option 1).
- `TextEngine` is pulled forward from Week 2, Latin only (A2).
- The preview is cropped to fill, using the same rule as the mapper (B).
- The throttle takes its clock as a parameter (D).
- Lifecycle requirements go into `capture` (E).
- The iOS front camera is a known limitation (decided while proposing this change).

What the plugins actually do, checked in the cached sources: `camera` 0.12.1, `camera_android_camerax` 0.7.5+1, `camera_avfoundation` 0.10.3+1 and `google_mlkit_commons` 0.13.0.

| Fact | Evidence | Consequence |
|---|---|---|
| Android delivers nv21 as one plane with raw format 17 | `android_camera_camerax.dart` `onStreamedFrameAvailable` | The plan's single-plane converter works unchanged |
| Android stream frames are in sensor orientation (landscape), not mirrored | CameraX `ImageAnalysis`; the preview delegate mirrors only the `Texture` | Rotation = sensor ∓ device orientation; front camera needs `mirror: true` |
| ML Kit on Android uses the rotation metadata | `InputImageConverter.kt` passes `rotationDegrees` | Boxes come back in upright coordinates |
| iOS rotates stream frames to the device orientation | `DefaultCamera.updateOrientation()` sets `videoOrientation` on `captureVideoOutput` | iOS frames are already upright → `ImageRotation.deg0` |
| iOS front-camera stream frames are mirrored | `DefaultCamera` sets `connection.isVideoMirrored = true` for `.front` | `mirror: false` on iOS; ML Kit reads mirrored text (known limitation) |
| ML Kit on iOS ignores rotation for byte images | `MLKVisionImage+FlutterPlugin.swift` uses the `UIImage`'s own (up) orientation | Consistent with the line above: frame coordinates are already upright |
| ML Kit's sample uses `sensorOrientation` as the rotation on iOS | commons README | Its painter compensates with `Platform.isIOS` checks; we don't copy that |
| `CameraPreview` wraps `buildPreview()` in `AspectRatio` and `RotatedBox` for the device orientation | `camera_preview.dart` | Put `CameraPreview` in a box of exactly the preview rectangle; the `AspectRatio` then fills it |

## Goals / Non-Goals

**Goals:**
- Pass the on-device exit check on the Samsung Galaxy and the iPhone 14: boxes stay on the text while rotating and switching cameras (iOS front camera: alignment only).
- Keep everything except the thin plugin adapters testable with fakes: throttling, orientation, pipeline, view states, lifecycle and switching.
- ≥ 90% line coverage on `lib/src/pipeline/` (plan §9).

**Non-Goals:**
- Making the view public, `LiveTranslateController`, the HUD and metrics (Week 3).
- Devanagari, switching between scripts, filtering lines, language ID and translation (Week 2).
- Un-mirroring iOS front-camera frames.
- Locking the app to portrait: the exit check needs rotation.

## Decisions

**D1. Small interfaces at the plugin boundary, with fakes in tests.**
- `CameraSession` is an `abstract interface class` with `start(CameraLensDirection)`, `stop()`, `Stream<CameraFrame> get frames`, `Widget buildPreview()`, `Size? get previewSize` and `dispose()`.
- `PluginCameraSession` implements it on `CameraController`.
- `TextEngine` has `Future<List<RecognizedLine>> recognize(InputImage)` and `close()`.
- `MlKitTextEngine` implements it on `TextRecognizer`.

All logic sits behind these interfaces, so tests use `FakeCameraSession` and `FakeTextEngine`, which plan §9 calls for. The two plugin adapters stay thin, are verified on the devices, and their error mapping is a pure function that unit tests cover. *Alternative:* fake `CameraPlatform.instance` with `plugin_platform_interface`. Rejected because it adds dev dependencies and tests the plugin rather than our logic.

**D2. `CameraFrame` couples a frame with its orientation.** It's an internal value holding the `CameraImage`, the `ImageRotation`, `mirror`, and a `generation` number (D6). The session attaches the orientation when the frame arrives, so a rotation or lens change can't mix up frames.

**D3. Orientation is a pure function: `frameOrientation({required TargetPlatform platform, required int sensorOrientation, required DeviceOrientation deviceOrientation, required CameraLensDirection lens})`.** It returns `(ImageRotation, bool mirror)`:
- **Android:** use the compensation formula from the spec. Mirror the front camera.
- **iOS:** always `deg0`, never mirror.
- **Anything else:** throw `UnsupportedError`.

The platform is passed in (the caller uses `defaultTargetPlatform`), so both branches are tested on the host machine. A one-line extension converts `ImageRotation` to `InputImageRotation` for ML Kit's metadata in `input_image_converter.dart`. iOS ignores that value anyway.

**D4. `FrameThrottle({Duration minInterval = const Duration(milliseconds: 200), DateTime Function() now = DateTime.now})`.**
- `run(Future<void> Function() work)` returns `bool`: whether the work ran.
- The busy flag is released in `finally`.
- The interval is measured from the start of the last frame that ran (plan's snippet).

This is the plan's snippet, with the clock injected so tests are deterministic, without adding `fake_async` or `clock` dependencies.

**D5. Minimal `Pipeline` in `lib/src/pipeline/pipeline.dart`.**
- `Pipeline({required TextEngine engine, FrameThrottle? throttle})` exposes `Stream<PipelineResult> results` and `Stream<LiveTranslateException> errors`, plus `void onFrame(CameraFrame)`.
- It runs throttle → `toInputImage` (unsupported frame → skip quietly) → `engine.recognize`.
- `PipelineResult` holds the lines, the frame size, the rotation, `mirror` and `generation`.
- An error from the engine is wrapped in `PipelineFailure` and sent to `errors`, and the busy flag is released (spec: a failed frame doesn't stop capture).

Week 2 inserts language ID and translation here. The view doesn't change.

**D6. Stale results are dropped using generation numbers.** The session increments `generation` on every `start` (lifecycle resume or lens switch) and every `stop`. The view ignores any `PipelineResult` whose `generation` isn't the current one. This meets "a frame in flight when paused or switched is never shown" without having to cancel a platform-channel call.

**D7. Lifecycle is handled in the view, through `WidgetsBindingObserver`.**
- `inactive` or `hidden` → `session.stop()`, which stops the stream, disposes the controller and increments the generation.
- `resumed` → `session.start(currentLens)`.

This follows the camera plugin's README guidance to release the camera when the app is inactive. Widget tests drive it with `tester.binding.handleAppLifecycleStateChanged`.

**D8. View layout (implements the new `overlay-geometry` requirement).**
- A `LayoutBuilder` gives the view size.
- A `ClipRect` wraps a `Stack` holding `Positioned.fromRect(rect: mapper.layout.previewRect, child: session.buildPreview())` and a full-size `CustomPaint(painter: DebugBoxPainter(rects))`.
- `buildPreview()` in `PluginCameraSession` returns `CameraPreview(controller)`. Inside a box of exactly the preview rectangle's size, its `AspectRatio` fills it, and its `RotatedBox` handles Android rotation.
- **Layout source:** the latest result's frame size and rotation. Before the first result, use `uprightPreviewSize(previewSize, deviceOrientation)`, which turns the plugin's landscape `previewSize` so its long side runs along the device's current axis. *Corrected during implementation:* the plan here was to rotate `previewSize` by the per-platform frame rule, but on iOS that rule is always 0°, while `previewSize` is still reported landscape, so portrait would have been laid out wrong until the first frame. The long-side rule is correct on both platforms.
- **States:** a placeholder (`SizedBox` with a progress indicator) while starting, and the error text for a `LiveTranslateException`.

**D9. Internal `LiveTranslateView` skeleton, not exported.** Its constructor takes a subset of the plan's §4.1 parameters: `cameraLensDirection`, `resolution` and `minFrameInterval`. It also takes `@visibleForTesting` factories for the session and the engine. A change to `cameraLensDirection` in `didUpdateWidget` triggers `stop()` then `start(newLens)`. If no camera with the requested lens exists, it falls back to the first camera. `targetLanguage` and the other §4.1 parameters arrive with the features that need them.

**D10. The example imports the internal view for Week 1.** `example/lib/main.dart` becomes a debug screen: the view plus a button to switch lenses. The import needs `// ignore_for_file: implementation_imports`, with a comment explaining that it's temporary until the view is exported (Week 4 at the latest). *Alternative:* export the view now. Rejected because it would commit the public API early (`public-api` spec, "Single entry library").

**D11. Error mapping is a pure function: `mapCameraError(Object error) -> LiveTranslateException`.**
- The three `CameraAccess*` codes → `CameraPermissionDenied`.
- Any other `CameraException` → `CameraUnavailable`.
- An empty camera list → `CameraUnavailable`.

Unit tests cover it.

**D12. Files (from the plan's §6).**
- `camera/`: `camera_session.dart` (interface, `CameraFrame`, `PluginCameraSession`, `mapCameraError`), `rotation.dart` (`frameOrientation`), `input_image_converter.dart`
- `pipeline/`: `frame_throttle.dart`, `pipeline.dart`
- `engines/`: `text_engine.dart` (interface, `RecognizedLine`) and `mlkit/mlkit_text_engine.dart`
- `view/`: `live_translate_view.dart`, `overlay_painter.dart` (`DebugBoxPainter`; the translated-text painter is Week 2)

**D13. A test-only dev dependency on `camera_platform_interface` (added during implementation).** Tests build frames with `CameraImage.fromPlatformInterface(CameraImageData(...))`. The other constructor, `fromPlatformData`, is deprecated, and `camera` doesn't re-export `CameraImageData`. The package is already a transitive dependency of `camera`, so it changes nothing for package users. This amends the proposal's "no dependencies added", which still holds for runtime dependencies.

## Risks / Trade-offs

- [On Android, the preview and the stream could have different aspect ratios or crops, because CameraX sizes `Preview` and `ImageAnalysis` separately] → The layout uses the stream frame's size, so the boxes are right relative to the frames. If the preview's field of view differs, the exit check will show a constant offset. Record what the devices show. If needed, a follow-up sets matching resolution selectors.
- [The iOS front camera reads mirrored text] → Known limitation, decided. The exit check on the iPhone front camera checks alignment only. Recorded under follow-ups.
- [`controller.value.deviceOrientation` can lag the UI rotation by a frame on Android] → At most one frame is tagged with the old orientation. Its boxes may be off for about 200 ms, which is acceptable for Week 1. Tracking (Week 3) smooths this.
- [A plugin `CameraException` thrown during `stop()` while the app is backgrounded] → `stop()` catches and ignores errors from disposing a controller that is already gone.
- [Debug-only drawing ships in the package] → The painter is internal, and Week 2 replaces it with the translated-text painter.

## Open Questions

- ~~Does the preview's field of view match the stream's on the Samsung Galaxy?~~ Resolved by the exit check: no constant offset was reported (see On-device results).

## On-device results

Exit check on 2026-10-11, running the example debug screen against printed and on-screen English text.

| Check | Samsung Galaxy, Android 15 | iPhone 14, iOS 26.6.1 |
|---|---|---|
| Back camera, portrait: boxes sit on the lines | Pass | Pass |
| Rotate to landscape and back | Pass | Pass |
| Switch to the front camera and back | Pass | Pass (alignment only; mirrored text is a known limitation) |
| Background and return: preview restarts | Pass | Pass |
| Constant offset between preview and boxes | None reported | None reported |

Evidence: two Android back-camera screenshots, plus the author's report that every check passes on both devices. One screenshot shows lines hugged tightly by their boxes (sideways text, phone held portrait). The other, taken handheld at an angle of a laptop screen, shows boxes trailing their lines by roughly 20 to 40 px. That fits hand movement during the roughly 200 ms between capturing a frame and drawing its boxes. A crop mismatch would show the same offset every time, and none was reported. The same screenshot shows tall, overlapping boxes around tilted lines, as expected for straight rectangles (tilted boxes are planned for 1.1+).

Follow-ups:
- Week 3 tracking and smoothing should reduce the lag while the phone moves.
- Un-mirroring iOS front-camera frames (known limitation) stays open.
