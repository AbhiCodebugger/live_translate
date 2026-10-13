# Spec Delta

## Purpose

Lets app code drive and observe the live translation view: what state it is in, which lines it shows, freezing and resuming, changing languages and scripts, switching cameras and the torch.

## ADDED Requirements

### Requirement: The controller reports the view's state
The controller SHALL report `initializing` until the camera is running, `running` while live translation runs, `frozen` while frozen, and `error` after the camera fails to start. Listeners SHALL be notified whenever the state changes. A controller not attached to a view SHALL report `initializing`.

#### Scenario: Camera starts
- **WHEN** a view with a controller is shown and its camera starts
- **THEN** the controller's state goes from `initializing` to `running`, and listeners are notified

#### Scenario: Camera permission denied
- **WHEN** the camera fails to start with `CameraPermissionDenied`
- **THEN** the controller's state is `error`

### Requirement: The controller exposes the current lines
The controller's `lines` SHALL be the `TranslatedLine`s the view currently shows, with rectangles in view coordinates, IDs and opacity. Listeners SHALL be notified when they change.

#### Scenario: A line is translated
- **WHEN** a frame's line is translated and shown at (17.5, 125)–(142.5, 162.5)
- **THEN** `lines` holds one `TranslatedLine` with that rectangle and translation, and listeners are notified

#### Scenario: Nothing translated yet
- **WHEN** the camera is running but no line has been translated
- **THEN** `lines` is empty

### Requirement: Freeze keeps the current translation still
`freeze()` SHALL pause the preview and stop processing frames, keep `lines` and the labels on screen unchanged, and set the state to `frozen`. `resume()` SHALL restart the preview and processing and set the state to `running`. Results from frames in flight when freezing SHALL be discarded. Freezing while frozen, or resuming while running, SHALL have no effect.

#### Scenario: Freeze
- **WHEN** the state is `running`, a line is shown, and `freeze()` is called
- **THEN** the state is `frozen`, the preview is paused, the same line is still shown, and new frames aren't processed

#### Scenario: Resume
- **WHEN** the state is `frozen` and `resume()` is called
- **THEN** the state becomes `running` and frames are processed again

#### Scenario: Frame in flight
- **WHEN** a frame is being recognized when `freeze()` is called, and its result arrives afterwards
- **THEN** the shown lines don't change

### Requirement: Leaving freeze when the camera restarts
When the camera restarts while frozen, because the app returned from the background or the camera was switched, the view SHALL resume live translation and the state SHALL become `running`.

#### Scenario: Back from the background while frozen
- **WHEN** the view is frozen, the app goes to the background and returns
- **THEN** the state is `running` and frames are processed again

### Requirement: Settings can be changed through the controller
`setTargetLanguage` and `setScripts` SHALL change the view's target language and scripts the same way changing the widget parameters does, without restarting the camera. The most recent change SHALL win, whether it came from the controller or a widget parameter.

#### Scenario: New target language
- **WHEN** the view translates into English and `setTargetLanguage(TranslateLanguage.french)` is called
- **THEN** new lines are translated into French and the camera isn't restarted

#### Scenario: Widget changes after the controller
- **WHEN** `setTargetLanguage(TranslateLanguage.french)` was called, and the widget is then rebuilt with a new `targetLanguage` of German
- **THEN** lines are translated into German

#### Scenario: Unchanged widget keeps the controller's choice
- **WHEN** `setTargetLanguage(TranslateLanguage.french)` was called, and the widget is rebuilt with the same `targetLanguage` as before
- **THEN** lines are still translated into French

### Requirement: Switching cameras through the controller
`switchCamera()` SHALL switch between the back and front cameras, as changing the lens widget parameter does.

#### Scenario: Back to front
- **WHEN** the back camera is in use and `switchCamera()` is called
- **THEN** capture restarts on the front camera

### Requirement: Torch
`setTorch(true)` SHALL turn on the camera's torch and `setTorch(false)` SHALL turn it off. On a camera without a torch, `setTorch` SHALL have no effect and SHALL NOT fail. The torch SHALL be off after the camera restarts.

#### Scenario: Torch on
- **WHEN** the back camera is running and `setTorch(true)` is called
- **THEN** the camera's flash mode is torch

#### Scenario: Camera without a torch
- **WHEN** the camera rejects torch mode
- **THEN** `setTorch(true)` completes without an error and the view keeps running

#### Scenario: Camera restarts
- **WHEN** the torch is on and the camera is switched
- **THEN** the torch is off on the new camera
