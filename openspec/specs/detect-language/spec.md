# detect-language Specification

## Purpose

Decides which language each recognized line is written in, so it can be translated from the right source language, or skipped when it is already in the target language or the language can't be determined.

## Requirements

### Requirement: Each line gets a source language
Each line SHALL be assigned the language identified with the highest confidence, as a BCP-47 code, when that confidence is at least 0.5, before the "One language per script in each frame" requirement settles one language for its script. A Devanagari line whose only such languages can't be translated on-device SHALL fall back as "Untranslatable Devanagari guesses fall back to Hindi or Marathi" describes. Otherwise the line SHALL have no source language.

#### Scenario: Confident identification
- **WHEN** language identification reports Spanish with confidence 0.9 for "Salida de emergencia"
- **THEN** the line's source language is "es"

#### Scenario: Undetermined language
- **WHEN** language identification can't determine a language for "OK"
- **THEN** the line has no source language

### Requirement: Source language hint
When the app restricts the possible source languages, a line SHALL only be assigned one of them, as "A single hinted language skips identification", "Several hinted languages narrow the guesses" and "The fallback keeps to the expected languages" describe.

#### Scenario: Single hinted language
- **WHEN** the source languages are restricted to Hindi and a line reads "नमस्ते"
- **THEN** the line is assigned "hi" and language identification is not run

#### Scenario: Line in another script under a single hint
- **WHEN** the source languages are restricted to Hindi and a line reads "en.wikipedia.org/wiki"
- **THEN** the line has no source language, is not translated, and language identification is not run

#### Scenario: Mixed-script line under a single hint
- **WHEN** the source languages are restricted to Hindi and a line reads "दवा 500mg"
- **THEN** the line is assigned "hi"

#### Scenario: Language in a script the package doesn't read
- **WHEN** the source languages are restricted to Arabic and a line reads "Exit"
- **THEN** the line is assigned "ar"

#### Scenario: Hint narrows the candidates
- **WHEN** the source languages are restricted to Hindi and Marathi, and identification reports Nepali 0.6, Marathi 0.3 and Hindi 0.55
- **THEN** the line is assigned "hi"

#### Scenario: No hinted language qualifies
- **WHEN** the source languages are restricted to Hindi and Marathi, a line reads "सावधान! आगे गहरा पानी है", and identification reports Nepali 0.9, Hindi 0.1 and Marathi 0.05
- **THEN** the line falls back to "hi"

### Requirement: Lines already in the target language are dropped
A line whose source language is the target language SHALL be dropped and SHALL NOT be translated.

#### Scenario: English line with English target
- **WHEN** the target language is English and a line is identified as English
- **THEN** the line is dropped and the translator is not called

### Requirement: Identifier lifetime
The language identifier SHALL be created on first use and closed when language detection is disposed. Detecting after disposal SHALL fail.

#### Scenario: Disposal closes the identifier
- **WHEN** language detection has identified lines and is then disposed
- **THEN** its identifier is closed exactly once

### Requirement: One language per script in each frame
In each frame, lines containing a Devanagari letter SHALL form one group, and other lines containing a Latin letter another. A line whose own best guess is the target language SHALL keep it and stay out of its group. Each group SHALL get one language: the one with the highest total confidence across its lines, counting only guesses that qualify for a line on their own and, when any line of the group has a qualifying guess for a language with an on-device translation model, only such languages. Every line in the group with a qualifying guess for that language SHALL be assigned it; a line whose qualifying guesses are all for languages without a model SHALL keep its own best guess.

#### Scenario: Stray Marathi guess among Hindi lines
- **WHEN** a frame has three Devanagari lines identified as Hindi 0.9, Hindi 0.85 and Marathi 0.9
- **THEN** all three lines are assigned "hi"

#### Scenario: Line without a qualifying guess
- **WHEN** a frame has two Latin lines, "Salida" identified as Spanish 0.9 and "OK" undetermined
- **THEN** "Salida" is assigned "es" and "OK" has no source language

#### Scenario: Target-language line among other Latin lines
- **WHEN** the target is English and a frame has "Salida" identified as Spanish 0.9, "Entrada" as Spanish 0.8 and "Exit" as English 0.95
- **THEN** "Salida" and "Entrada" are assigned "es", and "Exit" is dropped as already in the target language

