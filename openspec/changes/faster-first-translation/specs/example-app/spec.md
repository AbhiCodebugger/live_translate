# Spec Delta

## MODIFIED Requirements

### Requirement: Detected language on the source chip
While the source is "Detect language", the source chip SHALL show the view's source status, keeping the auto-detect icon: "Looking for text…" while searching, the language's name with a question mark when guessed, the language's name when downloading or ready, "No supported text found" when not found, "<name> can't be translated" when unsupported (the BCP-47 tag when it has no name), and the language's name with "download failed" when a download failed. Tapping the chip SHALL still open the picker with "Detect language" selected.

#### Scenario: Searching
- **WHEN** the source is "Detect language" and the status is searching
- **THEN** the source chip reads "Looking for text…" with the auto-detect icon

#### Scenario: Guessed
- **WHEN** the source is "Detect language" and the status is guessed for Spanish
- **THEN** the source chip reads "Spanish?"

#### Scenario: Downloading
- **WHEN** the source is "Detect language" and the status is downloading for Spanish
- **THEN** the source chip reads "Spanish" and shows a progress indicator

#### Scenario: French page
- **WHEN** the source is "Detect language" and the status is ready for French
- **THEN** the source chip reads "French" with the auto-detect icon

#### Scenario: Mixed languages
- **WHEN** the source is "Detect language", and a read gives three paragraphs Hindi and one English with both models on the device
- **THEN** the source chip reads "Hindi"

#### Scenario: Nothing shown
- **WHEN** the source chip reads "French" and the labels are cleared by a new scene
- **THEN** the source chip reads "Looking for text…"

#### Scenario: Not found
- **WHEN** the source is "Detect language" and the status is not found
- **THEN** the source chip reads "No supported text found"

#### Scenario: Unsupported
- **WHEN** the source is "Detect language" and the status is unsupported with "la"
- **THEN** the source chip reads "Latin can't be translated"

#### Scenario: Download failed
- **WHEN** the source is "Detect language" and the status is download failed for Spanish
- **THEN** the source chip reads "Spanish · download failed"

#### Scenario: Frozen
- **WHEN** the source chip reads "French" and the user freezes the view
- **THEN** the source chip still reads "French"

#### Scenario: Chosen language wins
- **WHEN** the user chooses Spanish as the source while the status is ready for French
- **THEN** the source chip reads "Spanish"

#### Scenario: Picker after detection
- **WHEN** the source chip reads "French" because it was detected, and the user taps it
- **THEN** the picker opens with "Detect language" selected
