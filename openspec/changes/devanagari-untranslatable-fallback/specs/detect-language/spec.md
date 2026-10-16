# Spec Delta

## ADDED Requirements

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

## MODIFIED Requirements

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
