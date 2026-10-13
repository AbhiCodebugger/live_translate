# Spec Delta

## ADDED Requirements

### Requirement: Tracks reset when the frame or session changes
All tracks SHALL be discarded when a frame's size or rotation differs from the previous frame's, or when it comes from a new capture session. The frame's lines then start new tracks with new IDs.

#### Scenario: Phone rotated
- **WHEN** a frame arrives at rotation 0° after frames at 90°
- **THEN** every line in it gets a new ID, and no earlier track remains

#### Scenario: Camera restarted
- **WHEN** a frame arrives with a newer capture-session generation, after the app returned from the background
- **THEN** every line in it gets a new ID, and no earlier track remains

## REMOVED Requirements

### Requirement: Tracks reset when the frame changes shape
**Reason**: Frames no longer carry mirroring, and the camera can no longer be switched. Replaced by "Tracks reset when the frame or session changes".
**Migration**: None.
