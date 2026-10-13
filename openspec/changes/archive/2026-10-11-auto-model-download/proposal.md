# Proposal

## Why

Pointing the camera at foreign text should just work, the way Google Lens does: the language is detected, its model arrives on its own, and the text is translated into the user's language. Today the app has to pick a target language. The target model only downloads once text is seen, and only over Wi-Fi. A detected language's model downloads only if the app listed that language in advance. Hindi isn't even read unless the app selects Devanagari. So on an English phone pointed at a Hindi sign with default settings, nothing gets translated.

## What Changes

- **Device language by default:** `targetLanguage` becomes optional. Without it, the view translates into the device's language, or English when that language has no on-device translation model.
- **Target model at start:** the target model is checked as soon as the view starts, or whenever the target changes, and downloaded straight away if it's missing. It doesn't wait for the first line of text.
- **Detected languages download on their own:** once a detected language is confirmed, its missing model downloads automatically, whether or not the app listed it in `sourceLanguages`. Confirmation is unchanged: confidence 0.8 or more in 3 of the last 10 frames. Source downloads still run one at a time, and stray detections still never download.
- **One language per script in each frame:** Hindi and Marathi share the Devanagari script, and short Hindi lines are sometimes identified as Marathi. Each frame now settles one language per script, from all its lines' guesses together. A language confirms only by leading its script in more recent frames than any rival. So Hindi text no longer downloads Marathi as well. The exception: a line identified as the target language is still dropped.
- **Any network:** automatic downloads no longer wait for Wi-Fi. Each download started is still reported once as `ModelNotDownloaded`, so apps can show progress. `TranslationModels.download`, which the app calls itself, keeps its `wifiOnly: true` default.
- **Both scripts by default:** without `scripts`, the view reads Latin and Devanagari, so Hindi is detected with no setup in Dart.
- **Example app:** relies on the defaults (no fixed English target, no explicit scripts) and drops the "Hindi only" chip. Each `ModelNotDownloaded` shows "Downloading the … model".

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `detect-language`: within a frame, the lines of each script share one language, chosen from all their guesses together; a hint with several languages narrows that choice.
- `live-view`: the target language defaults to the device language (English fallback); the default scripts become Latin and Devanagari.
- `translate`:
  - missing models download on any network;
  - the target model is fetched when translation into it begins, not on the first line;
  - a confirmed source language downloads whether or not it was expected, and confirmation needs a language to lead its script in more recent frames than any other;
  - the purpose line no longer promises "never downloads a model over mobile data unasked".

## Impact

- **Changed code:**
  - `lib/src/pipeline/line_translator.dart` (download policy, network, target prefetch)
  - `lib/src/pipeline/pipeline.dart` (prefetch the target on creation)
  - `lib/src/view/live_translate_view.dart` (optional target, device-language default, default scripts)
  - a new device-language helper under `lib/src/`
  - matching tests
  - `example/lib/main.dart` and `example/test/widget_test.dart`
- **Public API:** nothing exported changes. The view is still internal until 0.1.0.
- **Apps:** the Devanagari recognition model must be added natively for the default to work: the `text-recognition-devanagari` Gradle dependency and the `GoogleMLKit/TextRecognitionDevanagari` pod, as the example already does. The README, still the template, gains a "Getting started" section saying so, since `TextScript.devanagari`'s docs already point there.
- **Docs:** `README.md`.
- **Data use:** automatic downloads, about 30 MB per model, can now use mobile data.
