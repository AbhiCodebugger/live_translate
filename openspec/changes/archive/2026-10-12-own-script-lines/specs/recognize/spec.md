# Spec Delta

## MODIFIED Requirements

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
