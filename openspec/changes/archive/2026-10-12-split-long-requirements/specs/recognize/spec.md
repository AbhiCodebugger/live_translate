# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

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
