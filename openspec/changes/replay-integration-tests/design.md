# Design

## Context

See proposal.md for the motivation. The live view hands `Pipeline.read` a `CameraFrame`: a `CameraImage` with one plane (NV21 on Android, BGRA on iOS), its `ImageRotation` and a generation. `toInputImage` and `sampleColours` accept exactly those two single-plane formats. `mlKitEngines()` in `live_translate_view.dart` builds the real engines. The example's tests already build `CameraImage.fromPlatformInterface` frames and import `src/` with `implementation_imports` ignored. CI runs `flutter analyze` and `flutter test` in `example/`, which don't execute `integration_test/`. No device is attached to CI.

`LineTranslator` downloads a missing source model only after the language is confirmed over several reads. With every needed model downloaded up front, a single read translates fully.

## Goals / Non-Goals

**Goals:**
- Exercise everything after the camera exactly as the app does: conversion, every selected recogniser, grouping, language ID, translation and colour sampling.
- Assertions that hold across ML Kit model updates.
- Per-frame timings for both a cold and a warm read, ready to feed the README's performance table.

**Non-Goals:**
- Camera capture, rotation and motion. Replay frames are upright (`ImageRotation.deg0`), and rotation and motion are covered by unit tests.
- Exact translation text. It changes with model updates.
- Running on CI, which has no device. Firebase Test Lab or a device farm could come later.
- The settle/hold behaviour of the live view. Replay calls the pipeline directly.

## Decisions

**D1. Photos become stream-format frames in the test.**

`buildReplayFrame(Uint8List jpeg, TargetPlatform platform)` works in four steps:
1. Decode the photo with `ui.instantiateImageCodec`.
2. Read its RGBA bytes with `toByteData(format: rawRgba)`.
3. Crop to even width and height, because NV21 chroma is subsampled 2×2.
4. Convert:
   - **Android:** NV21. BT.601 full-range Y per pixel, then interleaved V,U averaged over each 2×2 block. `raw: 17` (`ImageFormat.NV21`), bytes per row equal to the width.
   - **iOS:** BGRA. A per-pixel byte swap, `raw: 1111970369` (`kCVPixelFormatType_32BGRA`), bytes per row equal to the width × 4.

The result is wrapped as `CameraFrame(rotation: deg0, generation: 1)`.

Alternative: `InputImage.fromFilePath`. Rejected: it bypasses `toInputImage` and the colour sampler, which read the camera formats, and those are exactly the parts a plugin bump could break.

**D2. A manifest describes what a correct read contains.**

`example/assets/replay_frames/frames.json`:

```json
{
  "frames": [
    {
      "file": "hi_exit_sign.jpg",
      "note": "Red EXIT/निकास sign, station platform",
      "target": "en",
      "scripts": ["latin", "devanagari"],
      "sourceLanguages": null,
      "expect": [
        { "source": "निकास", "language": "hi", "translation": ["exit"] }
      ]
    }
  ]
}
```

- `target` and `language` are BCP-47 codes.
- `sourceLanguages` is null to detect languages, or a list of codes.
- `translation` is optional: any one keyword must appear in the translation.

`ReplayManifest.parse` validates the codes against `TranslateLanguage` and `TextScript`, and fails with the file name on any mistake.

**D3. Matching is tolerant of OCR noise.**

Text is normalised to lowercase with whitespace collapsed and these characters dropped: `.,:;!?'"()«»“”‘’-–—`. An expectation passes when one paragraph of the read meets all of these:
- its normalised source text contains the normalised `source` fragment;
- its `sourceLanguage` equals `language`;
- its translation is non-empty and differs from its source after normalising;
- if `translation` keywords are given, its normalised translation contains at least one.

Each failure message names the frame, the expectation, and every paragraph actually read, so a failing run is diagnosable from the log alone. Fragments are kept to 1–3 distinctive words when writing the manifest.

