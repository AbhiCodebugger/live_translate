# Design

## Context

See proposal.md for the motivation and the specs for behaviour.

What exists now (after `still-frame-translation`):

| Piece | Where | Fate |
|---|---|---|
| `Pipeline.onFrame` → `FrameThrottle` → `TextEngine.recognize` (one script per turn) → `LineTranslator.translateLines` → `LineTracker.update` → `PipelineResult` | `lib/src/pipeline/`, `lib/src/tracking/` | removed |
| `Pipeline.readStill(frame)` → `recognizeAll` → paragraphs → `translateLines` → `sampleColours` → `StillResult` | `lib/src/pipeline/pipeline.dart`, `lib/src/still/` | becomes the only read: `Pipeline.read(frame)` |
| `TranslatedTextPainter`, `fitFontSize` | `lib/src/view/overlay_painter.dart`, `text_fit.dart` | removed (`textDirectionFor` stays) |
| `ParagraphPainter` with clipping and growth | `lib/src/view/paragraph_painter.dart` | used for all labels, plus opacity |
| View: `_lastFrame`, read tokens, freeze → `_readStill` | `lib/src/view/live_translate_view.dart` | generalised into the live flow |
| Language confirmation: 3 sightings at ≥ 0.8 in the last 10 `translateLines` calls | `LineTranslator._sight` / `_isConfirmed` | plus immediate confirmation for long texts |
| Colour mapping upright → raw | private `_toRaw` in `lib/src/still/colour_sampler.dart` | shared with the motion thumbnail |

Frames arrive at the camera rate (about 30 per second), with nv21 or bgra8888 single-plane buffers already copied into Dart.

## Goals / Non-Goals

**Goals:**
- Labels stay still while the phone is held, follow small drifts, and never re-render from a re-read unless the picture changed.
- Motion measurement costs under 2 ms per frame in profile mode on the test phones, so it can run on every frame on the UI isolate.
- Every scenario in the deltas is a unit or widget test. Motion and settling are pure Dart, tested with synthetic frames and a fake clock.

**Non-Goals:**
- Per-paragraph motion, zoom, tilt or rotation following (one global translation only).
- Moving motion estimation to an isolate (only if profiling shows jank).
- Revisiting `OverlayStyle`'s fields (noted for the 0.1.0 API review).

## Decisions

**D1. Motion from a normalised brightness thumbnail (`lib/src/motion/motion_estimator.dart`).**
- Each frame becomes an upright thumbnail whose long side is 64 samples (for example 36 × 64 for a portrait 720 × 1280 frame).
  - It is sampled at raw positions through the upright → raw mapping now shared from `colour_sampler.dart` as `uprightToRaw`.
  - Brightness is Y for nv21, and 0.299R + 0.587G + 0.114B for bgra8888.
  - The thumbnail's mean is subtracted, so exposure changes don't look like motion.
- `MotionEstimator.measure(frame) → Motion(shift, change)` compares with the previous frame's thumbnail, coarse to fine:
  - a half-size thumbnail is searched ±6 samples;
  - the best match is refined at full size ±2 around twice the coarse shift;
  - the score is the mean absolute difference over the overlapping area.
- One sample is 20 frame pixels at 1280, too coarse for a 1% steady threshold or smooth label motion. So the best whole-sample offset is refined to a fraction of a sample with a parabola through the scores either side, and the change is measured again at that fractional shift by bilinear interpolation. Without this, a 7 px drift read as 0 with a change of 9.5. With it, drifts are measured within about 2 px, and their leftover change stays at 6.5 or below.
- `shift` is that offset in upright frame pixels, as how far the content moved. `change` is the smaller of the whole-sample and fractional scores (0–255).
- The first frame, or a frame of a different size or rotation, gives `Motion.unknown`, which counts as moving.

Cost is about 600 × 169 + 2 300 × 25 ≈ 160 k absolute differences plus 2 300 samples per frame, well under a millisecond in AOT.

Alternatives:
- Phase correlation needs an FFT, more code for no gain at this size.
- ML Kit gives no motion.
- Per-paragraph optical flow is out of scope.

**D2. Thresholds, as named constants in `lib/src/live/live_settler.dart`, to be tuned on the device:**
- steady: |shift| < 1% of the upright frame width and `change` < 10;
- new scene: |shift| > 8% of the width, or `change` > 18;
- measured on synthetic texture: a drift leaves a change of 6.5 or below, an exposure change 0, and a different scene 24–28. Real camera noise and sharper real texture are tuned on the device.
- settle time: 300 ms;
- pan re-read: accumulated |dx| > 10% of the width or |dy| > 10% of the height;
- freeze keeps the result: accumulated shift < 2% in both directions;
- fade: 200 ms.

**D3. `LiveSettler`, a pure state machine with an injected clock.**

```
            steady >= 300 ms                     read done
 [moving] ----------------------> [reading] ---------------> [holding]
    ^  ^                             |  ^                     |  |
    |  +----- new scene (fade) ------+  |  steady >= 300 ms,  |  |
    |                                   +- moved > 10% -------+  |
    +-------------------- new scene: fade out -------------------+
```

Its interface:
- `onFrame(now, motion, frameSize) → SettleAction`, one of `none`, `read` or `clear`;
- `readStarted()`, `readFinished(success)`;
- `offset`: the shift accumulated since the frame being read or held, which keeps accumulating during a read;
- `canKeepOnFreeze`.

