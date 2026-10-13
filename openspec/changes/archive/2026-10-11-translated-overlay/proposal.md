# Proposal

## Why

`translation-engines` built recognition across scripts, language detection, translation and Wi-Fi-only model downloads, but nothing calls them yet: the live view still draws green debug boxes around Latin text. This change connects the engines to the camera pipeline and paints each translation over its original line. It finishes the second half of the plan's translation milestone, whose exit check is a Hindi sign showing correct English over each line on a real device.

## What Changes

- **Pipeline:** after recognition, each frame's lines go through `LineTranslator`. `PipelineResult` carries `LineTranslation`s (line, source language, translation) instead of bare lines. Translation failures and model and language problems flow into the existing `errors` stream.
- **View parameters** (from plan §4.1), on the still-internal `LiveTranslateView`:
  - `targetLanguage` (required)
  - `scripts` (default `{TextScript.latin}`)
  - `sourceLanguages` (`null` = detect automatically)
  - `style` (`OverlayStyle`)
  - `onError`, which receives camera errors and pipeline errors
- **Settings changes:** changing `targetLanguage`, `scripts` or `sourceLanguages` rebuilds the recognition and translation engines, closing the old ones, without restarting the camera. Results from before the change are discarded.
- **Translated-text painter** (replaces `DebugBoxPainter`): for each translated line it covers the original with a rounded background in `OverlayStyle` colours, and draws the translation on one line. The font shrinks from `maxFontSize` towards `minFontSize` to fit the line's width, and the text is ellipsised at the minimum. Untranslated lines aren't painted, so the original text stays visible. Right-to-left target languages are laid out right to left.
- **Example app:** the debug screen translates into English with Latin and Devanagari enabled. It gets a toggle between automatic detection and "Hindi only", and shows `onError` messages, so you can see model downloads during the exit check.
- **Noise and download fixes (found during the exit check):** with automatic detection, the Latin reader turned Devanagari into gibberish. Language ID assigned that gibberish to many languages (`hi-Latn`, `la` and others), which caused stray ~30 MB downloads and repeated "Can't translate" reports. Holding the phone still made the gibberish stable from frame to frame, so a confirmation rule alone wasn't enough. Now:
  - Latin-reader lines that mostly overlap a non-Latin reader's line are dropped.
  - A source model downloads automatically only when its language is in `sourceLanguages` and is confirmed (≥ 0.8 confidence in 3 of the last 10 frames), one at a time. Other confirmed missing languages are reported once.
  - "Unsupported language" reports also wait for confirmation.
- **Script check and no-op labels (found during the third exit-check run):** with "Hindi only" on, Latin lines such as a browser's address bar were assumed to be Hindi and "translated" into garbage. A single hinted language is now assigned only to lines containing a letter of its script (Latin or Devanagari). A translation identical to its line draws no label.
- **On-device exit check:** a Hindi sign shows English over each line on the Samsung Galaxy and the iPhone 14.

## Capabilities

### New Capabilities
- `overlay-rendering`: How translated labels are drawn over the camera view: covering the original line, fitting the font to the line, ellipsising, `OverlayStyle` colours, leaving untranslated lines alone, and right-to-left text.
- `live-view`: The live translation widget's configuration and reporting: target language, scripts, source-language hint, applying setting changes without restarting the camera, and reporting errors through `onError`.

### Modified Capabilities
- `translate`: a missing source model downloads automatically only when its language is expected (in `sourceLanguages`) and confirmed; other confirmed missing languages are only reported; unsupported-language reports need confirmation too; the target model still downloads at once.
- `detect-language`: a single hinted language is assigned only to lines containing a letter of its script, for Latin and Devanagari languages.
- `recognize`: with Latin and a non-Latin script selected, Latin-reader lines mostly covered by a non-Latin reader's line are dropped.
- `overlay-geometry`: the "Preview is displayed with the shared layout" requirement now places translated labels, not debug rectangles, with the shared layout.

## Impact

- **Code:**
  - `lib/src/pipeline/line_translator.dart` (download rules)
  - `lib/src/engines/multi_script_text_engine.dart` (overlap filter)
  - `lib/src/pipeline/pipeline.dart` (adds the translation stage; `PipelineResult` carries translations)
  - `lib/src/view/live_translate_view.dart` (new parameters, engine wiring, rebuilding on settings changes, `onError`)
  - `lib/src/view/overlay_painter.dart` (`TranslatedTextPainter` replaces `DebugBoxPainter`)
  - `example/lib/main.dart`
  - matching tests
- **Public API:** unchanged. The view stays internal until release 0.1.0, as decided in `camera-capture`.
- **Dependencies:** none added.
- **Out of scope (later in the plan):**
  - Exporting `LiveTranslateView`, and producing the public `TranslatedLine` (it needs the tracker's stable IDs).
  - Tracking, smoothing and fading, the controller, freeze, and the HUD.
  - `overlayBuilder`.
