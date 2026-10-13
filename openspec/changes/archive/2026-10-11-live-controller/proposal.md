# Proposal

## Why

`LiveTranslateView` can only be configured by rebuilding it with new parameters, and apps can't see what it's showing. Plan §4.2 gives apps a `LiveTranslateController` to drive and observe the view: its state, the current lines, freeze and resume, settings changes, switching cameras and the torch. Freeze is also the plan's fallback when live labels are hard to read, and the basis for the 0.2 "freeze and copy" recipe. `line-tracking` now produces `TranslatedLine`s with stable IDs, so the controller has real lines to expose.

## What Changes

- **`LiveTranslateController`** (a `ChangeNotifier`, plan §4.2), passed to the view through a new `controller` parameter:
  - `state`: `initializing`, `running`, `frozen` or `error` (new enum `LiveTranslateState`).
  - `lines`: the `TranslatedLine`s currently shown, in view coordinates. Listeners are notified when they change.
  - `freeze()` and `resume()`: freezing pauses the preview and frame streaming and keeps the current labels fixed; resuming restarts live translation.
  - `setTargetLanguage()` and `setScripts()`: change settings without restarting the camera, as the widget parameters already do. The most recent change wins, whether it came from the controller or the widget.
  - `switchCamera()`: toggles between the back and front cameras.
  - `setTorch(bool)`: turns the torch on or off where the camera has one; otherwise it has no effect.
- **Camera session:** `pause()` and `resume()` to freeze and unfreeze the preview and frame stream (`pausePreview` and `resumePreview` plus stopping and restarting the stream), and `setTorch()`.
- **Policies:**
  - Returning from the background or switching cameras while frozen resumes live translation, because the frozen picture is gone once the camera restarts.
  - The torch turns off whenever the camera restarts.
- **Example app:** freeze/resume and torch buttons. Switching cameras goes through the controller.
- **On-device exit check:** freeze, resume, torch and switching cameras through the controller, on both phones.
- **Deferred:** `metrics` (plan §4.2) arrives with `pipeline-metrics`. Exporting the controller happens together with the view at 0.1.0 (Week 4). The `onLinesChanged` and `onFrozen` callbacks are 0.2 (plan Week 5).

## Capabilities

### New Capabilities
- `controller`: Driving and observing the live view from app code: state, current lines, freeze and resume, target language and scripts, switching cameras, torch, and how controller calls combine with widget parameters.

### Modified Capabilities
- `capture`: capture can be paused and resumed (frozen preview, no frames processed), and returning from the background while paused restarts live capture.

## Impact

- **New code:**
  - `lib/src/controller/live_translate_controller.dart`
  - `lib/src/controller/live_translate_state.dart`
  - tests for both
- **Changed code:**
  - `lib/src/camera/camera_session.dart` (`pause`, `resume`, `setTorch`)
  - `lib/src/view/live_translate_view.dart` (`controller` parameter, attaching, effective settings, building lines outside `build`)
  - `test/support/fakes.dart`
  - `example/lib/main.dart`
- **Public API:** unchanged for now. The controller and state enum stay internal until the view is exported at 0.1.0, as decided in `camera-capture`.
- **Dependencies:** none.
