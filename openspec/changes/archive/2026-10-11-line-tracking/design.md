# Design

## Context

See proposal.md for the motivation. What exists now:
- `Pipeline` emits `PipelineResult(translations: List<LineTranslation>, imageSize, rotation, mirror, generation)` once per processed frame (`lib/src/pipeline/pipeline.dart`).
- `LiveTranslateView` maps every translated line's box through `CoordinateMapper` into an internal `OverlayLabel(rect, text)`. It skips untranslated lines and translations equal to their line.
- `TranslatedTextPainter` draws the labels.
- The public `TranslatedLine` (`id`, `sourceText`, `translatedText`, `sourceLanguage`, `rect`, `opacity`) has been exported since `bootstrap-package` but nothing produces it.
- `translation_cache.dart` already has `normalizeLineText` (trim and collapse whitespace).
- The `tracking/` folder in plan §6 doesn't exist yet.

From the Week 3 exploration: track in upright frame coordinates, and reset on geometry or generation changes. This is the first of three changes: `line-tracking`, then `live-controller`, then `pipeline-metrics`.

## Goals / Non-Goals

**Goals:**
- Each spec scenario is a unit test against the pure tracker. A matching test sets the overlap and similarity thresholds so the spec's numbers hold exactly.
- ≥ 90% line coverage on `lib/src/tracking/` and `lib/src/pipeline/` (plan §9).
- A visibly smooth 30-second recording on both phones.

**Non-Goals:**
- Optimal (Hungarian) assignment: greedy assignment is enough for a few dozen lines per frame (plan §8).
- Velocity prediction or Kalman filtering.
- Skipping translation for tracked lines. The tracker runs *after* translation, so the cache still absorbs repeats. Whether to skip is decided with real numbers in `pipeline-metrics`.
- Exposing `TranslatedLine`s to apps (`live-controller`).

## Decisions

**D1. The tracker lives in the pipeline, after translation.** It's `Pipeline → LineTracker.update(frameKey, List<LineTranslation>) → List<TrackedLine>`, and `PipelineResult.translations` becomes `lines: List<TrackedLine>`.

`TrackedLine` is internal and immutable: `id`, `box` (smoothed, upright frame coordinates), `sourceText`, `sourceLanguage`, `translatedText?` and `opacity`.

Keeping the tracker in the pipeline keeps the view a pure mapper and painter. It also means `live-controller` can read lines from the pipeline, and the tracker has no Flutter dependency beyond `dart:ui`'s `Rect`. Each view builds its own pipeline (and rebuilds it on settings changes), so it gets a fresh tracker for free.

*Alternative:* track in the view, in screen coordinates. Rejected because tracks would then depend on layout size, and the frame geometry the view sees can lag behind.

**D2. Frame key and reset.** `FrameKey` is a record `(Size imageSize, ImageRotation rotation, bool mirror, int generation)`. If it differs from the last frame's key, `update` clears every track before matching. That covers rotating the phone (rotation and/or upright size change), switching cameras (generation, mirror) and resuming from the background (generation).

