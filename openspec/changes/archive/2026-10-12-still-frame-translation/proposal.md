# Proposal

## Why

On-device checks against Google Lens showed the gap clearly. With the shutter tapped, our labels still carry live-tracking artefacts:
- ghosts of lines at old positions;
- boxes that creep with every small movement;
- sentences broken into half-line translations;
- black boxes over a white page.

Lens's result looks printed on the page and doesn't move, because after the tap it works from one still picture, translates whole paragraphs, and matches the page's colours. The plan scheduled still-image work and colour sampling for 1.1+. This change brings the tap-to-translate part forward, because freezing is the moment users read a translation closely.

## What Changes

- **Freezing reads the frozen picture once, from scratch.** Tapping freeze pauses the camera as today. The view then reads the last frame it received with every selected script (not taking turns), translates it, and replaces the live labels with the result. No tracker is involved, so nothing drifts, ghosts or fades. While it reads, the live labels are hidden and a progress indicator shows. Resuming discards the result and goes back to live labels.
- **Paragraph translation.** Recognized lines keep the paragraph (ML Kit block) they belong to. In the still result, each paragraph's lines are joined, rejoining words hyphenated at a line end, and translated as one text. The translation is laid out across the paragraph's area at a size close to the original text's line height, shrinking until it fits.
- **Page-coloured labels.** The still result's labels take their background and text colours from the frame: the page colour behind each paragraph and the ink colour of its text. If the sampled pair is hard to read, black or white text is used instead.
- **Settings while frozen.** Changing the target language, scripts or source languages while frozen re-reads the same frozen picture with the new settings.
- **Fixes from the first on-device check** (a French web page on the Samsung):
  - labels stay inside the screen; paragraphs cropped by the camera's fill no longer run off the edge;
  - a label whose translation doesn't fit grows into free space to its right, then below, before its text shrinks, so short headings with longer translations aren't cut to "Where does it co…";
  - a Devanagari misreading of a Latin line no longer replaces the real Latin line, which left lines untranslated (likely cause; confirmed on the next check);
  - lines the recognizer reports as unsure (confidence below 0.5, Android only) are dropped, removing translated junk from blurry areas;
  - the example app streams at `high` resolution, so small print is read more reliably.
- **Live labels are unchanged.** They keep line-by-line translation, tracking and the `OverlayStyle` colours.
- **Example app:** the shutter's frozen state now shows the still result. No example code should be needed beyond the existing freeze/resume. Its spec wording ("current labels kept") is updated.

## Capabilities

### New Capabilities
- `still-translation`: reading a frozen frame once: which frame, all selected scripts, paragraph grouping and joining, translation per paragraph, colour sampling, the progress state, re-reading on settings changes, and discarding on resume.

### Modified Capabilities
- `controller`: "Freeze keeps the current translation still" becomes freeze then show the still result. `lines` then holds one entry per translated paragraph.
- `overlay-rendering`: "Style is applied" now covers live labels only. New requirements cover drawing paragraph labels (reflow, size from line height, ellipsis) in sampled colours, keeping them inside the view, and growing them into free space.
- `recognize`: recognized lines carry their paragraph; a single frame can be read by every selected script at once; a mostly-Latin reading by the Devanagari recognizer no longer replaces a Latin line; unsure lines are dropped.
- `example-app` (from `lens-style-example-ui`): "Shutter freezes and resumes" now shows the still result instead of keeping the current labels.

## Impact

- **Code:**
  - `lib/src/engines/` (text engine interface and ML Kit engine: paragraph IDs; multi-script engine: read all scripts at once);
  - `lib/src/pipeline/` (a still-frame path: paragraph joining and translation);
  - a new `lib/src/still/` (colour sampling and the still result);
  - `lib/src/view/` (keeping the last frame, the freeze flow, the paragraph painter);
  - matching tests and goldens.
- **Public API:** no new or changed exported symbols. `TranslatedLine` is reused for paragraphs: one per paragraph, with the paragraph's rectangle. The dartdoc of `freeze()` changes to describe the new behaviour.
- **Dependencies:** none.
- **Order:** `lens-style-example-ui` and `own-script-lines` should be archived first. This change modifies `example-app`, which only becomes a main spec when `lens-style-example-ui` is archived.
- **Out of scope:**
  - steadier live labels (smarter tracking);
  - capturing a higher-resolution photo instead of reusing the last stream frame (see design);
  - rotated or curved text;
  - a gallery or still-image API (`translateImage`).
