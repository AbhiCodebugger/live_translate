# Spec Delta

## Purpose

Delivers live camera frames to text recognition without flooding it. Each frame is tagged with the rotation and mirroring needed to place its results on screen, and the camera follows the app's lifecycle.

## ADDED Requirements

### Requirement: Frames are dropped while one is processing
While a frame is being processed, any new frame SHALL be dropped, never queued.

#### Scenario: Frame arrives during processing
- **WHEN** a frame is being processed and a new frame arrives
- **THEN** the new frame is dropped and only one frame is processing

### Requirement: Frames respect a minimum interval
A frame SHALL be processed only if at least the minimum interval (default 200 ms) has passed since the previous processed frame started. Earlier frames SHALL be dropped.

#### Scenario: Frame too soon after the previous one
- **WHEN** the previous frame started processing 100 ms ago, has finished, and a new frame arrives with a 200 ms interval
- **THEN** the new frame is dropped

#### Scenario: Frame after the interval
- **WHEN** the previous frame started processing 200 ms ago, has finished, and a new frame arrives
- **THEN** the new frame is processed

### Requirement: A failed frame does not stop capture
If processing a frame fails, the failure SHALL be reported, and later frames SHALL continue to be processed.

#### Scenario: Recognition throws
- **WHEN** recognition throws on one frame and the next frame arrives after the interval
- **THEN** the failure is reported as a `PipelineFailure` and the next frame is processed

### Requirement: Platform frame formats
The camera SHALL stream nv21 frames on Android and bgra8888 frames on iOS. A frame that isn't a single plane in a format recognition supports SHALL be skipped without error.

#### Scenario: Unsupported frame
- **WHEN** a frame arrives with three planes or an unknown format
- **THEN** it is skipped, no error is reported, and capture continues

### Requirement: Android frame orientation
On Android, a frame's rotation SHALL be the sensor orientation minus the device orientation (back camera), or plus it (front camera), modulo 360. Front-camera frames SHALL be marked for mirroring.

#### Scenario: Back camera, portrait
- **WHEN** the back camera has sensor orientation 90 and the device is portrait-up
- **THEN** the rotation is 90° and the frame is not mirrored

#### Scenario: Back camera, landscape left
- **WHEN** the back camera has sensor orientation 90 and the device is landscape-left
- **THEN** the rotation is 0°

#### Scenario: Front camera, portrait
- **WHEN** the front camera has sensor orientation 270 and the device is portrait-up
- **THEN** the rotation is 270° and the frame is mirrored

### Requirement: iOS frame orientation
On iOS, frames SHALL be treated as already upright (rotation 0°) and never marked for mirroring, because the camera delivers them rotated to the device orientation and, for the front camera, already mirrored.

#### Scenario: Back camera in any orientation
- **WHEN** an iOS back-camera frame arrives with the device in landscape
- **THEN** the rotation is 0° and the frame is not mirrored

#### Scenario: Front camera
- **WHEN** an iOS front-camera frame arrives
- **THEN** the rotation is 0° and the frame is not mirrored

### Requirement: Capture follows the app lifecycle
When the app goes to the background, frame streaming SHALL stop and the camera SHALL be released, and any result from a frame still in flight SHALL be discarded. When the app returns, capture SHALL restart with the same lens.

#### Scenario: App goes to background
- **WHEN** the app is backgrounded while a frame is being recognized
- **THEN** the camera is released, and that frame's result is never shown

#### Scenario: App returns
- **WHEN** the app returns to the foreground
- **THEN** the camera restarts with the same lens and frames are processed again

### Requirement: Switching lenses
Changing the requested lens direction SHALL restart capture on the matching camera. Results from the previous camera SHALL be discarded.

#### Scenario: Switch to the front camera
- **WHEN** the lens direction changes from back to front
- **THEN** capture restarts on the front camera, and no box from a back-camera frame is shown afterwards

### Requirement: Disposal releases resources
Disposing capture SHALL stop streaming and release the camera and the recognizer. No frame SHALL be processed afterwards.

#### Scenario: Dispose while a frame is in flight
- **WHEN** capture is disposed while a frame is being recognized
- **THEN** the camera and recognizer are released, and the frame's result is ignored

### Requirement: Camera errors are reported as package errors
A denied or restricted camera permission SHALL be reported as `CameraPermissionDenied`. A device with no camera, or a camera that fails to start, SHALL be reported as `CameraUnavailable`.

#### Scenario: Permission denied
- **WHEN** the camera fails to start with `CameraAccessDenied`, `CameraAccessDeniedWithoutPrompt` or `CameraAccessRestricted`
- **THEN** a `CameraPermissionDenied` is reported

#### Scenario: No camera
- **WHEN** the device reports no cameras
- **THEN** a `CameraUnavailable` is reported
