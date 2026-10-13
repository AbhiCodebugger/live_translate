# Spec Delta

## MODIFIED Requirements

### Requirement: Frames yield text lines with boxes
Recognizing a frame SHALL return one entry per recognized line of text that passes the line filter, holding the line's text, its bounding box in upright frame coordinates, and the paragraph it belongs to. Lines of the same recognized paragraph SHALL share a paragraph identifier, unique within the frame and script, and SHALL be returned in reading order. A frame with no text, or only filtered lines, SHALL return an empty list.

#### Scenario: Frame with two lines
- **WHEN** a frame showing two lines of Latin text is recognized
- **THEN** two entries are returned, each with its text and a box around that line

#### Scenario: Frame with no text
- **WHEN** a frame with no text is recognized
- **THEN** an empty list is returned

#### Scenario: Two paragraphs
- **WHEN** a frame shows a heading and a two-line paragraph, recognized as two blocks
- **THEN** the heading's line has one paragraph identifier and both paragraph lines share another

### Requirement: Overlapping Latin readings are dropped
When Latin and a non-Latin script are both selected, a line read by the Latin recognizer SHALL be dropped if at least half of its box is covered by a line read by a non-Latin recognizer that has at least as many letters of its own script as Latin letters. The Latin recognizer turns non-Latin text into gibberish, while non-Latin recognizers also read Latin characters; a mostly-Latin reading by a non-Latin recognizer SHALL NOT replace the Latin recognizer's line, and SHALL itself be dropped when at least half of its box covers a Latin line. Latin lines that don't overlap are kept.

#### Scenario: Gibberish over a Hindi line
- **WHEN** Latin and Devanagari are selected, the Devanagari turn found "नमस्ते" at (0, 0)–(100, 20), and the Latin turn found "Tea Ho" at (5, 2)–(95, 18)
- **THEN** the result contains "नमस्ते" and not "Tea Ho"

#### Scenario: Separate English line
- **WHEN** Latin and Devanagari are selected, the Devanagari turn found "नमस्ते" at (0, 0)–(100, 20), and the Latin turn found "EXIT" at (0, 50)–(60, 70)
- **THEN** the result contains both lines

#### Scenario: Small overlap
- **WHEN** a Latin line's box is covered less than halfway by a Devanagari line's box
- **THEN** the Latin line is kept

#### Scenario: Latin only
- **WHEN** only Latin is selected
- **THEN** no line is dropped for overlap

#### Scenario: Mostly-Latin misreading over a Latin line
- **WHEN** Latin and Devanagari are selected, the Latin recognizer found "étudiant tous les usages" at (0, 0)–(200, 20), and the Devanagari recognizer read the same place as "étudiant तस les usages"
- **THEN** the result contains "étudiant tous les usages" and not "étudiant तस les usages"

## ADDED Requirements

### Requirement: A single frame can be read by every selected script
Besides taking turns, recognition SHALL be able to read one frame with every selected script, returning the merged lines of all scripts after the same filters as taking turns. Reading this way SHALL NOT change whose turn it is next.

#### Scenario: Both scripts at once
- **WHEN** Latin and Devanagari are selected, and one frame read with every script shows "EXIT" and "निकास"
- **THEN** the result contains both lines

#### Scenario: Turns are unaffected
- **WHEN** Latin and Devanagari are selected, one live frame has been recognized (Latin's turn), and then a frame is read with every script
- **THEN** the next live frame is recognized by Devanagari

### Requirement: Unsure lines are dropped
A recognized line SHALL be dropped when the recognizer reports a confidence below 0.5 for it. A line without a reported confidence (iOS reports none) SHALL be kept.

#### Scenario: Blurry junk on Android
- **WHEN** the recognizer reports the line "Il nv a ras de minitre" with confidence 0.3
- **THEN** it is not returned

#### Scenario: Clear line on Android
- **WHEN** the recognizer reports the line "Pourquoi l'utiliser ?" with confidence 0.9
- **THEN** it is returned

#### Scenario: No confidence on iOS
- **WHEN** the recognizer reports a line without a confidence
- **THEN** it is returned
