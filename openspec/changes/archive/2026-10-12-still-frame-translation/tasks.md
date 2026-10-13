# Tasks

## 1. Paragraphs in recognition

- [x] 1.1 Add `int paragraph` (default 0) to `RecognizedLine`, included in equality and `toString` (design D1). `MlKitTextEngine` sets it to the block index and keeps reading order. Verify with `test/engines/mlkit/` using the fake recognizer: a heading block and a two-line block give paragraph 0 for the heading and 1 for both lines, in order.
- [x] 1.2 Add `recognizeAll(InputImage)` to `TextEngine` (D3):
  - `MlKitTextEngine`: delegates to `recognize`;
  - `MultiScriptTextEngine`: runs every script in parallel, filters each script's lines, merges them with the existing filters, offsets paragraph identifiers per script, and leaves `_latest` and `_turn` alone;
  - the package fakes in `test/support/fakes.dart`: return `lines`.

  Verify with new cases in `test/engines/multi_script_text_engine_test.dart`:
  - "EXIT" and "निकास" are both returned from one call;
  - after one `recognize` (Latin), a `recognizeAll`, then a `recognize` uses Devanagari;
  - paragraph identifiers from the two scripts don't collide;
  - the overlap and own-script filters apply.

## 2. Joining and colours

- [x] 2.1 Add `joinParagraph(List<String>)` (D5) in `lib/src/still/paragraph.dart`. Verify with `test/still/paragraph_test.dart`:
  - two lines are joined with a space;
  - "une distri-" + "bution normale" gives "une distribution normale";
  - a trailing " -" after a space keeps the hyphen;
  - surrounding whitespace is trimmed;
  - one line comes back unchanged.
- [x] 2.2 Add `sampleColours(CameraFrame, Rect)` (D6) in `lib/src/still/colour_sampler.dart`. Verify with `test/still/colour_sampler_test.dart`, using synthetic nv21 and bgra8888 frames built in `test/support/frames.dart`:
  - near-black stripes on white give a near-white background and near-black ink;
  - white stripes on blue give blue and white;
  - a flat colour falls back to black or white by contrast;
  - a box on a 90°-rotated nv21 frame samples the right raw region (the stripes are placed only there);
  - a 3:1 contrast pair falls back to black or white.

## 3. Still path in the pipeline

- [x] 3.1 Add `Pipeline.readStill(CameraFrame) → Future<StillResult?>` and the `StillResult` / `StillParagraph` types in `lib/src/still/still_result.dart` (D4). Verify with `test/pipeline/pipeline_test.dart`, using the fakes:
  - two lines of one paragraph are translated as one joined text, with a union box and both line boxes;
  - two paragraphs give two entries;
  - a paragraph in the target language is absent;
  - the throttle and tracker are untouched, so a live frame right after is still processed;
  - an engine failure is rethrown;
  - an unsupported frame gives null.

## 4. Paragraph labels

- [x] 4.1 Add `fitParagraphFontSize` and `ParagraphPainter` with internal `ParagraphLabel` values in `lib/src/view/paragraph_painter.dart` (D8). Verify with `test/view/paragraph_painter_test.dart`, using the FlutterTest font:
  - 20-high lines start at size 16;
  - a longer text shrinks to the first size that fits;
  - a too-long text stops at the minimum with an ellipsis;
  - a 50-high heading gets size 40;
  - the background `rrect` covers the union rectangle in the sampled colour, fully opaque;
  - the style's yellow background isn't used.

  Add a golden of a two-paragraph page (dark-on-light, then light-on-blue), and commit the approved image.

## 5. View and controller

- [x] 5.1 Update `lib/src/view/live_translate_view.dart` for the freeze flow (D7):
  - keep `_lastFrame`;
  - on `freeze()`, read the still frame with a read token, and show a progress indicator while reading;
  - draw `ParagraphPainter` for the still result and nothing from `_result` while frozen;
  - re-read on settings changes while frozen;
  - drop stale tokens;
  - clear the still result on `resume()`;
  - report failures as `PipelineFailure`;
  - publish paragraph `TranslatedLine`s to the controller.

  Update the `freeze()` dartdoc. Verify with `test/view/live_translate_view_test.dart` and `test/controller/live_translate_controller_test.dart`, one test per scenario of the `still-translation` and `controller` deltas:
  - a fading ghost is gone after freezing;
  - with no frame yet, nothing is shown and there's no error;
  - a bilingual frame shows both labels;
  - a sentence across lines becomes one label;
  - a progress indicator shows while a gated recognition runs, with no labels;
  - a failure reaches `onError` and no labels show;
  - a new target while frozen re-reads, and no stale result appears;
  - resuming mid-read never shows that result, and live labels return;
  - `lines` is empty while reading, then one paragraph entry with joined source text and a union rectangle;
  - a frame in flight doesn't change `lines`.

  Keep the existing view and controller tests passing, updating the freeze tests that expected the live labels to stay.

