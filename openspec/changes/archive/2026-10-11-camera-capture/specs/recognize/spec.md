# Spec Delta

## Purpose

Turns a camera frame into lines of text, each with its bounding box in upright frame coordinates. The overlay places and translates these lines.

## ADDED Requirements

### Requirement: Frames yield text lines with boxes
Recognizing a frame SHALL return one entry per recognized line of text, holding the line's text and its bounding box in upright frame coordinates. A frame with no text SHALL return an empty list.

#### Scenario: Frame with two lines
- **WHEN** a frame showing two lines of Latin text is recognized
- **THEN** two entries are returned, each with its text and a box around that line

#### Scenario: Frame with no text
- **WHEN** a frame with no text is recognized
- **THEN** an empty list is returned

### Requirement: Latin script is recognized
Recognition SHALL read Latin-script text. Other scripts are added by later changes.

#### Scenario: English sign
- **WHEN** a frame of an English sign is recognized
- **THEN** the sign's words appear in the returned lines

### Requirement: Recognizer lifetime
The on-device recognizer SHALL be created when the first frame is recognized, not before, and SHALL be closed when recognition is disposed. Recognizing after disposal SHALL fail instead of re-creating the recognizer.

#### Scenario: No frames, no recognizer
- **WHEN** recognition is created and disposed without recognizing any frame
- **THEN** no recognizer was ever created

#### Scenario: Disposal closes the recognizer
- **WHEN** recognition has processed frames and is then disposed
- **THEN** its recognizer is closed exactly once
