# Tasks

## 1. Tests for the new scenarios' examples

- [x] 1.1 In `test/pipeline/line_translator_test.dart`, add the two "A single hinted language skips identification" scenarios: under a {Spanish} hint, "Salida" is assigned "es" with no identification, and "नमस्ते" gets no source language with no identification. Verify that `flutter test test/pipeline` passes.
- [x] 1.2 In `test/pipeline/qualifying_guesses_test.dart`, add the two "Several hinted languages narrow the guesses" scenarios: with {Spanish, French}, guesses Italian 0.9 and Spanish 0.6 give Spanish; with {Hindi, Marathi}, only Marathi 0.4 gives nothing. Verify that `flutter test test/pipeline` passes.
- [x] 1.3 In `test/engines/multi_script_text_engine_test.dart`, add "Misreading three-quarters over a Latin line": Latin "Pourquoi utiliser" at (0, 0)–(200, 20) and Devanagari "Pourquoi कख utiliser" at (0, 5)–(200, 25) give only the Latin line. Check that "Exactly half covered" and "As many Devanagari letters as Latin" are already covered by the existing tests "exactly half covered is dropped" and "a mixed line with as many Devanagari letters wins". Verify that `flutter test test/engines` passes.

## 2. Checks

- [x] 2.1 Verify that:
  - `openspec validate split-long-requirements --strict` passes;
  - every requirement description in the two deltas is under 500 bytes;
  - `dart format --set-exit-if-changed .` makes no changes;
  - `flutter analyze` reports no issues;
  - `flutter test` passes.

## Workflow follow-up

- Archive the change, then confirm that `openspec validate --specs --strict` passes for every main spec.
