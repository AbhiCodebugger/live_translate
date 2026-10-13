# Design

## Context

See proposal.md for the motivation. This change builds on `camera-capture` and `translation-engines`.

What exists now:

| Piece | Where | State |
|---|---|---|
| `Pipeline(engine, throttle)` | `lib/src/pipeline/pipeline.dart` | throttle → `toInputImage` → `TextEngine.recognize`; emits `PipelineResult(lines, imageSize, rotation, mirror, generation)` and a `LiveTranslateException` `errors` stream |
| `LineTranslator` | `lib/src/pipeline/line_translator.dart` | `translateLines(lines, target:, sourceLanguages:)` → `List<LineTranslation>`; reports through an `onError` callback |
| `MultiScriptTextEngine`, `MlKitTextEngine(script:)`, `MlKitLanguageEngine`, `MlKitTranslateEngine`, `MlKitModelStore` | `lib/src/engines/` | each closes once and refuses work after `close` |
| `LiveTranslateView` (internal) | `lib/src/view/live_translate_view.dart` | `cameraLensDirection`, `resolution`, `minFrameInterval`, plus `@visibleForTesting createSession` and `createEngine` |
| `DebugBoxPainter` | `lib/src/view/overlay_painter.dart` | strokes rectangles |
| `OverlayStyle` | `lib/src/models/overlay_style.dart` | defaults: background 0xCC000000, white text, radius 6, padding 4×2, font 10–28, w600 |

Decided earlier:
- The view stays internal until 0.1.0 (`camera-capture` D10).
- Models download automatically over Wi-Fi only, and the user is told once (A).
- The exit check is done with the phone held still over a sign. Freezing comes later.

## Goals / Non-Goals

**Goals:**
- Make the exit check pass on both phones: a Hindi sign shows English over each line.
- Every spec scenario in `overlay-rendering`, `live-view` and the changed `overlay-geometry` requirement is a widget or unit test, driven by fakes.
- Keep `lib/src/pipeline/` at ≥ 90% line coverage.

**Non-Goals:**
- Tracking, so a line can keep its translation from frame to frame (Week 3). Until then, text that is read slightly differently in each frame may flicker between translated and untranslated.
- `TranslatedLine` with stable IDs and opacity, which needs the tracker. The painter uses an internal value type for now.
- `overlayBuilder` (0.2.0), the HUD (Week 3), and exporting the view (0.1.0).

## Decisions

**D1. The pipeline gains a translation stage.**
- The constructor becomes `Pipeline({required TextEngine textEngine, required LineTranslator Function(onError) createTranslator, required TranslateLanguage target, Set<TranslateLanguage>? sourceLanguages, FrameThrottle? throttle})`.
- `_process` runs recognize → `translateLines` inside the same throttled run, so a frame isn't finished until its translations are. This keeps the "never queue" rule from the `capture` spec.
- `PipelineResult.lines` (`List<RecognizedLine>`) becomes `translations` (`List<LineTranslation>`).
- `LineTranslator`'s `onError` feeds the pipeline's `errors` stream. *Refined during implementation:* the pipeline takes `createTranslator: (onError) => LineTranslator(...)` instead of a ready-made translator, and passes its own error reporter in. The translator therefore can't exist without a stream to report to, and the view doesn't have to order construction carefully.

*Alternative:* translate in the view. Rejected because frames would no longer be throttled through the whole of their processing, and the view would have to coordinate two async stages.

**D2. Engines are built through one internal factory, replaceable in tests.**

The view gets `@visibleForTesting LiveTranslateEngines Function()? createEngines`, where `LiveTranslateEngines` is an internal record:

```dart
({
  TextEngine Function(Set<TextScript> scripts) text,
  LanguageEngine Function() language,
  TranslateEngine Function() translate,
  ModelStore models,
})
```

The default factory builds `MultiScriptTextEngine({for (s in scripts) s: MlKitTextEngine(script: s)})`, `MlKitLanguageEngine()`, `MlKitTranslateEngine()` and one `MlKitModelStore()`.

