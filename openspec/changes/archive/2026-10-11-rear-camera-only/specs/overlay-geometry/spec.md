# Spec Delta

## MODIFIED Requirements

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

## REMOVED Requirements

### Requirement: Front camera boxes are mirrored
**Reason**: Only the back camera is used, and its preview is never mirrored.
**Migration**: None. Boxes are always mapped without reflection.
