# capture Specification

## Purpose

Delivers live camera frames to text recognition without flooding it. Capture always uses the back camera. Each frame is tagged with the rotation needed to place its results on screen, and the camera follows the app's lifecycle.

## Requirements

### Requirement: A failed frame does not stop capture
If a read fails, the failure SHALL be reported as a `PipelineFailure`, no labels from that read SHALL be shown, and the view SHALL read again the next time the picture settles.

#### Scenario: Recognition throws
- **WHEN** recognition throws during a read, and the picture later moves and settles again
- **THEN** the failure is reported as a `PipelineFailure` and the next settled frame is read

### Requirement: Platform frame formats
The camera SHALL stream nv21 frames on Android and bgra8888 frames on iOS. A frame that isn't a single plane in a format recognition supports SHALL be skipped without error.

#### Scenario: Unsupported frame
- **WHEN** a frame arrives with three planes or an unknown format
- **THEN** it is skipped, no error is reported, and capture continues

### Requirement: Capture follows the app lifecycle
When the app goes to the background, frame streaming SHALL stop and the camera SHALL be released, and any result from a frame still in flight SHALL be discarded. When the app returns, capture SHALL restart on the back camera.

#### Scenario: App goes to background
- **WHEN** the app is backgrounded while a frame is being recognized
- **THEN** the camera is released, and that frame's result is never shown

#### Scenario: App returns
- **WHEN** the app returns to the foreground
- **THEN** the camera restarts on the back camera and frames are processed again

### Requirement: Disposal releases resources
Disposing capture SHALL stop streaming and release the camera and the recognizer. No frame SHALL be processed afterwards.

#### Scenario: Dispose while a frame is in flight
- **WHEN** capture is disposed while a frame is being recognized
- **THEN** the camera and recognizer are released, and the frame's result is ignored

### Requirement: Camera errors are reported as package errors
A denied or restricted camera permission SHALL be reported as `CameraPermissionDenied`. A device with no camera, or a camera that fails to start, SHALL be reported as `CameraUnavailable`. A camera that fails to start its frame stream, to pause or to resume SHALL be reported the same way. No camera failure SHALL reach the app as anything other than a `LiveTranslateException` through `onError`.

#### Scenario: Permission denied
- **WHEN** the camera fails to start with `CameraAccessDenied`, `CameraAccessDeniedWithoutPrompt` or `CameraAccessRestricted`
- **THEN** a `CameraPermissionDenied` is reported

#### Scenario: No camera
- **WHEN** the device reports no cameras
- **THEN** a `CameraUnavailable` is reported

#### Scenario: Other start failure
- **WHEN** starting the camera fails with an error that isn't a camera permission error
- **THEN** a `CameraUnavailable` is reported and the view shows its error state

#### Scenario: Pause fails
- **WHEN** the view is running and freezing fails to pause the camera
- **THEN** a `CameraUnavailable` is reported through `onError`, `freeze()` completes without throwing, and the view is frozen

#### Scenario: Resume fails
- **WHEN** the view is frozen and resuming fails to restart the camera
- **THEN** a `CameraUnavailable` is reported through `onError`, `resume()` completes without throwing, and the state is `error`

### Requirement: Capture can be paused
Capture SHALL be able to pause: the preview shows its last picture and no frames are streamed for processing. Resuming SHALL restart the live preview and frame streaming without restarting the camera. A paused capture SHALL be stopped and released like a running one when the app goes to the background, and SHALL restart live when the app returns.

#### Scenario: Pause and resume
- **WHEN** capture is paused and then resumed
- **THEN** no frames arrive while paused, frames arrive again after resuming, and the camera isn't restarted

#### Scenario: Background while paused
- **WHEN** capture is paused and the app goes to the background and returns
- **THEN** the camera restarts live, not paused

### Requirement: Capture uses the back camera
Capture SHALL always use the device's back camera. When no back camera is available, capture SHALL report `CameraUnavailable` and SHALL NOT fall back to another camera.

#### Scenario: Back and front cameras
- **WHEN** the device reports a front camera first and a back camera second
- **THEN** capture starts on the back camera

#### Scenario: Front camera only
- **WHEN** the device reports only a front camera
- **THEN** a `CameraUnavailable` is reported and no camera is started

### Requirement: Android frame rotation
On Android, a frame's rotation SHALL be the back camera's sensor orientation minus the device orientation, modulo 360. Frames SHALL never be marked for mirroring.

#### Scenario: Back camera, portrait
- **WHEN** the back camera has sensor orientation 90 and the device is portrait-up
- **THEN** the rotation is 90° and the frame is not mirrored

#### Scenario: Back camera, landscape left
- **WHEN** the back camera has sensor orientation 90 and the device is landscape-left
- **THEN** the rotation is 0°

### Requirement: iOS frames are upright
On iOS, frames SHALL be treated as already upright (rotation 0°) and never marked for mirroring, because the camera delivers them rotated to the device orientation.

#### Scenario: Back camera in any orientation
- **WHEN** an iOS back-camera frame arrives with the device in landscape
- **THEN** the rotation is 0° and the frame is not mirrored
