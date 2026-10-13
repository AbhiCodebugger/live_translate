# Tasks

## 1. Package

- [x] 1.1 `git mv lib/live_translate_overlay.dart lib/live_translate.dart`, then apply design D1's replacements to the package: `pubspec.yaml`, `lib/`, `test/`, `README.md`, `CHANGELOG.md` and `.github/`. Set `repository` and `issue_tracker` to the D4 URLs, and the README GIF to the D4 URL. Verify that `flutter pub get`, `flutter analyze` and `flutter test` pass at the root, and that `test/public_api_test.dart` imports only `package:live_translate/live_translate.dart`.

## 2. Example app

- [x] 2.1 Apply D1's replacements to `example/`. `git mv` the Kotlin folder (D2). Set the Android `android:label` and the iOS `CFBundleDisplayName` to `Live Translate`. Run `flutter clean` and `flutter pub get` in `example/` (D3). Verify:
  - `flutter analyze` and `flutter test` pass in `example/`;
  - `flutter build apk --debug` and `flutter build ios --debug --no-codesign` succeed;
  - the built APK's application ID is `dev.ranjan.live_translate_example`, checked with `aapt dump badging` or the merged manifest.

- [x] 2.2 Add a note under the README's iOS setup: ML Kit for iOS comes through CocoaPods, so the Swift Package Manager warning for the `google_mlkit_*` plugins is expected; SPM support is planned for 1.1. Verify the note sits between the real-device line and "Latin only".

## 3. Specs

- [x] 3.1 In `openspec/specs/public-api/spec.md`, change the Purpose line's package name to `live_translate` (a purpose isn't carried by a delta). Verify that `openspec validate public-api --type spec --strict` passes.

## 4. Repository and final check

- [x] 4.1 Verify that `git grep -n -I -e live_translate_overlay -e liveTranslateOverlay -- . ':!openspec/changes/archive'` finds nothing. Run `dart format --set-exit-if-changed .`, and run `flutter pub publish --dry-run` to check that the archive is named `live_translate` (ignoring the uncommitted-files warning).
- [x] 4.2 Once the user has run `git init` and created the empty GitHub repository `AbhiCodebugger/live_translate`: check with `git status` that `PLUGIN_PLAN.md`, `build/`, `coverage/` and `.dart_tool/` aren't listed, and that `.claude/`, `openspec/` and `doc/images/demo.gif` are. Then `git remote add origin https://github.com/AbhiCodebugger/live_translate.git`. After the user's first push, verify that `git ls-remote origin HEAD` answers, and that the README's GIF URL returns 200.

## Workflow follow-up

- After the on-device check (the example installs as "Live Translate"; delete the old app), archive the change and sync `public-api`.
- Update `PLUGIN_PLAN.md`'s name references (it's private, so outside this change's tracked files).
