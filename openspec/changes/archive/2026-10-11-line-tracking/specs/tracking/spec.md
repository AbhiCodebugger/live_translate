# Spec Delta

## Purpose

Follows each line of text from frame to frame so its label keeps a stable identity and position, fades out instead of vanishing, and keeps its translation through small recognition errors.

## ADDED Requirements

### Requirement: Lines keep their identity across frames
A line SHALL be matched to an existing track when their boxes overlap with an intersection-over-union of at least 0.3. Each track SHALL be matched to at most one line per frame, best overlaps first. A matched line SHALL keep the track's ID; an unmatched line SHALL start a new track with a new, unique ID.

#### Scenario: Slightly moved line
- **WHEN** a track has box (0, 0)–(100, 20), and the next frame has a line at (5, 0)–(105, 20)
- **THEN** the line keeps the track's ID (overlap ≈ 0.90)

#### Scenario: New line elsewhere
- **WHEN** the next frame also has a line at (0, 200)–(100, 220), overlapping no track
- **THEN** that line gets a new ID, different from every existing track's

#### Scenario: One line per track
- **WHEN** two lines in a frame both overlap the same single track
- **THEN** only the better-overlapping line keeps that track's ID, and the other starts a new track

### Requirement: Text similarity breaks near-ties
When a line overlaps several tracks almost equally, with overlaps within 0.1 of each other, it SHALL be matched to the track whose text is most similar. Text similarity is 1 minus the edit distance divided by the longer text's length, after trimming, collapsing whitespace and lowercasing.

#### Scenario: Two neighbouring lines
- **WHEN** tracks "Platform 1" at (0, 0)–(100, 20) and "Platform 2" at (0, 10)–(100, 30) exist, and a line "Platform 2" appears at (0, 5)–(100, 25), overlapping both by 0.6
- **THEN** it keeps the ID of the "Platform 2" track

### Requirement: Positions are smoothed
A matched track's box SHALL move halfway from its previous box towards the new line's box (an exponential moving average with factor 0.5). A new track SHALL start at its line's box.

#### Scenario: Line moves 10 pixels
- **WHEN** a track at (0, 0)–(100, 20) is matched by a line at (10, 0)–(110, 20)
- **THEN** the track's box becomes (5, 0)–(105, 20)

### Requirement: Lost lines fade out
A track with no matching line SHALL keep its ID and last box, and its opacity SHALL fall to 2/3 after one missed frame and 1/3 after two, and it SHALL be removed after three. A track that is matched again SHALL return to full opacity with the same ID.

#### Scenario: Missing for two frames
- **WHEN** a track goes unmatched in two consecutive frames
- **THEN** it still has its ID, and its opacity is 1/3

#### Scenario: Gone for three frames
- **WHEN** a track goes unmatched in three consecutive frames
- **THEN** it is removed

#### Scenario: Seen again
- **WHEN** a track unmatched for one frame is matched in the next
- **THEN** its opacity is 1 and its ID is unchanged

### Requirement: A tracked line keeps its translation
A track SHALL keep its source text and translation while the matched line's text stays similar (similarity 0.8 or more), even if that frame brings a different translation or none. When the text changes meaningfully (similarity below 0.8), the track SHALL take the new text and the new translation, or no translation if there is none. A track without a translation SHALL take the first translation a matched line brings.

#### Scenario: Recognition error
- **WHEN** a track reads "निकास", translated "Exit", and the next frame reads "निकाश" (similarity 0.8) with no translation
- **THEN** the track still shows "Exit"

#### Scenario: Different translation for similar text
- **WHEN** a track reads "निकास", translated "Exit", and the next frame reads "निकास " translated "Way out"
- **THEN** the track still shows "Exit"

#### Scenario: Text really changed
- **WHEN** a track reads "निकास", translated "Exit", and the next frame reads "प्रवेश", translated "Entrance", at the same position
- **THEN** the track shows "Entrance"

#### Scenario: Translation arrives later
- **WHEN** a track has no translation, and a matched line brings the translation "Exit"
- **THEN** the track shows "Exit"

### Requirement: Tracks reset when the frame changes shape
All tracks SHALL be discarded when a frame's size, rotation or mirroring differs from the previous frame's, or when it comes from a new capture session. The frame's lines then start new tracks with new IDs.

#### Scenario: Phone rotated
- **WHEN** a frame arrives at rotation 0° after frames at 90°
- **THEN** every line in it gets a new ID, and no earlier track remains

#### Scenario: Camera switched
- **WHEN** a frame arrives with a newer capture-session generation
- **THEN** every line in it gets a new ID, and no earlier track remains
