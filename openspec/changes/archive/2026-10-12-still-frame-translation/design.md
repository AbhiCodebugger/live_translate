# Design

## Context

See proposal.md for the motivation and the specs for behaviour.

What exists now:

| Piece | Where | Relevant here |
|---|---|---|
| `MlKitTextEngine.recognize` | `lib/src/engines/mlkit/mlkit_text_engine.dart` | flattens `result.blocks` → `block.lines` into `RecognizedLine(text, box)`, losing the block |
| `MultiScriptTextEngine` | `lib/src/engines/multi_script_text_engine.dart` | one script per call in turn; `_latest` per script; `_merge` with the Latin overlap filter; own-script letter filter (`own-script-lines`) |
| `Pipeline._process` | `lib/src/pipeline/pipeline.dart` | throttle → `toInputImage` → recognize → `LineTranslator.translateLines` → `LineTracker.update` → `PipelineResult` |
| `LineTranslator.translateLines` | `lib/src/pipeline/line_translator.dart` | per-line identification and settling per script, cached translation, model checks; takes any `RecognizedLine`s |
| View freeze | `lib/src/view/live_translate_view.dart` | `_frozen = true`, `_session.pause()`, keeps `_result` (tracked lines, including fading ones) |
| `TranslatedTextPainter` | `lib/src/view/overlay_painter.dart` | one-line labels with `fitFontSize`, style colours |
| Frames | `CameraFrame(image: CameraImage, rotation, generation)` | single-plane nv21 (Android) or bgra8888 (iOS); `CameraImage` bytes are Dart-owned copies, so a frame can be kept after streaming stops |

## Goals / Non-Goals

**Goals:**
- Every scenario in the deltas is a unit, widget or golden test, driven by the existing fakes.
- No new exported symbols, and the live path behaves exactly as before.
- The still result appears within about a second of tapping on the test phones (measured during the on-device check, not enforced in tests).

**Non-Goals:**
- Taking a higher-resolution photo (D2).
- Steadier live labels.
- Rotated or perspective-corrected text: labels stay axis-aligned rectangles.

## Decisions

**D1. Paragraph identity travels on `RecognizedLine`.** `RecognizedLine` gains `int paragraph`, the block index within that recognizer's result, defaulting to 0 so existing fakes and tests still compile. `MultiScriptTextEngine` makes identifiers unique across scripts by offsetting them per script (script index × 10 000). Nothing on the live path reads the field.

**D2. The still frame is the last streamed frame, not a new photo.**
- The view keeps a reference to the latest `CameraFrame` from `session.frames`, which costs nothing because frames are already copied into Dart.
- A `takePicture()` photo would be sharper, but it has a different size and aspect ratio from the preview, its orientation comes from EXIF, and it needs a file round-trip. It would also need a second coordinate mapping and is slower to appear.
- Reusing the stream frame keeps the existing conversion and mapping, which are already tested.
- Quality depends on `resolution` (default `medium`). The example can raise it, and the on-device check records whether `medium` is good enough. A photo capture can follow later behind the same still path.

**D3. `TextEngine.recognizeAll`.** The interface gains `Future<List<RecognizedLine>> recognizeAll(InputImage image)`.
- `MlKitTextEngine`: the same as `recognize`.
- `MultiScriptTextEngine`: runs every script's engine on the image in parallel, filters each script's lines as in `recognize`, and merges them through the same filter code. It neither touches `_latest` nor advances `_turn`.

Fakes gain the method. In the package fakes it returns `lines`.

**D4. A still path in the pipeline: `Pipeline.readStill(CameraFrame) → Future<StillResult?>`.**
- It doesn't go through the throttle. It's the only work while frozen, because live frames stop.
- Steps: `toInputImage` → `recognizeAll` → group lines by `paragraph`, keeping recognition order → build one `RecognizedLine` per paragraph, with the joined text (D5) and the union box → `translateLines` (the same translator, cache and model handling; a paragraph is just a longer line) → sample colours (D6) → `StillResult(paragraphs: [StillParagraph(box, lineBoxes, sourceText, sourceLanguage, translatedText, background, ink)], imageSize, rotation)`.
- Failures are rethrown, so the view reports them.
- It returns null for an unsupported frame format.

