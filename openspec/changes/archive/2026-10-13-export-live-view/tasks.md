# Tasks

## 1. Internal seams

- [x] 1.1 Add `meta: ^1.16.0` to `dependencies` in `pubspec.yaml`. On `LiveTranslateView`, replace `@visibleForTesting` with `@internal` on the `createSession`, `createEngines` and `now` fields and constructor parameters (design D2). Each seam's dartdoc says it is for this package's tests. Verify:
  - `flutter pub get` and `flutter analyze` are clean at the package root;
  - `flutter test test/view/` passes;
  - in a throwaway Dart file under `example/lib/` that passes `createSession: null`, `flutter analyze` reports `invalid_use_of_internal_member` (delete the file afterwards). If it doesn't, apply the design's fallback (keep `@visibleForTesting` as well) and record that in design.md.
- [x] 1.2 Check whether `dart doc` lists the `@internal` seams on the `LiveTranslateView` page. Verify by running `dart doc --output <scratch dir>` and reading the generated constructor entry. Record the result as one line in design.md D2; no code change either way.

## 2. Controller target language

- [x] 2.1 Add `TranslateLanguage? get targetLanguage` to `LiveTranslateController`, documented with the attach timing (design D3). Give `publishToController` a required `target`, include it in the no-op equality check, and reset it to `null` in `detachController`. Verify with new cases in `test/controller/live_translate_controller_test.dart`:
  - unattached is `null`;
  - publishing a new target notifies once, and publishing an equal one doesn't;
  - detaching resets it to `null`.
- [x] 2.2 Have the view pass `_target` in `_schedulePublish`, so `targetLanguage` follows widget and controller changes. Verify with new cases in `test/view/live_translate_view_test.dart`, one per scenario in the `controller` delta's "The controller reports the target language":
  - French device locale with no target gives French after the first pump, with a notification;
  - explicit German;
  - `setTargetLanguage(french)` notifies;
  - a widget rebuild to German notifies;
  - removing the view gives `null`.

## 3. Public exports

- [x] 3.1 Add the three `show` exports to `lib/live_translate_overlay.dart` (design D1). Remove "Internal until release 0.1.0" from the `LiveTranslateView` dartdoc, and make sure the view, controller and state dartdoc still read correctly as public docs. Verify with `test/public_api_test.dart`, importing only the entry library:
  - `LiveTranslateView`, `LiveTranslateController` and `LiveTranslateState.values` resolve, and the test builds a `const LiveTranslateView()`;
  - `flutter analyze` is clean;
  - `grep -n "export" lib/live_translate_overlay.dart` shows no export without `show` for the view and controller files.

## 4. Example app on the public API

- [x] 4.1 In `example/lib/camera_screen.dart`, replace `_target` with `TranslateLanguage? _chosenTarget`. Pass it to the view, and use `_chosenTarget ?? _controller.targetLanguage` for the target chip, the picker's selection and the chips' download indicators (design D4). Drop the `device_language.dart` import. Verify: the existing `example/test/camera_screen_test.dart` cases for "Starting target language" (French phone, Amharic phone) and "Choosing the target language" still pass after pumping the first frame.
- [x] 4.2 Replace `CameraScreen`'s `createSession` and `createEngines` with the `@visibleForTesting buildView` seam (design D5). Remove every `src/` import and the `implementation_imports` ignore from `example/lib/`. Update `example/test/camera_screen_test.dart` (and `support/fakes.dart` if needed) to pass a `buildView` closure that adds the fake session, engines and clock, ignoring `invalid_use_of_internal_member` there. Verify:
  - `grep -rn "src/\|implementation_imports" example/lib` finds nothing;
  - `flutter analyze` is clean in `example/`;
  - `flutter test` passes in `example/`.

## 5. Integration check

- [x] 5.1 Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` at the package root, then `flutter analyze`, `flutter test` and `flutter build apk --debug` in `example/`. Verify all succeed. Then tell the user the example is ready for the on-device check: target chip on first launch, picker, freeze and torch, unchanged on both phones.

## Workflow follow-up

- After the on-device check, archive the change, syncing the `public-api` and `controller` deltas into the main specs.
- Tick the matching Week 4 items in `PLUGIN_PLAN.md`, and drop the "Export status" note in §4.
