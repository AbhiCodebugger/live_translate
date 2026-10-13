# Spec Delta

## MODIFIED Requirements

### Requirement: Source language hint
When the app restricts the possible source languages to exactly one language, a line SHALL be assigned that language without running identification, provided the line contains a letter of that language's script, for languages written in Latin or Devanagari. Otherwise the line SHALL have no source language. When the app restricts them to several languages, a line SHALL be assigned the most likely of those languages, at confidence 0.5 or more, or no source language if none qualifies.

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
