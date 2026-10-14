# Tasks

## 1. Metrics value and pipeline timing

- [x] 1.1 Add `lib/src/pipeline/pipeline_metrics.dart` with `PipelineMetrics` (design D5), with dartdoc on every field. The doc says that `translation` includes detection and model checks, and that `paragraphs` counts every translated paragraph, including ones the view hides because they equal their source. Verify with a new `test/pipeline/pipeline_metrics_test.dart` covering the "PipelineMetrics is an immutable value" scenarios.
- [x] 1.2 Add the internal `ReadTimings` record to `ReadResult`, and the optional `now` clock to `Pipeline`, timing each stage as design D1 describes. Verify with new cases in `test/pipeline/pipeline_test.dart`:
  - "Stage timings": a manual clock advanced 120 ms while `FakeTextEngine.gate` is held and 80 ms while the translate engine's gate is held gives recognition 120 ms and translation 80 ms;
  - sampling: a clock ticking 5 ms per call over two paragraphs gives a positive sampling time, the sum of the per-paragraph spans, and a total at least the sum of the stages;
  - "Nothing to translate": translation and sampling are zero.

  Existing pipeline tests must still pass.

## 2. Controller stream

- [x] 2.1 Add `metrics` and the internal `publishMetrics` to `LiveTranslateController`, and close the stream in `dispose` (design D3). The dartdoc on `metrics` has a short listening example. Verify in `test/controller/live_translate_controller_test.dart`: two listeners get the same event, an unattached controller emits nothing on `publishMetrics`, and the stream is done after `dispose`.

## 3. View reports metrics

- [x] 3.1 In the view, pass `widget.now` or a `Stopwatch`-based clock to the pipeline, build `PipelineMetrics` in `_read` and publish it from the report step (design D2). Verify with one widget test per "Metrics are reported for each shown read" and "A read's metrics describe its result" scenario in `test/view/live_translate_view_test.dart` (new `group('metrics')`): settled read, holding still, failed read, superseded read (French then German, with the text engine's gate held), freezing a held view, live read of two paragraphs, and frozen read. Existing view tests must still pass.

## 4. Debug HUD

- [x] 4.1 Add `lib/src/view/debug_hud.dart` (`DebugHud`, `DebugHudData`) as design D4 describes. Verify with `test/view/debug_hud_test.dart`: "no read yet" with the fps line, the three lines for a read with 120/80/10 ms, `(frozen)` for a frozen read, singular and plural "paragraph", and a 40 px top inset that puts the panel below the status bar.
- [x] 4.2 Add `showDebugHud` to the view, with the frame-arrival queue, the notifier and the 500 ms timer, placing the HUD last in the stack (design D4). Its dartdoc says it is for development. Verify with one widget test per "Debug HUD" scenario: off by default, before the first read, after a read (a fake clock advanced inside the engines' gates), 29–31 fps from `deliver`, 0 fps after two seconds frozen, without a controller, above an `overlayBuilder`, and not while the camera starts. Check that no timer is left pending after the view is removed.

## 5. Public API and docs

- [x] 5.1 Export `PipelineMetrics` by name from `lib/live_translate.dart`. Extend `test/public_api_test.dart` to build a `PipelineMetrics`, read `controller.metrics`, and pass `showDebugHud: true`, through the entry import only. Verify that the test passes.
- [x] 5.2 Update `README.md`:
  - a features bullet;
  - a "Measuring performance" recipe that listens to `controller.metrics` and turns on `showDebugHud`, explaining each stage and that "steady to labels" is the ~300 ms settle time plus `total`;
  - "Debug HUD" in the controller recipe's closing sentence where it fits.

  Add `PipelineMetrics`, `controller.metrics` and `showDebugHud` entries under `## Unreleased` in `CHANGELOG.md`. Verify each new Dart block by pasting it into a throwaway `example/lib/readme_check.dart`, checking that `flutter analyze` in `example/` reports no issues, and deleting the file.

## 6. Integration check

- [x] 6.1 Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` at the package root and in `example/`, and `openspec validate pipeline-metrics-and-hud --strict`. Verify that all pass.

## Workflow follow-up

- On-device check by the user: turn on `showDebugHud` in the example app temporarily, and read the HUD on both test phones.
- Archive the change once reviewed.
