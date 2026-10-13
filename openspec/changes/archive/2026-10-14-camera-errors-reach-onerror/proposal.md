# Proposal

## Why

Week 4 requires every failure to reach the app as a `LiveTranslateException` through `onError`. An audit of the paths found three camera failures that escape as a raw `CameraException` instead:
- **The frame stream fails to start after the camera initialises.** Nothing is reported and the view keeps showing its spinner. The `capture` spec already says a camera that fails to start is reported as `CameraUnavailable`, so this is a bug.
- **`freeze()` can't pause the preview.** The exception is thrown at whoever called the controller, and `onError` hears nothing.
- **`resume()` can't restart the preview or the stream.** Same as above, and the view stays frozen.

The other paths already report correctly: permission and missing camera at start, failed reads, model downloads, unsupported languages and translator failures.

## What Changes

- **The camera session maps every failure** of starting, pausing and resuming to a `LiveTranslateException`: `CameraPermissionDenied` for permission codes, `CameraUnavailable` otherwise. This includes the frame stream failing to start.
- **A failed pause** is reported through `onError`. The view still freezes, so its labels hold still, and `freeze()` completes normally.
- **A failed resume** is reported through `onError`. The view goes to the `error` state, as after a failed start, and `resume()` completes normally. Returning from the background restarts the camera and recovers, as today.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `capture`: "Camera errors are reported as package errors" also covers the frame stream failing to start, and failures to pause or resume. Each is mapped and reported, never thrown at the app.

## Impact

- **Changed code:**
  - `lib/src/camera/camera_session.dart` (one mapping point for start, pause and resume)
  - `lib/src/view/live_translate_view.dart` (`freeze` and `resume` catch and report)
  - `test/support/fakes.dart` (`pauseError`, `resumeError`)
  - `test/camera/camera_session_test.dart` and `test/view/live_translate_view_test.dart`
- **Public API:** unchanged. `freeze()` and `resume()` no longer throw camera exceptions.
- **Dependencies:** none.