A read finishing in `moving` (a scene change during the read) is discarded by the view. A failed read returns to `moving`, so the next settle reads again.

**D4. One read path: `Pipeline.read(frame) → Future<ReadResult?>`.**
- `ReadResult` is `StillResult` renamed, plus `untranslatedLanguages`: the source tags of paragraphs left without a translation, collected before they're dropped.
- `Pipeline` loses `onFrame`, `results`, the throttle and the tracker. It keeps `errors`, and gains `modelsReady`, a stream of languages whose download `LineTranslator` finished (a new `onModelReady` callback).
- `TextEngine.recognize` now reads every script; `recognizeAll` is folded into it. `MultiScriptTextEngine` runs its engines in parallel and merges with the existing filters, dropping `_latest` and `_turn`.

**D5. Long texts confirm at once.** In `LineTranslator`, a guess at ≥ 0.8 whose text has at least 20 letters (`\p{L}`) adds the tag to `_confirmedNow`, and `_isConfirmed` returns true for those tags. The per-script competition still applies, so a long Marathi-labelled paragraph doesn't beat a script whose sightings are mostly Hindi.

**D6. View flow.** The view keeps:
- `_shown`: the `ReadResult` plus the anchor frame it came from;
- `_reading`: the read token from `still-frame-translation`;
- an `AnimationController` for opacity, with a `TickerProviderStateMixin`.

Each frame (not frozen) goes `MotionEstimator.measure` → `LiveSettler.onFrame`:
- `read`: start `pipeline.read(frame)` with a new token, and remember the frame as the pending anchor;
- `clear`: animate opacity to 0 over 200 ms, then drop `_shown`.

When a read completes with the current token, `_shown` is replaced, opacity is set to 1, and the settler is told. Labels map each paragraph box offset by `settler.offset`, using the result's mapper. The controller's `lines` are published with those rectangles and the current opacity. `setState` runs only when the offset changed by at least 0.5 view pixels, or on state changes, so held labels don't rebuild on every frame.

**D7. Freeze.**
- If `settler.canKeepOnFreeze` and `_shown != null`: pause the session and keep `_shown` and the offset.
- Otherwise: run the existing `_readStill(_lastFrame)` path, with a progress indicator.

Settings changes re-read `_shown`'s anchor frame, whether running or frozen. `modelsReady(language)` re-reads the anchor when `_shown.untranslatedLanguages` contains its tag.

**D8. Removed code and parameters.**
- removed: `minFrameInterval`, `FrameThrottle`, `LineTracker`, `TrackedLine`, `PipelineResult`, `TranslatedTextPainter`, `fitFontSize`, `labelTextStyle`, and their tests;
- `normalizeLineText` stays (cache and label filtering).

`OverlayStyle.backgroundColor` and `textColor` become the colours for a paragraph whose frame couldn't be sampled: `sampleColours` returns null instead of `fallbackColours`, and the view substitutes the style's. `maxFontSize` stays in the public type but no label uses it. The dartdoc says so, pending the 0.1.0 API review.

**D9. Tests use synthetic motion.**
- Package test fakes gain frames with a textured brightness pattern at a given offset (`texturedImage(dx, dy)`), so the estimator can be driven. A wholly different pattern stands in for a new scene.
- The view gets `@visibleForTesting now` for the settler's clock.
- The example fakes emit the same textured frames. Tests advance the injected clock instead of waiting real time where possible.

## Risks / Trade-offs

- [Labels now appear 300 ms after settling plus the read time (about 0.5–1.5 s at `high`), instead of flickering in at once] → This matches Lens's behaviour. The on-device check judges it.
- [Thresholds tuned on one page and one phone may misjudge a shaky hand or a low-texture scene] → They are named constants. A blank wall has no texture, so its shift is 0 and it counts as steady, which is harmless because nothing is there to read.
- [Global shift only: when the phone tilts, labels at the edges drift off their text] → Tilting shows up as a strong change and fades the labels. Gentler tilts drift until a pan re-read.
- [Auto-focus hunting blurs frames and raises `change`] → A brief fade and re-read at worst. The brightness normalisation absorbs exposure changes.
- ["Models downloaded by the app are noticed within 10 frames" now means 10 reads, which can be minutes apart while holding] → An app download completes through `TranslationModels`, not the translator, so `modelsReady` doesn't fire. Accepted: the next read picks it up. Revisit if the example's download flow needs it.
- [Removing line-by-line live mode is a behaviour change the plan didn't foresee] → The package isn't released, and the view isn't exported. The plan's "line tracking and smoothing" item is superseded and should be noted in the private plan.
- [`OverlayStyle.maxFontSize` is unused] → Documented, and left for the API review rather than broken now.

## On-device results

Checked by the user on 2026-10-12 in live mode over the French page: they reported that everything looks fine. That covers:
- no labels while sweeping;
- held, page-coloured paragraph labels after holding still;
- labels following a slow drift;
- re-reading after a pan;
- fading on a quick swing;
- the shutter keeping a held view.

The device wasn't named; earlier checks in this series were on the Samsung Galaxy. No timings or threshold adjustments were reported, so the D2 constants stay as measured on synthetic frames.
