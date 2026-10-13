# Spec Delta

## Purpose

Configures the live translation widget (what to read, what to translate into, which languages to expect) and tells the app about problems, without restarting the camera when the configuration changes.

## ADDED Requirements

### Requirement: Translates into the target language
The view SHALL require a target language and SHALL translate recognized lines into it.

#### Scenario: Hindi sign to English
- **WHEN** the target language is English, Devanagari is selected, and a frame shows a Hindi sign whose models are downloaded
- **THEN** each Hindi line is shown with its English translation

### Requirement: Selected scripts are read
The view SHALL read the scripts the app selects, Latin by default, taking turns between them when more than one is selected.

#### Scenario: Default script
- **WHEN** the app doesn't select scripts
- **THEN** only Latin text is read

#### Scenario: Latin and Devanagari
- **WHEN** the app selects Latin and Devanagari
- **THEN** both scripts' lines are translated and shown

### Requirement: Source language hint
The view SHALL pass the app's expected source languages to language detection, and SHALL detect the language of each line automatically when none are given.

#### Scenario: Hindi only
- **WHEN** the app restricts source languages to Hindi
- **THEN** every line is translated from Hindi without running language identification

### Requirement: Settings apply without restarting the camera
When the target language, the selected scripts or the source languages change, the view SHALL replace its recognition and translation engines, close the old ones, and discard results from before the change. The camera SHALL keep running.

#### Scenario: Target language changes
- **WHEN** the target language changes from English to French while the camera runs
- **THEN** the old engines are closed, new frames are translated into French, no English result is shown afterwards, and the camera isn't restarted

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
