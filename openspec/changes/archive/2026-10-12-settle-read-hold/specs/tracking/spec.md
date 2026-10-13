# Spec Delta

## REMOVED Requirements

### Requirement: Lines keep their identity across frames
**Reason**: Live labels are no longer rebuilt from every frame, so lines no longer need matching across frames. A read's paragraphs are held and shifted as a whole (`live-translation`).
**Migration**: None. The tracker was internal. `TranslatedLine.id` is still unique within the shown result.

### Requirement: Text similarity breaks near-ties
**Reason**: Part of line matching across frames, which is removed.
**Migration**: None.

### Requirement: Positions are smoothed
**Reason**: Held labels move by the measured picture shift instead of smoothing re-read positions.
**Migration**: None. See "Held labels follow small movements" in `live-translation`.

### Requirement: Lost lines fade out
**Reason**: Lines are no longer lost frame to frame. Labels fade only when the scene changes.
**Migration**: None. See "Fast movement or a new scene clears the labels" in `live-translation`.

### Requirement: A tracked line keeps its translation
**Reason**: A held result keeps its translations until the next read replaces it whole.
**Migration**: None.

### Requirement: Tracks reset when the frame or session changes
**Reason**: There are no tracks. A new capture session discards the held result through the read rules in `live-translation`.
**Migration**: None.
