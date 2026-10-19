# Spec Delta

## MODIFIED Requirements

### Requirement: Download a model
`TranslationModels.download` SHALL download the given language's model, requiring Wi-Fi unless `wifiOnly` is false, and SHALL complete once the model is on the device. A failed download SHALL throw `ModelNotDownloaded` for that language.

On iOS, where the platform doesn't report when a download ends, completion SHALL be detected by checking about once a second whether the model is on the device. A cancellation reported by the platform SHALL NOT count as a failure there. A download whose model isn't on the device within 5 minutes SHALL throw `ModelNotDownloaded`. On iOS the platform always allows mobile data, so `wifiOnly` has no effect.

#### Scenario: Default waits for Wi-Fi
- **WHEN** `download(TranslateLanguage.hindi)` is called
- **THEN** the download is requested with Wi-Fi required, so on mobile data it waits for Wi-Fi

#### Scenario: Mobile data allowed
- **WHEN** `download(TranslateLanguage.hindi, wifiOnly: false)` is called
- **THEN** the download is requested without requiring Wi-Fi

#### Scenario: Download fails
- **WHEN** the platform reports that the Hindi download failed
- **THEN** `download` throws `ModelNotDownloaded` with language Hindi

#### Scenario: iOS download whose platform call never completes
- **WHEN** on iOS, `download(TranslateLanguage.hindi)` is called, the platform's download call never completes, and the Hindi model is on the device 3 seconds later
- **THEN** `download` completes within about a second of the model arriving

#### Scenario: iOS download cancelled by the platform
- **WHEN** on iOS, the platform answers the Hindi download with a cancellation, and the Hindi model is on the device 3 seconds later
- **THEN** `download` completes, without throwing

#### Scenario: iOS download that never arrives
- **WHEN** on iOS, the Hindi model still isn't on the device 5 minutes after `download(TranslateLanguage.hindi)` was called
- **THEN** `download` throws `ModelNotDownloaded` with language Hindi

#### Scenario: Model already on the device
- **WHEN** on iOS, `download(TranslateLanguage.hindi)` is called and the Hindi model is already on the device
- **THEN** `download` completes without waiting a second

#### Scenario: Android unchanged
- **WHEN** on Android, the platform's download call completes successfully
- **THEN** `download` completes at once, without checking for the model