Reusing `translateLines` keeps the per-script settling. A page mixing two Latin-script languages gets one language for all its Latin paragraphs, which is a known limitation of live mode too (Risks).

**D5. Joining paragraph lines.** This is a pure function, `joinParagraph(List<String> lines)`: trim each line, then join with a single space. A line ending in `-` immediately after a letter (`\p{L}-$`) is joined to the next line without the hyphen or the space.

**D6. Colour sampling: `sampleColours(CameraFrame, Rect uprightBox) → ({Color background, Color ink})`, in `lib/src/still/colour_sampler.dart`.**
- **Mapping:** the upright box is mapped back to raw buffer coordinates by undoing the rotation (0/90/180/270; frames are never mirrored).
- **Sampling:** a grid of up to 48×16 points evenly spaced inside the box. Each point is read as RGB:
  - nv21: Y at `y*w + x`; V and U at `w*h + (y~/2)*w + (x~/2)*2` (V first), converted with BT.601;
  - bgra8888: bytes at `(y*bytesPerRow + x*4)` in B, G, R order.
- **Background:** samples are bucketed by colour (4 bits per channel), and the most common bucket's mean colour is the background. Text covers the minority of a paragraph's area.
- **Ink:** among the samples whose relative luminance differs from the background's by more than 0.25, take the 20% farthest from the background, and use their mean.
- **Contrast fallback:** if there are no such samples, or the WCAG contrast ratio is below 4.5, use black or white, whichever contrasts more with the background.

Sampling is synchronous Dart: at most 768 reads per paragraph, so well under a millisecond for a page.

**D7. View flow.**

```
 running --freeze()--> frozen(reading) --result--> frozen(still)
    ^                     |    ^                        |
    |                     |    +--settings change-------+  (re-read same frame)
    +------resume()-------+-----------------------------+
```

- `freeze()`: set `_frozen`, pause the session, clear `_result`, and start `_readStill(_lastFrame)` with a read token. A new freeze, a resume, or a settings change while frozen increments the token, and a result arriving with an old token is dropped.
- While reading: the view draws the preview plus a centred `CircularProgressIndicator`, and no labels.
- `_replacePipeline()` while frozen: build the new pipeline, then re-read `_lastFrame` (the `still-translation` requirement on settings changes).
- `resume()`: increment the token, clear `_still`, and resume the session.
- The controller is published with `lines` = paragraphs mapped to view rectangles, at opacity 1. Paragraphs without a translation, or whose translation equals the source, are left out, as for live lines.
- If no frame has been received, the view stays frozen with no labels and no indicator.

**D8. `ParagraphPainter`, in `lib/src/view/paragraph_painter.dart`, for still results.** It takes internal `ParagraphLabel(rect, lineHeight, text, background, ink)` values.
- **Background:** the rectangle, inflated by the style's padding, in an opaque `RRect` with the style's radius.
- **Text:** `fitParagraphFontSize` starts at `floor(0.8 × median line height)` and steps down one size until a wrapping `TextPainter` laid out at the inner width is no taller than the inner height. It stops at the style's minimum, and there it lays out with `maxLines = floor(innerHeight / lineHeightAtMin)` and an ellipsis.
- **Styling:** the style's font weight, and the target's text direction.

The live `TranslatedTextPainter` is unchanged. The view draws one painter or the other, never both.

**D9. Example app.** No code change is expected: the shutter already calls `freeze()` / `resume()`. The `example-app` delta only rewords the freeze scenario. Its existing frozen-state tests (shutter tooltips, detected language kept while frozen) need the fake engines to implement `recognizeAll`. The detected-language scenario still holds, because paragraphs carry `sourceLanguage`.

