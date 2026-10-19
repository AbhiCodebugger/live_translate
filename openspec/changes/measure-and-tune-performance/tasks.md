# Tasks

Device steps (groups 5 and 7) are run by the user on the Samsung Galaxy and the iPhone 14. Claude prepares the builds and the commands, and records the results.

## 1. Host benchmarks

- [x] 1.1 Add a `benchmark` tag to `dart_test.yaml`, skipped by default with a reason naming `flutter test --tags benchmark --run-skipped`; verify `flutter test` and `flutter test --coverage --exclude-tags golden` skip it and the CI commands still pass
- [x] 1.2 Add `test/benchmark/hot_paths_benchmark_test.dart`, timing (after a warm-up, over many iterations) `MotionEstimator.measure` on synthetic 720 × 480 NV21 and 640 × 480 BGRA frames for each rotation, `sampleColours` for 5 paragraph boxes, and `ParagraphPainter.paint` for 5 labels over 60 frames whose rects shift by 1–3 px; verify it prints µs per operation when run with the command from 1.1
- [x] 1.3 Create `openspec/changes/measure-and-tune-performance/measurements.md` with sections for host benchmarks, size, the device baseline and the final pass, and record the host baseline from 1.2 (machine, Flutter version); verify the file has the baseline numbers

## 2. Per-frame cost in the debug HUD

- [x] 2.1 Time `_onFrame`'s motion estimate and settler decision with the view's clock while the HUD is on, keep the durations in the one-second window beside `_frameTimes`, and add the mean and worst to `DebugHudData` (design decision 2); verify with new `test/view/live_translate_view_test.dart` cases for every scenario of "Debug HUD shows the per-frame cost", using a clock that advances per call, and that the existing HUD tests pass
- [x] 2.2 Render the cost in `DebugHud.linesFor` as `N fps · frame A.A ms avg, W.W max` (just `N fps` with no frames); verify with `test/view/debug_hud_test.dart`
- [x] 2.3 Mention the frame-cost line in the README's "Measuring performance" section (what it covers, that it excludes reads and painting, and what over 8 ms means for a 60 Hz screen); verify the README matches the HUD's text

## 3. Replay benchmark

- [x] 3.1 Add a stream-size option to `buildReplayFrame` in `example/integration_test/replay/frame.dart`, decoding the photo with its long side scaled to 720 (Android) or 640 (iOS); verify with a host test in `example/test/` that a 960 × 1280 photo gives a 540 × 720 NV21 frame and a 480 × 640 BGRA frame
- [x] 3.2 In `replay_test.dart`, do one cold read and 5 warm reads at full size and 5 warm reads at stream size, keep assertions on full size only, and report `warm` and `stream` (median and max per stage, `stream.passed`) and a `summary` (median across frames for cold, warm and stream) in `binding.reportData`, with a summary row in the printed table; verify `flutter analyze` is clean in `example/` and the header comment documents the `flutter drive --profile` command and the new fields

## 4. Size impact

- [x] 4.1 Write `tool/size_impact.sh` per design decision 8 (temporary copies of `example/` with and without Devanagari, a bare `flutter create` baseline, arm64 split APK, `Runner.app` zipped and unzipped, Markdown table with differences, nothing in the checkout touched); verify `git status` is clean after a run
- [x] 4.2 Run the script and record the table, Flutter version and date in `measurements.md`; verify every cell has a number
- [x] 4.3 Add a "Size impact" section to the README (the table, what each column measures, that App Store download sizes differ because of app thinning, how to rerun it) and link it from "Platform setup → Latin only"; verify the numbers match `measurements.md`

## 5. Device baseline (user)

- [x] 5.1 User: run the replay benchmark in profile mode on both phones (`flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/replay_test.dart -d <device>` in `example/`) and share `build/integration_response_data.json`; Claude records the summaries, device models and OS versions in `measurements.md`; verify both devices' summaries are recorded
- [x] 5.2 User: run the example app in profile mode with the HUD on and, on each phone, note 10 reads' totals and stages while holding over printed text, plus the frame-cost line while holding and while panning slowly; Claude records the medians; verify the readings are in `measurements.md`
- [x] 5.3 User: on the Samsung, record a DevTools frame chart (janky frames while holding and panning, and whether any jank shows package frames) and the memory view over a 2-minute scan (heap at start and end, and the trend); Claude records them; verify the observations are in `measurements.md`

## 6. Safe tuning

- [x] 6.1 Add `LabelLayoutCache` (fit memo plus an LRU of about 64 laid-out `TextPainter`s, disposing evictions, cleared on style change, disposed with the view) and pass it through `ParagraphPainter`, `placeParagraphLabels` and `fitParagraphFontSize` as an optional parameter (design decision 3); verify `paragraph_painter_test.dart`, `text_fit_test.dart` and the `paragraph_labels.png` golden pass unchanged, a new test shows a repaint of shifted labels makes no new layouts, a change to each key field makes a new layout, and the painter benchmark from 1.2 improves (record it in `measurements.md`)
- [x] 6.2 Build the motion thumbnail from a cached `Int32List` of raw byte offsets per frame shape (design decision 4); verify a new `motion_estimator_test.dart` case matches the old per-sample thumbnail for all four rotations and both formats, existing motion and settler tests pass, and the motion benchmark improves (record it). *Outcome: built and checked bit-identical, but the benchmark didn't improve (thumbnail reading is a small part of the cost; the shift search dominates), so it was reverted. Recorded in `measurements.md` and design decision 4.*
- [x] 6.3 Compute each colour sample's luminance once (design decision 5); verify `colour_sampler_test.dart` passes unchanged and the sampling benchmark improves (record it)
- [x] 6.4 Run `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test --coverage --exclude-tags golden` and `flutter test --tags golden`, and check coverage of `geometry/`, `live/`, `motion/`, `still/`, `cache/` and `pipeline/` is still at least 90%; verify all pass and record the coverage in `measurements.md`

## 7. Final device pass and budget check (user)

- [x] 7.1 User: repeat 5.1–5.3 on the tuned build; Claude records the results next to the baseline; verify `measurements.md` has before and after for every item
- [x] 7.2 Check each budget line in design decision 7 against the Samsung's final numbers and write the verdict per line in `measurements.md`; verify each line says pass or miss, with the evidence

## 8. Gated tuning (only for lines that missed in 7.2)

- [x] 8.1 For each missed line, find the cause from the stage timings or the profile and fold a fix into this change with `/opsx:update` (spec delta, design note and its own tasks) before building it; if every line passed, write "no gated tuning needed" in `measurements.md`; verify either the updated artifacts validate with `openspec validate measure-and-tune-performance` or the note is recorded

## 9. Performance docs

- [x] 9.1 Add a "Performance" section to the README: a table per device (model, OS, profile mode, package version, date) with the replay medians at stream size (recognition, translation, sampling, total), steady to labels (300 ms settle plus the live median total), the HUD frame cost, janky frames attributable to the package and the memory trend, plus how to reproduce each number, and note that replay frames are photos; verify every number matches the final pass in `measurements.md` and the README states the Samsung's real tier
- [x] 9.2 Add an Unreleased CHANGELOG entry (HUD frame cost, faster label repaint and motion estimate, README performance and size sections); verify `dart pub publish --dry-run` is clean

## Workflow follow-up

- Archive the change once the README numbers are reviewed.
- Tick the Week 6 measurement items in `PLUGIN_PLAN.md` (local only, never committed).
