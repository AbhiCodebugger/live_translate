# Tasks

## 1. Fallback

- [x] 1.1 In `LineTranslator._guess`, keep the raw candidates from `identify` and add the substitute guess (design §1 and §2): only for a line with a Devanagari letter, no qualifying translatable guess, and an untranslatable guess at 0.5 or more other than "und". Choose the best of Hindi and Marathi among the raw candidates, restricted to the hint, or Hindi when neither is reported. Give it the untranslatable guess's confidence. Add no substitute under a hint without a Devanagari language. Update the `_guess` and `_settle` doc comments. Verify with new `test/pipeline/line_translator_test.dart` cases, one per `detect-language` scenario of the new requirement and the changed "No hinted language qualifies" and "Only Marathi expected" scenarios. They cover: the Nepali/Hindi sign translated from Hindi; Marathi ranked above Hindi; Nepali only giving "hi"; a long Nepali 0.9 line confirming Hindi and starting its download; Nepali 0.6 with Hindi 0.55 unchanged; Latin "la" unchanged; a Spanish and French hint with no fallback; an undetermined line staying undetermined. Also verify that `test/pipeline/qualifying_guesses_test.dart` passes unchanged, and that `flutter test` passes
- [x] 1.2 Check the source status for the fallback: a Nepali-identified Hindi sign must report Hindi (guessed, downloading or ready), never unsupported "ne". Verify with a `translateFrame` status test

## 2. Docs

- [x] 2.1 Add one sentence to README "How it works": a Devanagari paragraph identified only as a language ML Kit can't translate, such as Nepali, is translated from Hindi or Marathi instead. Add a CHANGELOG "Unreleased" entry. Verify both mention it

## 3. Checks

- [x] 3.1 Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` at the root and in `example/`, `dart pub publish --dry-run`, and `openspec validate devanagari-untranslatable-fallback --strict`. Verify all pass
- [x] 3.2 The user reruns the replay test on the Samsung (`flutter test integration_test/replay_test.dart -d <device>` from `example/`). Verify that `hi_caution.jpg` now passes and no other frame regresses