**D10. Labels are clipped to the view, then grow into free space.** `ParagraphPainter` takes the view size and receives all labels at once.
- Each label's rectangle is first intersected with the view.
- If the translation doesn't fit at the starting size, the label widens to the right, up to the view's right edge or the left edge of the nearest label that overlaps it vertically. If it still doesn't fit, it extends downwards by up to its original height, stopping above the nearest label below it and at the view's bottom. Only then does the font shrink.
- Labels are grown in reading order against the other labels' original rectangles, so the result doesn't depend on drawing order. Two labels growing towards the same gap can't overlap, because each stops at the other's original rectangle.
- Growing covers whatever original text was in that space, such as untranslated numbers. That's accepted, because it's only empty or untranslated space.

**D11. A mostly-Latin Devanagari reading never beats a Latin line.** In `_merge`, a non-Latin line suppresses an overlapped Latin line only when it has at least as many letters of its own script as Latin letters (`lettersOf` counts both), so a tie such as "दवा 500mg" (2 and 2) still counts as Devanagari. A non-Latin line that is mostly Latin letters and covers at least half of a Latin line is itself dropped. This is the likely cause of the untranslated "étudiant tous les usages…" line on the device: the Devanagari reader's junk version, with two Devanagari letters, replaced the real line and then went untranslated. If the next on-device check still shows an untranslated line, it needs a debug log of the frozen read's per-script lines.

**D12. Drop unsure lines where the platform reports confidence.** `MlKitTextEngine` drops a line whose `TextLine.confidence` is below 0.5. ML Kit reports confidence on Android only (it's null on iOS), so iOS keeps every line. 0.5 is a first guess, to be tuned against the junk lines on the device. `RecognizedLine` doesn't carry confidence, because nothing downstream needs it.

**D13. The example streams at `ResolutionPreset.high`.** The package default stays `medium`, because live processing time grows with the frame size. The example passes `resolution: ResolutionPreset.high` to the view, so both live and frozen reads see sharper text. The on-device check records whether live mode stays responsive. If it doesn't, the follow-up is a full-resolution photo on freeze only (D2).

## Risks / Trade-offs

- [`high` streaming slows live recognition, roughly in proportion to the pixel count] → The frame throttle already drops frames rather than queueing them, so labels lag rather than pile up. The check records the feel, and photo-on-freeze is the fallback (D13).
- [A confidence threshold of 0.5 may drop real but faint text, or keep junk] → It's Android-only and tunable; the check compares against the screenshot's junk lines (D12).

- [The last streamed frame may be a few milliseconds older than the frozen preview picture] → Both come from the same moment of pausing. The on-device check confirms that labels line up.
- [Medium-resolution frames misread small print (for example "LPSUM" and "lunomings" in the screenshot)] → Paragraph translation tolerates single misread words better than lines do. Raising `resolution` is a widget parameter. A photo capture is the follow-up if the check shows it's needed (D2).
- [ML Kit sometimes merges two columns, or a heading and its paragraph, into one block] → The result is one label covering both. It's still readable, and the on-device check notes how often it happens.
- [Two Latin-script languages on one page share one detected language] → An existing per-script settling limitation, also in live mode, and not changed here.
- [Photos of glossy or unevenly lit pages give a patchy background] → The most-common-bucket choice favours the dominant page tone, and the contrast fallback keeps the text readable.
- [Re-reading on every settings change while frozen] → A user changes settings rarely, and the token drops stale results.
- [`RecognizedLine` gaining a field] → It's internal (not exported), and the default keeps call sites unchanged.

## On-device results

Checked by the user on 2026-10-12, over a French web page shown on a laptop screen, translating into English.

**First check (Samsung Galaxy, `medium` resolution):**
- Paragraphs translated as whole sentences, in the page's grey and ink colours, and nothing moved while frozen.
- It found five problems, fixed in tasks 8.1–8.4:
  - labels ran off the right edge;
  - a short heading was cut to "Where does it co…";
  - small print was misread ("LPSUM", "JCTION");
  - junk was translated from a blurry area;
  - the line "étudiant tous les usages…" was left untranslated.

**Second check, after the fixes (`high` resolution):**
- The user reported that everything looks good: every check in task 10.1 passed, including the untranslated line, which confirms the D11 cause, and live mode stayed responsive at `high`.
- Screenshots from both checks came from the Samsung Galaxy. Separate results for the iPhone 14 weren't reported.
- The user accepted the Samsung check for archiving.