## 6. Example app

- [x] 6.1 Add `recognizeAll` to `example/test/support/fakes.dart` (D9), returning the scene's lines, each in its own paragraph. Update `example/test/camera_screen_test.dart` so the freeze test checks that the still result's label is shown after freezing (the `example-app` delta), and that "keeps the language while frozen" still passes. Verify that `flutter analyze` and `flutter test` pass in `example/`.

## 7. Checks

- [x] 7.1 Verify that:
  - `dart format --set-exit-if-changed .` makes no changes;
  - `flutter analyze` reports no issues;
  - `flutter test` passes in the package and in `example/`;
  - `git diff lib/live_translate_overlay.dart` is empty, so there are no new exports;
  - `flutter build apk --debug` and `flutter build ios --debug --no-codesign` succeed in `example/`.

## 8. Fixes from the first on-device check

- [x] 8.1 Clip and grow paragraph labels (design D10). `ParagraphPainter` intersects each label with the view, then grows labels whose translation doesn't fit: right up to the view edge or the nearest label beside it, then down by up to the original height, stopping at labels below and at the view's bottom. Only then does the font shrink. Verify with `test/view/paragraph_painter_test.dart`, one test per new `overlay-rendering` scenario:
  - a paragraph (40, 600)–(460, 680) in a 360-wide view is covered only up to x = 360, and its text wraps within that width;
  - a heading (20, 100)–(140, 124) with a longer translation grows to x = 360 and keeps its starting size;
  - with a label at (200, 90)–(340, 130), it stops at x = 200 and then grows down;
  - a fitting translation keeps its rectangle.

  Update the golden with a cropped paragraph and a growing heading, and commit the approved image.
- [x] 8.2 Change the merge in `lib/src/engines/multi_script_text_engine.dart` (D11): a non-Latin line suppresses an overlapped Latin line only when it has at least as many letters of its script as Latin letters, and a mostly-Latin non-Latin line covering at least half of a Latin line is dropped. Verify with `test/engines/multi_script_text_engine_test.dart`:
  - "étudiant तस les usages" over "étudiant tous les usages" gives only the Latin line, for both `recognize` and `recognizeAll`;
  - the existing overlap cases ("Tea Ho" under "नमस्ते", the separate English line, the small overlap, Latin only) still pass.
- [x] 8.3 Drop unsure lines in `MlKitTextEngine` (D12): skip lines with `confidence` below 0.5, and keep lines whose confidence is null. Verify with `test/engines/mlkit/mlkit_text_engine_test.dart`, using the fake recognizer: lines at 0.3, 0.9 and null give only the 0.9 and null lines.
- [x] 8.4 Pass `resolution: ResolutionPreset.high` from `example/lib/camera_screen.dart` to the view (D13). Verify with a check in `example/test/camera_screen_test.dart` that the view's `resolution` is `ResolutionPreset.high`.

## 9. Checks after the fixes

- [x] 9.1 Rerun the checks from 7.1. Verify that all of them pass.

## 10. On-device check

- [x] 10.1 **Manual, by the user, on the Samsung Galaxy and the iPhone 14:** over the same French page as the Lens screenshot, tap the shutter, then check that:
  - a progress indicator shows briefly;
  - each paragraph shows one label in the page's colours, translated as whole sentences;
  - nothing moves until resume;
  - changing the target while frozen re-translates;
  - resume returns to live labels;
  - no label runs off the screen edge, and short headings show their whole translation;
  - the line "étudiant tous les usages de ce mot dans la littérature classique," is translated;
  - the junk labels from the blurry bottom area are gone on the Samsung;
  - live mode still feels responsive at `high` resolution.

  Also note:
  - roughly how long the result takes to appear;
  - whether `high` resolution reads the print well (no "LPSUM" or "JCTION");
  - how often a heading merges with its paragraph.

  Record the results under "On-device results" in `design.md`.

## Workflow follow-up

- Archive `lens-style-example-ui` and `own-script-lines` before archiving this change, because the `example-app` delta modifies a spec that only exists once `lens-style-example-ui` is archived.
