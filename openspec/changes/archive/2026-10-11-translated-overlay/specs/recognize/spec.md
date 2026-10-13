# Spec Delta

## ADDED Requirements

### Requirement: Overlapping Latin readings are dropped
When Latin and a non-Latin script are both selected, a line read by the Latin recognizer SHALL be dropped if at least half of its box is covered by a line read by a non-Latin recognizer. The Latin recognizer turns non-Latin text into gibberish, while non-Latin recognizers also read Latin characters. Latin lines that don't overlap are kept.

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
