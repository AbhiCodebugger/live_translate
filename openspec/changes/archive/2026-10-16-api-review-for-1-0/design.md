# Design

## Context

See proposal.md for motivation. What shapes the approach in the current code:

- The view builds `TranslatedLine`s in `build()` from `_shown.result.paragraphs`, with `id: 'p$i'` and `rect: place(paragraph.box)` plus the shift. Ids therefore come from list position and are rebuilt every frame.
- `_shown` holds the result and the frame it came from. `_shift` is how far the picture has moved since that frame, in upright frame pixels, and the mapper scales frame pixels to the view uniformly.
- `freeze()` sets `_shown = null` before reading the last frame, and a clear (new scene or fast movement) drops `_shown` once the fade ends. A settings change keeps `_shown` and re-reads its frame.
- `_startSize` in `paragraph_painter.dart` is `max(floor(lineHeight × 0.8), ceil(minFontSize))`. `maxFontSize` is only checked by an assert.
- Target and scripts are "effective settings" in the view state (the latest of widget and controller wins). `sourceLanguages` is read straight from `widget`.

## Goals / Non-Goals

**Goals:**
- Ids that survive every re-read of the same scene, assigned once per shown result rather than per frame.
- A rename with no aliases and nothing left over, so 1.0 has one name for one concept.

**Non-Goals:**
- Matching paragraphs by text. OCR jitter and a new target change the text, but the position doesn't.
- Deprecation shims or a migration tool. The package is pre-1.0 with one published preview, so the CHANGELOG mapping is enough.

## Decisions

### 1. Hard rename, file included
`TranslatedLine` becomes `TranslatedParagraph`, in `lib/src/models/translated_paragraph.dart`. The controller's `lines` becomes `paragraphs`, and `onLinesChanged` becomes `onParagraphsChanged`. `OverlayBuilder` keeps its name and gets a `paragraphs` parameter. `onFrozen` keeps its name. The fields stay the same.
- **Why:** A `@Deprecated` typedef plus duplicate getters and parameters would have to be removed again at 1.0, which is another breaking change, and they'd keep both names in the docs in the meantime.
- **Alternative:** Rename only the type and keep `lines`. That leaves `controller.lines` returning paragraphs, which is the same mismatch at a different spot.

### 2. Ids are assigned when a result is shown, by overlap
The view keeps `_shownIds`, parallel to `_shown.result.paragraphs`, and a counter `_nextId` for the life of the state; ids are `p<n>`. It also keeps `_previous`: the shown paragraphs' ids and boxes, moved by their shift into the current picture's frame coordinates. When a read's result is shown:
1. Move each new paragraph's box by the shift since its own frame (`_settler.pendingOffset`, or the frozen shift).
2. List every (new, previous) pair whose intersection is at least half the smaller box's area, sorted by intersection area, largest first. Take pairs whose new and previous paragraphs are both still free.
3. Matched paragraphs take the previous id. The rest take `p${_nextId++}`.

The match runs in upright frame pixels rather than view coordinates. Both rectangles of a pair go through the same uniform scale and offset, so the overlap share is the same, and no layout is needed inside `_read`.
- `_previous` is captured from what is shown just before the result changes. `freeze()` captures it before clearing `_shown`, so a freeze that reads still matches.
- A clear (when the fade starts), a camera start or stop, and `resume()` empty `_previous`. A settings change keeps it.
- **Why "half the smaller area":** a heading that grows or shrinks by a few pixels between reads still matches. Two side-by-side paragraphs don't, since they barely overlap.
- **Alternative:** IoU ≥ 0.5. It fails when a paragraph's recognized box changes size a lot between reads, for example when OCR merges a line into it.

### 3. `maxFontSize` caps the starting size
`_startSize = max(min(floor(lineHeight × 0.8), floor(maxFontSize)), ceil(minFontSize))`. The assert `minFontSize <= maxFontSize` keeps the order valid. Its doc comment explains the cap, and the README notes that large headings now stop at 28 by default.
- **Alternative:** Raise the default so today's look stays the same. You chose to keep 28. A 50-high heading's label drops from 40 to 28, which is the visible change of this proposal.

### 4. Source languages become effective state
The view gets `_sourceLanguages`, set in `initState` from the widget. In `didUpdateWidget` it changes only when the widget's value changes, exactly like `_scripts`. `ControllerHost` gains `setSourceLanguages(Set<TranslateLanguage>?)`. Equal sets, including both null, are a no-op; otherwise `_replacePipeline()`. The pipeline uses `_sourceLanguages` in place of `widget.sourceLanguages`.

## Risks / Trade-offs

- [Every app on 0.1.0 or 0.2.0 must rename] → The CHANGELOG lists each old name next to its new one. This lands before 1.0, after which renames are not allowed.
- [Overlap matching can give a paragraph a new id after a large pan, or hand an id to a different paragraph that moved into its place] → Ids are a convenience for keys and animations, not a guarantee of identity. The docs say they stay the same "while the same paragraph is read in the same place".
- [The smaller default label size for big headings] → It's documented, and apps can raise `maxFontSize`.

## Migration Plan

Apps rename `TranslatedLine` to `TranslatedParagraph`, `controller.lines` to `controller.paragraphs` and `onLinesChanged` to `onParagraphsChanged`, and set `OverlayStyle(maxFontSize: …)` if they want large headings bigger. Nothing else changes. The version bump happens in the release, outside this change.
