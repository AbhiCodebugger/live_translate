# Tasks

## 1. Download policy

- [x] 1.1 In `LineTranslator`, make every automatic download `wifiOnly: false`. Make confirmed source languages always download: remove `_SourceRole` and `_reportedMissing`, and keep the confirmation and one-at-a-time rules (design D3, D4). Update `test/pipeline/line_translator_test.dart` so every `translate` scenario passes:
  - "Detected but not expected" downloads Swahili and reports it once;
  - "Hindi seen on an English phone" downloads Hindi on the third frame and translates once the download completes;
  - "Download on mobile data" sees `(english, false)` in `FakeModelStore.downloads`;
  - the stray, low-confidence, too-far-apart, third-frame, one-at-a-time and retry scenarios still pass with `wifiOnly` false.

  Verify that `flutter test test/pipeline` passes.
- [x] 1.2 Add `LineTranslator.prepare(target)` and call it from the `Pipeline` constructor (design D2). Verify with tests:
  - "First frame with the target missing": the English download is requested before any frame, and the first Hindi frame doesn't add a second download or report;
  - "Target changes": a pipeline built for French with the French model missing downloads French before `onFrame`;
  - "Target already present": no download and no report;
  - "Missing target model": a download starts at once.

  Verify that `flutter test test/pipeline` passes.

- [x] 1.3 Settle one language per script per frame, and confirm a language only when it leads its script in the window (design D7). Verify with `test/pipeline/line_translator_test.dart`:
  - every `detect-language` scenario of "One language per script in each frame": stray Marathi among Hindi, line without a qualifying guess, target-language line among Latin lines, and scripts decided separately;
  - "Stray Marathi on Hindi text" downloads only Hindi;
  - "Two languages competing in one script" confirms Hindi and not Marathi;
  - "One download at a time" now uses Hindi and Spanish;
  - the existing "Hint narrows the candidates" and "No hinted language qualifies" cases still pass.

  Verify that `flutter test` passes.

## 2. View defaults

- [x] 2.1 Add `lib/src/models/device_language.dart` with `deviceTargetLanguage(Locale)` (design D1). Verify with `test/models/device_language_test.dart`:
  - `en_US` and `en_GB` give English;
  - `fr_FR` gives French;
  - `hi_IN` gives Hindi;
  - `am_ET` (no on-device model) gives English.
- [x] 2.2 Make `LiveTranslateView.targetLanguage` optional. Use the device language when it is `null`, in `initState` and when the widget's target changes to `null`. Change the default `scripts` to Latin and Devanagari (design D1, D5). Verify with new cases in `test/view/live_translate_view_test.dart`, setting `tester.platformDispatcher.localeTestValue`:
  - "No target on an English phone": `en_US`, no target, gives "[en]" labels;
  - "No target on a French phone": `fr_FR` gives "[fr]" labels, and the French model is checked before the first frame;
  - "Device language without a model": `am_ET` gives "[en]";
  - "Default script": the text engine is built with `{latin, devanagari}`;
  - "Latin only": passing `{latin}` builds it with `{latin}`;
  - a controller `setTargetLanguage` still wins over the device default.

  Keep all existing view tests passing; tests that relied on the Latin-only default pass `scripts` explicitly where needed.

## 3. Example and docs

- [x] 3.1 Update `example/lib/main.dart` (design D6): drop `targetLanguage`, `scripts` and the "Hindi only" chip, and show "Downloading the ‹language› model…" for every `ModelNotDownloaded`. Update `example/test/widget_test.dart` if needed. Verify that `flutter analyze` and `flutter test` pass in `example/`, and that both platform builds succeed.
- [x] 3.2 Replace the README's "Getting started" template text with the native Devanagari setup: the `com.google.mlkit:text-recognition-devanagari` Gradle dependency, the `GoogleMLKit/TextRecognitionDevanagari` pod, and the iOS 15.5 minimum. Note that both scripts are read by default. Verify that the dependency and pod lines match `example/android/app/build.gradle.kts` and `example/ios/Podfile`.

## 4. Checks

- [x] 4.1 Run the package checks. Verify that:
  - `dart format --set-exit-if-changed .` makes no changes;
  - `flutter analyze` reports no issues;
  - `flutter test --coverage` passes, with `lib/src/pipeline/` and `lib/src/controller/` still at least 90% line coverage (report both figures).
- [x] 4.2 **Manual, done by the user on the Samsung Galaxy (Android 15) and the iPhone 14 (iOS 26.6.1),** with both phones set to English, on mobile data, and with the English, Hindi and Marathi models deleted first (reinstall the app). Check that:
  - the English model starts downloading at launch, before the camera sees any text;
  - pointing at Hindi text starts the Hindi download within a few seconds, and no Marathi download follows;
  - once it completes, Hindi lines show English labels.

  Record the results under "On-device results" in `design.md`, listing both devices with every check.

## Workflow follow-up

- When archiving, update the `translate` spec's Purpose so it no longer says models are never downloaded over mobile data unasked.
