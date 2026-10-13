# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Latin script is recognized`
- TO: `### Requirement: Selected scripts are recognized`

## MODIFIED Requirements

### Requirement: Frames yield text lines with boxes
Recognizing a frame SHALL return one entry per recognized line of text that passes the line filter, holding the line's text and its bounding box in upright frame coordinates. A frame with no text, or only filtered lines, SHALL return an empty list.

#### Scenario: Frame with two lines
- **WHEN** a frame showing two lines of Latin text is recognized
- **THEN** two entries are returned, each with its text and a box around that line

#### Scenario: Frame with no text
- **WHEN** a frame with no text is recognized
- **THEN** an empty list is returned

### Requirement: Selected scripts are recognized
Recognition SHALL read Latin-script text and Devanagari-script text, for whichever of these scripts are selected. Latin is selected by default.

#### Scenario: English sign
- **WHEN** a frame of an English sign is recognized with Latin selected
- **THEN** the sign's words appear in the returned lines

#### Scenario: Hindi sign
- **WHEN** a frame of a Hindi sign is recognized with Devanagari selected
- **THEN** the sign's Devanagari words appear in the returned lines

### Requirement: Recognizer lifetime
Each selected script's on-device recognizer SHALL be created when that script first recognizes a frame, not before, and every created recognizer SHALL be closed when recognition is disposed. Recognizing after disposal SHALL fail instead of re-creating a recognizer.

#### Scenario: No frames, no recognizer
- **WHEN** recognition is created and disposed without recognizing any frame
- **THEN** no recognizer was ever created

#### Scenario: Disposal closes the recognizer
- **WHEN** recognition has processed frames and is then disposed
- **THEN** each created recognizer is closed exactly once

#### Scenario: Second script waits for its turn
- **WHEN** Latin and Devanagari are selected and exactly one frame has been recognized
- **THEN** only the Latin recognizer has been created

## ADDED Requirements

### Requirement: Selected scripts take turns
When more than one script is selected, consecutive frames SHALL be recognized by each selected script in turn, in the order Latin then Devanagari. Each result SHALL contain the latest lines found by every selected script, so one script's lines do not disappear while another script takes its turn.

#### Scenario: Recognizers alternate
- **WHEN** Latin and Devanagari are selected and four frames are recognized
- **THEN** the scripts used are Latin, Devanagari, Latin, Devanagari

#### Scenario: Both scripts' lines are kept
- **WHEN** the Latin turn found "EXIT" and the following Devanagari turn found "निकास"
- **THEN** the Devanagari turn's result contains both "EXIT" and "निकास"

#### Scenario: A script's lines are replaced on its next turn
- **WHEN** the Latin turn found "EXIT" and Latin's next turn finds no text
- **THEN** that result no longer contains "EXIT"

### Requirement: Lines without enough letters are dropped
A recognized line SHALL be dropped when it contains fewer than two letters in any script. This removes very short lines, digits-only lines and punctuation-only lines.

#### Scenario: Digits-only line
- **WHEN** a frame contains the lines "2026" and "Platform 2"
- **THEN** only "Platform 2" is returned

#### Scenario: Single letter
- **WHEN** a frame contains the lines "A" and "No entry"
- **THEN** only "No entry" is returned

#### Scenario: Devanagari word with vowel signs
- **WHEN** a frame contains the line "नमस्ते"
- **THEN** it is returned