This replaces Week 1's `createEngine`. Tests pass fakes for all four. The model store lives for the whole life of the view, because it holds no native resources and its download state is per device.

**D3. Settings changes rebuild the pipeline, not the camera.**
- In `didUpdateWidget`, a change to `targetLanguage`, `scripts` (compared as sets) or `sourceLanguages` triggers `_rebuildPipeline()`.
- It cancels the pipeline subscriptions, disposes the old pipeline, closes the old text, language and translate engines, then builds new engines, a new `LineTranslator` (with a fresh cache) and a new pipeline. It re-subscribes to `session.frames` and clears the current result.
- The old pipeline is disposed before anything is re-subscribed, so a frame still in flight can't emit (the pipeline emits nothing after `dispose`, as `camera-capture` specified). The camera session's generation is untouched, so the camera isn't restarted.
- The translator is rebuilt too, because its model availability and "reported once" sets are per translator. A new target gets fresh reports, which is what the user would expect.

This follows the plan's "close translators when settings change".

**D4. `onError` receives every `LiveTranslateException`.** That covers both camera start failures (which also still replace the preview with the error) and the pipeline's `errors` stream. Week 1's `debugPrint` for pipeline errors is removed.

**D5. `TranslatedTextPainter` in `overlay_painter.dart` replaces `DebugBoxPainter`.**
- **Input:** `List<OverlayLabel>`, an internal immutable value of `(Rect rect, String text)`, built only for translations that aren't null (spec: untranslated lines are left visible). It also takes `OverlayStyle style` and `TextDirection textDirection`.
- **Per label:**
  1. Draw a rounded rectangle (`RRect.fromRectAndRadius(rect, Radius.circular(style.borderRadius))`) filled with `style.backgroundColor`.
  2. Take the inner rectangle: `style.padding.deflateRect(rect)`.
  3. Choose a font size with `fitFontSize` (D6).
  4. Lay out a `TextPainter` with `maxLines: 1`, `ellipsis: '…'`, the style's colour and weight, and `textDirection`, using the inner width as `maxWidth`.
  5. Paint it vertically centred in the inner rectangle, starting from the start edge for `textDirection`.
- **Repainting:** `shouldRepaint` compares the labels, style and direction, so the painter repaints only when one of them changes.

**D6. Font fitting is a separate pure function: `double fitFontSize({required String text, required Size inner, required OverlayStyle style, required TextDirection direction})`.**
- The upper bound is `min(style.maxFontSize, inner.height / lineHeightFactor)`, using the measured height of one line at size 1 times the size, so it's exact for the font in use.
- It binary-searches whole sizes between the minimum and that bound for the largest size whose single-line width fits `inner.width`. That's about 5 layouts instead of up to 18 per label.
- If nothing fits, it returns `style.minFontSize`, and the painter ellipsises the text.
- Tests use the default test font (FlutterTest: each glyph is one font size wide and a line is one font size tall), so expected sizes can be worked out by hand.

**D7. Text direction comes from the target language.** `textDirectionFor(TranslateLanguage)` returns `TextDirection.rtl` for Arabic, Hebrew, Persian and Urdu, and `ltr` otherwise. The view passes it to the painter. *Alternative:* use the ambient `Directionality`. Rejected because an English-language app translating into Arabic would lay out Arabic left to right.

**D8. Example debug screen.**
- `LiveTranslateView(targetLanguage: english, scripts: {latin, devanagari}, sourceLanguages: _hindiOnly ? {hindi} : null, cameraLensDirection: _lens, onError: _showError)`.
- A `FilterChip` "Hindi only" switches the hint, and the existing button switches cameras.
- `_showError` shows a `SnackBar` with a friendly message. For `ModelNotDownloaded(language)` that's "Downloading the <name> model over Wi-Fi…".
- The `implementation_imports` ignore stays until the view is exported.

