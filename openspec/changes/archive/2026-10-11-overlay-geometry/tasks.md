# Tasks

## 1. Rotation

- [x] 1.1 Add `lib/src/geometry/image_rotation.dart`: `enum ImageRotation { deg0, deg90, deg180, deg270 }` with `bool get isQuarterTurn` and `Size upright(Size delivered)`, plus dartdoc (design D1). Verify with `test/geometry/image_rotation_test.dart`: 1280×720 at `deg90` and `deg270` becomes 720×1280, at `deg0` and `deg180` it stays 1280×720, and `isQuarterTurn` is true only for 90 and 270.

## 2. Fill-and-crop layout

- [x] 2.1 Add `CoverLayout` to `lib/src/geometry/coordinate_mapper.dart`: an `@immutable final class` with `CoverLayout.fit({required Size uprightSize, required Size viewSize})` exposing `scale`, `offset` and `previewRect`, `==`/`hashCode`, and the empty-size short circuit (design D2, D3). Verify with `test/geometry/cover_layout_test.dart`, covering the spec scenarios "Wide frame in a tall view is cropped left and right" (scale 0.625, preview (-45, 0)–(405, 800)), "Matching aspect ratio needs no crop", and an empty view and an empty frame each giving scale 0 and `Rect.zero`.

## 3. Box mapping

- [x] 3.1 Add `CoordinateMapper` to `lib/src/geometry/coordinate_mapper.dart`: the constructor takes `imageSize`, `rotation`, `viewSize` and `mirror`, computes `layout` once, and has `Rect mapToView(Rect box)` with mirroring after scaling (design D2, D4). Verify with `test/geometry/coordinate_mapper_test.dart`: one test per spec scenario (back camera portrait → (17.5, 125)–(142.5, 162.5); back camera landscape → (62.5, 80)–(187.5, 117.5); front camera at 270° → (217.5, 125)–(342.5, 162.5); centred box unaffected by mirroring; box in the cropped margin → (-45, 0)–(-20, 25); 0×0 view and 0×0 frame → `Rect.zero`).
- [x] 3.2 Add the combination-invariant tests to `test/geometry/coordinate_mapper_test.dart`: 4 rotations × mirrored/not × frames {1280×720, 640×480} × views {360×800, 800×360, 768×1024, 1024×768}, 64 cases, each checking invariants (a)–(e) from design D6 with a `rectMoreOrLessEquals` helper (tolerance 1e-9). Verify that all 64 cases are generated and pass, and that test names say which combination failed.

## 4. Checks

- [x] 4.1 Run the package checks. Verify that `dart format --set-exit-if-changed .` makes no changes, `flutter analyze` reports no issues, `flutter test` passes, and `grep -n geometry lib/live_translate_overlay.dart` finds nothing (the layer stays internal).
- [x] 4.2 Measure coverage. Run `flutter test --coverage`, then add up `LH` (lines hit) and `LF` (lines found) across the `SF:lib/src/geometry/` entries in `coverage/lcov.info`. Verify that LH/LF is at least 90%, and report the figure.
