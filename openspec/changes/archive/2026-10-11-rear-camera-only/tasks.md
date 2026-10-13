# Tasks

## 1. No mirroring

- [x] 1.1 Remove mirroring end to end (design D3):
  - `frameOrientation` drops `lens` and returns `ImageRotation`, and the `FrameOrientation` typedef goes;
  - delete `CameraFrame.mirror`, `PipelineResult.mirror`, `FrameKey.mirror` and `CoordinateMapper.mirror` with its reflection branch;
  - update the view's `CoordinateMapper` calls.

  Update the tests:
  - `test/camera/rotation_test.dart` loses its front-camera cases and keeps both back-camera Android scenarios and the iOS landscape scenario;
  - `test/geometry/coordinate_mapper_test.dart` loses the mirroring cases and keeps an unmirrored 270° case;
  - `test/pipeline/pipeline_test.dart` and `test/tracking/line_tracker_test.dart` drop `mirror` from frames and keys.

  Verify that `flutter analyze` is clean, `flutter test` passes, and `grep -rn mirror lib test` finds nothing.

## 2. Back camera only

- [x] 2.1 Add `selectBackCamera` to `camera_session.dart` and make `CameraSession.start()` take no argument (design D1, D2). `_start` selects with it. `FakeCameraSession.starts` becomes a count. The view drops `cameraLensDirection` and `_lens`. Verify with `test/camera/camera_session_test.dart`:
  - front first and back second selects the back camera;
  - front only reports `CameraUnavailable`, through both `selectBackCamera` and `PluginCameraSession.start()`;
  - an empty list still reports `CameraUnavailable`.

  Update the view tests that set or change the lens. The background/return scenario checks a second `start` call. Verify that `flutter test` passes.
- [x] 2.2 Remove `switchCamera` from `LiveTranslateController`, `ControllerHost` and the view's host implementation (design D1). Update the tests:
  - drop the switch case from `test/controller/live_translate_controller_test.dart`;
  - in `test/view/live_translate_view_test.dart`, delete the "`switchCamera` restarts on the front camera" case;
  - rewrite the "torch is off after a camera switch" case as off after background and return, matching the `controller` delta.

  Verify that `flutter test` passes and `grep -rniE "CameraLensDirection|switchCamera|front" lib test` finds nothing.

## 3. Public API and example

- [x] 3.1 Drop `CameraLensDirection` from the entry library's `camera` export, leaving `show ResolutionPreset`. Update `test/public_api_test.dart` so it no longer expects `CameraLensDirection`. Verify that `flutter test test/public_api_test.dart` passes.
- [x] 3.2 Remove the switch-camera button and `_switchCamera` from `example/lib/main.dart` (design D5). Update `example/test/widget_test.dart` to find the freeze and torch buttons and tap the torch button without errors. Verify that `flutter analyze` and `flutter test` pass in `example/`, and that both platform builds succeed.

## 4. Checks

- [x] 4.1 Run the package checks. Verify that:
  - `dart format --set-exit-if-changed .` makes no changes;
  - `flutter analyze` reports no issues;
  - `flutter test --coverage` passes, with `lib/src/controller/` and `lib/src/pipeline/` still at least 90% line coverage (report both figures).
- [x] 4.2 **Manual, on the Samsung Galaxy (Android 15) and the iPhone 14 (iOS 26.6.1):** with "Hindi only" on, over Hindi text, check that the example opens on the back camera with labels lined up in portrait and landscape, that torch and freeze/resume still work, and that no switch-camera button is shown. Record the results under "On-device results" in `design.md`, listing both devices with every check.

## Workflow follow-up

- When archiving, update the `Purpose` lines of the `capture`, `overlay-geometry` and `controller` main specs so they no longer mention mirroring or switching cameras.
