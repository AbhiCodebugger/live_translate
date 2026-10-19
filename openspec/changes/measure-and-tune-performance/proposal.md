# Proposal

## Why

1.0 promises measured performance and a documented size impact in the README, and neither has been measured yet. The §10 budget (no dropped UI frames, labels following every frame, under ~800 ms from steady to labels, under ~500 ms per read on a mid-range Android phone, flat memory) is still a list of targets. Reading the code shows likely costs nobody has checked. Every frame where held labels move by a pixel or more, the view rebuilds, and the label painter fits each label's font size again with repeated text layouts. The motion estimate runs on the UI thread for every frame. The replay benchmark reads photos of about 960 × 1280, which is larger than the frames the camera actually streams, so its times overstate a live read.

## What Changes

- **Measurement tooling**
  - The debug HUD shows how long the per-frame work on the UI thread takes (the motion estimate), as the mean and worst over the last second. Jank can then be traced to the package or ruled out on the phone itself.
  - The replay test reads each frame several times while warm and reports the median and worst of each stage. It also benchmarks each frame at the camera's streamed size (long side 720 on Android, 640 on iOS, as `ResolutionPreset.medium` delivers), next to the full photo.
  - Host micro-benchmarks for the motion estimate, colour sampling and label painting, tagged so the normal test run skips them. They are for before/after comparisons, not published numbers.
  - A size-impact script builds the example app's release APK (arm64) and iOS app with Latin only and with Devanagari, plus a bare Flutter app as a baseline, and prints a table.
- **Tuning that doesn't change behaviour, from reading the code**
  - Label painting keeps each label's fitted font size and text layout from frame to frame. A held label that only moves with the camera is not fitted again, and drawing it looks exactly the same.
  - The motion estimate reads its thumbnail without allocating per sample.
  - Colour sampling computes each sample's luminance once instead of inside the sort comparator.
- **Device measurements (run by the user, on the Samsung Galaxy and the iPhone 14)**: a baseline before tuning, the same again after tuning, a DevTools frame and memory profile over a 2-minute scan, and the size builds.
- **Tuning gated on the numbers**: if a stage misses its budget after the safe tuning, its fix is decided from the measurements and folded into this change with `/opsx:update` before it is built. Possible fixes include the recognizers' frame handling, the capture resolution, or the settle time. Nothing that changes behaviour is decided now.
- **README**: a measured performance table (device, OS, build mode, stage medians, steady to labels, UI frame cost, memory), a size impact table, and how to reproduce both. The "Measuring performance" section mentions the HUD's new frame-cost line.

Out of scope: the 1.0.0 version bump and publishing, the demo video, the FAQ and comparison sections, `ARCHITECTURE.md`, moving work to isolates or native code unless the measurements call for it, and new public API.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `live-view`: the debug HUD also shows the mean and worst per-frame UI-thread time of the last second.

## Impact

- `lib/src/view/live_translate_view.dart`, `lib/src/view/debug_hud.dart`: time the per-frame work and show it in the HUD.
- `lib/src/view/paragraph_painter.dart` (plus a layout cache owned by the view state): reuse fitted layouts across frames.
- `lib/src/motion/motion_estimator.dart`, `lib/src/still/colour_sampler.dart`: fewer allocations and repeated computations on the hot paths.
- `example/integration_test/replay_test.dart`, `example/integration_test/replay/`: repeated warm reads, stream-size frames, summary statistics in the reported data.
- New `test/benchmark/` (tagged `benchmark` in `dart_test.yaml`) and a size script under `tool/`.
- `README.md` (performance, size impact, measuring), `CHANGELOG.md` (Unreleased).
- No public API change, and no new dependencies.
