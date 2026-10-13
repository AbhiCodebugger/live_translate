# Spec Delta

## MODIFIED Requirements

### Requirement: Source language hint
When the app restricts the possible source languages, a line SHALL only be assigned one of them, as "A single hinted language skips identification" and "Several hinted languages narrow the guesses" describe.

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
- **WHEN** the source languages are restricted to Hindi and Marathi, and identification reports Nepali 0.9, Hindi 0.1 and Marathi 0.05
- **THEN** the line has no source language

## ADDED Requirements

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
