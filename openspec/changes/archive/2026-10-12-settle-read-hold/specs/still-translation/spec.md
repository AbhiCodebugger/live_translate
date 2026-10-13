# Spec Delta

## MODIFIED Requirements

### Requirement: Freezing reads the frozen frame once
When the view freezes while a result is held and the picture has moved by less than 2% of the frame's width and height since the frame that was read, it SHALL keep showing that result, moved by that shift, without reading. Otherwise it SHALL read the last frame it received before pausing, once, and show that frame's result. Results from reads started before freezing SHALL be ignored unless they are being kept as above.

#### Scenario: Freezing a held view
- **WHEN** a result is held, the picture has moved by 1% since its read, and the user freezes
- **THEN** the same labels stay, nothing is read, and no progress indicator shows

#### Scenario: Freezing while moving
- **WHEN** no result is held because the camera was moving, and the user freezes
- **THEN** the last frame is read once and its result is shown

#### Scenario: Freezing after a pan
- **WHEN** a result is held but the picture has moved by 12% since its read, and the user freezes
- **THEN** the last frame is read once and its result replaces the held labels

#### Scenario: Ghosts are gone
- **WHEN** labels are fading out after a new scene and the user freezes
- **THEN** the result shown is only what the frozen frame's read found, fully opaque

#### Scenario: No frame yet
- **WHEN** the view freezes before any frame has been received
- **THEN** no labels are shown and the view stays frozen without error
