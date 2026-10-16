# Proposal

## Why

On a Samsung Galaxy (Android 15), pointing the example app at text in "Detect language" mode often showed "Detect language" for a long time, and sometimes forever, with no sign of what was happening. Three things cause this:

- After one successful read, a steady picture is never read again. Short text needs its language seen in 3 reads before its model downloads, so holding the phone still stalls detection indefinitely.
- The app only learns a language once a line is translated, so the guess, the download and the dead ends (an unreadable script, an untranslatable language) are all invisible.
- All Latin-script paragraphs in a frame share one language. An untranslatable language that covers most of the page, such as lorem ipsum identified as Latin, takes over the real paragraphs too, and nothing gets translated.

ML Kit gives no download progress and no way to install a model from our own servers, so the download itself can't be made faster. What we can do is stop the stalls and show the user each stage.

## What Changes

- **New `SourceStatus` on `LiveTranslateController`.** It reports where finding the source language stands: searching, guessed (seen but not yet confirmed), downloading, ready, unsupported, not found, or download failed, with the language where one applies. Listeners are notified when it changes. This is a new public API, with no breaking change.
- **A steady picture whose language isn't settled is read again.** While the held result has paragraphs with no language, or a guessed but unconfirmed language, the live view reads a steady picture again every second, so short text confirms within a few seconds without moving the phone. It stops once the language is settled, or after the status becomes "not found".
- **"Not found" instead of waiting forever.** After 3 reads of a steady picture with no paragraph getting a language, the status becomes not found. That covers no text, unreadable scripts like Cyrillic, and gibberish.
- **Untranslatable languages don't capture a script group.** In the per-script vote, only languages with an on-device translation model compete, when any line has one. Lines whose only guesses are untranslatable keep their own guess and stay untranslated.
- **Example app source chip shows the stages:** "Looking for text…", "Spanish?", "Spanish" with a progress indicator while downloading, "Spanish", "No supported text found", "Latin can't be translated" and "Download failed".
- README documents `SourceStatus` and the re-read behaviour.

Out of scope: our own model hosting or a different translation engine, reading new scripts (Cyrillic and others), prefetching models, and downloading before a language is confirmed.

## Capabilities

### New Capabilities
- `source-status`: what the source-language status reports, how it moves between stages, and which language it names when a picture holds several.

### Modified Capabilities
- `controller`: the controller exposes `sourceStatus` and notifies listeners when it changes.
- `live-translation`: a steady picture is read again while its source language isn't settled, instead of only once.
- `detect-language`: the per-script vote only counts translatable languages when there are any.
- `example-app`: the source chip shows the source status instead of only naming the language of translated lines.
- `public-api`: the entry library exports `SourceStatus` and its subtypes.

## Impact

- `lib/src/pipeline/line_translator.dart`: computes each read's source status from guesses, confirmation and model state; changes the script vote.
- `lib/src/pipeline/pipeline.dart`, `lib/src/still/read_result.dart`: carry the status out of each read.
- `lib/src/live/live_settler.dart`, `lib/src/view/live_translate_view.dart`: re-read timing, "not found" counting, and publishing the status to the controller.
- `lib/src/controller/live_translate_controller.dart`, a new `lib/src/models/source_status.dart`, `lib/live_translate.dart`.
- `example/lib/camera_screen.dart`, `example/lib/languages.dart`: the source chip.
- `README.md`, `CHANGELOG.md`, and tests for each of the above.
- Battery: up to a few extra reads per steady scene, only while the language isn't settled.
