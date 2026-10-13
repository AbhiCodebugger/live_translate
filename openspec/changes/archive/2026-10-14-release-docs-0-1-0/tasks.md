# Tasks

## 1. README v1

- [x] 1.1 Replace `README.md` with the v1 structure in the proposal:
  - one-line pitch and the GIF image (D1 URL);
  - features;
  - install;
  - platform setup for Android and iOS (design Context);
  - quick start;
  - recipes: Hindi signage, freeze with the controller, managing models, handling errors;
  - supported scripts and languages, and model downloads;
  - limitations;
  - how it works (a short settle-read-hold explanation);
  - license.

  Verify per design D2: paste every Dart block into a throwaway `example/lib/readme_check.dart`, check that `flutter analyze` in `example/` reports no issues, then delete the file.
- [x] 1.2 Prove the setup steps on a fresh app (design D3) in the scratchpad: `flutter create`, add the package by `path:`, follow the README literally, paste the quick start. Verify that `flutter build apk --debug` succeeds, and that `flutter build ios --no-codesign --debug` succeeds or fails only for a recorded environment reason. Add to the README any step the build needed; delete the scratch app.

## 2. CHANGELOG and version

- [x] 2.1 Replace `CHANGELOG.md` with a single `## 0.1.0` entry (design D4), and set `version: 0.1.0` in `pubspec.yaml`. Verify that `grep -n "^version:" pubspec.yaml` shows 0.1.0, the CHANGELOG has no "TODO", and `flutter analyze` and `flutter test` at the package root still pass.

## 3. Demo GIF

- [x] 3.1 Add `/doc/images/` to `.pubignore` with a comment (design D1). Verify that `dart pub publish --dry-run` doesn't list `doc/images/` in the archive (read its file tree only; publish nothing).
- [x] 3.2 Ask the user to record the demo from the example app (design D1 guidance) and save it as `doc/images/demo.gif`. Verify the file exists and is under 5 MB, and that the README's image URL ends in `doc/images/demo.gif`.

## Workflow follow-up

- After the user pushes, check that the README's GIF renders on GitHub, then archive the change.
- Tick the README v1 and CHANGELOG/version items in Week 4 of `PLUGIN_PLAN.md`.
