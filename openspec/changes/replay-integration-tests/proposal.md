# Proposal

## Why

Every test today runs on fake engines, so nothing checks that real ML Kit still reads Hindi signs and Latin menus after a plugin bump or a change to grouping, filtering or colour sampling. Each release currently means pointing a phone at signs by hand. The plan calls for replay tests, a set of saved real pictures run through the real pipeline on a device, before each release. They would also give repeatable inputs for the performance numbers that 0.2.0 needs to publish.

## What Changes

- **Replay frames:** 10–20 JPEG photos of real text (Hindi and Latin signs, menus, pages) under `example/assets/replay_frames/`, taken with the phones' camera apps. Each is at most 1280 px on its longer side, has no EXIF data, and is about 200 KB.
- **A manifest** (`frames.json`) gives, for each photo, the target language and scripts to use, and what a correct read must contain. That is, for each expected paragraph: a source-text fragment, its detected language, and optionally translation keywords.
- **A replay harness:**
  - Decodes each photo, converts it to the camera's own stream format (NV21 on Android, BGRA on iOS), and wraps it as a camera frame.
  - Runs it through the real `Pipeline` with the real ML Kit engines, so the frame converter, recognisers, grouping, language ID, translation and colour sampling all run as in the app.
- **An integration test** (`example/integration_test/replay_test.dart`) that downloads the needed models and replays every frame. It checks each expected paragraph was found, its language detected, and its translation produced. It prints each frame's `PipelineMetrics` and reports them through `integration_test`'s report data, for the performance numbers.
- **A frame preparation script** (`example/tool/prepare_replay_frames.dart`) that applies EXIF orientation, resizes, strips metadata and re-encodes a photo for the frame folder.
- **Host unit tests** for the parts that don't need a device: the manifest, the matching rules and the pixel-format conversion.
- **Docs:** a "Replay tests" section in `example/README.md`, on capturing frames and running the tests. A line in the main README's testing notes, if any.

The tests run only on a real device (ML Kit), so CI analyzes them but doesn't run them. Running them is part of the release checklist.

## Capabilities

### New Capabilities

None. This is test tooling, and no package behaviour changes (`skip_specs`).

### Modified Capabilities

None.

## Impact

- **New:**
  - `example/integration_test/replay_test.dart`
  - `example/integration_test/replay/` (frame building, manifest, matching)
  - `example/tool/prepare_replay_frames.dart`
  - `example/assets/replay_frames/` (photos and `frames.json`)
  - `example/test/replay_support_test.dart`
- **Changed:**
  - `example/pubspec.yaml`: dev dependencies `integration_test` (SDK) and `image` (for the script only), and the frames as assets.
  - `example/README.md`
  - `README.md`, only if a testing note fits there.
- **Package code and API:** unchanged.
- **Published package:** grows by the frames, kept under 3 MB in total. They ship with `example/`, so the example still builds from the published package.
- **Privacy:** the repo is public. Photos should show public signage, menus or printed pages only, with no faces or personal details. The script strips EXIF, including location.