**D9. Files.** The changed files are `pipeline/pipeline.dart`, `view/live_translate_view.dart` and `view/overlay_painter.dart`. New are `view/text_fit.dart` (`fitFontSize`, `textDirectionFor`) and an engines record typedef in `view/live_translate_view.dart`. Tests are updated in `test/pipeline/pipeline_test.dart`, `test/view/live_translate_view_test.dart` and `test/view/overlay_painter_test.dart`, with a new `test/view/text_fit_test.dart`.

**D10. Downloads need a confirmed language (added after the first exit-check run; narrowed by D11).**

*Problem:* with "Hindi only" off, the Latin reader turns Devanagari into gibberish lines, and language ID sometimes assigns those to unrelated languages at ≥ 0.5 confidence. Under `translation-engines` D6, each such language immediately started a ~30 MB Wi-Fi download, and the author saw several downloads while pointing at Hindi text. The bar for *translating* a line is right at 0.5, but the bar for *downloading* must be higher. The user chose option 1 of three; the other two were "download only hinted languages" and "both".

*Rule:*
- `chooseSourceLanguage` returns the chosen `LanguageGuess` (tag and confidence) instead of only the tag.
- A line assigned from a single hinted language gets confidence 1.0.
- `LineTranslator` counts frames: each `translateLines` call is one frame. For each language it remembers the frame numbers in which it was assigned at ≥ 0.8, counting at most once per frame.
- A language is confirmed when at least 3 of those frame numbers fall within the last 10 frames.

*Per-language model state:* `unknown`, `checking`, `available`, `missing` (checked, not downloaded and not yet downloading) or `downloading`.
- A `missing` language isn't checked again every frame.
- A missing source model starts downloading only when its language is confirmed and no other source download is running.
- The target model is chosen by the app, not detected, so it downloads as soon as it's found missing.
- A failed download returns the language to `missing`. Its frame numbers are kept, so if it's still confirmed, the next frame retries.

*Why these thresholds:* garbage rarely scores 0.8 in three frames. A real sign held in view is confirmed in about 0.6 s at 5 frames a second. The 10-frame window stops stray hits from piling up over minutes.

**D11. Remove the noise at its source, and download only expected languages (added after the second exit-check run).**

*Problem:* D10 assumed noise is unstable from frame to frame. On the device, with "Hindi only" off, models still downloaded and "Can't translate" messages kept arriving for `hi-Latn`, `la` and other tags. With the phone held still, the Latin reader turns the *same* Devanagari text into the *same* gibberish every frame, so the noise passed D10's confirmation. The user chose option A + B.

