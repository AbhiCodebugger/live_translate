# Proposal

## Why

1.0 freezes the public API: after it, renames and type changes are breaking. A review of every exported type found two types that would force a 2.0 or stay awkward for good, two closed hierarchies with no stated policy, one parameter that silently does nothing when changed, and a few gaps and stale docs. Fixing them now costs one migration note. After 1.0 it costs a major version.

## What Changes

- **BREAKING: `TextScript` becomes a final class with constants.** `TextScript.latin`, `TextScript.devanagari`, `TextScript.values` and `name` keep working, so `scripts: {TextScript.latin}` compiles unchanged. New scripts (Chinese, Japanese and Korean are planned for 1.1) can then ship in a minor release. Only an exhaustive `switch` expression over `TextScript` needs a default case.
- **BREAKING: `TranslatedParagraph.sourceLanguage` becomes a non-null `TranslateLanguage`,** instead of a nullable BCP-47 `String`. A shown paragraph was always translated, so its source language is always known and translatable. It's now a required constructor parameter.
- **Stated policy for the sealed types.** `LiveTranslateException` and `SourceStatus` stay sealed, so apps can keep switching over them exhaustively. The README says that new subtypes come only in a major version.
- **Changing `LiveTranslateView.resolution` restarts the camera at the new resolution.** Today the change is ignored until the camera restarts for another reason. The README's advice to change the view's `key` goes away.
- **`LiveTranslateController.scripts` and `sourceLanguages` getters,** next to the existing `targetLanguage`. They report what the attached view reads and expects, including changes made through either the widget or the controller.
- **`OverlayStyle.copyWith` and `toString`.**
- **Docs:** dartdoc that still says "lines" where it means paragraphs (`LiveTranslateView`, `targetLanguage`, `sourceLanguages`, `controller`, `LiveTranslateState.running`). The README's API tables and a CHANGELOG "Breaking" section with a migration table.

Out of scope: the version bump to 1.0.0 and publishing; renaming `PipelineMetrics`, `PipelineFailure` or `ModelNotDownloaded` (reviewed and kept); new scripts.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `public-api`: `TextScript` is an extensible set of constants. `TranslatedParagraph.sourceLanguage` is a required `TranslateLanguage`. `OverlayStyle` gains `copyWith` and `toString`. The sealed hierarchies are stable within a major version.
- `controller`: the controller reports the attached view's scripts and expected source languages.
- `live-view`: a change of `resolution` restarts the camera at the new resolution.

## Impact

- `lib/src/models/text_script.dart` and its internal users (`engines/mlkit/script_mapping.dart` switches on it; `engines/multi_script_text_engine.dart` iterates `values`).
- `lib/src/models/translated_paragraph.dart`, plus `lib/src/view/live_translate_view.dart` where shown paragraphs are built from internal `ReadParagraph`s (whose BCP-47 source stays a `String`).
- `lib/src/view/live_translate_view.dart`: restarting the camera session on a resolution change; publishing scripts and source languages to the controller.
- `lib/src/controller/live_translate_controller.dart`: the new getters.
- `lib/src/models/overlay_style.dart`: `copyWith`, `toString`.
- Tests for each, `README.md` (API tables, sealed-type policy, resolution), `CHANGELOG.md` (Unreleased, Breaking, with a migration table), and the example app if it reads `sourceLanguage`.
- No new dependencies.
