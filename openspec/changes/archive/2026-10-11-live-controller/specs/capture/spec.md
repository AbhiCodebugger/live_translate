# Spec Delta

## ADDED Requirements

### Requirement: Capture can be paused
Capture SHALL be able to pause: the preview shows its last picture and no frames are streamed for processing. Resuming SHALL restart the live preview and frame streaming without restarting the camera. A paused capture SHALL be stopped and released like a running one when the app goes to the background, and SHALL restart live when the app returns.

#### Scenario: Pause and resume
- **WHEN** capture is paused and then resumed
- **THEN** no frames arrive while paused, frames arrive again after resuming, and the camera isn't restarted

#### Scenario: Background while paused
- **WHEN** capture is paused and the app goes to the background and returns
- **THEN** the camera restarts live, not paused
