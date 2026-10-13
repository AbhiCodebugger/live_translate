# Design

## Context

See proposal.md for the motivation. This is the first of the two Week 1 changes. `camera-capture` follows and depends on it. The package currently has `lib/src/models/`, `lib/src/errors.dart` and `lib/src/engines/mlkit/script_mapping.dart`. Nothing under `geometry/` exists yet.

The plan (§8, Week 1) sketches `mapToView(box, imageSize:, rotation: InputImageRotation, viewSize:, mirror:)`. The arithmetic in that sketch is right: swap the size for quarter turns, scale to cover the view, centre it, and mirror after scaling. This design keeps that arithmetic and changes how it is packaged (D1, D2).

Decided while exploring Week 1:
- The debug view lives inside the package.
- `TextEngine` is pulled forward into `camera-capture`.
- The preview fills the view and is cropped, using the same rule as the mapper.
- Week 1 is split into two changes.

## Goals / Non-Goals

**Goals:**
- One source of truth for the fill-and-crop layout, used by both the mapper and, in the next change, the preview widget.
- Pure, synchronous and allocation-light: no I/O and no platform checks, so it can be called for every box on every processed frame.
- Exhaustive tests that pin every scenario in the spec, plus invariants over the full combination of rotations, mirroring, orientations and screen shapes.

**Non-Goals:**
- Working out the rotation from the sensor and device orientation, or any Android/iOS differences. Those belong to `camera-capture` (see D5).
- Rotated or skewed boxes. ML Kit's corner points are ignored, and boxes are axis-aligned rectangles (rotated boxes are planned for 1.1+).
- Mapping from the view back to the image (nothing in the plan needs it).
- Clipping to the view. The painter does that (spec: "Mapped boxes are not clipped").

## Decisions

**D1. An internal `ImageRotation` enum instead of ML Kit's `InputImageRotation`.** It has the values `deg0`, `deg90`, `deg180` and `deg270`, plus `bool get isQuarterTurn` and `Size upright(Size delivered)`. The plan's §5 says the pure-logic layer depends on nothing. Taking `InputImageRotation` would tie `geometry/` to `google_mlkit_commons` and its tests to an ML Kit import. `camera-capture` adds the one-line conversion at the camera boundary. *Alternative:* use `InputImageRotation` as the plan's sketch does. Rejected because it breaks the layering rule for no gain. *Alternative:* a plain `int` for degrees. Rejected because an `int` allows invalid values such as 45.

**D2. A `CoverLayout` value object plus a `CoordinateMapper` class, instead of one top-level function.**
- `CoverLayout.fit({required Size uprightSize, required Size viewSize})` is an `@immutable final class` holding `scale`, `offset` and `previewRect`.
- `CoordinateMapper({required Size imageSize, required ImageRotation rotation, required Size viewSize, required bool mirror})` computes its layout once in the constructor and exposes `CoverLayout get layout` and `Rect mapToView(Rect box)`.

A frame carries many boxes but has one layout, so computing the layout once per frame avoids repeating the same scale and offset maths for every box. Exposing `layout` is how the preview widget in `camera-capture` sizes the preview with exactly the rule the mapper uses, which is the spec's "single layout" requirement. *Alternative:* the plan's free function `mapToView(...)`. Rejected because it recomputes the layout for every box and doesn't give the preview widget anything to share.

**D3. Empty sizes short-circuit.** If either size is empty (`Size.isEmpty`), `CoverLayout.fit` returns scale 0 with `previewRect == Rect.zero`, and `mapToView` returns `Rect.zero`. This happens in practice: the first layout pass can report a 0×0 view, and a dropped camera frame can report 0×0. Throwing or producing `NaN` or `Infinity` there would crash the overlay or poison smoothing later on.

**D4. Mirroring reflects across the view's vertical centre, after scaling.** This is the plan's approach. Because the preview is centred, this is the same as reflecting across the preview's centre, so mirroring never changes the crop. The result is rebuilt with `Rect.fromLTRB` from the swapped edges, so it is always normalized.

**D5. Platform differences stay out of the mapper.** I had suggested a test scenario for each platform in this spec. The spec instead fixes the mapper's input as boxes in upright frame coordinates, which ML Kit documents as its output when it is given the frame's rotation. Android and iOS differ in how that rotation is *computed*: from the sensor orientation plus the device orientation on Android, mostly the sensor orientation on iOS. That is `camera-capture`'s job, and its on-device exit check is where a platform mismatch would show up. If iOS turns out to report boxes differently, the fix goes into the camera layer's conversion, and the mapper stays a pure function with no platform checks.

**D6. Testing strategy.**
- *Hand-computed examples:* one test per spec scenario, with values checked independently while writing the spec.
- *Combination invariants:* every combination of 4 rotations × mirrored/not × frames {1280×720 (16:9), 640×480 (4:3)} × views {portrait phone 360×800, landscape phone 800×360, portrait tablet 768×1024, landscape tablet 1024×768}, 64 cases in total. For each case:
  - (a) the full upright frame maps to `layout.previewRect`;
  - (b) the preview contains the view and matches it exactly on at least one axis;
  - (c) the frame's centre maps to the view's centre;
  - (d) a mapped box's width and height equal the original's multiplied by `scale`;
  - (e) the mirrored result equals the unmirrored result reflected across the view's centre, and is normalized.
- Results are compared with a small `rectMoreOrLessEquals` helper (tolerance 1e-9), since the values are doubles.
- *Coverage:* `flutter test --coverage`, then the share of covered lines in `coverage/lcov.info` for `lib/src/geometry/` must be at least 90% (plan §9).

**D7. Files (from the plan's §6).** `lib/src/geometry/image_rotation.dart` and `lib/src/geometry/coordinate_mapper.dart` (which holds `CoverLayout` and `CoordinateMapper`). Tests go in `test/geometry/` alongside them. Nothing is exported from `live_translate_overlay.dart`.

## Risks / Trade-offs

- [ML Kit's coordinate convention on iOS is unverified on a device] → The spec defines the input contract. `camera-capture`'s exit check on the iPhone 14 confirms it, and any fix belongs in that change's conversion code.
- [The preview widget could drift from `CoverLayout` if it uses `FittedBox` or `CameraPreview`'s default letterboxing] → `camera-capture` must position the preview from `mapper.layout.previewRect`. That change's design must name this explicitly.
- [Tests could share a misconception with the code] → Invariants (b), (c) and (e) are geometric properties that don't rely on the implementation's formula, and the hand-computed examples were checked with a separate calculation.
