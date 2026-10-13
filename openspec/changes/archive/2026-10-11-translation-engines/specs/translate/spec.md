# Spec Delta

## Purpose

Translates each recognized line into the target language on-device. It reuses earlier translations, never downloads a model over mobile data unasked, and reports each problem once rather than on every frame.

## ADDED Requirements

### Requirement: Lines are translated into the target language
A line with a supported source language SHALL be translated into the target language once both languages' models are on the device. A line with no source language SHALL be returned untranslated.

#### Scenario: Spanish line to English
- **WHEN** the line "Salida" has source language Spanish, the target is English, and both models are downloaded
- **THEN** the line is returned with its translation

#### Scenario: No source language
- **WHEN** a line has no source language
- **THEN** it is returned untranslated and the translator is not called

### Requirement: Repeated text is translated once
Translations SHALL be cached by line text, ignoring leading, trailing and repeated whitespace, together with the source and target languages. The cache SHALL hold the 200 most recently used entries.

#### Scenario: Same text over ten frames
- **WHEN** the same line text with the same languages is translated in 10 consecutive frames
- **THEN** the translator is called once

#### Scenario: Whitespace differences share a translation
- **WHEN** " Salida  de emergencia" and "Salida de emergencia" are translated with the same languages
- **THEN** the translator is called once

#### Scenario: Least recently used entry is evicted
- **WHEN** 201 different texts are translated, and then the first text again
- **THEN** the translator is called for the first text a second time

### Requirement: Missing models download over Wi-Fi only
Before translating, both the source and target models SHALL be checked. When a model is missing, a download SHALL be started once for that language with Wi-Fi required, a `ModelNotDownloaded` SHALL be reported once for that language, and lines needing it SHALL be returned untranslated until the download completes. Translation SHALL never be attempted while a model is missing.

#### Scenario: Hindi model missing
- **WHEN** Hindi lines are translated to English in three frames and the Hindi model is missing
- **THEN** one Wi-Fi-only download of Hindi is started, one `ModelNotDownloaded(hindi)` is reported, the lines are untranslated, and the translator is never called

#### Scenario: Download completes
- **WHEN** the Hindi download completes and a Hindi line is translated again
- **THEN** the line is translated

#### Scenario: Download fails
- **WHEN** the Hindi download fails
- **THEN** a later Hindi line starts one new download attempt

### Requirement: Unsupported source languages are reported once
A line whose source language can't be translated on-device SHALL be returned untranslated, and an `UnsupportedLanguagePair` SHALL be reported once per source language.

#### Scenario: Language without a translation model
- **WHEN** lines identified as "la-Latn" appear in three frames
- **THEN** they are untranslated and one `UnsupportedLanguagePair` with source "la-Latn" is reported

### Requirement: Translation failures don't stop other lines
If translating one line fails, that line SHALL be returned untranslated, the failure SHALL be reported as a `PipelineFailure`, and the other lines SHALL still be translated.

#### Scenario: One line fails
- **WHEN** translating the first of two lines throws
- **THEN** the second line is still translated and one `PipelineFailure` is reported

### Requirement: Translator lifetime
A translator SHALL be created for a language pair when that pair is first translated, reused for later lines, and closed when translation is disposed.

#### Scenario: One translator per pair
- **WHEN** Spanish and French lines are each translated to English twice
- **THEN** exactly two translators are created, and both are closed on disposal
