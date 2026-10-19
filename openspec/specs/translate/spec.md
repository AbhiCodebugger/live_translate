# translate Specification

## Purpose

Translates each recognized line into the target language on-device. It reuses earlier translations, downloads the models it needs on its own (the target at once, a detected language once confirmed), and reports each problem once rather than on every frame.

## Requirements

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

### Requirement: Unsupported source languages are reported once
A line whose source language can't be translated on-device SHALL be returned untranslated. An `UnsupportedLanguagePair` SHALL be reported once per source language, and only once that language is confirmed.

#### Scenario: Language without a translation model
- **WHEN** lines identified as "la-Latn" with confidence 0.9 appear in three frames
- **THEN** they are untranslated and one `UnsupportedLanguagePair` with source "la-Latn" is reported

#### Scenario: Stray unsupported tag
- **WHEN** a line is identified as "hi-Latn" with confidence 0.9 in one frame only
- **THEN** nothing is reported

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

### Requirement: Models downloaded by the app are noticed
A model found missing SHALL be checked again at most once every 10 frames, so a model the app downloads, for example through `TranslationModels`, is used without restarting translation.

#### Scenario: App downloads the model
- **WHEN** the Swahili model is missing, then the app downloads it, and Swahili lines keep arriving
- **THEN** within 10 frames the Swahili lines are translated

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

### Requirement: Automatic downloads use any network and are reported once each
Every automatic model download SHALL be requested without requiring Wi-Fi, and a `ModelNotDownloaded` SHALL be reported once for each download started, including each retry after a failed download.

#### Scenario: Download on mobile data
- **WHEN** an automatic download of the English model starts
- **THEN** it is requested without requiring Wi-Fi, and one `ModelNotDownloaded(english)` is reported

#### Scenario: Retry is reported again
- **WHEN** the source languages are restricted to Hindi, the Hindi download fails, and a later confirmed Hindi frame starts a new download
- **THEN** a second `ModelNotDownloaded(hindi)` is reported for the retry

### Requirement: A long paragraph confirms its language at once
A language identified with confidence 0.8 or more for a text of at least 20 letters SHALL count as confirmed immediately, in addition to the rule that confirms a language seen in 3 of the last 10 reads. A confirmed language's missing model SHALL then be downloaded under the usual rules.

#### Scenario: One read of a French page
- **WHEN** no source languages are given, the French model is missing, and one read identifies a 120-letter paragraph as French with confidence 0.95
- **THEN** a download of French starts after that read

#### Scenario: Short text still needs repeats
- **WHEN** a 9-letter line is identified as Swahili with confidence 0.9 in one read
- **THEN** no download starts

### Requirement: Automatic downloads finish on iOS
On iOS, an automatic model download SHALL count as finished once its model is on the device, even though the platform never reports the end of the download and may report it as cancelled. It SHALL then be treated exactly like a completed download on Android: the source status moves on, and the held picture is read again. A download whose model doesn't arrive within 5 minutes SHALL count as failed and be retried as any failed download is.

#### Scenario: Model arrives while the view checks other models
- **WHEN** on iOS, the Hindi source model is downloading, the view checks models while it downloads, the platform reports the download as cancelled, and the Hindi model is on the device 10 seconds later
- **THEN** the source status becomes ready with Hindi, and the held picture's Hindi paragraphs are translated without moving the camera

#### Scenario: Target model arrives
- **WHEN** on iOS, the view starts with a target whose model is missing, and the model is on the device 20 seconds later
- **THEN** the target download counts as finished, and paragraphs waiting for it are translated

#### Scenario: Model never arrives
- **WHEN** on iOS, the Hindi model still isn't on the device 5 minutes after its automatic download started
- **THEN** the source status becomes download failed with Hindi, and a later confirmed Hindi read starts a new download
