# Tasks

## 1. Package configuration

- [x] 1.1 Update `pubspec.yaml`: description 60–180 characters, `sdk: ^3.12.0`, `flutter: ">=3.44.0"`, add `camera: ^0.12.1`, `google_mlkit_text_recognition: ^0.17.1`, `google_mlkit_translation: ^0.15.1`, `google_mlkit_language_id: ^0.15.1`, and remove the template comment block (design D1, D2). Verify that `flutter pub get` succeeds.
- [x] 1.2 Update `analysis_options.yaml`: keep `flutter_lints`, add `strict-casts`, `strict-inference` and `strict-raw-types`, and turn on `public_member_api_docs` (design D8). Verify with `flutter analyze`. It may only report the template files that task 1.3 removes.
- [x] 1.3 Delete `lib/live_translate.dart` and `test/live_translate_test.dart`. Create `lib/live_translate_overlay.dart` with a library-level dartdoc and no exports yet. Verify that no `Calculator` reference remains (`grep -r Calculator lib test` is empty).
- [x] 1.4 Replace `LICENSE` with the BSD-3-Clause text, © 2026 Abhinav Ranjan (design D10). Verify that the file starts with the copyright line and contains all three clauses.

## 2. Public models

- [x] 2.1 Add `lib/src/models/text_script.dart`: `enum TextScript { latin, devanagari }` with dartdoc on the enum and each value. Verify with `test/models/text_script_test.dart`, which asserts `TextScript.values` is exactly `[latin, devanagari]`.
- [x] 2.2 Add `lib/src/models/translated_line.dart`: an `@immutable final class` with a `const` constructor, the six §4.3 fields, an opacity `assert` (0–1), `==`, `hashCode` via `Object.hash`, and `toString` (design D4). Verify with `test/models/translated_line_test.dart`, covering equality, inequality on `opacity`, null `sourceLanguage`, and the assertion on `opacity: 1.5`.
- [x] 2.3 Add `lib/src/models/overlay_style.dart`: an `@immutable final class` with the §4.3 defaults, `assert`s for `minFontSize > 0` and `minFontSize <= maxFontSize`, `==` and `hashCode`. Verify with `test/models/overlay_style_test.dart`, covering every default value, equality, and the assertion on inverted bounds.

## 3. Error hierarchy

- [x] 3.1 Add `lib/src/errors.dart`: `sealed class LiveTranslateException implements Exception`, with the `final class` subtypes `CameraPermissionDenied`, `CameraUnavailable`, `ModelNotDownloaded(language)`, `UnsupportedLanguagePair(source, target)` and `PipelineFailure(cause, [stackTrace])`. Each has dartdoc and a `toString` that includes its context (design D5). Verify with `test/errors_test.dart`, covering an exhaustive `switch` expression over all five subtypes with no default, `ModelNotDownloaded(hindi).toString()` containing `ModelNotDownloaded` and `hindi`, and `PipelineFailure` keeping its `cause` and the cause's message.

## 4. Script mapping

- [x] 4.1 Add `lib/src/engines/mlkit/script_mapping.dart`: an extension on `TextScript` with an exhaustive `switch` expression to `TextRecognitionScript` (`devanagari` → `devanagiri`) (design D6). Verify with `test/engines/mlkit/script_mapping_test.dart`, checking that every `TextScript.values` entry maps, and that `latin` → `latin` and `devanagari` → `devanagiri`.

## 5. Entry library

- [x] 5.1 Export the models and errors from `lib/live_translate_overlay.dart`, and re-export `TranslateLanguage` and `CameraLensDirection, ResolutionPreset` using `show` (design D3). Do not export `script_mapping.dart`. Verify with `test/public_api_test.dart`, which imports only the entry library and uses `TranslatedLine`, `TextScript`, `OverlayStyle`, every exception subtype, `TranslateLanguage.english`, `CameraLensDirection.back` and `ResolutionPreset.medium`.
- [x] 5.2 Run the package checks. Verify that `dart format --set-exit-if-changed .`, `flutter analyze` (zero issues, including `public_member_api_docs`) and `flutter test` all pass.

## 6. Example app (Week 0 spike)

- [x] 6.1 Create `example/` with `flutter create --platforms=android,ios --project-name live_translate_overlay_example example`. Depend on `live_translate_overlay` via `path: ../`, plus `camera` and `google_mlkit_text_recognition`. Set Android `minSdk` ≥ 24, add the `CAMERA` permission and `com.google.mlkit:text-recognition-devanagari`. Set iOS `platform :ios, '15.5'`, add `NSCameraUsageDescription` and the `GoogleMLKit/TextRecognitionDevanagari` pod (design D9). Verify that `flutter build apk --debug` succeeds in `example/`.
- [x] 6.2 Replace `example/lib/main.dart` with the spike screen: camera preview, a `SegmentedButton<TextScript>`, and a "Recognise" button that takes a picture, runs `TextRecognizer` for the selected script, and shows the recognised text. Close the recognizer and dispose the camera on dispose. Add a widget smoke test (or delete the generated one) so `flutter test` in `example/` passes. Verify that `flutter analyze` is clean in `example/`.
- [x] 6.3 **Manual, on the author's devices:** run the example on the Android phone and the iPhone. Recognise a Latin photo and a Devanagari photo on each, then record the outcome (device, OS, pass/fail) in the "Devanagari check" paragraph of `design.md`. Verify that the paragraph states the on-device result for both platforms.
