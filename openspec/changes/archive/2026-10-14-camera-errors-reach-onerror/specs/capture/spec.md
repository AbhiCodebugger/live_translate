# Spec Delta

## MODIFIED Requirements

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