**D4. Each frame runs through a fresh pipeline, cold then warm.**

`setUpAll` collects every `target` and expected `language` and downloads each model with `TranslationModels().download(language, wifiOnly: false)`, with a 5-minute timeout per model. It reports the time taken separately.

Per frame, the test builds one `Pipeline` with `mlKitEngines()` for the frame's `target`, scripts and source languages. It reads the frame twice:
- the **cold** read: the first recognition and translation after the engines are built;
- the **warm** read: recognisers warm, translations cached, like a held view read again after a small pan.

It asserts on the warm read and records `PipelineMetrics`-shaped timings from both. It then closes all engines. A fresh pipeline per frame stops one frame's language sightings from helping the next.

**D5. Results are printed and reported.**

The test prints a table: frame, paragraphs, and cold/warm recognition, translation, sampling and total in ms. It also sets `IntegrationTestWidgetsFlutterBinding.reportData` to `{"platform", "device", "frames": [...]}`.

`example/test_driver/integration_test.dart` uses `integrationDriver()`. With it, `flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/replay_test.dart` writes `build/integration_response_data.json`. Profile mode gives timings fit for the README. `flutter test integration_test` runs in debug, which is fine for correctness.

**D6. The frame preparation script uses `package:image`, only in the example's dev dependencies.**

`dart run tool/prepare_replay_frames.dart <photo>... [--name base]` does the following for each photo:
1. Decode it and apply the EXIF orientation (`bakeOrientation`).
2. Clear all EXIF data, including location.
3. Resize so the longer side is 1280 px.
4. Encode it as JPEG at quality 75 into `assets/replay_frames/`. Quality 80 put the first 14 photos, taken of a screen, over 3 MB; 75 keeps the text sharp.
5. Print the size, and warn if a file is over 300 KB or the folder is over 3 MB.

The package itself gains no dependency.

**D7. Host tests cover the device-free parts.**

`example/test/replay_support_test.dart` imports the harness from `../integration_test/replay/` and checks:
- conversion: a 4×2 image of known colours, painted with `ui.PictureRecorder` and encoded to PNG, becomes NV21 with the expected Y and VU values, and BGRA in the right byte order;
- odd sizes are cropped to even;
- manifest parsing, and its error on an unknown language;
- matching: a fragment with OCR-ish punctuation passes, the wrong language fails, and a translation equal to its source fails.

These run in CI with the rest of the example's tests.

**D8. The frame set is chosen for coverage.**

About 15 photos:

| Coverage | Count |
|---|---|
| Hindi signs (one with a short single word) | 4 |
| Marathi | 1 |
| Mixed Devanagari and English boards | 2 |
| Spanish menus | 2 |
| French pages | 2 |
| German sign | 1 |
| English page with target Hindi | 1 |
| Light text on a dark background (colour sampling) | 1 |
| Dim or low-light picture | 1 |

The user takes the photos. During apply, I prepare them with the script and draft each frame's manifest entry by looking at the photo. The user then confirms the entries on the first device run.

## Risks / Trade-offs

- **[The frames make the example app ~3 MB bigger]** → Flutter has no test-only assets. The size-impact measurement in the next change builds the example without the `assets/replay_frames/` line, and says so.
- **[Photos are sharper than stream frames]** → Downscaling to 1280 px narrows the gap. The dim photo keeps one hard case. Replay is a regression check, not a quality benchmark.
- **[ML Kit updates change what is read]** → Short fragments and keyword-only translation checks keep the tests stable. A genuine drop in quality still fails loudly with the full read in the log.
- **[Personal data in a public repo]** → The proposal limits the photos to public text, and the script strips EXIF, including GPS.
- **[First run needs network and time]** → The model downloads are timed and reported separately. They happen once per device.

## Migration Plan

None. Test tooling only. After the first passing run on both phones, add "run replay tests on both phones" to the private `RELEASE.md` checklist.
