# Design

## Context

See proposal.md for the motivation. What exists now:
- `LiveTranslateView` (internal) is configured only by its parameters: `targetLanguage`, `scripts`, `sourceLanguages` and `cameraLensDirection`.
- In `didUpdateWidget`, a changed target, scripts or hint rebuilds the pipeline, and a changed lens restarts the camera.
- Its state tracks `_running`, `_suspended` (backgrounded) and `_error`.
- It builds `TranslatedLine`s inside `build` (in the `LayoutBuilder`) and hands them to `TranslatedTextPainter`.
- `CameraSession` has `start`, `stop`, `frames`, `generation`, `uprightPreviewSize`, `buildPreview` and `dispose`.
- `PluginCameraSession` runs operations one at a time (`_serially`).

The camera plugin offers `pausePreview()`, `resumePreview()`, `isPreviewPaused` and `setFlashMode(FlashMode.torch / off)`; the last throws `CameraException` where unsupported. These are in camera 0.12.1, checked in source.

Plan §4.2's `metrics` and the 0.2 callbacks are deferred (see proposal). This is the second of three changes: `line-tracking` (done), `live-controller`, then `pipeline-metrics`.

## Goals / Non-Goals

**Goals:**
- Every `controller` and `capture` scenario is a unit or widget test using `FakeCameraSession` and fake engines.
- The controller's public surface is exactly plan §4.2, minus `metrics`, so exporting it at 0.1.0 needs no changes.
- Freeze, resume, torch and camera switching work on both phones.

**Non-Goals:**
- `metrics` (`pipeline-metrics`), the `onLinesChanged`/`onFrozen` callbacks (0.2), and the copy sheet (0.2 example).
- Remembering the torch across camera restarts. It turns off, as specified.
- Several views sharing one controller.

## Decisions

**D1. The controller is a `ChangeNotifier`. The view attaches to it through library-level functions, not public members.**

`lib/src/controller/live_translate_controller.dart` declares:
- `LiveTranslateController`, with public members `state`, `lines`, `freeze`, `resume`, `setTargetLanguage`, `setScripts`, `switchCamera` and `setTorch`.
- `abstract interface class ControllerHost`, implemented by the view's state, with the same six operations.
- Top-level functions `attachController(controller, host)`, `detachController(controller, host)` and `publishToController(controller, {state, lines})`. These can reach the controller's private fields because they live in the same library.

At 0.1.0 the entry library exports `show LiveTranslateController, LiveTranslateState`, so apps never see the attachment functions or the host interface.

Calls on an unattached controller complete without doing anything. Attaching a controller that's already attached to another view fails an `assert`.

*Alternative:* `@internal` members. Rejected because the analyzer flags `@internal` on members of an exported class. *Alternative:* a stream of commands. Rejected because there's more to test, and an `await`ed `freeze()` should complete once the view is frozen.

**D2. `LiveTranslateState` is an enum: `initializing`, `running`, `frozen`, `error`.**

The view works out the state from its fields:
- `_error != null` → `error`;
- not running → `initializing`;
- `_frozen` → `frozen`;
- otherwise → `running`.

**D3. Effective settings: the most recent change wins.**
- The view state keeps `_target`, `_scripts` and `_lens`, set from the widget in `initState`.
- In `didUpdateWidget`, each *changed* widget parameter overwrites its effective value. An unchanged parameter leaves a value the controller set.
- The controller's `setTargetLanguage`, `setScripts` and `switchCamera` overwrite the effective values directly.

A change of target or scripts goes through the existing `_tearDownPipeline` and `_buildPipeline`. A change of lens goes through `_start`. `sourceLanguages` stays widget-only, as in plan §4.2.

**D4. Lines are published after the frame, never during build.**
- The view keeps building `TranslatedLine`s in `build` for the painter.
- When they, or the state, differ from what was last published, `build` schedules a single `addPostFrameCallback`, which calls `publishToController`.
- The controller then updates and notifies its listeners outside the build phase.

Listeners that call `setState` are therefore always safe. The controller compares with `listEquals` and only notifies on a real change.

**D5. Freeze and resume.**
- `freeze()` (running only): `await session.pause()`, set `_frozen = true`, and keep `_result`. `_onResult` ignores results while frozen, which covers frames in flight. The tracker isn't touched, so tracks carry on after resuming.
- `resume()` (frozen only): `await session.resume()`, then `_frozen = false`.
- `_start()` (lens switch, return from background) and `_stop()` clear `_frozen`, which gives "leaving freeze when the camera restarts".
- Freezing outside `running`, or resuming outside `frozen`, does nothing.

**D6. The session gets `pause()`, `resume()` and `setTorch(bool)`.**
- In `PluginCameraSession`, all three run through `_serially`.
- `pause()` calls `pausePreview()`, then `stopImageStream()`.
- `resume()` calls `resumePreview()`, then restarts the stream with the same generation and orientation callback. Stream setup is refactored into `_startStream(controller, description, generation)` so `_start` and `resume` share it.
- `setTorch(on)` calls `setFlashMode(on ? FlashMode.torch : FlashMode.off)` and ignores `CameraException`.

A new `CameraController` starts with the flash at its default, not torch, so "torch is off after a restart" needs no extra code. `stop()` handles a paused controller like any other.

**D7. Example app.** It owns a `LiveTranslateController` and uses three floating buttons:
- freeze/resume, with an icon from `controller.state` via `ListenableBuilder`;
- torch, tracking an on/off flag in its own state;
- switch camera, via `controller.switchCamera()`.

The widget's `_lens` state is removed, because the lens is now driven through the controller. The "Hindi only" chip and the error messages stay.

**D8. Files:**
- `lib/src/controller/live_translate_controller.dart` and `live_translate_state.dart` (plan §6);
- changes to `camera_session.dart`, `live_translate_view.dart`, `test/support/fakes.dart` (`FakeCameraSession` gets `pauses`, `resumes` and `torch` records) and `example/lib/main.dart`.

## Risks / Trade-offs

- [`pausePreview` and `stopImageStream` behave differently on CameraX and AVFoundation, for example a black frame or a delay] → The exit check covers both phones. If needed, pausing could keep the stream running and just ignore frames. That's slightly worse for battery, but behaves the same everywhere.
- [Publishing after the frame delays controller updates by one frame (about 16 ms)] → That's invisible next to the ~200 ms between processed frames.
- [Precedence between the controller and the widget could surprise apps that set both] → Documented on both APIs. "Most recent change wins" is what `TextEditingController` users expect.
- [The torch silently does nothing on cameras without one] → As specified. The example's torch icon may still show "on" in that case. Acceptable for the example; the docs mention it.

## On-device results

Exit check on 2026-10-11: the example app with "Hindi only" on and the Hindi model downloaded, pointed at Hindi text, driving every action through the `LiveTranslateController` buttons.

| Check | Samsung Galaxy, Android 15 | iPhone 14, iOS 26.6.1 |
|---|---|---|
| Freeze stops the preview and keeps the English labels fixed while the phone moves | Pass | Pass |
| Resume brings back live translation | Pass | Pass |
| Torch turns on and off on the back camera | Pass | Pass |
| Torch on the front camera does nothing harmful | Pass | Pass |
| Switch camera works through the controller | Pass | Pass |
| Background while frozen, then return: live translation runs | Pass | Pass |

Platform differences in pausing: none reported. Both platforms showed a still frame with fixed labels while frozen and resumed cleanly.

Evidence: the author's report that every check passes on both devices. No recordings were attached.
