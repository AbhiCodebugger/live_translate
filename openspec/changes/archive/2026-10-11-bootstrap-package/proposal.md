# Proposal

## Why

The repository is still the `flutter create --template=package` scaffold: it exports a template `Calculator`, declares a stale `flutter: ">=1.17.0"` constraint, has no ML Kit or camera dependencies, and has no example app. Every later week of `PLUGIN_PLAN.md` (capture, geometry, recognition, tracking) builds on the package skeleton, the public model types (§4.3) and the error hierarchy (§4.5). Week 0 also needs a way to recognise text from a real photo on the author's phones and to confirm Devanagari support before Week 2 commits to it.

## What Changes

- **BREAKING** (pre-release only): Replace the template library `lib/live_translate.dart` (and its `Calculator`) with the entry library `lib/live_translate_overlay.dart`, which matches the package name already set in `pubspec.yaml`.
- Update `pubspec.yaml`: a real description, SDK and Flutter constraints aligned with the ML Kit and camera plugins (Dart `^3.12.0`, Flutter `>=3.44.0`), and dependencies on `camera`, `google_mlkit_text_recognition`, `google_mlkit_translation` and `google_mlkit_language_id`.
- Tighten `analysis_options.yaml` while staying on `flutter_lints`: turn on strict analyzer language modes and require docs on public members.
- Add the public models from §4.3: `TranslatedLine`, `TextScript` (`latin`, `devanagari`) and `OverlayStyle`, as immutable value types.
- Add the error hierarchy from §4.5: a `sealed` `LiveTranslateException` with `final` subclasses.
- Re-export the dependency types the public API uses (`TranslateLanguage`, `CameraLensDirection`, `ResolutionPreset`), so consumers don't need direct dependencies on those plugins.
- Add the Week 0 `lib/src/` structure for the files this change creates (`models/`, `errors.dart`, plus the ML Kit script mapping), following §6.
- Add an `example/` app (Android and iOS) with a Week 0 spike screen: take one photo with the camera and show the text recognised for the selected script.
- Record the Devanagari script-support check in OpenSpec: the spec states the supported scripts, and the design records the evidence.
- Replace the `LICENSE` placeholder with BSD-3-Clause, the license named in the plan's header.

## Capabilities

### New Capabilities
- `public-api`: The package's public surface: what the entry library exports, the immutable public models (`TranslatedLine`, `TextScript`, `OverlayStyle`), the re-exported dependency types, the `LiveTranslateException` error hierarchy, and which text scripts the package supports.

### Modified Capabilities
<!-- None: no specs exist yet. -->

## Impact

- **Code:** removes `lib/live_translate.dart` and `test/live_translate_test.dart`. Adds `lib/live_translate_overlay.dart`, `lib/src/models/*`, `lib/src/errors.dart`, `lib/src/engines/mlkit/script_mapping.dart` and matching tests.
- **Dependencies:** adds `camera` ^0.12.1, `google_mlkit_text_recognition` ^0.17.1, `google_mlkit_translation` ^0.15.1 and `google_mlkit_language_id` ^0.15.1. Raises the minimum Flutter version to 3.44.
- **Platforms (example app only):** Android minSdk ≥ 24 and the Devanagari Gradle dependency. iOS deployment target 15.5, the Devanagari pod and `NSCameraUsageDescription`.
- **Out of scope:** CI (§11), `LiveTranslateView`, `LiveTranslateController`, `TranslationModels`, and pipeline and engine logic (Weeks 1–3), plus README, CHANGELOG and publishing metadata (Week 4).
