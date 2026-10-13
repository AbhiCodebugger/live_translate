# Tasks

## 1. Script-aware letter filter

- [x] 1.1 In `lib/src/engines/line_filter.dart`, replace `hasEnoughLetters` with `hasEnoughLettersOf(String text, TextScript script)`, which needs at least two letters of the script (design D2). Move `hasLetterOf` and its script patterns there from `lib/src/pipeline/line_translator.dart`, which now imports them (D3). Update `test/engines/line_filter_test.dart`:
  - for Latin: "2026", "A", "!!", "" and "12:30" are dropped, and "Platform 2", "No entry" and "Ok" are kept;
  - for Devanagari: "नमस्ते" and "दवा 500mg" are kept, and "है", "Elememte chan na" and "Lorem क ipsum" are dropped;
  - move the `hasLetterOf` cases from `test/pipeline/script_test.dart` here.

  Verify that `flutter test test/engines test/pipeline` passes.

## 2. Per-recognizer filtering

- [x] 2.1 In `lib/src/engines/multi_script_text_engine.dart`, filter each recognizer's lines with `hasEnoughLettersOf(line.text, script)` before storing them in `_latest` (design D1). Add cases to `test/engines/multi_script_text_engine_test.dart`, one per new scenario of the `recognize` delta:
  - Latin text read by the Devanagari turn is not returned;
  - a stray Devanagari letter is not returned;
  - "दवा 500mg" is returned;
  - on a Latin page, the Devanagari turn's result contains only the Latin turn's "Pourquoi l'utiliser?".

  Keep the existing cases (digits-only, single letter, both scripts' latest lines, overlap) passing. Verify that `flutter test` passes in the package.

## 3. Checks

- [x] 3.1 Verify that:
  - `dart format --set-exit-if-changed .` makes no changes;
  - `flutter analyze` reports no issues;
  - `flutter test` passes in the package and in `example/`;
  - `git diff lib/live_translate_overlay.dart` is empty, so the public API is unchanged.
