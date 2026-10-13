# Spec Delta

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Capture follows the app lifecycle
When the app goes to the background, frame streaming SHALL stop and the camera SHALL be released, and any result from a frame still in flight SHALL be discarded. When the app returns, capture SHALL restart on the back camera.

#### Scenario: App goes to background
- **WHEN** the app is backgrounded while a frame is being recognized
- **THEN** the camera is released, and that frame's result is never shown

#### Scenario: App returns
- **WHEN** the app returns to the foreground
- **THEN** the camera restarts on the back camera and frames are processed again

## REMOVED Requirements

### Requirement: Android frame orientation
**Reason**: Its front-camera rotation and mirroring no longer apply. Replaced by "Android frame rotation", which keeps the back-camera rule and scenarios.
**Migration**: None.

### Requirement: iOS frame orientation
**Reason**: Its front-camera case no longer applies. Replaced by "iOS frames are upright", which keeps the back-camera rule and scenario.
**Migration**: None.

### Requirement: Switching lenses
**Reason**: The package uses only the back camera, so there is no lens to switch to.
**Migration**: None. Remove any `cameraLensDirection` argument; the view always uses the back camera.
