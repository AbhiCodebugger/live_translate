# Proposal

## Why

On iOS, a translation model download never reports that it finished, although the model does arrive. So on the iPhone the live view stays on "downloading", and the held picture isn't read again when its model arrives. `TranslationModels.download` either never completes or throws `ModelNotDownloaded` for a model that did download. A first-time iOS user sees no translation until they move the camera, and the example's model screen says "Couldn't download". This must be fixed before 1.0.

The cause is in `google_mlkit_translation` 0.15.1 with `google_mlkit_commons` 0.13.0, found during the performance measurements:
- Every model call (check, download or delete) creates a new `GenericModelManager`, and the previous one is deallocated. A deallocated manager answers its pending download with a `cancelled` error. The view checks models while a download runs, so this happens almost at once.
- A download left alone never completes either: the plugin waits for ML Kit's notification for its own model object, and that notification never arrives.

## What Changes

- **iOS: completion is detected by checking for the model.** After starting a download, the package checks once a second whether the model is on the device. It completes as soon as the model is there. A `cancelled` answer from the plugin no longer counts as a failure.
- **iOS: a download that doesn't arrive within 5 minutes fails.** The plugin never reports a real failure on iOS either, so this time limit is the only failure signal. The live view then shows "download failed" and retries as it does today. `TranslationModels.download` throws `ModelNotDownloaded`.
- **Android is unchanged.** Its plugin reports completion and failure correctly.
- **README: `wifiOnly` has no effect on iOS.** The iOS plugin always allows mobile data. The README says so where it documents `TranslationModels.download`.
- The example's model screen and the live view's source status work on iOS without changes of their own, because both go through the fixed download.

Out of scope: fixing the plugin upstream (worth reporting; this change works whether or not it is fixed), download progress, and making `wifiOnly` work on iOS.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `model-management`: `TranslationModels.download` completes on iOS once the model is on the device, ignores the plugin's `cancelled` answer, and fails after 5 minutes without the model.
- `translate`: automatic downloads on iOS finish when the model arrives, so the source status reaches ready and waiting paragraphs are translated.

## Impact

- `lib/src/engines/mlkit/mlkit_model_store.dart`: the iOS completion check, the time limit and the handling of `cancelled`. Both `TranslationModels` and the live view's automatic downloads go through it.
- `test/engines/mlkit/mlkit_model_store_test.dart`: iOS and Android cases with a fake model manager and a controllable wait.
- `example/integration_test/replay_test.dart`: its own once-a-second workaround can go, since `TranslationModels.download` now completes.
- `README.md` (the `wifiOnly` note on iOS, and removing any iOS download caveat), `CHANGELOG.md` (Unreleased: a fix).
- No public API change and no new dependencies.
