# Design

## Context

See proposal.md for the motivation. What exists now:
- `LiveTranslateView` takes `cameraLensDirection` (default back) and keeps an effective `_lens` that the widget parameter or `switchCamera()` can change; a lens change goes through `_start`.
- `CameraSession.start(CameraLensDirection lens)`. `PluginCameraSession._start` picks the first camera facing `lens`, falling back to `cameras.first`, and reports `CameraUnavailable` only for an empty list. The camera list is injectable (`cameras:`), so selection can be tested without the plugin.
- `rotation.frameOrientation(platform, sensorOrientation, deviceOrientation, lens)` returns `({ImageRotation rotation, bool mirror})`; only the Android front camera sets `mirror`.
- `mirror` then flows through `CameraFrame` → `PipelineResult` → `FrameKey` (tracking) → `CoordinateMapper`, which reflects boxes when it is set.
- `LiveTranslateController.switchCamera()` forwards to `ControllerHost.switchCamera()`.
- The entry library re-exports `CameraLensDirection`; the view and controller are not exported yet.

## Goals / Non-Goals

**Goals:**
- No front-camera code path is left: no lens type in the package's own API, no mirror flag anywhere.
- Every changed scenario in the delta specs is covered by an existing or updated unit or widget test.

**Non-Goals:**
- External cameras, or picking among several back cameras (wide, ultra-wide, telephoto). The first back camera the plugin lists is used, as today.
- Any change to freeze, torch or lifecycle behaviour beyond dropping the camera-switch trigger.

## Decisions

**D1. Remove the lens from the API instead of fixing it to back.**

`CameraSession.start()` takes no argument, and `LiveTranslateView` has no lens parameter or `_lens` field. `ControllerHost.switchCamera` and `LiveTranslateController.switchCamera` are deleted. `FakeCameraSession.starts` becomes a count of `start` calls.

*Alternative:* keep `cameraLensDirection` but assert it is `back`. Rejected because it keeps a parameter with one legal value and an export only to support it.

**D2. Camera selection is a pure function: the first back camera, or `CameraUnavailable`.**

`selectBackCamera(List<CameraDescription>)` in `camera_session.dart` returns the first camera with `lensDirection == back` and throws `CameraUnavailable` when there is none, covering an empty list too. `_start` calls it before creating a `CameraController`, so both `capture` scenarios are unit tests, with no plugin involved.

*Alternative:* fall back to the first camera, as today. Rejected because on a device without a back camera that would show the front camera's mirrored preview with unmirrored boxes, which is exactly the misalignment the mirror path existed to prevent.

**D3. Remove mirroring end to end.**
- `frameOrientation` drops its `lens` parameter and returns `ImageRotation`. The typedef `FrameOrientation` goes away. Android uses `(sensor − device + 360) % 360`, and iOS returns `deg0`.
- `CameraFrame.mirror`, `PipelineResult.mirror`, `FrameKey.mirror` and `CoordinateMapper.mirror` are deleted, along with the reflection branch in `mapToView`.
- The view's two `CoordinateMapper` constructions lose their `mirror:` argument.

*Alternative:* keep `CoordinateMapper.mirror` as a general geometry option. Rejected because nothing would set it, and the `overlay-geometry` requirement for it is removed.

**D4. The capture-session generation stays.**

It still separates sessions across background/return restarts and stop/start, so tracking still resets and stale results are still dropped on those restarts. Only the "camera switched" trigger disappears.

**D5. Example app.**

`example/lib/main.dart` loses `_switchCamera` and its button. Freeze/resume and torch stay, with their `ListenableBuilder` icons. `example/test/widget_test.dart` finds the two remaining buttons and taps the torch button instead of the switch-camera one.

## Risks / Trade-offs

- [A device with only front or external cameras (some tablets, Chromebooks) can no longer use the view] → It reports `CameraUnavailable` through `onError`, which apps already handle. Such devices were never test targets.
- [Removing the mirror path loses geometry tests that also exercised scaling at 270°] → Keep a 270° rotation case in `coordinate_mapper_test.dart`, unmirrored, so every quarter turn is still covered.

## Migration Plan

Nothing is published and the view and controller aren't exported, so there are no consumers to migrate. The only public change is dropping the `CameraLensDirection` re-export. When archiving, update the `Purpose` lines of the `capture`, `overlay-geometry` and `controller` main specs, which still mention mirroring or switching cameras.

## On-device results

Exit check on 2026-10-11: the example app with "Hindi only" on and the Hindi model downloaded, pointed at Hindi text.

| Check | Samsung Galaxy, Android 15 | iPhone 14, iOS 26.6.1 |
|---|---|---|
| Opens on the back camera | Pass | Pass |
| Labels line up in portrait and landscape | Pass | Pass |
| Torch turns on and off | Pass | Pass |
| Freeze holds the labels; resume restores live translation | Pass | Pass |
| No switch-camera button | Pass | Pass |

Evidence: the author's report that every check passes. No recordings were attached.
