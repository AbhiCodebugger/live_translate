# Tasks

## 1. Recognition across scripts

- [x] 1.1 Add `lib/src/engines/line_filter.dart` with `hasEnoughLetters(String text)` (at least 2 `\p{L}` matches; design D3). Verify with `test/engines/line_filter_test.dart`: "2026", "A", "!!" and "" fail; "Platform 2", "No entry" and "नमस्ते" pass.
- [x] 1.2 Give `MlKitTextEngine` a `script` parameter (default `TextScript.latin`) that creates `TextRecognizer(script: script.recognitionScript)` (design D2). Verify by extending `test/engines/mlkit/mlkit_text_engine_test.dart`: the factory receives the script, the default is Latin, and the existing tests still pass.
- [x] 1.3 Add `lib/src/engines/multi_script_text_engine.dart`: `MultiScriptTextEngine(Map<TextScript, TextEngine>)`, which takes turns between scripts in `TextScript` order, filters lines, keeps each script's latest lines, closes every engine once, and throws `StateError` after close (design D2). Verify with `test/engines/multi_script_text_engine_test.dart`, using `FakeTextEngine`s:
  - 4 frames use Latin, Devanagari, Latin, Devanagari;
  - the Devanagari turn's result contains both "EXIT" and "निकास";
  - Latin's next turn with no text drops "EXIT";
  - "2026" and "A" are filtered out;
  - with Latin and Devanagari selected and one frame recognized, only the Latin engine has been called;
  - a single script passes straight through;
  - close closes both engines once, and recognize after close throws.

## 2. Language detection

- [x] 2.1 Add `lib/src/engines/language_engine.dart` (the `LanguageEngine` interface and the `LanguageGuess` value) and `lib/src/engines/mlkit/mlkit_language_engine.dart`: `LanguageIdentifier(confidenceThreshold: 0.01)` created on first use through an injectable factory, `identifyPossibleLanguages` mapped to guesses, closed once, and throwing after close (design D1, D4). Verify with `test/engines/mlkit/mlkit_language_engine_test.dart` using a fake `LanguageIdentifier`: no identifier before the first call, guesses mapped with their confidences, closed exactly once, and an error after close.
- [x] 2.2 Add `chooseSourceLanguage(guesses, hint)` to `lib/src/pipeline/line_translator.dart` (design D4). Verify with `test/pipeline/choose_source_language_test.dart` covering the detect-language spec scenarios: Spanish 0.9 gives "es"; only "und" gives null; best below 0.5 gives null; hint {hindi, marathi} with Nepali 0.6, Marathi 0.3, Hindi 0.55 gives "hi"; hint {hindi, marathi} with Nepali 0.9, Hindi 0.1, Marathi 0.05 gives null. *Corrected during implementation:* the scenario originally used a single-language hint, which the spec says skips identification.

## 3. Translation engine and cache

- [x] 3.1 Add `lib/src/engines/translate_engine.dart` and `lib/src/engines/mlkit/mlkit_translate_engine.dart`: one `OnDeviceTranslator` per `(from, to)` pair, created on first use through an injectable factory, all closed once, and throwing after close (design D8). Verify with `test/engines/mlkit/mlkit_translate_engine_test.dart` using a fake `OnDeviceTranslator`: Spanish→English and French→English twice each create exactly two translators, text goes to the right one, close closes both once, and translate after close throws.
- [x] 3.2 Add `lib/src/cache/translation_cache.dart`: an LRU with capacity 200, keyed by normalized text and language pair (design D5). Verify with `test/cache/translation_cache_test.dart`: a hit after a put; " Salida  de emergencia" and "Salida de emergencia" share an entry; different language pairs don't share; after 201 puts the first entry is evicted; reading an entry protects it from eviction.

## 4. Model store and public `TranslationModels`

- [x] 4.1 Add `lib/src/engines/model_store.dart` and `lib/src/engines/mlkit/mlkit_model_store.dart`, wrapping `OnDeviceTranslatorModelManager` through an injectable instance and passing `bcpCode` and `isWifiRequired` (design D1). Verify with `test/engines/mlkit/mlkit_model_store_test.dart` using a fake manager: the right BCP-47 codes and Wi-Fi flag are passed for check, download and delete.
- [x] 4.2 Add `lib/src/translation_models.dart`: `final class TranslationModels` with `isDownloaded`, `download({wifiOnly = true})`, `delete` and `downloaded()`, plus `@visibleForTesting TranslationModels.withStore`. A `false` result or a `PlatformException` becomes `ModelNotDownloaded`, and the dartdoc covers Wi-Fi waiting and the lack of progress (design D7). Export it from `lib/live_translate_overlay.dart`. Verify with `test/translation_models_test.dart` using a fake `ModelStore`, covering every model-management spec scenario: `isDownloaded`, Wi-Fi required by default, `wifiOnly: false` passed through, a failed download throws `ModelNotDownloaded(hindi)`, delete, and `downloaded()` returns exactly {English, Hindi}. Also extend `test/public_api_test.dart` so `TranslationModels` resolves through the entry library.

## 5. Line translator

- [x] 5.1 Add `LineTranslator` and `LineTranslation` to `lib/src/pipeline/line_translator.dart`, implementing design D6: drop target-language lines; leave lines with no source untranslated; report `UnsupportedLanguagePair` once per tag; track per-language model state with a shared in-flight check; start a Wi-Fi-only download and report `ModelNotDownloaded` once per attempt; use the cache; report a translation failure as `PipelineFailure`; and use a single hinted language without identification. Verify with `test/pipeline/line_translator_test.dart`, using fakes for all four collaborators, with one test per scenario in the translate spec and the detect-language spec's "Single hinted language" and "Lines already in the target language" scenarios:
  - three frames with the Hindi model missing give one download with `wifiOnly: true`, one `ModelNotDownloaded`, untranslated lines and zero translate calls;
  - after the download completes, lines translate;
  - after a failed download, one retry happens;
  - five Hindi lines in one frame give one model check;
  - "la-Latn" in three frames gives one `UnsupportedLanguagePair`;
  - when one line's translation throws, the other line still translates and one `PipelineFailure` is reported;
  - the same text over ten frames gives one translate call.

## 6. Checks

- [x] 6.1 Run the package checks. Verify that `dart format --set-exit-if-changed .` makes no changes, `flutter analyze` reports no issues, `flutter test` passes, and the only new export in `lib/live_translate_overlay.dart` is `src/translation_models.dart` (check with `git diff lib/live_translate_overlay.dart`).
- [x] 6.2 Measure coverage. Run `flutter test --coverage` and add up `LH`/`LF` for the `SF:lib/src/cache/` and `SF:lib/src/pipeline/` entries in `coverage/lcov.info`. Verify that each directory is at least 90%, and report both figures.
