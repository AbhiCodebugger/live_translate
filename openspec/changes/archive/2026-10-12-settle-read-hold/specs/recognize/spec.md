# Spec Delta

## REMOVED Requirements

### Requirement: Selected scripts take turns
**Reason**: Reads are now occasional, so every read uses every selected script instead of one script per frame.
**Migration**: None. See "Every read uses every selected script".

### Requirement: A single frame can be read by every selected script
**Reason**: Reading with every script is now the only mode, so this becomes "Every read uses every selected script".
**Migration**: None.

### Requirement: Recognizer lifetime
**Reason**: Its "second script waits for its turn" behaviour no longer exists; replaced by "Recognizers live from the first read to disposal".
**Migration**: None.

## ADDED Requirements

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
