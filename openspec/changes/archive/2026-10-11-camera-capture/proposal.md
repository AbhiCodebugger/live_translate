# Proposal

## Why

`overlay-geometry` can place a box correctly once it knows the frame's rotation and mirroring, but nothing produces frames or boxes yet. This change completes Week 1 by wiring the live camera to text recognition and drawing debug rectangles over the preview. It meets the plan's Week 1 exit check: boxes stay on real text while you rotate the phone and switch cameras, on both platforms. It also deals with the first hard problem, frame flooding, by dropping frames instead of queueing them.

## What Changes

- **Camera session:** start the camera with nv21 frames on Android and bgra8888 on iOS. Stream frames, pause on background and resume on foreground, switch lenses, and release everything on dispose. Camera permission and availability failures surface as the existing `CameraPermissionDenied` and `CameraUnavailable` errors.
- **Frame throttle:** drop a frame if one is already being processed or if the minimum interval (default 200 ms) hasn't passed. The clock is passed in, so tests are deterministic.
- **Frame orientation:** work out each frame's rotation and mirroring per platform. Our investigation of the plugins (design D3) found that iOS delivers frames already upright, and already mirrored for the front camera, while Android delivers frames in the sensor's orientation and mirrors only the preview.
- **Frame converter:** turn a camera frame into an ML Kit `InputImage` (the plan's single-plane converter).
- **`TextEngine`, pulled forward from Week 2:** an interface for text recognition, plus a Latin-only ML Kit implementation that creates its recognizer on first use and closes it on dispose.
- **Minimal pipeline:** throttle → convert → recognize, producing the recognized lines together with the frame's size, rotation and mirroring. Results from before a pause are discarded.
- **Internal `LiveTranslateView` skeleton (not exported):** shows the preview at `CoverLayout.previewRect`, clipped to the view, and paints a debug rectangle at each mapped line. Changing its lens direction switches cameras.
- **Example app:** the Week 0 spike screen is replaced by a debug screen with a lens toggle, for the on-device exit check.
- **Known limitation (decided):** the iOS front camera gives ML Kit mirrored frames, so text recognition there is unreliable. Boxes still map correctly for whatever ML Kit finds. Un-mirroring the frames is follow-up work.

## Capabilities

### New Capabilities
- `capture`: Getting camera frames to recognition. Covers platform frame formats, throttling, per-platform rotation and mirroring, app lifecycle, switching lenses, disposal, and camera error reporting. It absorbs the plan's §14 `lifecycle` scenario.
- `recognize`: Turning a frame into text lines with boxes in upright frame coordinates, with the recognizer created on first use and closed on dispose. Week 2 extends it with Devanagari, switching between scripts and filtering lines.

### Modified Capabilities
- `overlay-geometry`: adds a requirement that the on-screen preview is displayed with the shared fill-and-crop layout and clipped to the view, so the boxes and the preview can't drift apart.

## Impact

- **New code:**
  - `lib/src/camera/` (`camera_session.dart`, `input_image_converter.dart`, `rotation.dart`)
  - `lib/src/pipeline/` (`frame_throttle.dart`, `pipeline.dart`)
  - `lib/src/engines/text_engine.dart` and `lib/src/engines/mlkit/mlkit_text_engine.dart`
  - `lib/src/view/` (`live_translate_view.dart`, `overlay_painter.dart`)
  - matching tests
- **Changed code:** `example/lib/main.dart` (debug screen) and its widget test.
- **Public API:** unchanged. Nothing new is exported.
- **Dependencies:** none added.
- **Out of scope:** Devanagari and switching between scripts, language ID, translation, tracking and smoothing, the controller, the debug HUD, torch, and un-mirroring iOS front-camera frames.
