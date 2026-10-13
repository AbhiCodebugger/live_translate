# Design

## Context

See proposal.md for the motivation. This is the first of the two Week 2 changes. `translated-overlay` follows and wires these engines into `Pipeline` and `LiveTranslateView`.

**Current code.**
- `TextEngine` and `RecognizedLine` are in `lib/src/engines/text_engine.dart`.
- `MlKitTextEngine` is Latin-only, takes an injectable `createRecognizer`, and creates its recognizer on first use.
- `TextScript` maps to ML Kit in `engines/mlkit/script_mapping.dart`.
- `Pipeline` runs throttle → convert → recognize.

**Decided while exploring Week 2.**
- Missing models download automatically over Wi-Fi only (A).
- Every selected script's latest lines are kept and drawn together.
- An undetermined or unsupported language leaves the line untranslated, and `UnsupportedLanguagePair` is reported once per language.
- Week 2 is split into two changes.

**Plugin facts**, from the cached sources of `google_mlkit_translation` 0.15.1, `google_mlkit_language_id` 0.15.1 and `google_mlkit_commons` 0.13.0:

| Fact | Evidence | Consequence |
|---|---|---|
| `translateText` calls `downloadModelIfNeeded()` with default conditions (no Wi-Fi requirement) before every translation | `TextTranslator.kt:66`, `GoogleMlKitTranslationPlugin.swift:72` | We must check models before translating, or a ~30 MB mobile-data download starts silently |
| `ModelManager` has `isModelDownloaded(bcp)`, `downloadModel(bcp, isWifiRequired:)` and `deleteModel(bcp)`, and no progress or listing API | `model_manager.dart` | `downloaded()` checks each `TranslateLanguage`; progress isn't available (as plan §4.4 suspected) |
| `downloadModel` returns `true` on success and throws a `PlatformException` on failure | `model_manager.dart:25-35` | Both a `false` result and an exception map to `ModelNotDownloaded` |
| Language ID returns `"und"` when undetermined. `identifyPossibleLanguages` returns tags with confidences above the identifier's threshold | `language_identifier.dart` | Use a low threshold (0.01) and apply the spec's 0.5 rule ourselves, so a hint can choose among lower-ranked candidates |
| `BCP47Code.fromRawValue(code)` maps a language tag to `TranslateLanguage`, or returns `null` | `on_device_translator.dart:359` | `null` means unsupported, which leads to `UnsupportedLanguagePair` |

## Goals / Non-Goals

**Goals:**
- Every spec scenario is a unit test, using fakes for ML Kit.
- ≥ 90% line coverage on `lib/src/cache/` and `lib/src/pipeline/` (plan §9).
- The ML Kit adapters are thin, and their logic (lazy creation, closing, pair reuse) is tested by injecting fake plugin objects.

**Non-Goals:**
- Wiring into `Pipeline` or the view, and the translated-text painter (`translated-overlay`).
- Download progress (the plugin has none).
- Tracking whether a line was already translated across frames, and reusing that translation (Week 3). This change reuses translations through the cache only.

## Decisions

**D1. Four small interfaces at the ML Kit boundary.**
- `TextEngine` (exists) recognizes lines.
- `LanguageEngine.identify(String text) -> Future<List<LanguageGuess>>`. A `LanguageGuess` holds a tag and a confidence.
- `TranslateEngine.translate(String text, {required TranslateLanguage from, required TranslateLanguage to}) -> Future<String>`.
- `ModelStore` has `isDownloaded`, `download({wifiOnly})` and `delete`.

Each has `close()` where it holds native resources, and each has an `MlKit*` implementation in `engines/mlkit/` that takes injectable plugin factories (the pattern `MlKitTextEngine` already uses). Logic above the interfaces is pure and tested with fakes. *Alternative:* one `TranslationEngine` covering language ID, translation and models. Rejected because `TranslationModels` needs only the model store, and separate fakes keep the tests focused.

**D2. Recognition across several scripts.**
- `MlKitTextEngine({TextScript script = TextScript.latin, ...})` creates `TextRecognizer(script: script.recognitionScript)`.
- `MultiScriptTextEngine(Map<TextScript, TextEngine>)` implements `TextEngine`. Each call it picks the next script in `TextScript` order (Latin, then Devanagari), recognizes, filters, stores that script's lines in `_latest[script]`, and returns the concatenation across scripts in that order.
- `close()` closes every inner engine once, and `recognize()` after `close()` throws `StateError`.
- With one script it simply passes through, plus filtering.

*Alternative:* run every script on every frame. Rejected because it doubles inference per frame, and the plan says to alternate.

**D3. Letter filter: `hasEnoughLetters(String text)` counts `RegExp(r'\p{L}', unicode: true)` matches and requires at least 2.**
- Unicode letters include Devanagari consonants and independent vowels, while vowel signs are `\p{M}`. So "नमस्ते" counts 4 letters and passes, and "2026" and "A" are dropped.
- A one-syllable Devanagari word such as "है" (one consonant plus a vowel sign) is dropped too. That's acceptable for signage, and noted as a risk.

