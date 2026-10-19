# Tasks

The device check (group 4) is run by the user on the iPhone 14 and the Samsung Galaxy. Claude prepares the commands and records the results.

## 1. Model store

- [x] 1.1 Add `@internal` test seams to `MlKitModelStore`: the platform (default `defaultTargetPlatform`) and the wait between checks (default `Future.delayed`) (design decision 2); verify the existing `mlkit_model_store_test.dart` cases still pass unchanged
- [x] 1.2 Implement the iOS path of `download` per design decision 1: return at once if the model is there, start the platform download unawaited, ignore `cancelled` and `download_in_progress`, honour `true`, `false` and other errors, check `isDownloaded` once a second, and throw `ModelNotDownloaded` after 300 checks. Leave Android exactly as it is. Verify with new `mlkit_model_store_test.dart` cases for every `model-management` delta scenario: call never completes, cancelled, never arrives (300 checks, then throws), already on the device (no wait), Android completes without checking, plus a platform `false` and an unknown error on iOS failing at once
- [x] 1.3 Check that a finished iOS download leaves no check loop running (the loop stops once it completes or fails, and the dropped platform result is caught); verify with a test that counts `isDownloaded` calls after `download` completes, and that no unhandled async error is reported

## 2. Live view on iOS

- [x] 2.1 Add `line_translator_test.dart` cases that drive `LineTranslator` with an iOS `MlKitModelStore` over a fake manager, one case per `translate` delta scenario: a source download answered with `cancelled` whose model then appears (status becomes ready, `onModelReady` fires), a target model that appears later (waiting lines are translated on the next read), and a model that never appears (status becomes download failed, and a later confirmed read starts a new download); verify they pass and the existing translator tests are unchanged

## 3. Example, docs and checks

- [x] 3.1 In `example/integration_test/replay_test.dart`, make `_downloadModels` await `TranslationModels.download` directly, keep its per-model timing, and update its doc comment (design decision 4); verify `flutter analyze` is clean in `example/`
- [x] 3.2 README: where `TranslationModels.download` and `wifiOnly` are documented (API "Other types" and "Managing models from your own UI"), say that on iOS downloads always use any network; remove any iOS download caveat; verify the README text matches the spec
- [x] 3.3 CHANGELOG Unreleased: a "Fixed" entry for iOS model downloads never completing (status stuck on downloading, held picture not re-read, `TranslationModels.download` hanging or failing), plus the `wifiOnly` note; verify `dart pub publish --dry-run` shows only the uncommitted-files warning
- [x] 3.4 Run `dart format --set-exit-if-changed .`, `flutter analyze` (package and example), `flutter test --coverage --exclude-tags golden`, `flutter test --tags golden` and the example's tests; verify all pass and `engines/` coverage of `mlkit_model_store.dart` covers both platforms' paths

## 4. Device check (user)

- [x] 4.1 User, iPhone 14: delete a model in the example's "Languages on this phone" (for example Spanish), then download it there; verify it ends as downloaded, not "Couldn't download"
- [x] 4.2 User, iPhone 14: delete the Spanish model, choose "Detect language", and hold the camera still over Spanish text; verify the chip goes from "Spanish?" to downloading to "Spanish", and labels appear without moving the camera
- [x] 4.3 User, iPhone 14: run the replay test in profile mode (`flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/replay_test.dart -d <iPhone>` in `example/`) with at least one model deleted first; verify it downloads through `TranslationModels.download` and passes as before
- [x] 4.4 User, Samsung: repeat 4.1; verify Android still downloads and reports done as before

## Workflow follow-up

- Consider reporting the plugin bug upstream (`google_mlkit_commons` `GenericModelManager`: a new manager per call cancels pending downloads, and the success notification is registered for the wrong object).
- Archive the change after the device check.
