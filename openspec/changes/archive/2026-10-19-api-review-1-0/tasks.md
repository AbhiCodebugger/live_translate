# Tasks

The device check (group 6) is run by the user. Claude prepares the build and records the results.

## 1. TextScript

- [x] 1.1 Replace the `TextScript` enum with a final class per design decision 1 (private const constructor, `name`, `latin`, `devanagari`, `values`, `toString` of `TextScript.<name>`, dartdoc saying scripts can be added in a minor version); verify `test/models/text_script_test.dart` covers every scenario of "Supported text scripts" (set, names, const set and map key use, `scripts: {TextScript.latin}` compiling)
- [x] 1.2 Update the internal users (`script_mapping.dart`'s switch, `multi_script_text_engine.dart`, `line_filter.dart`, `line_translator.dart`) so they compile without exhaustive switches over `TextScript`, throwing a `StateError` for an unknown script; verify `script_mapping_test.dart`, `line_filter_test.dart`, `multi_script_text_engine_test.dart` and `script_test.dart` pass unchanged

## 2. TranslatedParagraph source language

- [x] 2.1 Make `TranslatedParagraph.sourceLanguage` a required `TranslateLanguage` (field, constructor, `==`, `hashCode`, `toString` with its BCP-47 code, dartdoc), and convert from the `ReadParagraph` tag in `live_translate_view.dart` per design decision 2, with a debug assert naming any tag that doesn't parse; verify `translated_paragraph_test.dart` covers the modified "TranslatedParagraph is an immutable value" scenarios, and a `live_translate_view_test.dart` case shows a paragraph translated from Spanish reporting `TranslateLanguage.spanish`
- [x] 2.2 Update every other `TranslatedParagraph(` construction and `sourceLanguage` read in `test/` and `example/`; verify `flutter analyze` is clean in the package and the example

## 3. Controller getters

- [x] 3.1 Add `scripts` and `sourceLanguages` to `LiveTranslateController`, published through `_publish` and `reportToController` as unmodifiable copies, `null` when not attached (design decision 4); verify new `live_translate_controller_test.dart` cases for every scenario of "The controller reports scripts and source languages"

## 4. Resolution restart

- [x] 4.1 Make the view replace its camera session when `resolution` changes (design decision 3): cancel the subscription, stop and dispose the old session, create one through `createSession` with the new resolution, subscribe, bump the read token and `_start()` unless suspended, serialised so the latest change wins; verify new `live_translate_view_test.dart` cases for every scenario of "A resolution change restarts the camera" (new session at `high`, no restart for the same resolution, frozen becomes running, placeholder shown during the restart, a failed start reported), plus a stale read from before the restart not being shown, and the existing view tests passing

## 5. OverlayStyle, docs and checks

- [x] 5.1 Add `OverlayStyle.copyWith` (through the constructor) and `toString` (design decision 5); verify `overlay_style_test.dart` covers every scenario of "OverlayStyle can be copied with changes"
- [x] 5.2 Fix the stale "lines" dartdoc on `LiveTranslateView` (class doc, `targetLanguage`, `sourceLanguages`, `controller`) and `LiveTranslateState.running`; verify `grep -n "lines\b"` over those files finds only the correct uses (a paragraph's lines, line height)
- [x] 5.3 README: the `TranslatedParagraph.sourceLanguage` row, the controller's `scripts` and `sourceLanguages` rows, `copyWith` in the `OverlayStyle` section, the sealed-type and `TextScript` policy under "Other types", and the `resolution` row and the sentence after the view table without the `key` advice; verify every API table row matches the code, and the README's code samples still compile (`test/public_api_test.dart` covers the source status sample)
- [x] 5.4 CHANGELOG Unreleased: a "Breaking" section with a before/after table for `TextScript` switches and `TranslatedParagraph.sourceLanguage`, plus "New" entries for the controller getters, `copyWith`/`toString` and the resolution restart; verify `dart pub publish --dry-run` shows only the uncommitted-files warning
- [x] 5.5 Run `dart format --set-exit-if-changed .`, `flutter analyze` (package and example), `flutter test --coverage --exclude-tags golden`, `flutter test --tags golden` and the example's tests; verify all pass and core-directory coverage stays at least 90%

## 6. Device check (user)

- [x] 6.1 User, one phone: in the example app, switch the HUD on and check that live translation, freeze, the language pill and the text sheet still work after the API changes; verify labels and the sheet's source and translation look as before

## Workflow follow-up

- Archive the change once the device check passes.
- Then bump to 1.0.0 (version, CHANGELOG heading) as a separate release step.
