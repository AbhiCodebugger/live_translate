# live-view Specification

## Purpose

Configures the live translation widget (what to read, what to translate into, which languages to expect) and tells the app about problems, without restarting the camera when the configuration changes.

## Requirements

### Requirement: Translates into the target language
The view SHALL translate recognized lines into the app's target language. When the app gives none, it SHALL translate into the device's language, or into English when the device language has no on-device translation model. The device language is read when the view starts.

#### Scenario: Hindi sign to English
- **WHEN** the target language is English, Devanagari is selected, and a frame shows a Hindi sign whose models are downloaded
- **THEN** each Hindi line is shown with its English translation

#### Scenario: No target on an English phone
- **WHEN** the app gives no target language, the device language is English (United States), and a frame shows a Hindi sign whose models are downloaded
- **THEN** each Hindi line is shown with its English translation

#### Scenario: No target on a French phone
- **WHEN** the app gives no target language and the device language is French (France)
- **THEN** lines are translated into French, and the French model is checked as soon as the view starts

#### Scenario: Device language without a model
- **WHEN** the app gives no target language and the device language is one with no on-device translation model, such as Amharic
- **THEN** lines are translated into English

### Requirement: Selected scripts are read
The view SHALL read the scripts the app selects, Latin and Devanagari by default, all of them in each read.

#### Scenario: Default script
- **WHEN** the app doesn't select scripts
- **THEN** each read uses both Latin and Devanagari

#### Scenario: Latin and Devanagari
- **WHEN** the app selects Latin and Devanagari
- **THEN** both scripts' paragraphs are translated and shown

#### Scenario: Latin only
- **WHEN** the app selects only Latin
- **THEN** only Latin text is read

### Requirement: Source language hint
The view SHALL pass the expected source languages to language detection, and SHALL detect the language of each line automatically when none are given. The expected languages SHALL be the most recent of the widget's `sourceLanguages` and the controller's `setSourceLanguages`.

#### Scenario: Hindi only
- **WHEN** the app restricts source languages to Hindi
- **THEN** every line is translated from Hindi without running language identification

#### Scenario: Set through the controller
- **WHEN** the widget gives no source languages and the controller sets Hindi
- **THEN** every line is translated from Hindi without running language identification

### Requirement: Settings apply without restarting the camera
When the target language, the selected scripts or the source languages change, the view SHALL replace its recognition and translation engines, close the old ones, and discard results of reads from before the change. If a result was shown, the view SHALL read the frame it came from again with the new settings. The camera SHALL keep running.

#### Scenario: Target language changes
- **WHEN** a held result is shown in English and the target changes to French
- **THEN** the old engines are closed, the held frame is read again and shown in French, no English result is shown afterwards, and the camera isn't restarted

#### Scenario: Unchanged settings
- **WHEN** the view is rebuilt with the same target language, scripts and source languages
- **THEN** the engines are kept

### Requirement: Problems are reported to the app
The view SHALL report each `LiveTranslateException` through its `onError` callback: camera permission and availability errors, missing models, unsupported language pairs and pipeline failures. A camera error SHALL also be shown in place of the preview.

#### Scenario: Missing model
- **WHEN** the Hindi model isn't downloaded and a Hindi line is seen
- **THEN** `onError` receives `ModelNotDownloaded(hindi)` once

#### Scenario: Camera permission denied
- **WHEN** the camera can't start because permission was denied
- **THEN** `onError` receives `CameraPermissionDenied`, and the error is shown in place of the preview

### Requirement: Changed paragraphs are reported to the app
The view SHALL call its `onParagraphsChanged` callback with the paragraphs it shows whenever they change, with the same paragraphs and at the same moments as a controller's `paragraphs` and listeners would see, whether or not a controller is attached. It SHALL NOT be called while the paragraphs stay the same, and SHALL NOT be called for the empty list the view starts with.

#### Scenario: A paragraph is translated
- **WHEN** a settled read shows one translated paragraph at (17.5, 125)–(142.5, 162.5) in a view with `onParagraphsChanged` and no controller
- **THEN** `onParagraphsChanged` is called once with one `TranslatedParagraph` with that rectangle and translation

#### Scenario: Labels follow a shift
- **WHEN** the held labels move 10 view pixels to the right
- **THEN** `onParagraphsChanged` is called with each rectangle moved 10 to the right

#### Scenario: Labels are cleared
- **WHEN** a held result fades out after a new scene and its labels are dropped
- **THEN** `onParagraphsChanged` is called with paragraphs at decreasing opacity, and finally with an empty list

#### Scenario: Nothing changes
- **WHEN** a result is held and the picture doesn't move
- **THEN** `onParagraphsChanged` isn't called again

