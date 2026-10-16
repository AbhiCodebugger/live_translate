# Tasks

## 1. Harness support (host-tested)

- [x] 1.1 Add `integration_test` (SDK) and `image` to the example's `dev_dependencies`. Add `example/integration_test/replay/frame.dart` with `buildReplayFrame` (design D1). Verify with `example/test/replay_support_test.dart`:
  - a 4×2 PNG of known colours gives the expected NV21 Y and VU bytes, and BGRA in the right order;
  - a 5×3 image is cropped to 4×2;
  - the frame's rotation is `deg0` and its `CameraImage` reports the right raw format and size.
- [x] 1.2 Add `example/integration_test/replay/manifest.dart` (`ReplayManifest.parse`) and `example/integration_test/replay/matching.dart` (normalising and expectation matching, design D2 and D3). Verify with host tests for:
  - a valid manifest;
  - an unknown language code failing with the file name;
  - a fragment passing despite punctuation and case;
  - the wrong language failing;
  - a translation equal to its source failing;
  - a keyword match;
  - the failure message listing every paragraph read.

## 2. Frame preparation

- [x] 2.1 Add `example/tool/prepare_replay_frames.dart` (design D6). Verify by running it on a test photo with EXIF orientation and GPS data, made in the scratchpad with `package:image`. The output must be upright, at most 1280 px on its longer side, and have empty EXIF. The script must warn about a file over 300 KB.
- [ ] 2.2 **Needs the user's photos.** The user puts about 15 photos (design D8) in a folder and shares the path. Run the script on them into `example/assets/replay_frames/`. Draft `frames.json` by viewing each prepared photo: 1–3 expectations per frame with short distinctive fragments. Declare the folder under `flutter: assets` in `example/pubspec.yaml`. Verify that the folder totals at most 3 MB, that `ReplayManifest.parse` accepts `frames.json` (a host test loads the real file), and that every `file` exists.

## 3. Integration test

- [x] 3.1 Add `example/integration_test/replay_test.dart` (design D4 and D5) and `example/test_driver/integration_test.dart`. Verify that `flutter analyze` in `example/` reports no issues and that `flutter test` in `example/` (host only) still passes. Running it on a device is the user's step, below.

## 4. Docs

- [x] 4.1 Add a "Replay tests" section to `example/README.md`:
  - what the tests check;
  - how to add a frame (photo rules: public text only; the script command; manifest fields);
  - how to run them: `flutter test integration_test/replay_test.dart -d <device>` for correctness, and `flutter drive --profile …` for timings and the JSON report.

  In `README.md`, add one sentence on replay tests where the example app section mentions testing, or leave `README.md` unchanged if nothing there is affected. Verify that the commands in the docs match the files added.

## 5. Integration check

- [ ] 5.1 Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` at the package root and in `example/`, and `flutter pub publish --dry-run` at the root. The package must still validate and stay well under pub's size limit, with the frames included. Verify that all pass.

## Workflow follow-up

- On-device run by the user on both phones:
  - `cd example && flutter test integration_test/replay_test.dart -d <device>`, and share the output or failures, so I can adjust fragments that are too strict;
  - then the `flutter drive --profile` command, which gives the timings for the performance numbers.
- After both phones pass, add the replay run to the private `RELEASE.md` checklist.
- Archive the change once reviewed.
