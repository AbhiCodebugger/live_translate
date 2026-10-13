# Tasks

## 1. Controller

- [x] 1.1 Add `lib/src/controller/live_translate_state.dart` (`enum LiveTranslateState { initializing, running, frozen, error }`) and `lib/src/controller/live_translate_controller.dart`. The controller file holds `LiveTranslateController` (`ChangeNotifier` with `state`, `lines`, `freeze`, `resume`, `setTargetLanguage`, `setScripts`, `switchCamera`, `setTorch`), `ControllerHost`, and the top-level `attachController`, `detachController` and `publishToController` (design D1, D2). Verify with `test/controller/live_translate_controller_test.dart`, using a fake host:
  - an unattached controller reports `initializing` with no lines, and its calls complete without effect;
  - after attaching, each call reaches the host;
  - publishing a new state or new lines notifies once, and publishing equal values doesn't notify;
  - attaching to a second host trips an assertion;
  - after detaching, calls are ignored again.

## 2. Camera session

- [x] 2.1 Add `pause()`, `resume()` and `setTorch(bool)` to `CameraSession`. Implement them in `PluginCameraSession` through `_serially`: `pausePreview` plus `stopImageStream`; `resumePreview` plus restarting the stream with the same generation via a shared `_startStream`; and `setFlashMode(torch/off)` ignoring `CameraException` (design D6). Extend `FakeCameraSession` with `pauses`, `resumes` and a `torch` record. Verify with `test/camera/camera_session_test.dart`: an idle `PluginCameraSession` completes `pause`, `resume` and `setTorch` without throwing. Verify that `flutter analyze` is clean. The plugin calls themselves are checked on device in group 5.

## 3. View wiring

- [x] 3.1 Update `LiveTranslateView` (design D3, D4, D5):
  - add the `controller` parameter, attaching in `initState`/`didUpdateWidget` and detaching in `dispose`;
  - keep effective `_target`, `_scripts` and `_lens`, where the most recent change wins;
  - implement `ControllerHost` (freeze, resume, settings, switch, torch);
  - track `_frozen`, ignoring results while frozen and clearing it in `_start`/`_stop`;
  - publish state and lines after each frame when they change.

  Verify with new cases in `test/view/live_translate_view_test.dart`, one per `controller` and `capture` spec scenario:
  - state goes `initializing` → `running` with a notification, and permission denied gives `error`;
  - `lines` holds the shown line at (17.5, 125)–(142.5, 162.5), and is empty before any translation;
  - freeze pauses the session, keeps the line and ignores new frames; resume restarts processing; a result in flight during freeze doesn't change `lines`;
  - background and return while frozen gives `running`;
  - `setTargetLanguage(french)` gives "[fr]" labels without a camera restart; a later widget change to German wins; an unchanged widget keeps French;
  - `setScripts` rebuilds the text engine with the new scripts;
  - `switchCamera` restarts on the front camera;
  - `setTorch(true)` reaches the session, a session that rejects the torch doesn't break the view, and the torch record is off after a camera switch.

  Keep all existing view tests passing.
- [x] 3.2 Measure coverage. Run `flutter test --coverage` and add up `LH`/`LF` for `SF:lib/src/controller/` and `SF:lib/src/pipeline/`. Verify that each is at least 90%, and report both figures.

## 4. Example app and checks

- [x] 4.1 Update `example/lib/main.dart` (design D7): a `LiveTranslateController`, plus freeze/resume, torch and switch-camera buttons that use it, with icons reflecting `controller.state` through `ListenableBuilder`. Keep the "Hindi only" chip and the error messages. Update `example/test/widget_test.dart` to find all three buttons and tap the switch-camera button without errors. Verify that `flutter analyze` and `flutter test` pass in `example/`, and that both platform builds succeed.
- [x] 4.2 Run the package checks. Verify that `dart format --set-exit-if-changed .` makes no changes, `flutter analyze` reports no issues, `flutter test` passes, and `git diff lib/live_translate_overlay.dart` is empty.

## 5. On-device exit check

- [x] 5.1 **Manual, on the Samsung Galaxy (Android 15) and the iPhone 14 (iOS 26.6.1),** with "Hindi only" on, over Hindi text. Verify, for each device:
  - freeze stops the preview and keeps the English labels fixed, even when the phone moves;
  - resume brings back live translation;
  - torch turns the light on and off on the back camera, and does nothing harmful on the front camera;
  - switch camera works through the controller;
  - backgrounding while frozen and returning gives live translation.
- [x] 5.2 Record the results from 5.1 under "On-device results" in `design.md`, including any platform difference in how pausing behaves. Verify that the section lists both devices with every check.
