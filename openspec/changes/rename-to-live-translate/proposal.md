# Proposal

## Why

The package is called `live_translate_overlay`, but its job is live translation, and the overlay is just how it shows the result. The shorter `live_translate` is easier to find and type, and it's free on pub.dev. Nothing has been published yet, so renaming now costs only an edit. After 0.1.0 it would mean abandoning one pub.dev package for another.

## What Changes

- **BREAKING** (pre-release only): **package name** `live_translate_overlay` becomes `live_translate`.
  - The entry library `lib/live_translate_overlay.dart` becomes `lib/live_translate.dart`.
  - Apps import `package:live_translate/live_translate.dart`.
  - Every package test import and every example import follows.
- **Example app** `live_translate_overlay_example` becomes `live_translate_example`:
  - pubspec name and its dependency on the package;
  - Android `namespace` and `applicationId` become `dev.ranjan.live_translate_example`, with the Kotlin `MainActivity` package and folder moved;
  - the iOS bundle ID becomes `dev.ranjan.liveTranslateExample`, and its test target `dev.ranjan.liveTranslateExample.RunnerTests`;
  - the app's label under the icon becomes **Live Translate** on both platforms.
  (The IDE's `.iml` module files aren't tracked; the IDE regenerates them.)
- **GitHub repository:** the user deleted `AbhiCodebugger/live_translate_overlay` and starts a fresh repository, `AbhiCodebugger/live_translate`, from a new `git init` (earlier history isn't carried over). The change updates:
  - `repository` and `issue_tracker` in `pubspec.yaml`;
  - the README's demo GIF URL;
  - the new repository's `origin` remote.
- **Docs:** README (title, install command, imports, link to the setup), CHANGELOG, and the example's README.
- **README iOS note** (added on request): ML Kit for iOS comes through CocoaPods, so Flutter's Swift Package Manager warning for the `google_mlkit_*` plugins is expected. SPM support is planned for 1.1.
- **Specs:** the `public-api` purpose and requirements name the new package and library.
- Not changed:
  - class names (`LiveTranslateView` and the rest already match);
  - the local folder, already `live_translate`;
  - archived OpenSpec changes, which are history;
  - the private plan file is renamed in prose only.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `public-api`: "Single entry library" and "Dependency types are re-exported" name `live_translate` and `package:live_translate/live_translate.dart`.

## Impact

- **Files:** 53 tracked files mention the old name: `pubspec.yaml`, `lib/live_translate_overlay.dart` (renamed), 40 package test files, 13 example files (lib, tests, pubspec, lockfile, Android Gradle, manifest and Kotlin path, iOS project and `Info.plist`, README), README and the `public-api` spec.
- **Public API:** the import path changes. No symbol changes.
- **Devices:** with new app IDs, the example installs beside the old one on both phones; the old app can be deleted.
- **Outside the repo:** the user creates `AbhiCodebugger/live_translate` and pushes a fresh history. The old repository is gone, so old links don't redirect; nothing points at them once this change is in.
