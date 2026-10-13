# Spec Delta

## Purpose

Decides which language each recognized line is written in, so it can be translated from the right source language, or skipped when it is already in the target language or the language can't be determined.

## ADDED Requirements

### Requirement: Each line gets a source language
Each line SHALL be assigned the language identified with the highest confidence, as a BCP-47 code, when that confidence is at least 0.5. Otherwise the line SHALL have no source language.

#### Scenario: Confident identification
- **WHEN** language identification reports Spanish with confidence 0.9 for "Salida de emergencia"
- **THEN** the line's source language is "es"

#### Scenario: Undetermined language
- **WHEN** language identification can't determine a language for "OK"
- **THEN** the line has no source language

### Requirement: Source language hint
When the app restricts the possible source languages to exactly one language, every line SHALL be assigned that language without running identification. When it restricts them to several languages, a line SHALL be assigned the most likely of those languages, at confidence 0.5 or more, or no source language if none qualifies.

#### Scenario: Single hinted language
- **WHEN** the source languages are restricted to Hindi
- **THEN** every line is assigned "hi" and language identification is not run

#### Scenario: Hint narrows the candidates
- **WHEN** the source languages are restricted to Hindi and Marathi, and identification reports Nepali 0.6, Marathi 0.3 and Hindi 0.55
- **THEN** the line is assigned "hi"

#### Scenario: No hinted language qualifies
- **WHEN** the source languages are restricted to Hindi and Marathi, and identification reports Nepali 0.9, Hindi 0.1 and Marathi 0.05
- **THEN** the line has no source language

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
