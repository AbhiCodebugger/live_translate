# overlay-geometry Specification

## Purpose

Positions text boxes detected in a camera frame correctly in the view. The camera preview fills the view and is cropped, so each translated label must line up with the text it replaces.

## Requirements

### Requirement: Upright frame size follows the rotation
The upright size of a camera frame SHALL be the delivered frame size, with width and height swapped when the frame's rotation is a quarter turn (90° or 270°). For 0° and 180° the size SHALL stay as delivered.

#### Scenario: Quarter turn swaps the dimensions
- **WHEN** a 1280×720 frame has a rotation of 90°
- **THEN** its upright size is 720×1280

#### Scenario: Half turn keeps the dimensions
- **WHEN** a 1280×720 frame has a rotation of 180°
- **THEN** its upright size is 1280×720

### Requirement: Preview fills the view and is cropped
The preview layout SHALL scale the upright frame uniformly by the smallest factor that covers the whole view, and centre it. Any overflow SHALL be cropped equally on both sides of the overflowing axis. The preview and the overlay SHALL both use this one layout.

#### Scenario: Wide frame in a tall view is cropped left and right
- **WHEN** an upright 720×1280 frame is laid out in a 360×800 view
- **THEN** the preview occupies the rectangle from (-45, 0) to (405, 800), at scale 0.625

#### Scenario: Matching aspect ratio needs no crop
- **WHEN** an upright 720×1280 frame is laid out in a 360×640 view
- **THEN** the preview occupies exactly the view, from (0, 0) to (360, 640)

### Requirement: Boxes map with the preview's scale and offset
A box given in upright frame coordinates SHALL map to view coordinates using the same scale and offset as the preview layout, so it covers the same content it covered in the frame. Working out the rotation and making sure boxes are in upright coordinates is the camera layer's job, not this mapping's.

#### Scenario: Back camera in portrait
- **WHEN** the box (100, 200)–(300, 260) is mapped from a 1280×720 frame at 90° into a 360×800 view
- **THEN** the result is (17.5, 125)–(142.5, 162.5)

#### Scenario: Back camera in landscape
- **WHEN** the box (100, 200)–(300, 260) is mapped from a 1280×720 frame at 0° into an 800×360 view
- **THEN** the result is (62.5, 80)–(187.5, 117.5)

#### Scenario: Whole frame maps to the preview rectangle
- **WHEN** the full upright frame is mapped for any rotation and view size
- **THEN** the result equals the preview layout's rectangle, and its centre is the view's centre

### Requirement: Mapped boxes are not clipped
A mapped box SHALL keep its true position even when it falls partly or entirely in the cropped-away part of the preview. Clipping to the view is left to the painter.

#### Scenario: Box in the cropped margin
- **WHEN** the box (0, 0)–(40, 40) is mapped from a 1280×720 frame at 90° into a 360×800 view
- **THEN** the result is (-45, 0)–(-20, 25), partly outside the view

### Requirement: Empty sizes do not fail
When the view size or the frame size has zero width or height, mapping and layout SHALL return an empty rectangle at the origin instead of throwing or producing non-finite values.

#### Scenario: View not laid out yet
- **WHEN** a box is mapped into a 0×0 view
- **THEN** the result is an empty rectangle at (0, 0)

#### Scenario: Empty frame
- **WHEN** a box is mapped from a 0×0 frame
- **THEN** the result is an empty rectangle at (0, 0)

### Requirement: Preview is displayed with the shared layout
The camera preview SHALL be drawn at the fill-and-crop layout's preview rectangle and clipped to the view. Translated labels SHALL be placed with that same layout, so a label covers the preview content it was detected in. Before the first frame arrives, the layout SHALL use the camera's reported preview size.

#### Scenario: Tall view
- **WHEN** an upright 720×1280 frame is shown in a 360×800 view
- **THEN** the preview is drawn from (-45, 0) to (405, 800) and nothing is painted outside the view

#### Scenario: Box lines up with the preview
- **WHEN** a line with box (100, 200)–(300, 260) is recognized and translated in a 1280×720 back-camera frame at 90° in a 360×800 view
- **THEN** its label covers (17.5, 125)–(142.5, 162.5)
