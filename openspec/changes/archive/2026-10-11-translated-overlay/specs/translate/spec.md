# Spec Delta

## MODIFIED Requirements

### Requirement: Missing models download over Wi-Fi only
Before translating, both the source and target models SHALL be checked. A missing target model SHALL be downloaded at once. A missing source model SHALL be downloaded automatically only as the "Source models download only when expected and confirmed" requirement allows. Downloads SHALL require Wi-Fi, and a `ModelNotDownloaded` SHALL be reported once per download started. Lines needing a missing model SHALL be returned untranslated, and translation SHALL never be attempted while a model is missing.

#### Scenario: Hindi model missing
- **WHEN** the source languages are restricted to Hindi, Hindi lines are translated to English in three frames, and the Hindi model is missing
- **THEN** one Wi-Fi-only download of Hindi is started, one `ModelNotDownloaded(hindi)` is reported, the lines are untranslated, and the translator is never called

#### Scenario: Download completes
- **WHEN** the Hindi download completes and a Hindi line is translated again
- **THEN** the line is translated

#### Scenario: Download fails
- **WHEN** the Hindi download fails
- **THEN** a later Hindi line starts one new download attempt

#### Scenario: Missing target model
- **WHEN** the English target model is missing and the first Spanish line is translated
- **THEN** a Wi-Fi-only download of English starts at once

### Requirement: Unsupported source languages are reported once
A line whose source language can't be translated on-device SHALL be returned untranslated. An `UnsupportedLanguagePair` SHALL be reported once per source language, and only once that language is confirmed.

#### Scenario: Language without a translation model
- **WHEN** lines identified as "la-Latn" with confidence 0.9 appear in three frames
- **THEN** they are untranslated and one `UnsupportedLanguagePair` with source "la-Latn" is reported

#### Scenario: Stray unsupported tag
- **WHEN** a line is identified as "hi-Latn" with confidence 0.9 in one frame only
- **THEN** nothing is reported

## ADDED Requirements

### Requirement: Source models download only when expected and confirmed
A detected language SHALL count as confirmed when it was assigned with confidence 0.8 or more in at least 3 of the last 10 frames; a line assigned from a single hinted language counts as confidence 1. A missing source model SHALL be downloaded automatically only when its language is in the app's source languages and is confirmed, one such download at a time. Otherwise a confirmed missing language SHALL only be reported, once.

#### Scenario: Detected but not expected
- **WHEN** no source languages are given, Swahili is identified with confidence 0.9 in three frames, and its model is missing
- **THEN** no download starts, and one `ModelNotDownloaded(swahili)` is reported

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
- **WHEN** the source languages are Hindi and Marathi, both are confirmed, and the Hindi download is in progress
- **THEN** Marathi doesn't start downloading until the Hindi download ends

### Requirement: Models downloaded by the app are noticed
A model found missing SHALL be checked again at most once every 10 frames, so a model the app downloads, for example through `TranslationModels`, is used without restarting translation.

#### Scenario: App downloads the model
- **WHEN** the Swahili model is missing, then the app downloads it, and Swahili lines keep arriving
- **THEN** within 10 frames the Swahili lines are translated
