# Proposal

## Why

The overlay is redrawn from scratch for every processed frame. ML Kit's boxes shift slightly each time, so labels jump while the phone moves. A line misread in one frame ("Exlt" for "Exit") misses the translation cache and loses its label for that frame, so labels flicker. A line that drops out for a single frame vanishes instead of fading. The exit-check runs for `translated-overlay` showed exactly this. It's the third of the plan's three hard problems (§5, "flicker"), and the plan's Week 3 exit check is a 30-second recording that looks smooth.

## What Changes

- **Line tracker** (`lib/src/tracking/`), pure Dart:
  - **Matching:** each frame's lines are matched to the previous tracks by box overlap (IoU ≥ 0.3), with text similarity breaking ties. Matched lines keep their ID; new lines get a new one.
  - **Smoothing:** each tracked box is an exponential moving average of its recent boxes (α = 0.5).
  - **Fade:** a track missing from a frame fades over 3 processed frames (opacity 2/3, then 1/3), then is removed. It returns to full opacity if seen again.
  - **Translation reuse:** a tracked line keeps its translation while its text stays similar (similarity ≥ 0.8), and only changes it when the text changes meaningfully.
  - **Reset:** all tracks are dropped when the frame's size, rotation, mirroring or session generation changes, for example after rotating the phone or switching cameras.
- **Pipeline:** the tracker runs after translation, and `PipelineResult` carries tracked lines (ID, smoothed box, text, language, translation, opacity) instead of raw per-frame translations.
- **Public model in use:** the view now produces `TranslatedLine` values (plan §4.3) for every tracked line with a translation. They hold a stable `id`, a `rect` mapped into the view, and an `opacity`. They aren't exposed to apps yet; that comes with the controller in `live-controller`.
- **Painter:** draws `TranslatedLine`s and applies each one's opacity to its background and text, so fading lines fade on screen.
- **On-device exit check:** a 30-second screen recording on both phones, panning slowly across Hindi text with "Hindi only" on, looks smooth with no flicker.

## Capabilities

### New Capabilities
- `tracking`: following each line of text across frames: stable identity, smoothed position, fading when lost, reusing a line's translation, and resetting when the frame geometry changes.

### Modified Capabilities
- `overlay-rendering`: labels are drawn with their line's opacity, so a line that has left the frame fades out instead of vanishing.

## Impact

- **New code:** `lib/src/tracking/` (`iou.dart`, `text_similarity.dart`, `smoothing.dart`, `line_tracker.dart`) and matching tests.
- **Changed code:**
  - `lib/src/pipeline/pipeline.dart` (tracking stage; `PipelineResult.lines`)
  - `lib/src/view/live_translate_view.dart` (builds `TranslatedLine`s)
  - `lib/src/view/overlay_painter.dart` (draws `TranslatedLine` with opacity; `OverlayLabel` removed)
  - their tests, and the golden image if it changes
- **Public API:** unchanged. `TranslatedLine` was already exported and only starts being produced internally.
- **Dependencies:** none.
- **Out of scope:**
  - `LiveTranslateController`, freeze, torch, and exposing lines to apps (`live-controller`);
  - metrics and the HUD (`pipeline-metrics`);
  - skipping translation for tracked lines to save platform calls (measured in `pipeline-metrics` first);
  - rotated boxes (1.1+).
