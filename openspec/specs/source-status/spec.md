# source-status Specification

## Purpose

Reports where the live view stands in finding the language it translates from, from first sighting to a translation, so apps can show progress and dead ends instead of an endless "detecting".

## Requirements

### Requirement: Source status stages
The source status SHALL be one of: searching; guessed, with a language; downloading, with a language; ready, with a language; unsupported, with a BCP-47 tag; not found; or download failed, with a language. Each stage names at most one language.

#### Scenario: Stages carry their language
- **WHEN** the status is downloading for Spanish
- **THEN** it reports the downloading stage and the language Spanish

### Requirement: Searching until a language is found
The status SHALL be searching while the camera runs and no read of the current scene has given any paragraph a source language, unless the "Not found after three reads" requirement applies.

#### Scenario: Camera just started
- **WHEN** the camera is running and nothing has been read yet
- **THEN** the status is searching

#### Scenario: New scene
- **WHEN** the status is ready for French and the labels are cleared by a new scene
- **THEN** the status is searching

### Requirement: Guessed before confirmation
When a read gives paragraphs a source language whose model is not on the device, and that language is not yet confirmed as the translate capability defines, the status SHALL be guessed with that language.

#### Scenario: One read of a short Spanish sign
- **WHEN** one read identifies "Salida" as Spanish 0.9 and the Spanish model is missing
- **THEN** the status is guessed for Spanish and no download has started

### Requirement: Downloading while the model downloads
While a download of the named language's model runs, the status SHALL be downloading with that language.

#### Scenario: Confirmed and downloading
- **WHEN** Spanish is confirmed with its model missing and its download starts
- **THEN** the status is downloading for Spanish

#### Scenario: Long paragraph
- **WHEN** one read identifies a 120-letter paragraph as French 0.95 and the French model is missing
- **THEN** after that read the status is downloading for French

### Requirement: Ready once the model is present
When the named language's model is on the device, the status SHALL be ready with that language. A paragraph already in the target language SHALL count as having a language, and when every paragraph with a language is in the target language the status SHALL be ready with the target language.

#### Scenario: Model already downloaded
- **WHEN** one read identifies "Salida" as Spanish 0.9 and the Spanish model is on the device
- **THEN** the status is ready for Spanish

#### Scenario: Download completes
- **WHEN** the status is downloading for Spanish and the download completes
- **THEN** the status is ready for Spanish

#### Scenario: Page already in the target language
- **WHEN** the target is English and every paragraph read is identified as English
- **THEN** the status is ready for English

### Requirement: Unsupported for untranslatable languages
When the named language is identified but has no on-device translation model, the status SHALL be unsupported with its BCP-47 tag once that language is confirmed, and guessed is never reported for it.

#### Scenario: Lorem ipsum
- **WHEN** a steady page whose only text is lorem ipsum is identified as "la" with confidence 0.9 in three reads
- **THEN** the status is unsupported with "la"

### Requirement: Not found after three reads
When three consecutive reads of the current scene give no paragraph a source language, the status SHALL be not found. It SHALL stay not found until a read gives a paragraph a language or the scene changes.

#### Scenario: Cyrillic page
- **WHEN** the camera is held steady on a Ukrainian page and three reads give no paragraph a source language
- **THEN** the status is not found

#### Scenario: Language appears later
- **WHEN** the status is not found and the user pans to a Spanish heading that a read identifies as Spanish with its model on the device
- **THEN** the status is ready for Spanish

### Requirement: Download failed until retried
When a download of the named language's model fails, the status SHALL be download failed with that language, until a later download of it starts or another language is named.

#### Scenario: Download fails
- **WHEN** the status is downloading for Spanish and the download fails
- **THEN** the status is download failed for Spanish

#### Scenario: Retry
- **WHEN** the status is download failed for Spanish and a later read starts a new Spanish download
- **THEN** the status is downloading for Spanish

### Requirement: One language named for the picture
When paragraphs of a read have different source languages, the status SHALL name the language of the most paragraphs not in the target language. On a tie it SHALL keep the language it already names when that one is tied, and otherwise the tied language of the first such paragraph in reading order.

#### Scenario: Mostly Hindi
- **WHEN** a read gives three paragraphs Hindi and one Spanish, and both models are on the device
- **THEN** the status is ready for Hindi

#### Scenario: Tie keeps the current language
- **WHEN** the status is ready for Spanish and the next read gives one paragraph Spanish and one French
- **THEN** the status stays ready for Spanish

### Requirement: Same stages with a chosen source
When the app restricts the source languages, the status SHALL use the same stages for the languages lines are assigned, and SHALL be not found when three reads assign no paragraph a language.

#### Scenario: Hindi chosen, model missing
- **WHEN** the source languages are restricted to Hindi, the Hindi model is missing, and Hindi lines are read until Hindi is confirmed
- **THEN** the status is guessed for Hindi before confirmation and downloading for Hindi after

#### Scenario: Hindi chosen, Latin page
- **WHEN** the source languages are restricted to Hindi and three reads of a steady English page assign no paragraph a language
- **THEN** the status is not found

### Requirement: Frozen picture status
While frozen, the status SHALL describe the frozen picture's latest read. A completed download that refreshes the frozen result SHALL update it.

#### Scenario: Freeze on a downloading language
- **WHEN** the view is frozen with Hindi paragraphs untranslated, the status is downloading for Hindi, and the download completes
- **THEN** the frozen frame is read again and the status is ready for Hindi
