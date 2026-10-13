# Tasks

## 1. Motion measurement

- [x] 1.1 Share the upright → raw mapping from `lib/src/still/colour_sampler.dart` as `uprightToRaw` (D1), keeping `test/still/colour_sampler_test.dart` passing. Add `texturedImage(width, height, {dx, dy, seed, format})` to `test/support/frames.dart`: a deterministic brightness pattern shifted by (dx, dy), with a different `seed` for a different scene.
- [x] 1.2 Add `MotionEstimator` and `Motion` in `lib/src/motion/motion_estimator.dart` (D1): an upright 64-long-side thumbnail with its mean subtracted, a coarse ±6 then fine ±2 search, and shift in frame pixels plus change. Verify with `test/motion/motion_estimator_test.dart`:
  - the same frame twice gives shift (0, 0) and change near 0;
  - a pattern moved by (+40, 0) and by (0, −24) frame pixels is measured within 4 frame pixels, and so is a 7 px drift;
  - the same holds for nv21 and bgra8888, and for a 90°-rotated frame (shift measured upright);
  - a frame 30 levels brighter gives shift 0 and change below 10;
  - a different seed gives change above 18;
  - the first frame, and a frame after a size change, give `Motion.unknown`.

  Add a timing test that measures 100 runs on a 1280 × 720 frame and prints the mean, without asserting it (CI machines vary).

## 2. Settling

- [x] 2.1 Add `LiveSettler` with the D2 constants and the D3 states in `lib/src/live/live_settler.dart`, driven by an injected clock. Verify with `test/live/live_settler_test.dart`, one test per `live-translation` scenario at the settler level:
  - a sweep (shift above 1% every frame) never asks to read;
  - 200 ms steady asks nothing, 300 ms asks to read once;
  - 10 s steady while holding asks nothing more;
  - drifts add up into `offset`, including during a read;
  - a 15% jump or a change above 18 asks to clear, and nothing is read until 300 ms steady again;
  - a 20%-of-height pan then 300 ms steady asks to read again, while 4% doesn't;
  - while reading, settling asks nothing more;
  - a failed read goes back to waiting;
  - `canKeepOnFreeze` is true under 2% and false at 12%.

## 3. Engines and translator

- [x] 3.1 Fold `recognizeAll` into `TextEngine.recognize`. `MultiScriptTextEngine` reads every script in parallel with the existing merge filters and drops `_latest` and `_turn`. Update the package fakes, the example fakes and every test that relied on turns (D4). Verify with `test/engines/multi_script_text_engine_test.dart`:
  - one `recognize` returns "EXIT" and "निकास";
  - after one read, both recognizers exist (`recognize` delta, "Both recognizers on the first read");
  - the overlap, own-script and paragraph-identifier cases still pass;
  - the turn tests are removed.
- [x] 3.2 Add long-text confirmation to `LineTranslator` (D5), and an `onModelReady` callback fired when its own download completes. Verify with `test/pipeline/line_translator_test.dart`:
  - a 120-letter French text at 0.95 in one call starts a French download;
  - a 9-letter Swahili line at 0.9 in one call starts nothing;
  - the existing confirmation cases still pass;
  - `onModelReady(hindi)` fires once when the Hindi download completes.

## 4. Pipeline

- [x] 4.1 Make `Pipeline.read(frame) → ReadResult?` the only processing path (D4). Rename the still result types to `ReadResult` / `ReadParagraph`, add `untranslatedLanguages`, add the `modelsReady` stream, and remove `onFrame`, `results`, `PipelineResult`, the throttle and the tracker. Delete `lib/src/tracking/`, `lib/src/pipeline/frame_throttle.dart` and their tests. Verify with `test/pipeline/pipeline_test.dart`:
  - the existing `readStill` cases, now under `read`, pass;
  - a paragraph left untranslated because its model is missing appears in `untranslatedLanguages`;
  - `modelsReady` emits the language when the translator reports it.

## 5. Painting

