# Proposal

## Why

The package's job is translating text the user points the phone at, and that is always the rear camera. Front-camera support costs a mirroring path through orientation, geometry and tracking, a lens parameter, `switchCamera` on the controller and a button in the example, and it brings a known limitation (mirrored text reads backwards). Dropping it now, before the view and controller are exported at 0.1.0, simplifies the API and the code with no consumers to break.

## What Changes

- **Rear camera only:** capture always uses the device's back camera. A device without one reports `CameraUnavailable`; the package no longer falls back to another camera.
- **BREAKING (internal API, nothing exported yet):**
  - `LiveTranslateView` loses its `cameraLensDirection` parameter.
  - `LiveTranslateController.switchCamera()` and `ControllerHost.switchCamera()` are removed.
  - The entry library stops re-exporting `CameraLensDirection`.
- **No mirroring:** frames, pipeline results, tracking keys and coordinate mapping no longer carry a mirror flag. Android frame rotation is always the back-camera formula (sensor orientation minus device orientation).
- **Unchanged:** freeze and resume, the torch (rear camera), lifecycle restarts, and resetting tracks and the torch when the camera restarts after returning from the background.
- **Example app:** the switch-camera button is removed; freeze/resume and torch stay.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `capture`: always the back camera, with `CameraUnavailable` when there is none; Android and iOS orientation lose their front-camera cases; the "Switching lenses" requirement is removed; the lifecycle restart no longer mentions "the same lens".
- `overlay-geometry`: the "Front camera boxes are mirrored" requirement is removed, and mapping scenarios no longer mention mirroring.
- `tracking`: tracks reset on a change of frame size, rotation or capture session (mirroring is gone); the "Camera switched" scenario becomes a restart after returning from the background.
- `controller`: `switchCamera` is removed; leaving freeze and resetting the torch now happen only on a restart after returning from the background.
- `public-api`: `CameraLensDirection` is no longer re-exported.

## Impact

- **Changed code:**
  - `lib/live_translate_overlay.dart` (drop the `CameraLensDirection` export)
  - `lib/src/camera/camera_session.dart`, `camera_frame.dart`, `rotation.dart`
  - `lib/src/geometry/coordinate_mapper.dart`
  - `lib/src/pipeline/pipeline.dart`
  - `lib/src/tracking/line_tracker.dart`
  - `lib/src/view/live_translate_view.dart`
  - `lib/src/controller/live_translate_controller.dart`
  - matching tests and `test/support/fakes.dart`
  - `example/lib/main.dart` and `example/test/widget_test.dart`
- **Public API:** one re-export removed. Nothing else in the entry library changes.
- **Dependencies:** none.
