# Spec Delta

## Purpose

Positions text boxes detected in a camera frame correctly in the view. The camera preview fills the view and is cropped, and is mirrored for the front camera, so each translated label must line up with the text it replaces.

## ADDED Requirements

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
- **WHEN** the box (100, 200)–(300, 260) is mapped from a 1280×720 frame at 90° into a 360×800 view without mirroring
- **THEN** the result is (17.5, 125)–(142.5, 162.5)

#### Scenario: Back camera in landscape
- **WHEN** the box (100, 200)–(300, 260) is mapped from a 1280×720 frame at 0° into an 800×360 view without mirroring
- **THEN** the result is (62.5, 80)–(187.5, 117.5)

#### Scenario: Whole frame maps to the preview rectangle
- **WHEN** the full upright frame is mapped for any rotation, view size and mirroring
- **THEN** the result equals the preview layout's rectangle, and its centre is the view's centre

### Requirement: Front camera boxes are mirrored
When mirroring is requested (front camera), a mapped box SHALL be reflected across the view's vertical centre line after scaling, and remain a normalized rectangle (left ≤ right).

#### Scenario: Front camera at 270°
- **WHEN** the box (100, 200)–(300, 260) is mapped from a 1280×720 frame at 270° into a 360×800 view with mirroring
- **THEN** the result is (217.5, 125)–(342.5, 162.5)

#### Scenario: Centred box is unaffected by mirroring
- **WHEN** a box centred horizontally in the upright frame is mapped with and without mirroring
- **THEN** both results are equal

### Requirement: Mapped boxes are not clipped
A mapped box SHALL keep its true position even when it falls partly or entirely in the cropped-away part of the preview. Clipping to the view is left to the painter.

#### Scenario: Box in the cropped margin
- **WHEN** the box (0, 0)–(40, 40) is mapped from a 1280×720 frame at 90° into a 360×800 view without mirroring
- **THEN** the result is (-45, 0)–(-20, 25), partly outside the view

### Requirement: Empty sizes do not fail
When the view size or the frame size has zero width or height, mapping and layout SHALL return an empty rectangle at the origin instead of throwing or producing non-finite values.

#### Scenario: View not laid out yet
- **WHEN** a box is mapped into a 0×0 view
- **THEN** the result is an empty rectangle at (0, 0)

#### Scenario: Empty frame
- **WHEN** a box is mapped from a 0×0 frame
- **THEN** the result is an empty rectangle at (0, 0)
