# Tasks

## 1. Text fitting

- [x] 1.1 Add `lib/src/view/text_fit.dart` with `fitFontSize` (binary search over whole sizes, capped by inner height and the style's maximum, falling back to the minimum; design D6) and `textDirectionFor(TranslateLanguage)` (RTL for Arabic, Hebrew, Persian and Urdu; D7). Verify with `test/view/text_fit_test.dart`, using the FlutterTest font (each glyph is one font size wide and a line is one font size tall):
  - "Exit" in a 200×40 inner area gives 28;
  - a 16-character text in a 260×40 area gives 16;
  - a text too long even at size 10 gives 10;
  - a 14-high inner area gives no more than 14;
  - Arabic, Hebrew, Persian and Urdu are RTL, and English and Hindi are LTR.

## 2. Translated-text painter

- [x] 2.1 Replace `DebugBoxPainter` in `lib/src/view/overlay_painter.dart` with `TranslatedTextPainter(labels, style, textDirection)` and the internal `OverlayLabel(rect, text)` value. It draws a rounded background in the style's colour and radius, then single-line text at the fitted size, with an ellipsis, centred vertically in the padded inner area. `shouldRepaint` compares labels, style and direction (design D5). Verify with `test/view/overlay_painter_test.dart`, covering:
  - the `paints` matcher shows one `rrect` per label at the label's rectangle with radius 6 and colour 0xCC000000;
  - a custom style paints a yellow background;
  - no labels paint nothing;
  - `shouldRepaint` is false for equal inputs and true when the labels or the style change.

  Also add a golden test (`matchesGoldenFile`) for short, long (shrunk) and too-long (ellipsised) labels under the default style, and commit the approved golden image.

## 3. Pipeline translation stage

- [x] 3.1 Extend `Pipeline` with a `LineTranslator`, a target language and source languages. It runs recognize then `translateLines` inside one throttled run, and `PipelineResult.translations` replaces `lines` (design D1). Update `test/pipeline/pipeline_test.dart` with `FakeTextEngine`, a `LineTranslator` over the fake language, translate and model-store engines, and a fake clock:
  - a result carries translated lines, plus the frame size, rotation, mirror and generation;
  - a line already in the target language is absent;
  - a missing model produces `ModelNotDownloaded` on `errors`;
  - a frame arriving while recognition or translation is in progress is dropped;
  - nothing is emitted after `dispose`.

  Keep the existing cases (an engine failure gives a `PipelineFailure`, and unsupported frames are skipped) passing.

## 4. View wiring

- [x] 4.1 Update `lib/src/view/live_translate_view.dart` (design D2–D4, D7):
  - add `targetLanguage` (required), `scripts` (default `{TextScript.latin}`), `sourceLanguages`, `style` and `onError`;
  - replace `createEngine` with `@visibleForTesting createEngines` returning the `LiveTranslateEngines` record;
  - build the pipeline from it;
  - rebuild the engines and pipeline in `didUpdateWidget` when the target, scripts or source languages change;
  - send camera errors and pipeline errors to `onError`;
  - paint with `TranslatedTextPainter`, using labels mapped through `CoordinateMapper` for lines whose translation isn't null, and the direction from `textDirectionFor(targetLanguage)`.

  Update `test/view/live_translate_view_test.dart`, using fake engines and session:
  - a translated line's label covers (17.5, 125)–(142.5, 162.5) in the 360×800 layout case;
  - an untranslated line has no label;
  - the default scripts are {Latin};
  - Latin and Devanagari both produce labels;
  - the "Hindi only" hint skips identification;
  - changing the target closes the old text, language and translate engines exactly once, starts the camera no extra times, and shows no result from the old target;
  - a rebuild with equal settings keeps the engines;
  - `onError` receives `CameraPermissionDenied` (also shown on screen) and one `ModelNotDownloaded(hindi)`.

  Keep the existing placeholder, lifecycle, stale-generation, lens-switch and dispose tests passing.
- [x] 4.2 Check coverage of the pipeline layer. Run `flutter test --coverage` and add up `LH`/`LF` for the `SF:lib/src/pipeline/` entries. Verify that it is at least 90%, and report the figure.

## 5. Example app

- [x] 5.1 Update `example/lib/main.dart` (design D8): target English; scripts Latin and Devanagari; a "Hindi only" `FilterChip` that switches `sourceLanguages` between `{hindi}` and `null`; the switch-camera button; and an `onError` `SnackBar` with friendly text ("Downloading the Hindi model over Wi-Fi…" for `ModelNotDownloaded`). Update `example/test/widget_test.dart` to also find and tap the chip. Verify that `flutter analyze` and `flutter test` pass in `example/`, and that `flutter build apk --debug` and `flutter build ios --debug --no-codesign` succeed.

## 6. Package checks

- [x] 6.1 Run the package checks. Verify that `dart format --set-exit-if-changed .` makes no changes, `flutter analyze` reports no issues, `flutter test` passes, and `git diff lib/live_translate_overlay.dart` is empty (no new exports).

## 7. Download confirmation

- [x] 7.1 Change `chooseSourceLanguage` to return the chosen `LanguageGuess` instead of only its tag, and give a single hinted language confidence 1.0. In `LineTranslator` (design D10), add:
  - a frame counter, incremented once per `translateLines` call;
  - per-language frame numbers for assignments at ≥ 0.8, counted at most once per frame;
  - confirmation when at least 3 of them fall within the last 10 frames;
  - `missing` and `downloading` states, so a missing model isn't re-checked every frame;
  - one source download at a time;
  - target models downloading immediately.

  Update `test/pipeline/choose_source_language_test.dart` for the new return type, and `test/pipeline/line_translator_test.dart` with one test per scenario of the `translate` delta in this change:
  - three Hindi frames start one download, and none starts after two;
  - one stray detection at 0.9 starts nothing;
  - five frames at 0.7 start nothing;
  - frames 1, 7 and 13 start nothing;
  - the hinted language downloads on the third frame;
  - a missing target downloads at once;
  - Marathi waits while Hindi downloads, then starts;
  - a failed download retries on the next confirmed frame.

  Also update the pipeline and view tests that expect a download after one frame, so they deliver three. Verify that `flutter test` passes and pipeline coverage stays ≥ 90%.

- [x] 7.2 Add the overlap filter to `lib/src/engines/multi_script_text_engine.dart` (design D11 A): with Latin and a non-Latin script selected, drop each Latin line whose box is at least half covered by a non-Latin line. Verify with new cases in `test/engines/multi_script_text_engine_test.dart`, one per scenario of the `recognize` delta: gibberish over a Hindi line is dropped; a separate English line is kept; a small overlap is kept; Latin only drops nothing.
- [x] 7.3 Restrict automatic source downloads and confirm unsupported reports (design D11 B):
  - track sightings per language tag;
  - auto-download a missing source model only when it is in `sourceLanguages` and confirmed;
  - otherwise report `ModelNotDownloaded` once when confirmed;
  - report `UnsupportedLanguagePair` once per tag, only when confirmed.

  Update `test/pipeline/line_translator_test.dart` to cover every scenario of this change's `translate` delta: detected but not expected gives no download and one report; one stray detection, repeated low confidence and detections too far apart start nothing; the hinted language downloads on the third frame; a missing target downloads at once; downloads run one at a time; a stray "hi-Latn" reports nothing; "la-Latn" in three frames reports once; a model the app downloads is used within 10 frames (missing models are re-checked at most every 10 frames). Update the pipeline and view tests that relied on unhinted downloads. Update `example/lib/main.dart` so the message says "Downloading … over Wi-Fi" only for English, or Hindi with "Hindi only" on. Verify that `flutter test` passes in the package and in `example/`, and that pipeline coverage is ≥ 90%.

- [x] 7.4 Add `scriptOf(TranslateLanguage)` and `hasLetterOf(String, TextScript)` in `lib/src/pipeline/line_translator.dart`, and apply them to the single-hint path in `LineTranslator`. In `LiveTranslateView`, skip labels whose normalized translation equals the line's text (design D12). Verify with:
  - `test/pipeline/line_translator_test.dart`: under {hindi}, a Latin URL line gets no source language, no translation and no identification; "दवा 500mg" is assigned "hi"; under {arabic}, "Exit" is assigned "ar".
  - `test/pipeline/script_test.dart` for `scriptOf` (Hindi and Marathi are Devanagari, Spanish is Latin, Arabic is null) and `hasLetterOf`.
  - `test/view/live_translate_view_test.dart`: a line translated to its own text, ignoring extra whitespace, has no label.

  `flutter test` passes, and pipeline coverage is ≥ 90%.

## 8. On-device exit check

- [x] 8.1 **Manual, on the Samsung Galaxy (Android 15) and the iPhone 14 (iOS 26.6.1), on Wi-Fi:** run the example, wait for any model-download snackbar to finish, then hold the back camera still over a printed Hindi sign or menu. Verify, for each device:
  - "Hindi only" on: each Hindi line shows an English label;
  - "Hindi only" off: labels still appear, or note which lines automatic detection misses;
  - English text in the frame gets no label;
  - long translations shrink or are ellipsised within their line.

  Also note whether English needed a download.
- [x] 8.2 Record the results from 8.1 under "On-device results" in `design.md`, and answer the Open Question about the English model, or carry it forward if the results don't settle it. Verify that the section lists both devices with every check.
