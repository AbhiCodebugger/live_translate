# Proposal

## Why

Freezing now gives a calm, Lens-like result. Live translation still reads every frame, so labels re-render with every small movement of the phone: boxes shift, translations change as the text is read slightly differently, and lost lines fade in place. Better tracking can only smooth this; the cause is reading every frame. Lens's live mode looks still because it reads once when the camera settles, then keeps that result stuck to the page.

## What Changes

- **Live mode settles, reads once and holds:**
  - Every frame is used only to measure how the picture moves: a cheap global shift and change estimate from a small brightness thumbnail.
  - When the picture has been steady for about 300 ms, the view reads that frame exactly as freezing does: every selected script, whole paragraphs, page colours.
  - While holding, frames aren't read again. Labels move with the measured shift, so small hand movements keep them on their text.
  - A fast movement or a new scene fades the labels out. Once the camera settles again, it reads again.
  - After a slower pan that moved the picture well away from the last read, the view reads again once steady. The shifted labels stay until the new result replaces them.
  - When a model that the last read lacked finishes downloading, the held view is read again.
- **Freezing** keeps the held labels when the picture hasn't moved since they were read, so tapping the shutter on a held view changes nothing visible. Otherwise it reads the frozen frame as today.
- **Long paragraphs confirm their language at once:**
  - With reads only every few seconds, "3 of the last 10 frames" would mean the user has to settle three times before a detected language's model downloads.
  - A language identified with confidence 0.8 or more on a paragraph of at least 20 letters now counts as confirmed immediately.
  - Short texts keep the old rule.
- **Removed** (the package hasn't been released, and the view isn't exported yet, so nothing external breaks):
  - line-by-line live labels, their one-line painter and the font fitting;
  - the line tracker;
  - the per-frame pipeline and its frame throttle;
  - the view's `minFrameInterval` parameter;
  - recognizers taking turns between scripts: every read uses every selected script.
- **`OverlayStyle` colours become the fallback** for labels whose page colours can't be sampled. `maxFontSize` is no longer used by any label (see design).

## Capabilities

### New Capabilities
- `live-translation`: when the live view reads (after the picture settles), how held labels follow small movements, when they fade out, when the view reads again (after a pan, a new scene or a completed download), and how reads never queue.

### Modified Capabilities
- `still-translation`: freezing keeps held labels when the picture hasn't moved since they were read.
- `controller`: freeze follows the rule above; `lines` holds the held paragraphs while running.
- `live-view`: scripts are read together instead of in turns; a settings change reads the held view again.
- `recognize`: turn-taking is removed; every read uses every selected script; recognizers are created on the first read.
- `capture`: the frame-dropping and minimum-interval requirements are replaced by "reads never queue" and "a failed read doesn't stop live translation".
- `overlay-rendering`: one-line live labels are removed; paragraph labels fade by opacity; the style's colours are the fallback.
- `translate`: long paragraphs confirm their language at once.
- `tracking`: every requirement removed, because the hold-and-shift behaviour in `live-translation` replaces line tracking.

## Impact

- **Code:**
  - new: `lib/src/motion/` (thumbnail, shift and change estimate) and `lib/src/live/` (the settle, read and hold state machine);
  - `lib/src/pipeline/` (a single `read(frame)`, plus a callback when a model is ready);
  - `lib/src/engines/multi_script_text_engine.dart` (one read mode);
  - `lib/src/pipeline/line_translator.dart` (long-paragraph confirmation);
  - `lib/src/view/` (the live flow, fading, freeze rule);
  - removed: `lib/src/tracking/`, `TranslatedTextPainter`, `fitFontSize`, `FrameThrottle`;
  - matching tests.
- **Public API:** no exported symbol changes. `TranslatedLine.opacity` now carries the paragraph fade. `OverlayStyle`'s colour fields change meaning (fallback only), and `maxFontSize` goes unused. Both are noted for the 0.1.0 API review.
- **Example app:** no code change expected. Its tests deliver frames that are now steady, so labels appear after the settle time.
- **Dependencies:** none.
- **Out of scope:**
  - following zoom, tilt or rotation (these count as a new scene and trigger a re-read);
  - optical flow per paragraph (one global shift moves all labels);
  - a full-resolution photo capture.