#### Scenario: Same as the controller
- **WHEN** a view has both a controller and `onParagraphsChanged`
- **THEN** every list `onParagraphsChanged` receives equals the controller's `paragraphs` at that moment, and each controller notification that changes `paragraphs` comes with one `onParagraphsChanged` call

### Requirement: The frozen result is reported to the app
Once the frozen picture's result is shown, the view SHALL call its `onFrozen` callback once with the paragraphs it shows. That is right away when freezing keeps the held labels, after the read otherwise, and again each time the frozen picture is read again. It SHALL NOT be called while a read runs or when the read fails.

#### Scenario: Freezing a held view
- **WHEN** a paragraph is held, the picture hasn't moved, and the view freezes
- **THEN** `onFrozen` is called once with that paragraph, at opacity 1

#### Scenario: Freezing while moving
- **WHEN** no result is held, the view freezes, and the read of the last frame finds one paragraph
- **THEN** `onFrozen` isn't called while the read runs, and is called once with that paragraph when it finishes

#### Scenario: Nothing found
- **WHEN** the view freezes and the frozen frame's read finds no text
- **THEN** `onFrozen` is called once with an empty list

#### Scenario: No frame yet
- **WHEN** the view freezes before any frame has been received
- **THEN** `onFrozen` is called once with an empty list

#### Scenario: Read fails
- **WHEN** the view freezes and the frozen frame's read throws
- **THEN** `onFrozen` isn't called, and `onError` receives a `PipelineFailure`

#### Scenario: Target changes while frozen
- **WHEN** the view is frozen showing English, `onFrozen` has been called, and the target changes to French
- **THEN** `onFrozen` is called again with the French paragraphs once the frozen frame has been read again

#### Scenario: Resumed before the read finishes
- **WHEN** the view freezes, and resumes before the frozen frame's read finishes
- **THEN** `onFrozen` isn't called

### Requirement: Custom placeholder while the camera starts
While the camera starts, and while it restarts after the app returns from the background, the view SHALL show the widget its `placeholderBuilder` builds, filling the view, in place of the default progress indicator. Without a `placeholderBuilder` it SHALL show the default progress indicator. A camera error SHALL be shown as before, not the placeholder.

#### Scenario: Camera starting
- **WHEN** a view with a `placeholderBuilder` returning a "Starting…" text is shown and the camera hasn't started yet
- **THEN** "Starting…" is shown and no progress indicator is

#### Scenario: Camera started
- **WHEN** the camera starts
- **THEN** the placeholder is replaced by the preview

#### Scenario: Back from the background
- **WHEN** the app returns from the background and the camera is restarting
- **THEN** the placeholder is shown until the camera has started

#### Scenario: Camera error
- **WHEN** the camera fails to start with `CameraPermissionDenied` in a view with a `placeholderBuilder`
- **THEN** the error is shown in place of the preview, not the placeholder

#### Scenario: No placeholder given
- **WHEN** a view without a `placeholderBuilder` is shown and the camera hasn't started yet
- **THEN** a progress indicator is shown

### Requirement: Debug HUD
When `showDebugHud` is `true`, the view SHALL show a small panel over the camera, above the labels or the app's overlay. It SHALL show the latest shown read's total, recognition, translation and sampling times in whole milliseconds, its paragraph count, and the number of live frames the view measured in the last second. It SHALL be off by default and SHALL NOT need a controller.

#### Scenario: Off by default
- **WHEN** a view is shown without `showDebugHud`
- **THEN** no HUD is shown

#### Scenario: Before the first read
- **WHEN** the HUD is on, the camera is running and nothing has been read
- **THEN** the HUD says no read has been made yet, and shows the frame rate

#### Scenario: After a read
- **WHEN** the HUD is on and a read whose recognition took 120 ms, translation 80 ms and sampling 10 ms showed one paragraph
- **THEN** the HUD shows the total in milliseconds, 120 ms for recognition, 80 ms for translation, 10 ms for sampling, and one paragraph

#### Scenario: Frame rate
- **WHEN** the HUD is on and frames arrive every 33 ms for two seconds
- **THEN** the HUD shows between 29 and 31 frames per second

#### Scenario: Camera stops sending frames
- **WHEN** the view is frozen for two seconds
- **THEN** the HUD shows 0 frames per second

#### Scenario: Without a controller
- **WHEN** the HUD is on, no controller is attached, and a read is shown
- **THEN** the HUD shows that read's times

#### Scenario: Above a custom overlay
- **WHEN** the HUD is on and the view has an `overlayBuilder`
- **THEN** the HUD is drawn above the overlay

#### Scenario: Clear of the status bar
- **WHEN** the HUD is on and the view fills a screen whose status bar takes the top 40 pixels
- **THEN** the HUD is drawn below the status bar

#### Scenario: While the camera starts
- **WHEN** the HUD is on and the camera hasn't started
- **THEN** no HUD is shown, only the placeholder
