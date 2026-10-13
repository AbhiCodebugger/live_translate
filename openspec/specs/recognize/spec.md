# recognize Specification

## Purpose

Turns a camera frame into lines of text, each with its bounding box in upright frame coordinates. The overlay places and translates these lines.

## Requirements

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

### Requirement: Selected scripts are recognized
Recognition SHALL read Latin-script text and Devanagari-script text, for whichever of these scripts are selected. Latin is selected by default.

#### Scenario: English sign
- **WHEN** a frame of an English sign is recognized with Latin selected
- **THEN** the sign's words appear in the returned lines

#### Scenario: Hindi sign
- **WHEN** a frame of a Hindi sign is recognized with Devanagari selected
- **THEN** the sign's Devanagari words appear in the returned lines

### Requirement: Lines without enough letters are dropped
A recognized line SHALL be dropped when it contains fewer than two letters of the script whose recognizer read it. This removes very short lines, digits-only lines and punctuation-only lines, and readings of another script's text: the Devanagari recognizer also reads Latin characters, badly. Devanagari vowel signs are marks, not letters.

#### Scenario: Digits-only line
- **WHEN** a frame contains the lines "2026" and "Platform 2"
- **THEN** only "Platform 2" is returned

#### Scenario: Single letter
- **WHEN** a frame contains the lines "A" and "No entry"
- **THEN** only "No entry" is returned

#### Scenario: Devanagari word with vowel signs
- **WHEN** a frame contains the line "नमस्ते"
- **THEN** it is returned

#### Scenario: Latin text read by the Devanagari recognizer
- **WHEN** Latin and Devanagari are selected, and the Devanagari turn reads "Elememte chan na" from a French page
- **THEN** that line is not returned

#### Scenario: Stray Devanagari letter
- **WHEN** the Devanagari turn reads "Lorem क ipsum"
- **THEN** that line is not returned

#### Scenario: Mixed Devanagari line
- **WHEN** the Devanagari turn reads "दवा 500mg"
- **THEN** it is returned

#### Scenario: Latin page under both scripts
- **WHEN** Latin and Devanagari are selected, the Latin turn reads "Pourquoi l'utiliser?", and the following Devanagari turn reads "Pourquoi l'utiliscr?" slightly lower
- **THEN** the Devanagari turn's result contains only "Pourquoi l'utiliser?"

### Requirement: Overlapping Latin readings are dropped
When Latin and a non-Latin script are both selected and a Latin recognizer's line overlaps a non-Latin recognizer's line, the reading in the text's own script SHALL be kept and the other dropped, as "A non-Latin reading replaces Latin gibberish under it" and "A mostly-Latin misreading gives way to the Latin line" describe. Latin lines that don't overlap are kept.

#### Scenario: Gibberish over a Hindi line
- **WHEN** Latin and Devanagari are selected, the Devanagari recognizer found "नमस्ते" at (0, 0)–(100, 20), and the Latin recognizer found "Tea Ho" at (5, 2)–(95, 18)
- **THEN** the result contains "नमस्ते" and not "Tea Ho"

#### Scenario: Separate English line
- **WHEN** Latin and Devanagari are selected, the Devanagari recognizer found "नमस्ते" at (0, 0)–(100, 20), and the Latin recognizer found "EXIT" at (0, 50)–(60, 70)
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

### Requirement: Every read uses every selected script
Each read SHALL recognize the frame with every selected script and return the merged lines of all scripts after the line filters.

#### Scenario: Both scripts in one read
- **WHEN** Latin and Devanagari are selected, and one read of a frame shows "EXIT" and "निकास"
- **THEN** the result contains both lines

### Requirement: Recognizers live from the first read to disposal
Each selected script's on-device recognizer SHALL be created on the first read, not before, and every created recognizer SHALL be closed when recognition is disposed. Recognizing after disposal SHALL fail instead of re-creating a recognizer.

#### Scenario: No frames, no recognizer
- **WHEN** recognition is created and disposed without reading any frame
- **THEN** no recognizer was ever created

#### Scenario: Disposal closes the recognizer
- **WHEN** recognition has read frames and is then disposed
- **THEN** each created recognizer is closed exactly once

#### Scenario: Both recognizers on the first read
- **WHEN** Latin and Devanagari are selected and exactly one frame has been read
- **THEN** both recognizers have been created

### Requirement: A non-Latin reading replaces Latin gibberish under it
A line read by the Latin recognizer SHALL be dropped if at least half of its box is covered by a line read by a non-Latin recognizer that has at least as many letters of its own script as Latin letters. The Latin recognizer turns non-Latin text into gibberish.

#### Scenario: Exactly half covered
- **WHEN** Latin and Devanagari are selected, the Devanagari recognizer found "नमस्ते" at (0, 0)–(100, 20), and the Latin recognizer found "Tea Ho" at (50, 0)–(150, 20)
- **THEN** the result contains "नमस्ते" and not "Tea Ho"

#### Scenario: As many Devanagari letters as Latin
- **WHEN** Latin and Devanagari are selected, and at the same place the Devanagari recognizer read "दवा 500mg" and the Latin recognizer read "Tea 500mg"
- **THEN** the result contains "दवा 500mg" and not "Tea 500mg"

### Requirement: A mostly-Latin misreading gives way to the Latin line
A line read by a non-Latin recognizer with fewer letters of its own script than Latin letters SHALL NOT cause a Latin line to be dropped, and SHALL itself be dropped when at least half of its box covers a Latin line. Non-Latin recognizers also read Latin characters, badly.

#### Scenario: Misreading three-quarters over a Latin line
- **WHEN** Latin and Devanagari are selected, the Latin recognizer found "Pourquoi utiliser" at (0, 0)–(200, 20), and the Devanagari recognizer found "Pourquoi कख utiliser" at (0, 5)–(200, 25)
- **THEN** the result contains "Pourquoi utiliser" and not "Pourquoi कख utiliser"