*A, overlap filter in `MultiScriptTextEngine`:* when Latin and a non-Latin script are both selected, a Latin-reader line is dropped if a non-Latin-reader line covers at least half of its box (the intersection area divided by the Latin box's area). The ratio is measured against the Latin line, not as intersection over union, because gibberish boxes are often a different size from the real line.
- If the Devanagari reader also reads English, as ML Kit documents for non-Latin recognizers, the English line still appears through it.
- If it doesn't, the Latin line doesn't overlap any Devanagari line and is kept.

So the filter is safe either way, and the exit check shows which case the devices are in.

*B, download only expected languages:* in `LineTranslator`, a missing *source* model downloads automatically only when its language is in `sourceLanguages` **and** confirmed (D10's rule). With no hint, or for a confirmed language outside the hint, a missing model is reported once with `ModelNotDownloaded`, and the app decides whether to call `TranslationModels.download`. The target model still downloads at once, because the app chose it.

*Re-checking missing models:* a model found missing is checked again once 10 frames have passed since its last check. A model the app downloads itself, for example after seeing `ModelNotDownloaded`, is then picked up within about 2 seconds, at the cost of at most one platform call per missing language every 10 frames.

*Unsupported reports:* sightings are now kept per language tag (a `String`) rather than per `TranslateLanguage`. `UnsupportedLanguagePair` is reported once per tag, and only once the tag is confirmed, so one stray `hi-Latn` reads as nothing.

*Example:* the `ModelNotDownloaded` message says "Downloading … over Wi-Fi" only for languages that will download (English, or Hindi with "Hindi only" on). Otherwise it says the model isn't on the device yet.

**D12. A single hint must match the line's script, and no-op translations draw nothing (added after the third exit-check run).**

*Problem:* on the Samsung with "Hindi only" on, Hindi paragraphs translated correctly. But the browser's address bar and tab titles, which are Latin text, also got labels, because a single hinted language skips identification and was assigned to every line. Short Devanagari words that the model returned unchanged ("दवयी", "एला") got labels repeating themselves.

*Script check:* `scriptOf(TranslateLanguage)` returns `TextScript.devanagari` for Hindi and Marathi, `TextScript.latin` for the 37 Latin-script languages in ML Kit's list, and `null` for the rest. `hasLetterOf(String, TextScript)` uses `RegExp(r'\p{Script=Devanagari}', unicode: true)` or `\p{Script=Latin}`. Under a single hint, a line without a letter of the hinted language's script gets no source language. Identification still isn't run, so this costs no extra platform calls. A mixed line such as "दवा 500mg" still qualifies, and languages in scripts the package can't read skip the check.

*No-op labels:* the view drops a `LineTranslation` whose `translatedText`, normalized like the cache key (trimmed, whitespace collapsed), equals the line's text. It happens in the view, where labels are built, so the translation data stays faithful to what ML Kit returned.

## Risks / Trade-offs

- [Translations flicker while text is read slightly differently in each frame (a cache miss leaves the line untranslated for that frame)] → Accepted until Week 3's tracking reuses translations per tracked line. The exit check is done with the phone held still.
- [With no `sourceLanguages`, automatic detection never downloads a source model, so a first-time user sees untranslated text until the app downloads models] → An intended trade-off (D11 B): predictable data use matters more for an embeddable package. The README recipe for Hindi signage sets `sourceLanguages`, and the 0.2 example adds a model manager screen.
- [Labels jump slightly as the camera moves, because each processed frame brings fresh boxes from ML Kit] → Expected until Week 3's tracking and smoothing (plan §5, the third hard problem). Confirmed as observed during the first exit-check run.
- [The first Hindi translation waits for a ~30 MB download over Wi-Fi] → The example shows the `onError` snackbar. The exit check notes whether the phone was on Wi-Fi.
- [Translating inside the throttled run lowers the frame rate] → Measured in Week 5 against the plan's 3–5 updates per second. The cache makes repeated frames cheap.
- [Rebuilding the pipeline mid-frame could drop one frame] → Harmless. Settings changes are rare.
- [Font tests using the test font don't prove readability on a device] → The exit check covers how it looks on the phones.

## Open Questions

- Does ML Kit report the English model as always downloaded, or will the first run also download English? **Still unanswered:** the final exit-check report didn't say whether an English download message appeared. It doesn't affect correctness, because `LineTranslator` downloads a missing target at once and treats a present one as available. Carried forward to the Week 5 performance and size measurements.

## On-device results

The exit check was run on 2026-10-11 with the example debug screen, on Wi-Fi, with the back camera over Hindi text. It took four runs. Each of the first three found a problem that this change then fixed: D10 after the first run, D11 after the second, and D12 after the third. The final run, after D12:

| Check | Samsung Galaxy, Android 15 | iPhone 14, iOS 26.6.1 |
|---|---|---|
| "Hindi only" off: no stray downloads; only English downloads, and at most "The hindi model isn't on this device yet." | Pass | Pass |
| "Hindi only" off: no stream of "Can't translate…" messages | Pass | Pass |
| "Hindi only" on: English labels over each Hindi line | Pass | Pass |
| "Hindi only" on: no labels on Latin text (URL bar, tabs) | Pass | Pass |
| Labels sit on their lines with the phone held still | Pass | Pass |
| Long translations shrink or end in "…" | Pass | Pass |

Evidence: the author reported that every check passes on both devices. A Samsung screenshot from the third run, before D12, already showed correct English over each Hindi paragraph, labels shrinking or ending in "…", and the Latin-text problem that D12 fixed.

Labels still jump slightly while the phone moves, as expected until Week 3's tracking and smoothing.
