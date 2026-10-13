# Spec Delta

## MODIFIED Requirements

### Requirement: Leaving freeze when the camera restarts
When the camera restarts while frozen, because the app returned from the background, the view SHALL resume live translation and the state SHALL become `running`.

#### Scenario: Back from the background while frozen
- **WHEN** the view is frozen, the app goes to the background and returns
- **THEN** the state is `running` and frames are processed again

### Requirement: Torch
`setTorch(true)` SHALL turn on the camera's torch and `setTorch(false)` SHALL turn it off. On a camera without a torch, `setTorch` SHALL have no effect and SHALL NOT fail. The torch SHALL be off after the camera restarts.

#### Scenario: Torch on
- **WHEN** the back camera is running and `setTorch(true)` is called
- **THEN** the camera's flash mode is torch

#### Scenario: Camera without a torch
- **WHEN** the camera rejects torch mode
- **THEN** `setTorch(true)` completes without an error and the view keeps running

#### Scenario: Camera restarts
- **WHEN** the torch is on, and the app goes to the background and returns
- **THEN** the torch is off on the restarted camera

## REMOVED Requirements

### Requirement: Switching cameras through the controller
**Reason**: Only the back camera is used, so there is nothing to switch to.
**Migration**: Remove calls to `switchCamera()` and any button that triggers it.
