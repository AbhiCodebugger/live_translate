# Proposal

## Why

ML Kit reports each text box in the upright camera image. The overlay draws in the view, where the preview is scaled, cropped to fill the view, and mirrored for the front camera. If the two don't agree, every translated label lands in the wrong place. This is the first of the plan's "three hard problems". It's pure maths, so it can be specified and tested exhaustively before any camera code exists. Week 1's on-device exit check then builds on a mapper that is already proven.

## What Changes

- Add a pure-Dart geometry layer under `lib/src/geometry/`. It maps a box from upright image coordinates to view coordinates for a preview that fills the view and is cropped, with optional horizontal mirroring for the front camera.
- Expose the same fill-and-crop layout as a reusable calculation, so the preview widget in the next change (`camera-capture`) sizes the preview with exactly the rule the mapper assumes.
- Add a package-internal rotation type, so the geometry layer doesn't depend on ML Kit types. ML Kit's rotation is converted at the camera boundary in `camera-capture`.
- Add exhaustive unit tests: 4 rotations × mirrored/not × portrait/landscape views × tall/wide screens, plus hand-computed examples, reaching ≥ 90% line coverage on `lib/src/geometry/`.
- Nothing is exported from the public library. The public API (`public-api` spec) doesn't change.

## Capabilities

### New Capabilities
- `overlay-geometry`: How a text box detected in a camera frame is positioned in the view: the fill-and-crop rule shared with the preview, rotation, front-camera mirroring, and behaviour for degenerate sizes.

### Modified Capabilities
<!-- None. public-api is unchanged: the geometry layer is internal. -->

## Impact

- **Code:** new `lib/src/geometry/coordinate_mapper.dart` and `lib/src/geometry/image_rotation.dart`, plus `test/geometry/` tests. No changes to existing files.
- **Dependencies:** none added. The geometry layer imports only `dart:math` and `dart:ui`.
- **Next change:** `camera-capture` depends on this. It converts ML Kit's rotation to the internal type, renders the preview with the shared fill-and-crop layout, and checks on both phones that the boxes stay on the text.
- **Out of scope:** the camera, frame conversion, working out the rotation per platform, painting, and recognition. All of these belong to `camera-capture`.
