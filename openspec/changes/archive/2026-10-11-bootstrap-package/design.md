# Design

## Context

The repo is an unmodified `flutter create --template=package` scaffold. Only the `name:` in `pubspec.yaml` has been changed, to `live_translate_overlay`. The toolchain is Flutter 3.47.2 with Dart 3.13.2. There are no specs yet. See proposal.md for the motivation.

Dependency facts checked on pub.dev on 2026-10-11, from each package's published source:

| Package | Latest | Requires | Notes |
|---|---|---|---|
| `camera` | 0.12.1 | Dart ^3.12, Flutter ≥ 3.44 | Android SDK 24+, iOS 13+. Re-exports `CameraLensDirection` and `ResolutionPreset` from `camera_platform_interface` |
| `google_mlkit_text_recognition` | 0.17.1 | same | Re-exports `google_mlkit_commons`. `TextRecognitionScript { latin, chinese, devanagiri, japanese, korean }` (the plugin's spelling) |
| `google_mlkit_translation` | 0.15.1 | same | `TranslateLanguage` lives here. Re-exports `google_mlkit_commons` |
| `google_mlkit_language_id` | 0.15.1 | same | ML Kit pods need iOS 15.5 or later. Android minSdk 21 |

**Devanagari check (Week 0):** ML Kit Text Recognition v2 supports Devanagari on-device on both platforms. Latin is bundled by default. **Devanagari is not**: the consuming app must add `com.google.mlkit:text-recognition-devanagari` (Android Gradle) and `GoogleMLKit/TextRecognitionDevanagari` (iOS Podfile). This setup falls on consumers, so it must appear in the README's Setup section (§7, Week 4), and the extra size must be measured (§7 "Size impact"). Bengali, Tamil, Telugu and other Indian scripts are **not** supported by ML Kit on-device recognition today, so `TextScript` stays `{latin, devanagari}` as the plan says. The on-device spike (task group 6) confirms this on real hardware.

On-device results (example app, still photo, back camera):

| Platform | Device | OS | Latin | Devanagari |
|---|---|---|---|---|
| Android | Samsung Galaxy | Android 15 | Pass | Pass: 21 lines from a handwritten manuscript page in 271 ms. Text is close but imperfect (merged words, stray vowel signs), as expected for hand-lettered script |
| iOS | iPhone 14 | iOS 26.6.1 | Pass | Pass: 21 lines from the same manuscript page in 77 ms. Similar quality to Android, with a few different misreads |

Conclusion: Latin and Devanagari recognition work on-device on both platforms with the example's native setup (Devanagari Gradle dependency and pod, iOS 15.5 target). `TextScript { latin, devanagari }` stands.

## Goals / Non-Goals

**Goals:**
- A clean package skeleton where `flutter analyze` reports nothing and `flutter test` passes, ready for Week 1 to add `camera/`, `geometry/` and `pipeline/` code.
- Freeze the shape of the §4.3 models and §4.5 errors early, since pre-1.0 changes are cheap but every later week depends on them.
- An example app the author can run on their phones to finish the Week 0 exit check.

**Non-Goals:**
- Empty placeholder directories for later weeks (`view/`, `controller/`, `pipeline/` and so on). Git doesn't track empty directories, and each week creates its own.
- `copyWith`, JSON serialisation or code generation for the models. Nothing in the plan needs them yet.
- `LiveTranslateView`, `LiveTranslateController`, `TranslationModels` and any engine interfaces.
- Publishing metadata (`repository`, `topics`), README and CHANGELOG content, and CI.

## Decisions

**D1. Constraints: `sdk: ^3.12.0`, `flutter: ">=3.44.0"`.** These match the floor of all four dependencies. Keeping the scaffold's `^3.13.2` would lock out consumers on Flutter 3.44–3.46 for no gain. The analyzer derives the language version from the SDK lower bound, so it will flag any Dart 3.13-only feature. *Alternative:* keep `^3.13.2`. Rejected because it narrows reach without a benefit.

**D2. No direct dependency on `google_mlkit_commons`.** Both ML Kit plugins re-export it. Importing `InputImage` and friends through `google_mlkit_text_recognition` avoids a fourth version constraint that could drift. *Alternative:* list it directly. Revisit if a file needs commons without either plugin.

**D3. Re-export with `show`.** The entry library does `export 'package:google_mlkit_translation/google_mlkit_translation.dart' show TranslateLanguage;` and `export 'package:camera/camera.dart' show CameraLensDirection, ResolutionPreset;`. `show` keeps the surface exactly as §4 describes. Camera types are exported now, although only Week 1+ widgets use them, so the public surface is fixed in one place.

**D4. Models are hand-written immutable classes.** They are `@immutable` and `final class`, with `const` constructors and `==` and `hashCode` written by hand (`Object.hash`). The plan's surface is too small to justify `freezed`, `equatable` or build_runner. `final class` prevents consumers from subclassing value types, which would undermine equality. Invariants (opacity range, font size bounds) are `assert`s in the constructor, in line with Flutter's own value types (for example `EdgeInsets`). `TranslatedLine.rect` uses `dart:ui`'s `Rect` and `OverlayStyle` uses `Color`, `EdgeInsets` and `FontWeight`, as §4.3 specifies.

**D5. Errors: `sealed class LiveTranslateException implements Exception`, with `final class` subtypes.** `sealed` gives consumers exhaustive `switch`. `final` stops outside subclassing, which would otherwise break that exhaustiveness. Each subtype has a `const` constructor where its fields allow, and a `toString()` that includes its context. `UnsupportedLanguagePair.source` is a BCP-47 `String`, not a `TranslateLanguage`, because language ID can detect languages that `TranslateLanguage` doesn't cover; that is exactly the unsupported case. `PipelineFailure` carries `Object cause` plus an optional `StackTrace? stackTrace`, so failures can be reported faithfully.

**D6. `TextScript` → `TextRecognitionScript` mapping lives in `lib/src/engines/mlkit/script_mapping.dart`.** It is a private extension with an exhaustive `switch` expression, so adding a `TextScript` value without a mapping fails to compile. It goes in the §6 `engines/mlkit/` folder now because the spec's "every script maps to an on-device recognizer" requirement needs it to be testable. It also hides the plugin's `devanagiri` misspelling behind our `devanagari`.

**D7. File layout (subset of §6).**
```
lib/
  live_translate_overlay.dart          exports only
  src/
    errors.dart
    models/translated_line.dart, overlay_style.dart, text_script.dart
    engines/mlkit/script_mapping.dart
test/
  models/..._test.dart, errors_test.dart, engines/mlkit/script_mapping_test.dart
  public_api_test.dart                 compiles against the entry library only
```
Tests mirror `lib/src/`. Files use `snake_case`, and each library contains one public type.

**D8. Analysis options stay on `flutter_lints`, made stricter.** Add `analyzer.language: strict-casts, strict-inference, strict-raw-types`, and turn on the `public_member_api_docs` lint so the "dartdoc on every public symbol" requirement (Week 4) is enforced from day one instead of retrofitted. No other extra lints, as the user requested.

**D9. Example app is a Week 0 spike screen using only `camera`.** It shows a camera preview, a `SegmentedButton<TextScript>` and a "Recognise" button. `takePicture()` → `InputImage.fromFilePath` → `TextRecognizer(script: …)` → the recognised text is shown in a scrollable sheet. This needs no `image_picker` or `path_provider`. The example imports ML Kit directly, since it's a spike for the author, and depends on the package via `path: ../`. It is replaced by the real demo in Week 5. Platform setup: Android `minSdk` ≥ 24, `CAMERA` permission and the Devanagari Gradle dependency. iOS `platform :ios, '15.5'`, `NSCameraUsageDescription` and the Devanagari pod.

**D10. `LICENSE` is BSD-3-Clause, © 2026 Abhinav Ranjan,** following the plan's header.

## Risks / Trade-offs

- [The SDK lower bound of 3.12 can't be tested locally, since the toolchain is 3.13] → The analyzer enforces the language version; no 3.13-only APIs are used. Re-check with a 3.44 toolchain when CI arrives.
- [Re-exporting dependency enums ties our public API to their versions] → Accepted by §4. A major ML Kit bump that renames `TranslateLanguage` values would be a breaking release for us too. CHANGELOG entries must call this out.
- [The example app's ML Kit pods and Gradle artefacts make the first build slow and large] → Example only. The package itself adds no native configuration.
- [The Devanagari conclusion rests on docs and plugin source until checked on a device] → Task 6.3 is a manual on-device check. If it fails, the spec's script set is revised before Week 2.

## Migration Plan

Not applicable: nothing has been published, and nothing depends on the `Calculator` template.
