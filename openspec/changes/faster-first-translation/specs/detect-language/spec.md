# Spec Delta

## MODIFIED Requirements

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
