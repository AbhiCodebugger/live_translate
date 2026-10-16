# Tasks

## 1. SourceStatus type

- [x] 1.1 Add `lib/src/models/source_status.dart` with the sealed `SourceStatus` and its seven subtypes (value equality, `toString`), and export it from `lib/live_translate.dart`; verify with a new `test/models/source_status_test.dart` (equality, exhaustive switch) and the "One import is enough" case in `test/public_api_test.dart`

## 2. Translatable-only script vote

- [x] 2.1 In `LineTranslator._settle`, count only translatable tags (`BCP47Code.fromRawValue`) in a group's totals when any line has one, and let lines with only untranslatable guesses keep their own best guess; verify with `test/pipeline/line_translator_test.dart` cases "Lorem ipsum beside a Spanish heading" and "Only untranslatable guesses", with existing vote and `la-Latn` unsupported tests still passing

## 3. Per-read status and model events in the pipeline

- [x] 3.1 Have `LineTranslator` report each read's status (name the language per "One language named for the picture", map it to guessed, downloading, ready or unsupported, or "none"); verify with `line_translator_test.dart` cases for guessed-before-confirmation, downloading after confirmation, ready with model present, target-language page, unsupported only after confirmation, the majority and tie rules, and a single hinted language
- [x] 3.2 Add an internal model-events stream beside `Pipeline.modelsReady` (kept, so the `createTranslator` signature doesn't change) (download started, ready, failed per language), emitting failed where `_onMissing` currently resets to missing, and carry the read status on `ReadResult`; verify in `test/pipeline/pipeline_test.dart` that a failed fake download emits failed and a completed one emits ready, and that existing download-refresh tests in `test/view/live_translate_view_test.dart` still pass

## 4. Settler re-reads

- [x] 4.1 Add the `unsettled` input and `rereadInterval` (1 s) to `LiveSettler`, recording when a read finished, so a steady picture with a held result is read again only while unsettled and 1 s after the last read; verify in `test/live/live_settler_test.dart` with the fake clock: re-read at 1 s while unsettled, none at 0.9 s, none when settled, movement still waits for the 300 ms settle
- [x] 4.2 Update `live-translation` behaviour notes in `README.md` (a steady picture is read again until its language is settled) and verify the README describes the new read rule

## 5. View and controller status

- [x] 5.1 In `LiveTranslateView`, combine each read's status with the not-found count (3 consecutive reads with no language, reset on clear, settings change or a found language), reset to searching on a clear, apply model events for the named language between reads, feed `unsettled` to the settler, and handle frozen reads; verify in `live_translate_view_test.dart` with fake engines: short sign held still confirms on the third read and downloads, a Ukrainian-like page (no text) reaches not found after three reads and stops reading, download failure shows download failed, a frozen re-read after a download gives ready
- [x] 5.2 Add `sourceStatus` to `LiveTranslateController` through `_publish`, notifying only on a change and reporting searching when unattached; verify in `test/controller/live_translate_controller_test.dart` (guessed notifies, unchanged status doesn't, unattached is searching)
- [x] 5.3 Document `SourceStatus` and `controller.sourceStatus` in `README.md` with a short `switch` example, and add a CHANGELOG entry; verify the README snippet compiles by mirroring it in a test or the example app

## 6. Example app source chip

- [x] 6.1 Replace `detectedLanguage()` in `example/lib/camera_screen.dart` and `example/lib/languages.dart` with rendering of `controller.sourceStatus`: "Looking for text…", "Spanish?", name plus progress indicator while downloading, name, "No supported text found", "<name> can't be translated" (with a small name table for untranslatable language-ID tags such as `la`, otherwise the tag), and "<name> · download failed"; verify with updated `example/test/camera_screen_test.dart` and `example/test/languages_test.dart` covering every scenario of "Detected language on the source chip"
- [x] 6.2 Update `example/README.md` and the README's example-app "Language pill" description for the new chip text; verify both describe the stages

## 7. Integration checks

- [x] 7.1 Run `flutter analyze` and `flutter test` in the package and in `example/`, and `openspec validate faster-first-translation --strict`; verify all pass
- [x] 7.2 Hand the build to the user for a manual check on the Samsung Galaxy: a Spanish sign held still shows "Spanish?" then downloading within about 5 s, uk.lipsum.com shows "No supported text found" or "Latin can't be translated", and es.lipsum.com translates the Spanish headings
