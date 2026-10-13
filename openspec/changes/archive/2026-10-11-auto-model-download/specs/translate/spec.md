# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Missing models download over Wi-Fi only`
- TO: `### Requirement: Missing models download automatically`

- FROM: `### Requirement: Source models download only when expected and confirmed`
- TO: `### Requirement: Source models download once confirmed`

## MODIFIED Requirements

### Requirement: Missing models download automatically
Before translating, both the source and target models SHALL be checked. Lines needing a missing model SHALL be returned untranslated, and translation SHALL never be attempted while a model is missing. A missing source model SHALL be downloaded automatically as the "Source models download once confirmed" requirement allows.

#### Scenario: Hindi model missing
- **WHEN** the source languages are restricted to Hindi, Hindi lines are translated to English in three frames, and the Hindi model is missing
- **THEN** one download of Hindi is started, one `ModelNotDownloaded(hindi)` is reported, the lines are untranslated, and the translator is never called

#### Scenario: Download completes
- **WHEN** the Hindi download completes and a Hindi line is translated again
- **THEN** the line is translated

#### Scenario: Download fails
- **WHEN** the Hindi download fails
- **THEN** a later Hindi line starts one new download attempt

#### Scenario: Missing target model
- **WHEN** the English target model is missing and translation into English begins
- **THEN** a download of English starts at once

### Requirement: Source models download once confirmed
A language SHALL count as confirmed when, in at least 3 of the last 10 frames, it was its script's language for the frame with an average confidence of 0.8 or more across the lines that identified it, and in more of those frames than any other language of its script. A single hinted language counts as confidence 1. A missing source model SHALL be downloaded once its language is confirmed, whether or not the app expected it, one download at a time.

#### Scenario: Detected but not expected
- **WHEN** no source languages are given, Swahili is identified with confidence 0.9 in three frames, and its model is missing
- **THEN** one download of Swahili starts, and one `ModelNotDownloaded(swahili)` is reported

#### Scenario: One stray detection
- **WHEN** the source languages are Hindi and Marathi, and Marathi is identified with confidence 0.9 in one frame
- **THEN** no download starts and nothing is reported

#### Scenario: Repeated low-confidence detection
- **WHEN** the source languages are Hindi and Marathi, and Marathi is identified with confidence 0.7 in five frames
- **THEN** no download starts

#### Scenario: Detections too far apart
- **WHEN** the source languages are Hindi and Marathi, and Marathi is identified with confidence 0.9 in frames 1, 7 and 13
- **THEN** no download starts, because no 10 consecutive frames contain all three

#### Scenario: Confirmed on the third frame
- **WHEN** the source languages are restricted to Hindi and Hindi lines appear in three frames
- **THEN** no download starts after the first two frames, and one starts on the third

#### Scenario: One download at a time
- **WHEN** Hindi and Spanish lines appear together, both languages are confirmed with their models missing, and the Hindi download is in progress
- **THEN** Spanish doesn't start downloading until the Hindi download ends

#### Scenario: Stray Marathi on Hindi text
- **WHEN** no source languages are given and, in each of five frames, two Devanagari lines are identified as Hindi 0.9 and one as Marathi 0.9, with both models missing
- **THEN** only Hindi is downloaded

#### Scenario: Two languages competing in one script
- **WHEN** over the last 10 frames Devanagari text was Hindi in four frames and Marathi in three, each with confidence 0.9
- **THEN** Hindi is confirmed and Marathi is not

#### Scenario: Hindi seen on an English phone
- **WHEN** no source languages are given, the target is English, Hindi is identified with confidence 0.9 in three frames, and the Hindi model is missing
- **THEN** one download of Hindi starts on the third frame, and Hindi lines are translated into English once it completes

### Requirement: A missing target model downloads at once
When translation into a target language begins, because the view started or the target changed, the target model SHALL be checked and, if missing, its download SHALL start straight away, before any line is seen and without waiting for confirmation, because the target was chosen by the app or the device.

#### Scenario: First frame with the target missing
- **WHEN** the English target model is missing, the source languages are restricted to Hindi, and the Hindi model is present
- **THEN** the English download has already started before the first frame, and the first frame that contains a Hindi line doesn't start a second one

#### Scenario: Target changes
- **WHEN** translation switches to French and the French model is missing
- **THEN** a download of French starts at once, before any line is translated into French

#### Scenario: Target already present
- **WHEN** translation into English begins and the English model is on the device
- **THEN** no download starts and nothing is reported

## REMOVED Requirements

### Requirement: Downloads require Wi-Fi and are reported once each
**Reason**: Automatic downloads now use any network, so translation works on first use without Wi-Fi. Replaced by "Automatic downloads use any network and are reported once each".
**Migration**: An app that must avoid mobile data can download models itself with `TranslationModels.download`, which still waits for Wi-Fi by default, before showing the view.

## ADDED Requirements

### Requirement: Automatic downloads use any network and are reported once each
Every automatic model download SHALL be requested without requiring Wi-Fi, and a `ModelNotDownloaded` SHALL be reported once for each download started, including each retry after a failed download.

#### Scenario: Download on mobile data
- **WHEN** an automatic download of the English model starts
- **THEN** it is requested without requiring Wi-Fi, and one `ModelNotDownloaded(english)` is reported

#### Scenario: Retry is reported again
- **WHEN** the source languages are restricted to Hindi, the Hindi download fails, and a later confirmed Hindi frame starts a new download
- **THEN** a second `ModelNotDownloaded(hindi)` is reported for the retry
