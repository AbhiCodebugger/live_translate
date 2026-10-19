# Design

## Context

Every model call in the package goes through one `ModelStore`, `MlKitModelStore`, which wraps the plugin's `ModelManager`. Both `TranslationModels` and the live view's automatic downloads (`LineTranslator._onMissing`) use it. `LineTranslator` already handles a download's end: success marks the model available, re-reads the held picture and moves the source status on, and failure marks it missing for a later retry. So the fix belongs in the store alone. The view needs nothing beyond a store whose `download` completes.

What the iOS plugin does (`google_mlkit_commons` 0.13.0, `GenericModelManager.swift`; `google_mlkit_translation` 0.15.1):
- Each `nlp#manageLanguageModelModels` call creates a new `GenericModelManager` and drops the previous one. On deinit, the dropped manager answers its pending download with `FlutterError(code: "cancelled")`. On the Dart side that's a `PlatformException`, which the store turns into `ModelNotDownloaded` today.
- `download` returns `"success"` at once if the model is already there. Otherwise it waits for `mlkitModelDownloadDidSucceed` or `…DidFail` with `object: model`, for a model object ML Kit doesn't post. So a download left alone never completes, and a real failure is never reported either.
- `ModelDownloadConditions(allowsCellularAccess: true, …)` is hard-coded. The `wifi` argument is ignored.

The replay test already works around this with a check once a second and a 5-minute limit, and it was verified on the iPhone 14: models were detected 4–11 s after the download started.

## Goals / Non-Goals

**Goals:**
- `download` on iOS completes within about a second of the model arriving, whatever the plugin's call does.
- Tests can drive the iOS path quickly and deterministically, without a real clock.

**Non-Goals:**
- Any change to `LineTranslator`, the view or `SourceStatus`.
- Changing Android's path, including its Wi-Fi handling.

## Decisions

### 1. The fix lives in `MlKitModelStore`, and only iOS takes the new path
`download` reads `defaultTargetPlatform`, as `camera_session.dart` already does. On Android it does exactly what it does today. On iOS:
1. If `isDownloaded` is already true, it returns at once.
2. It starts the plugin's download without awaiting it, and watches its result:
   - `true`: done.
   - `false`: failed, `ModelNotDownloaded`.
   - `PlatformException` with code `cancelled` or `download_in_progress`: ignored, keep checking.
   - Any other error: failed.
3. Meanwhile it checks `isDownloaded` every second and completes when it's true. It throws `ModelNotDownloaded` after 300 checks, which is at least 5 minutes.

Whichever finishes first wins, and the other result is dropped.
- **Why:** One place serves both `TranslationModels` and the view. Honouring a real `true` or `false` keeps the store correct if the plugin is fixed upstream. `download_in_progress` can only come from a future plugin that keeps one manager, and it means a download of this model is already running, so waiting for the model is still correct.
- **Alternative:** Checking on both platforms. Android reports correctly, and a time limit there would break `wifiOnly`, where the download can legitimately wait hours for Wi-Fi. So no.
- **Alternative:** Fixing it in `LineTranslator`, which already checks missing models every 10 frames. That would fix only the view, and checks there depend on frames arriving. A frozen or covered camera sends none.

### 2. The time limit counts checks, and the wait is injectable
`MlKitModelStore` gains test-only parameters (marked `@internal`, like the view's seams): the platform, and the wait between checks (`Future<void> Function(Duration)`, `Future.delayed` by default). The limit is a number of checks (300, one a second), not elapsed wall-clock time. A test with an instant wait then runs all 300 checks in milliseconds and still exercises the failure.
- **Why:** The package doesn't depend on `fake_async` directly. Counting checks is deterministic, and each real check takes extra time, so the real limit is never shorter than 5 minutes.
- **Alternative:** A `Stopwatch` with an injectable clock. That's more seams for no gain in behaviour.

### 3. Five minutes, as in the replay test
A 30 MB model on a slow connection took 65 s on the Samsung. At 1 Mbit/s it takes about 4 minutes. On iOS the limit is the only failure signal, so it's set generously. A failed download is retried by the next confirmed read anyway. While waiting, the source status says "downloading", which is true.

### 4. The replay test drops its workaround
Once `TranslationModels.download` completes on iOS, `_downloadModels` in `replay_test.dart` awaits it directly and keeps its per-model timing. That makes the replay test an end-to-end check of the fix on the iPhone.

## Risks / Trade-offs

- [A real failure on iOS (no network) shows "downloading" for 5 minutes before "download failed"] → This is the best available without a platform failure signal. The README notes that ML Kit doesn't report progress, so apps already show an indeterminate state.
- [Checking every second makes one platform call a second per download] → It's a cheap file-existence check, and it stops when the download ends. At most one source download and one target download run at a time.
- [Each check drops the plugin's previous manager, cancelling its pending download call] → Harmless: ML Kit's download continues (verified on the iPhone), and `cancelled` is ignored.
- [A future plugin version fixes the notification] → Its `true` or `false` result is honoured, so the store completes or fails at once. The checks become redundant but stay correct.

## Migration Plan

None: there's no API change. Apps get the fix by upgrading. Rollback is reverting the store change.