#### Scenario: Scripts are decided separately
- **WHEN** a frame has a Devanagari line identified as Hindi 0.9 and a Latin line identified as Spanish 0.9
- **THEN** the Devanagari line is assigned "hi" and the Latin line "es"

#### Scenario: Lorem ipsum beside a Spanish heading
- **WHEN** a frame has one Latin paragraph identified as Spanish 0.9 and four identified as "la" 0.8
- **THEN** the Spanish paragraph is assigned "es" and the four others keep "la"

#### Scenario: Only untranslatable guesses
- **WHEN** a frame has three Latin paragraphs, all identified as "la" 0.9
- **THEN** all three are assigned "la"

### Requirement: A single hinted language skips identification
When the app restricts the possible source languages to exactly one language, a line SHALL be assigned that language without running identification, provided the line contains a letter of that language's script, for languages written in Latin or Devanagari. Otherwise the line SHALL have no source language.

#### Scenario: Spanish hint on a Latin line
- **WHEN** the source languages are restricted to Spanish and a line reads "Salida"
- **THEN** the line is assigned "es" and language identification is not run

#### Scenario: Devanagari line under a Spanish hint
- **WHEN** the source languages are restricted to Spanish and a line reads "नमस्ते"
- **THEN** the line has no source language and language identification is not run

### Requirement: Several hinted languages narrow the guesses
When the app restricts the possible source languages to several languages, only identification guesses for those languages SHALL qualify, at confidence 0.5 or more, and each script's language SHALL be chosen among them as "One language per script in each frame" describes.

#### Scenario: Unlisted language ignored
- **WHEN** the source languages are restricted to Spanish and French, and identification reports Italian 0.9 and Spanish 0.6
- **THEN** the line is assigned "es"

#### Scenario: Hinted guess below 0.5
- **WHEN** the source languages are restricted to Hindi and Marathi, and identification reports only Marathi 0.4
- **THEN** the line has no source language

### Requirement: Untranslatable Devanagari guesses fall back to Hindi or Marathi
When a line contains a Devanagari letter, no language with an on-device translation model qualifies for it, and identification reports a language without such a model at confidence 0.5 or more, the line SHALL instead get one guess at that guess's confidence: whichever of Hindi and Marathi identification ranks higher, or Hindi when it reports neither. The guess SHALL then vote like any qualifying guess. Lines without a Devanagari letter SHALL NOT fall back.

#### Scenario: Hindi sign identified as Nepali
- **WHEN** a line reads "सावधान! आगे गहरा पानी है" and identification reports Nepali 0.7 and Hindi 0.2
- **THEN** the line is assigned "hi" and translated from Hindi

#### Scenario: Marathi ranked above Hindi
- **WHEN** a line reads "कृपया येथे वाहन उभे करू नये" and identification reports Nepali 0.6, Marathi 0.3 and Hindi 0.1
- **THEN** the line is assigned "mr"

#### Scenario: Neither Hindi nor Marathi reported
- **WHEN** a Devanagari line is identified only as Nepali 0.9
- **THEN** the line is assigned "hi"

#### Scenario: The fallback can confirm its language
- **WHEN** a Devanagari line of 20 letters or more is identified as Nepali 0.9 and Hindi 0.05, and the Hindi model is not on the device
- **THEN** Hindi is confirmed and its model starts downloading

#### Scenario: Translatable guess already qualifies
- **WHEN** a Devanagari line is identified as Nepali 0.6 and Hindi 0.55
- **THEN** the line is assigned "hi" with confidence 0.55, as without the fallback

#### Scenario: Latin lines don't fall back
- **WHEN** a frame has three Latin paragraphs, all identified as "la" 0.9
- **THEN** all three are assigned "la"

#### Scenario: Undetermined Devanagari line
- **WHEN** a Devanagari line has no guess at 0.5 or more for any language
- **THEN** the line has no source language

### Requirement: The fallback keeps to the expected languages
When the app expects several source languages, the fallback SHALL choose only among the expected ones of Hindi and Marathi, and there SHALL be no fallback when neither is expected.

#### Scenario: Expected languages without Devanagari
- **WHEN** the source languages are restricted to Spanish and French, and a Devanagari line is identified as Nepali 0.9
- **THEN** the line has no source language

#### Scenario: Only Marathi expected
- **WHEN** the source languages are restricted to Marathi and Spanish, and a Devanagari line is identified as Nepali 0.9 and Hindi 0.3
- **THEN** the line is assigned "mr"
