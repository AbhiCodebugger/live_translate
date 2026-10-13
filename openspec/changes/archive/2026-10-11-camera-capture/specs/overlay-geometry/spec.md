# Spec Delta

## ADDED Requirements

### Requirement: Preview is displayed with the shared layout
The camera preview SHALL be drawn at the fill-and-crop layout's preview rectangle and clipped to the view. Overlay boxes SHALL be drawn with that same layout, so a box lines up with the preview content it was detected in. Before the first frame arrives, the layout SHALL use the camera's reported preview size.

#### Scenario: Tall view
- **WHEN** an upright 720×1280 frame is shown in a 360×800 view
- **THEN** the preview is drawn from (-45, 0) to (405, 800) and nothing is painted outside the view

#### Scenario: Box lines up with the preview
- **WHEN** a line with box (100, 200)–(300, 260) is recognized in a 1280×720 back-camera frame at 90° in a 360×800 view
- **THEN** its debug rectangle is drawn at (17.5, 125)–(142.5, 162.5)