**D3. Matching is greedy over scored pairs.**
- For every pair of (previous track, new line) with IoU ≥ 0.3, the score is `iou + 0.1 × textSimilarity`.
- Pairs are sorted by score, descending, and taken greedily, skipping any track or line already used.
- The 0.1 weight means text only decides between overlaps that differ by less than 0.1 (the spec's "near-ties"), while a clearly better overlap still wins.

`iou(Rect, Rect)` returns 0 for empty or disjoint boxes and is pure. IDs come from a per-tracker counter, prefixed `t` (`t1`, `t2`, …), unique for the tracker's lifetime.

**D4. Text similarity: `textSimilarity(a, b) = 1 − levenshtein(a', b') / max(|a'|, |b'|)`,** where `x' = normalizeLineText(x).toLowerCase()`, and two empty strings count as 1. Levenshtein uses two rolling rows, O(n·m) time and O(m) memory. Lines are short (under 100 characters), so this is cheap at a few dozen lines per frame. It's measured over UTF-16 code units, which is exact for Latin and Devanagari as recognised (no surrogate pairs).

**D5. Smoothing: `lerpRect(old, new, 0.5)`, edge by edge.** It lives in `smoothing.dart` with `const smoothingFactor = 0.5`. The plan says to tune α on video, so the factor is a named constant in one place.

**D6. Fade.** Each track keeps `missed` (0 to 3). An unmatched track gets `missed += 1`, `opacity = 1 − missed / 3`, and is removed when `missed == 3`. A matched track gets `missed = 0` and `opacity = 1`. A faded track keeps its last smoothed box, which is still used for matching, so a briefly hidden line comes back with the same ID.

**D7. Translation reuse,** in the matched branch:
- similarity(track.sourceText, line.text) ≥ 0.8 → keep `sourceText` and `translatedText`. If the track has no translation and the line has one, adopt it.
- Otherwise → take the line's text, language and translation, possibly `null`.

The source text deliberately stays the one that produced the translation, so the label and its source stay consistent.

**D8. The view builds `TranslatedLine`s; the painter draws them.**
- For each `TrackedLine` with a translation that isn't a no-op (the existing `normalizeLineText` comparison), the view builds `TranslatedLine(id, sourceText, translatedText, sourceLanguage, rect: mapper.mapToView(box), opacity)`.
- `TranslatedTextPainter(lines: List<TranslatedLine>, style, textDirection)` replaces `OverlayLabel`, which is deleted.
- The painter skips lines at opacity 0 and multiplies the background and text colour alpha by the opacity (`color.withValues(alpha: color.a * opacity)`).
- `shouldRepaint` compares the lists (`TranslatedLine` has value equality), the style and the direction.
- The golden test's lines are fully opaque, so the image shouldn't change. Re-approve it only if a pixel differs, and record why.

**D9. Files (from plan §6):** `lib/src/tracking/iou.dart`, `text_similarity.dart`, `smoothing.dart` and `line_tracker.dart` (`LineTracker`, `TrackedLine`, `FrameKey`). Tests go in `test/tracking/`.

## Risks / Trade-offs

- [Smoothing adds lag: with α = 0.5 a label covers half the remaining distance each processed frame, so it trails by about 2 frames (~400 ms at 5 fps) during fast pans] → It's a trade-off for stability, and the plan says to tune α on video. Record what the recording shows, then adjust the constant if needed.
- [A faded track can be wrongly matched by a different line moving into its old place] → It's limited to 3 frames, and the 0.8 similarity check replaces the translation if the text differs.
- [Greedy matching can mis-assign in dense paragraphs where lines overlap neighbours by less than 0.3] → Lines in a paragraph rarely overlap their neighbours by 0.3. Any mismatch is temporary and fixes itself when the text changes.
- [Tracking after translation still translates misread text, costing a cache miss and a platform call] → Accepted for now (Non-Goals). `pipeline-metrics` measures it.

## On-device results

Exit check on 2026-10-11: the example debug screen with "Hindi only" on and the Hindi model downloaded, recording about 30 seconds of holding still over Hindi text, panning slowly across it, then moving away and back.

| Check | Samsung Galaxy, Android 15 | iPhone 14, iOS 26.6.1 |
|---|---|---|
| Labels stay put when the phone is still (no jumping) | Pass | Pass |
| Labels don't flicker on and off for lines that stay in view | Pass | Pass |
| Labels follow slow pans smoothly | Pass | Pass |
| Lines leaving the view fade out instead of vanishing | Pass | Pass |

Evidence: the author's report that every check passes on both devices. No recordings were attached.

Smoothing factor: the author reported no lag problem, so `smoothingFactor` stays at 0.5. Revisit it when the HUD and metrics in `pipeline-metrics` make the update rate visible.
