# controller Specification

## Purpose

Lets app code drive and observe the live translation view: what state it is in, which lines it shows, freezing and resuming, changing languages and scripts, and the torch.

## Requirements

### Requirement: The controller reports the view's state
The controller SHALL report `initializing` until the camera is running, `running` while live translation runs, `frozen` while frozen, and `error` after the camera fails to start. Listeners SHALL be notified whenever the state changes. A controller not attached to a view SHALL report `initializing`.

#### Scenario: Camera starts
- **WHEN** a view with a controller is shown and its camera starts
- **THEN** the controller's state goes from `initializing` to `running`, and listeners are notified

#### Scenario: Camera permission denied
- **WHEN** the camera fails to start with `CameraPermissionDenied`
- **THEN** the controller's state is `error`

### Requirement: The controller exposes the current lines
The controller's `lines` SHALL be the paragraphs the view currently shows, as `TranslatedLine`s with rectangles in view coordinates (including any shift the labels follow), IDs and opacity. Listeners SHALL be notified when they change.

#### Scenario: A line is translated
- **WHEN** a settled read shows one translated paragraph at (17.5, 125)–(142.5, 162.5)
- **THEN** `lines` holds one `TranslatedLine` with that rectangle and translation, and listeners are notified

#### Scenario: Labels follow a shift
- **WHEN** the held labels move 10 view pixels to the right
- **THEN** each rectangle in `lines` moves 10 to the right, and listeners are notified

#### Scenario: Nothing translated yet
- **WHEN** the camera is running but nothing has been read
- **THEN** `lines` is empty

### Requirement: Freeze keeps the current translation still
`freeze()` SHALL pause the preview, stop measuring and reading live frames, and set the state to `frozen`, keeping or reading a result as `still-translation` describes. While a read runs, `lines` SHALL be empty; otherwise it SHALL hold one `TranslatedLine` per shown paragraph. `resume()` SHALL restart the preview and live translation and set the state to `running`. Freezing while frozen, or resuming while running, SHALL have no effect.

#### Scenario: Freeze
- **WHEN** the state is `running`, a held paragraph is shown, the picture hasn't moved, and `freeze()` is called
- **THEN** the state is `frozen`, the preview is paused, and `lines` still holds the same paragraph

#### Scenario: Resume
- **WHEN** the state is `frozen` and `resume()` is called
- **THEN** the state becomes `running` and frames are measured again

#### Scenario: Frame in flight
- **WHEN** a read is running when `freeze()` is called on a view with no held result, and that read finishes afterwards
- **THEN** its result isn't shown; `lines` changes only to the result of reading the frozen frame

#### Scenario: Paragraph lines
- **WHEN** a read finds one paragraph of two lines, translated as "It has long been known that working with readable text"
- **THEN** `lines` holds one `TranslatedLine` with that translation, its source text being both lines joined, and a rectangle covering both lines

### Requirement: Leaving freeze when the camera restarts
When the camera restarts while frozen, because the app returned from the background, the view SHALL resume live translation and the state SHALL become `running`.

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

### Requirement: The controller reports the target language
The controller's `targetLanguage` SHALL be the language the attached view translates into. When the app gives the view no target, it SHALL be the device-language default the view chose. It SHALL follow changes made through the widget or the controller, and listeners SHALL be notified when it changes. A controller not attached to a view SHALL report `null`.

#### Scenario: Default target on a French phone
- **WHEN** a view with a controller and no target language is shown on a phone whose language is French (France)
- **THEN** after the view's first frame, the controller's `targetLanguage` is French and listeners are notified

#### Scenario: Explicit target
- **WHEN** a view with a controller is shown with `targetLanguage: TranslateLanguage.german`
- **THEN** the controller's `targetLanguage` is German

#### Scenario: Changed through the controller
- **WHEN** the view translates into English and `setTargetLanguage(TranslateLanguage.french)` is called
- **THEN** the controller's `targetLanguage` becomes French and listeners are notified

#### Scenario: Changed through the widget
- **WHEN** the view translates into English and is rebuilt with `targetLanguage: TranslateLanguage.german`
- **THEN** the controller's `targetLanguage` becomes German and listeners are notified

#### Scenario: Not attached
- **WHEN** a controller has not been passed to a view, or its view has been removed
- **THEN** its `targetLanguage` is `null`

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

### Requirement: The controller reports the source status
The controller's `sourceStatus` SHALL be the attached view's source status, as the source-status capability defines. Listeners SHALL be notified whenever it changes, and SHALL NOT be notified while it stays the same. A controller not attached to a view SHALL report searching.

#### Scenario: Language guessed
- **WHEN** a view with a controller reads "Salida" as Spanish 0.9 with the Spanish model missing
- **THEN** the controller's `sourceStatus` is guessed for Spanish and listeners are notified

#### Scenario: Unchanged status
- **WHEN** the status is ready for Spanish and the next read also gives ready for Spanish
- **THEN** listeners are not notified for the status

#### Scenario: Not attached
- **WHEN** a controller has not been passed to a view, or its view has been removed
- **THEN** its `sourceStatus` is searching
