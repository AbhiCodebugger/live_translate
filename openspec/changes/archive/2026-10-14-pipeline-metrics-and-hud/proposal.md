# Proposal

## Why

The performance budget calls for "one full read under ~500 ms" and "steady to labels under ~800 ms", but the package can't measure either today. Neither can apps that want to know why translation feels slow on a given phone. 0.2.0 promised a `PipelineMetrics` stream for benchmarks and a debug HUD to see the numbers on the device. Both are needed before the real performance numbers can be measured and published in the README.

## What Changes

- **`PipelineMetrics`**: a new exported, immutable value describing one read. It has the time spent recognising text, translating (language detection, model checks and translation), sampling page colours, and in total. It also has the number of paragraphs shown and whether it was a frozen read.
- **`LiveTranslateController.metrics`**: a broadcast `Stream<PipelineMetrics>` with one event per read whose result the view shows. Reads that fail or are superseded emit nothing. It is closed when the controller is disposed.
- **`LiveTranslateView.showDebugHud`**: when `true`, a small panel over the camera shows the latest read's stage timings, the number of paragraphs, and how many camera frames per second the view receives. It is off by default, and it works without a controller.
- **README**: a "Measuring performance" recipe for `metrics` and `showDebugHud`, and a features bullet. **CHANGELOG**: entries in the `## Unreleased` section.

Not in this change: the example app's HUD toggle (example-app polish), replay tests, and publishing measured numbers.

## Capabilities

### New Capabilities

- `pipeline-metrics`: what one read's metrics contain, when they are reported, and how apps receive them through the controller.

### Modified Capabilities

- `live-view`: a new requirement for the debug HUD.
- `public-api`: "Single entry library" also lists `PipelineMetrics`.

## Impact

- **Changed code:**
  - `lib/src/pipeline/pipeline_metrics.dart` (new)
  - `lib/src/pipeline/pipeline.dart` (stage timing with an injectable clock)
  - `lib/src/still/read_result.dart` (carries the timings)
  - `lib/src/controller/live_translate_controller.dart` (`metrics` stream and internal publish function)
  - `lib/src/view/live_translate_view.dart` (reports metrics, counts frames, `showDebugHud`)
  - `lib/src/view/debug_hud.dart` (new)
  - `lib/live_translate.dart` (export `PipelineMetrics`)
- **Tests:** `test/pipeline/pipeline_test.dart`, `test/controller/live_translate_controller_test.dart`, `test/view/live_translate_view_test.dart`, `test/view/debug_hud_test.dart` (new), `test/public_api_test.dart`
- **Docs:** `README.md`, `CHANGELOG.md`
- **Public API:** additive only.
- **Dependencies:** none.
