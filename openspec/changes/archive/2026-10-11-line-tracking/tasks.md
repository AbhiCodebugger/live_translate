# Tasks

## 1. Building blocks

- [x] 1.1 Add `lib/src/tracking/iou.dart` with `iou(Rect a, Rect b)`, returning 0 for empty or disjoint boxes (design D3). Verify with `test/tracking/iou_test.dart`:
  - identical boxes give 1;
  - disjoint boxes give 0;
  - (0, 0)–(100, 20) vs (5, 0)–(105, 20) gives 1900/2100;
  - the spec's 0.6 near-tie pair gives 0.6;
  - an empty box gives 0.
- [x] 1.2 Add `lib/src/tracking/text_similarity.dart` with `textSimilarity(a, b)`: normalized and lowercased Levenshtein using two rolling rows, where two empty strings give 1 (design D4). Verify with `test/tracking/text_similarity_test.dart`:
  - "Exit" vs "exit" gives 1;
  - "निकास" vs "निकाश" gives 0.8;
  - "Platform 1" vs "Platform 2" gives 0.9;
  - " Salida  de " vs "Salida de" gives 1;
  - "" vs "" gives 1;
  - "abc" vs "" gives 0.
- [x] 1.3 Add `lib/src/tracking/smoothing.dart` with `const smoothingFactor = 0.5` and `smoothRect(previous, next)` (design D5). Verify with `test/tracking/smoothing_test.dart`: (0, 0)–(100, 20) smoothed towards (10, 0)–(110, 20) gives (5, 0)–(105, 20).

## 2. Line tracker

- [x] 2.1 Add `lib/src/tracking/line_tracker.dart` with `LineTracker.update(FrameKey, List<LineTranslation>) -> List<TrackedLine>`, plus `TrackedLine` (value equality) and `FrameKey` (design D2, D3, D6, D7). It covers greedy scored matching, new IDs, smoothing, fading, translation reuse and resetting on key changes. Verify with `test/tracking/line_tracker_test.dart`, one test per `tracking` spec scenario:
  - slightly moved line keeps its ID; a new line elsewhere gets a new ID; one line per track;
  - the two neighbouring lines resolve to "Platform 2";
  - the 10 px move is smoothed to (5, 0)–(105, 20);
  - opacity is 1/3 after two missed frames, the track is removed after three, and full opacity returns when it's seen again;
  - a recognition error keeps "Exit"; a different translation for similar text keeps "Exit"; really changed text shows "Entrance"; a translation arriving later is adopted;
  - rotating the phone or switching cameras resets the IDs.

## 3. Pipeline and view

- [x] 3.1 Run the tracker in `Pipeline` after translation, replacing `PipelineResult.translations` with `lines: List<TrackedLine>` (design D1). Update `test/pipeline/pipeline_test.dart`:
  - two frames with the same line give the same ID;
  - a line missing from the next frame comes back at opacity 2/3;
  - a frame from a newer generation starts new IDs.

  Keep the existing pipeline tests passing.
- [x] 3.2 Build `TranslatedLine`s in `LiveTranslateView` and draw them with `TranslatedTextPainter(lines:, style:, textDirection:)`, deleting `OverlayLabel` (design D8). The painter multiplies colour alpha by opacity and skips opacity 0. Update `test/view/overlay_painter_test.dart` (an opacity 1/3 label paints its rrect at alpha 0xCC × 1/3; opacity 0 paints nothing; `shouldRepaint` notices an opacity change) and `test/view/live_translate_view_test.dart` (labels carry stable IDs across frames; a line that disappears for one frame is still painted at reduced opacity). Verify that the golden test passes unchanged, or re-approve it with a recorded reason.
- [x] 3.3 Measure coverage. Run `flutter test --coverage` and add up `LH`/`LF` for `SF:lib/src/tracking/` and for `SF:lib/src/pipeline/`. Verify that each is at least 90%, and report both figures.

## 4. Checks

- [x] 4.1 Run the package and example checks. Verify that:
  - `dart format --set-exit-if-changed .` makes no changes and `flutter analyze` reports no issues;
  - `flutter test` passes in the package and in `example/`;
  - `git diff lib/live_translate_overlay.dart` is empty;
  - `flutter build apk --debug` and `flutter build ios --debug --no-codesign` succeed in `example/`.

## 5. On-device exit check

- [x] 5.1 **Manual, on the Samsung Galaxy (Android 15) and the iPhone 14 (iOS 26.6.1):** with "Hindi only" on and the Hindi model downloaded, record about 30 seconds of the screen. Hold still for a few seconds, then pan slowly across Hindi text, then move away and back. Verify, for each device:
  - labels stay put when the phone is still (no jumping);
  - labels don't flicker on and off for lines that stay in view;
  - labels follow slow pans smoothly (note any visible lag);
  - lines leaving the view fade out instead of vanishing.
- [x] 5.2 Record the results from 5.1 under "On-device results" in `design.md`, including whether the smoothing factor needs tuning. Verify that the section lists both devices with every check.
