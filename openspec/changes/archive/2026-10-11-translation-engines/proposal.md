# Proposal

## Why

Week 1 draws boxes around Latin text. Week 2's goal is translated text over each line, including Hindi signage. That needs Devanagari recognition, language detection, on-device translation and model management. This change builds all four as engines behind interfaces, fully tested with fakes and without a phone. The next change, `translated-overlay`, wires them into the view and the painter and runs the on-device Hindi exit check.

We also found that ML Kit's `translateText` silently downloads missing models over any network on every call. The model policy chosen while exploring Week 2 is: download automatically, over Wi-Fi only, and report `ModelNotDownloaded` once. Enforcing it means checking for models ourselves before translating.

## What Changes

- **Multi-script recognition:** `MlKitTextEngine` takes a `TextScript`. A new multi-script engine alternates between scripts' recognizers frame by frame, keeps each script's latest lines so neither script's lines blink, and filters out lines with fewer than two letters (very short, digits-only and punctuation-only lines).
- **Language detection:** a `LanguageEngine` interface with an ML Kit language-ID implementation. Each line gets a source language: the only hinted source language if exactly one is given, otherwise the most likely identified language within the hint set (or among all languages without a hint), or none.
- **Translation:** a `TranslateEngine` interface with an ML Kit implementation that creates one translator per language pair on first use and closes them all on `close()`.
- **Translation cache:** an LRU cache of 200 entries, keyed by normalized text and language pair.
- **Model policy (decision A):** a line translator that:
  - drops lines already in the target language;
  - leaves lines with no detected language untranslated;
  - reports `UnsupportedLanguagePair` once per language;
  - checks both models before translating;
  - starts a Wi-Fi-only download for a missing model;
  - reports `ModelNotDownloaded` once per language;
  - leaves those lines untranslated until the download completes.
- **Public `TranslationModels`** (plan §4.4): `isDownloaded`, `download({wifiOnly = true})`, `delete` and `downloaded`, exported from the entry library.

## Capabilities

### New Capabilities
- `detect-language`: Choosing each line's source language from language ID and the optional source-language hint, and dropping lines already in the target language.
- `translate`: Turning a line into the target language with lazily created translators, a cache, the Wi-Fi-only automatic-download policy, and once-per-language error reporting.
- `model-management`: The public `TranslationModels` API for checking, downloading (Wi-Fi only by default), deleting and listing translation models.

### Modified Capabilities
- `recognize`:
  - Devanagari joins Latin.
  - Several scripts alternate frame by frame, and each keeps its latest lines.
  - Lines with fewer than two letters are filtered out.
  - The recognizer's lifetime becomes per script.
- `public-api`: the entry library also exports `TranslationModels`.

## Impact

- **New code:**
  - `lib/src/engines/language_engine.dart`, `lib/src/engines/translate_engine.dart` and `lib/src/engines/model_store.dart` (interfaces)
  - their ML Kit implementations under `lib/src/engines/mlkit/`
  - `lib/src/engines/multi_script_text_engine.dart`
  - `lib/src/cache/translation_cache.dart`
  - `lib/src/pipeline/line_translator.dart`
  - `lib/src/translation_models.dart`
  - tests for all of the above
- **Changed code:** `lib/src/engines/mlkit/mlkit_text_engine.dart` (script parameter) and `lib/live_translate_overlay.dart` (one new export).
- **Dependencies:** none added. `google_mlkit_language_id` and `google_mlkit_translation` are already dependencies.
- **Out of scope (moves to `translated-overlay`):**
  - wiring these engines into `Pipeline` and `LiveTranslateView`;
  - `targetLanguage`, `scripts`, `sourceLanguages` and `onError` on the view;
  - the translated-text painter and `OverlayStyle` rendering;
  - the on-device Hindi exit check.