**D4. Choosing the source language is a pure function: `chooseSourceLanguage(List<LanguageGuess> guesses, Set<TranslateLanguage>? hint) -> String?`.**
- `"und"` guesses are ignored.
- With no hint, it returns the best guess if its confidence is ≥ 0.5.
- With a multi-language hint, it returns the best guess whose tag maps to a hinted language and whose confidence is ≥ 0.5.
- With a single-language hint, the caller skips identification and uses that language's `bcpCode` (D6).

`MlKitLanguageEngine` uses `LanguageIdentifier(confidenceThreshold: 0.01)` with `identifyPossibleLanguages`, creates it on first use, and closes it once.

**D5. `TranslationCache` in `lib/src/cache/translation_cache.dart`.**
- It's an LRU of `capacity` entries (default 200) on a `LinkedHashMap`. A hit removes the entry and re-inserts it.
- The key is a record `(String text, TranslateLanguage from, TranslateLanguage to)`, where `text` is normalized: trimmed, with runs of whitespace collapsed to one space.
- It has no dependencies, so it is fully unit-testable.

**D6. `LineTranslator` in `lib/src/pipeline/line_translator.dart` is the policy layer, and implements decision A.**

It is created with `LanguageEngine`, `TranslateEngine`, `ModelStore`, `TranslationCache` and `void Function(LiveTranslateException) onError`. Its method is `translateLines(List<RecognizedLine> lines, {required TranslateLanguage target, Set<TranslateLanguage>? sourceLanguages}) -> Future<List<LineTranslation>>`, where `LineTranslation` holds the line, `sourceLanguage` and a nullable `translatedText`.

For each line, in parallel with `Future.wait`:
1. Choose the source language (D4), or use the single hinted language.
2. If the source is the target, drop the line.
3. If there is no source, return the line untranslated.
4. If the source maps to no `TranslateLanguage`, report `UnsupportedLanguagePair(source, target)` once per source tag (tracked in a set), and return the line untranslated.
5. Check model availability for the source and the target (`_ensureModel`).
6. If both models are available: return a cache hit, or call `translate`, store the result and return it. If translation throws, report `PipelineFailure` and return the line untranslated.

`_ensureModel(language)` uses a per-language state, one of `unknown`, `checking`, `available` or `downloading`:
- **`unknown`:** ask `isDownloaded`. If it says yes, the language becomes `available`. If not, start `download(wifiOnly: true)` without waiting, report `ModelNotDownloaded(language)` and set `downloading`.
- **`downloading`:** report nothing again. When the download succeeds the language becomes `available`. When it fails it returns to `unknown`, so a later line retries once and reports once per attempt.
- **Concurrent checks:** lines asking during `checking` share one in-flight `isDownloaded` future, so a frame with five Hindi lines triggers one check and at most one download.

**D7. The public `TranslationModels` lives in `lib/src/translation_models.dart` and is exported.**
- It's a `final class` with `TranslationModels()`, which uses `MlKitModelStore`, and a `@visibleForTesting TranslationModels.withStore(ModelStore)`.
- `downloaded()` runs `Future.wait` over `TranslateLanguage.values`.
- `download` maps a `false` result or a `PlatformException` to `ModelNotDownloaded(language)`. *Refined during implementation:* this mapping lives in `MlKitModelStore`, so `LineTranslator`'s automatic downloads fail the same way and `TranslationModels` passes the error through.

The dartdoc states that progress isn't available and that `wifiOnly` makes the download wait for Wi-Fi.

**D8. `MlKitTranslateEngine`** keeps one `OnDeviceTranslator` per `(from, to)` pair in a map, created on first use through an injectable factory, and `close()` closes them all once. `translated-overlay` calls `close()` when the target language changes, as the plan says. The engine re-creates translators on demand only until it's disposed, and `translate` after dispose throws `StateError`.

**D9. Files (from the plan's §6).**
- `engines/`: `language_engine.dart` (interface, `LanguageGuess`), `translate_engine.dart`, `model_store.dart`, `multi_script_text_engine.dart`, `line_filter.dart` (`hasEnoughLetters`)
- `engines/mlkit/`: `mlkit_language_engine.dart`, `mlkit_translate_engine.dart`, `mlkit_model_store.dart`, and an updated `mlkit_text_engine.dart`
- `cache/translation_cache.dart`
- `pipeline/line_translator.dart` (including `chooseSourceLanguage`)
- `translation_models.dart`

Nothing except `TranslationModels` is exported.

## Risks / Trade-offs

- [A model could be deleted between our check and `translateText`, letting the plugin download it over any network] → This is a narrow race that only `TranslationModels.delete` can cause during live translation. Accepted and documented. `translated-overlay` can mark a language `unknown` again after `delete` if needed.
- [Language ID is weak on 1–3 word sign lines and can't separate Hindi from Marathi] → `sourceLanguages` exists for exactly this. The README recipe for Hindi signage should set `sourceLanguages: {TranslateLanguage.hindi}` (Week 4 docs).
- [Language ID tags may not match translation codes for some languages, such as a script suffix like `"hi-Latn"` for romanized Hindi] → These map to `null`, so the line is untranslated and `UnsupportedLanguagePair` is reported once. Visible during the `translated-overlay` exit check, and acceptable for 0.1.
- [The letter filter drops one-syllable Devanagari words] → Rare on signage. Revisit if the exit check shows missing lines.
- [Translating every line of every processed frame costs platform calls] → The cache absorbs repeated text. Week 3 tracking reuses translations for tracked lines.
