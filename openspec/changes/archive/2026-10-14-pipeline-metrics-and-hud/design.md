# Design

## Context

See proposal.md for the motivation. `Pipeline.read` converts the frame, recognises text, groups paragraphs, calls `LineTranslator.translateLines` (language detection, model checks, cache, translation) and samples colours per paragraph inside the list that builds the `ReadResult`. The view runs reads through `_read`, which drops any result whose token is stale and only then shows it. The controller learns what the view shows through internal top-level functions (`publishToController`, `attachController`) and has no streams yet. The view already takes an `@internal` `now` clock for the settler, and the tests drive it by hand.

## Goals / Non-Goals

**Goals:**
- Timings that tests can check exactly, using the same injected clock the settler uses.
- Turning the HUD on doesn't rebuild the whole view on every frame.

**Non-Goals:**
- Timing the settle wait or measuring "steady to labels" directly. It is the fixed ~300 ms settle time plus the read total, and the README says so.
- Splitting translation into detection and translation. They run interleaved per paragraph inside `translateLines`, so separate timings would need the translator's internals threaded through. One stage is enough for the budget.
- Metrics for reads that fail or are superseded.
- An `onMetrics` callback on the view. The controller stream is the planned API, and the HUD covers the no-controller case.

## Decisions

**D1. The pipeline times its stages with an injected clock.**

`Pipeline` takes an optional `DateTime Function() now`. It reads the clock at the start, after recognition (which includes `toInputImage`), and after `translateLines`. Around each `sampleColours` call it reads the clock again and adds the time to the sampling total. It reads the clock once more at the end. Negative differences are clamped to zero. The durations travel on `ReadResult` as an internal `ReadTimings` record (`recognition`, `translation`, `sampling`, `total`), so no public type depends on `ReadResult`.

The view passes `widget.now` when given. Otherwise it passes a monotonic clock built from a `Stopwatch`, so wall-clock jumps can't distort the timings. The settler keeps `DateTime.now`, since it only compares nearby instants.

Alternative: `Stopwatch` inside the pipeline. Rejected: widget and unit tests couldn't control it, and every timing assertion would become a range.

**D2. The view builds `PipelineMetrics` and reports it after the frame.**

When `_read` accepts a result (current token, no error), it creates `PipelineMetrics(recognition, translation, sampling, total, paragraphs: result.paragraphs.length, frozen: _frozen)`. It stores it as `_latestMetrics` (for the HUD) and as `_pendingMetrics`. The post-frame report step from the last change publishes `_pendingMetrics` to the controller through a new internal `publishMetrics(controller, metrics)` and then clears it. That way an event never comes before the result it describes is on screen. `_scheduleReport` already runs whenever there is a controller.

Stale reads return before this point, failed reads throw before it, and keeping labels on freeze never calls `_read`. Each of those emits nothing, as the spec requires.

**D3. The controller owns a broadcast stream.**

`LiveTranslateController` gets `final _metrics = StreamController<PipelineMetrics>.broadcast()` and `Stream<PipelineMetrics> get metrics`. `publishMetrics` adds an event only while a host is attached and the stream is open. The controller overrides `dispose()` to close the stream before calling `super.dispose()`. A broadcast stream lets the HUD-less app, a benchmark harness and DevTools logging listen at once, and needs no buffering, since metrics are only useful live.

**D4. The HUD reads from a notifier, not from the view's `build`.**

`debug_hud.dart` holds an internal `DebugHud` widget built from a `ValueListenable<DebugHudData>`, where `DebugHudData` is `({PipelineMetrics? latest, int framesPerSecond})`. It is wrapped in `IgnorePointer`, `SafeArea` (so it clears the status bar and notches when the view fills the screen, as on-device testing showed) and `Align(alignment: Alignment.topLeft)` with 8 px padding, in white monospace text on `0x99000000`. It shows three lines:

```
read 214 ms (frozen)
ocr 120 · translate 80 · colours 10
1 paragraph · 30 fps
```

Before the first read, the first line is `no read yet` and the second is left out.

The view owns the notifier only while `showDebugHud` is true, and creates or drops it in `didUpdateWidget`. In `_onFrame`, the view records the arrival time of each live frame it measures (the frames that pass the running, not-frozen and current-generation check) in a queue, drops entries older than 1 s, and updates the notifier. A 500 ms periodic `Timer`, running only while the HUD is on, recomputes the count, so the rate falls to 0 when frames stop, such as while frozen. In the `Stack`, the HUD goes last, above the labels or overlay and the frozen-read indicator. It isn't built in the placeholder or error branches.

Alternative: put the fps in the view's own state. Rejected: it would call `setState` on the whole camera stack 30 times a second.

**D5. `PipelineMetrics` lives in `lib/src/pipeline/pipeline_metrics.dart`.**

It is a `final class` with a const constructor, `==`, `hashCode` and a `toString()` like `PipelineMetrics(total: 214 ms, recognition: 120 ms, translation: 80 ms, sampling: 10 ms, paragraphs: 1, frozen: false)`. It is exported by name.

## Testing approach

- **Pipeline:**
  - A manual clock that the test advances while the fake text and translate engines are held at their gates. Recognition and translation come out exact.
  - A clock that ticks 5 ms per call checks the sampling sum over two paragraphs.
  - An empty read checks the zero stages.
- **Controller:** a unit test for multiple listeners, the unattached state, and closing on dispose.
- **View:** widget tests through the controller for the emission scenarios, reusing the `callbacks` group's freeze helpers.
- **HUD:**
  - Widget tests read the HUD's text. Its key is internal and its finder is in the test support.
  - The frame rate comes from `deliver`, which already advances the clock 33 ms per frame.
  - The 0 fps case advances the clock and pumps the 500 ms timer.

## Risks / Trade-offs

- **[Timer left running in tests]** → The timer exists only while the HUD is on, and is cancelled in `dispose` and when the HUD is turned off. A widget test that leaves it running fails with "A Timer is still pending", which guards this.
- **[`paragraphs` counts translations equal to their source]** → The view hides those labels, so the count can be one higher than the labels shown. It is documented on the field. The number is about the read's work, not the screen.
- **[Translation timing includes model checks]** → Documented on the field. The first read after a language switch looks slow for that reason, and that is worth seeing.

## Migration Plan

Additive. The CHANGELOG's `## Unreleased` section gets the new entries, and the version stays 0.1.0 until the release change.
