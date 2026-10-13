# Tasks

## 1. Session maps every failure

- [x] 1.1 Wrap `start`, `pause` and `resume` in `PluginCameraSession` so that any failure is rethrown through `mapCameraError` (design D1). Verify with a new case in `test/camera/camera_session_test.dart`: when listing cameras throws a `StateError`, `start()` throws `CameraUnavailable`. Existing session tests must still pass.

## 2. View reports pause and resume failures

- [x] 2.1 Add `pauseError` and `resumeError` to `FakeCameraSession`. In the view, catch `LiveTranslateException` from `_session.pause()` in `freeze()`: report it and stay frozen (D2). Catch it from `_session.resume()` in `resume()`: report it and set the error state (D3). Verify with new cases in `test/view/live_translate_view_test.dart`, one per delta scenario:
  - **other start failure:** `startError = CameraUnavailable()` gives `onError` that error, and the view shows its error state;
  - **pause fails:** `freeze()` completes, `onError` gets the error, and the state is `frozen`;
  - **resume fails:** `resume()` completes, `onError` gets the error, and the state is `error`.

## 3. Integration check

- [x] 3.1 Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` at the package root and in `example/`. Verify all pass.
