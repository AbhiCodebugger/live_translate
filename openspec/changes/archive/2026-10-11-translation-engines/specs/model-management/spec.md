# Spec Delta

## Purpose

Lets apps check, download, delete and list on-device translation models from their own UI. Downloads wait for Wi-Fi unless the app explicitly allows mobile data.

## ADDED Requirements

### Requirement: Check whether a model is downloaded
`TranslationModels.isDownloaded` SHALL report whether the given language's translation model is on the device.

#### Scenario: Downloaded model
- **WHEN** the Hindi model is on the device
- **THEN** `isDownloaded(TranslateLanguage.hindi)` returns true

### Requirement: Download a model
`TranslationModels.download` SHALL download the given language's model, requiring Wi-Fi unless `wifiOnly` is false, and SHALL complete once the model is on the device. A failed download SHALL throw `ModelNotDownloaded` for that language.

#### Scenario: Default waits for Wi-Fi
- **WHEN** `download(TranslateLanguage.hindi)` is called
- **THEN** the download is requested with Wi-Fi required, so on mobile data it waits for Wi-Fi

#### Scenario: Mobile data allowed
- **WHEN** `download(TranslateLanguage.hindi, wifiOnly: false)` is called
- **THEN** the download is requested without requiring Wi-Fi

#### Scenario: Download fails
- **WHEN** the platform reports that the Hindi download failed
- **THEN** `download` throws `ModelNotDownloaded` with language Hindi

### Requirement: Delete a model
`TranslationModels.delete` SHALL remove the given language's model from the device.

#### Scenario: Delete Hindi
- **WHEN** `delete(TranslateLanguage.hindi)` completes
- **THEN** `isDownloaded(TranslateLanguage.hindi)` returns false

### Requirement: List downloaded models
`TranslationModels.downloaded` SHALL return the set of languages whose models are on the device.

#### Scenario: Two models present
- **WHEN** only the English and Hindi models are on the device
- **THEN** `downloaded()` returns {English, Hindi}
