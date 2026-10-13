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
The view SHALL pass the app's expected source languages to language detection, and SHALL detect the language of each line automatically when none are given.

#### Scenario: Hindi only
- **WHEN** the app restricts source languages to Hindi
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
