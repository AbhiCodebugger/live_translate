# Spec Delta

## ADDED Requirements

### Requirement: One language per script in each frame
In each frame, lines containing a Devanagari letter SHALL form one group, and other lines containing a Latin letter another. A line whose own best guess is the target language SHALL keep it and stay out of its group. Each group SHALL get one language: the one with the highest total confidence across its lines, counting only guesses that qualify for a line on their own. Every line in the group with a qualifying guess SHALL be assigned that language.

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

## MODIFIED Requirements

### Requirement: Each line gets a source language
Each line SHALL be assigned the language identified with the highest confidence, as a BCP-47 code, when that confidence is at least 0.5, before the "One language per script in each frame" requirement settles one language for its script. Otherwise the line SHALL have no source language.

#### Scenario: Confident identification
- **WHEN** language identification reports Spanish with confidence 0.9 for "Salida de emergencia"
- **THEN** the line's source language is "es"

#### Scenario: Undetermined language
- **WHEN** language identification can't determine a language for "OK"
- **THEN** the line has no source language

### Requirement: Source language hint
When the app restricts the possible source languages to exactly one language, a line SHALL be assigned that language without running identification, provided the line contains a letter of that language's script, for languages written in Latin or Devanagari. Otherwise the line SHALL have no source language. When the app restricts them to several languages, only guesses for those languages SHALL qualify, at confidence 0.5 or more, and each script's language SHALL be chosen among them as the "One language per script in each frame" requirement describes.

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