- [x] 5.1 Apply opacity to `ParagraphPainter` (background and ink alpha × opacity; nothing drawn at 0) through `ParagraphLabel.opacity`. Make `sampleColours` return null when a frame can't be sampled, with the view using the style's colours then (D8). Remove `TranslatedTextPainter`, `fitFontSize`, `labelTextStyle` and their tests and golden. Update `OverlayStyle`'s dartdoc: colours are the fallback, and `maxFontSize` is unused. Verify with `test/view/paragraph_painter_test.dart`:
  - opacity 1/2 halves both alphas;
  - opacity 0 draws nothing.

  The painter receives resolved colours, so "an unsampled paragraph is drawn in the style's yellow and black" is tested in the view (6.1).

  Also update `test/still/colour_sampler_test.dart`, where a box outside the frame now gives null.

## 6. View and controller

- [x] 6.1 Rebuild the live flow in `lib/src/view/live_translate_view.dart` (D6, D7):
  - each frame goes through the estimator and the settler;
  - `read` and `clear` actions;
  - one read at a time, with tokens;
  - labels offset by `settler.offset`;
  - a 200 ms fade on clear;
  - publish `lines` with offset rectangles and opacity;
  - the freeze rule (keep under 2%, otherwise read);
  - settings changes re-read the anchor frame;
  - `modelsReady` re-reads when the held result lacked that language;
  - remove `minFrameInterval`;
  - add `@visibleForTesting now`.

  Rewrite `test/view/live_translate_view_test.dart` around textured frames and the injected clock, one test per scenario of the `live-translation`, `still-translation`, `controller`, `live-view` and `capture` deltas:
  - sweep: no read;
  - 300 ms steady: one read, labels shown;
  - 200 ms: nothing;
  - 10 s holding: no further read;
  - a 30 px drift moves the labels and `lines` by 30 frame px, mapped;
  - movement during a read offsets that read's labels;
  - a 15% jump and a new scene fade out over 200 ms;
  - a 20% pan re-reads, with the old labels kept until replaced;
  - a 4% drift doesn't re-read;
  - a completed Hindi download re-reads and translates;
  - no second read while one runs;
  - a read that finishes after backgrounding isn't shown;
  - freezing a held view keeps it without reading;
  - freezing while moving or after a 12% pan reads;
  - freezing before any frame, and the "Ghosts are gone" scenario;
  - a target change on a held view re-reads in French without restarting the camera;
  - a failed read is reported, and the next settle reads;
  - both scripts read in one read.

  Keep the placeholder, lifecycle, controller-state, torch and dispose tests passing.

## 7. Example app

- [x] 7.1 Update `example/test/support/fakes.dart` (textured frames that hold still or jump to a new scene) and `example/test/camera_screen_test.dart`:
  - frames settle before labels appear;
  - the detected-download test uses a Hindi paragraph of 20 or more letters, so one read confirms it;
  - "goes back to Detect language" emits a new scene instead of empty frames;
  - the shutter test freezes a held view.

  Verify that `flutter analyze` and `flutter test` pass in `example/`.

## 8. Checks

- [x] 8.1 Verify that:
  - `dart format --set-exit-if-changed .` makes no changes;
  - `flutter analyze` reports no issues;
  - `flutter test` passes in the package and in `example/`;
  - `git diff lib/live_translate_overlay.dart` is empty;
  - `openspec validate settle-read-hold --strict` passes;
  - `flutter build apk --debug` and `flutter build ios --debug --no-codesign` succeed in `example/`.

## 9. On-device check

- [x] 9.1 **Manual, by the user, on the Samsung Galaxy (and the iPhone 14 if available):** over the French page, live mode, without the shutter. Check that:
  - sweeping shows no labels;
  - holding still shows paragraph labels in page colours after a moment, and they don't re-render while held;
  - a slow drift keeps the labels on their text;
  - panning down a little and stopping replaces the labels with the new area's;
  - a quick swing or pointing elsewhere fades them out;
  - the shutter on a held view keeps exactly what's shown.

  Also note:
  - the time from stopping to labels appearing;
  - any jank while moving;
  - whether the thresholds feel too eager or too slow.

  Record the results under "On-device results" in `design.md`.
