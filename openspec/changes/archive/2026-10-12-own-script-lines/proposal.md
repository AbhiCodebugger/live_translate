# Proposal

## Why

During the on-device check of `lens-style-example-ui`, a French page under "Detect language" showed every line twice, offset by the hand's movement, and one copy was full of misread words ("rechecate", "Elememte", "ermbarasian phrass"). The Devanagari recognizer also reads Latin characters, just badly, and the engine merges its latest lines with the Latin recognizer's. Its misreadings of Latin text then get translated as if they were real lines. Reading both scripts is the default, so every Latin page is affected.

## What Changes

- Each recognizer keeps only lines with at least two letters of its own script. The Devanagari recognizer's readings of Latin-only text are dropped, along with lines where it found only a stray Devanagari letter. The Latin recognizer's lines are already Latin letters, so they're unaffected. Its gibberish over Devanagari text is still handled by the existing overlap filter.
- This replaces the current "at least two letters in any script" check, which becomes the same rule applied per recognizer.
- Mixed lines still work: a Devanagari line with an English word or a number, such as "दवा 500mg", keeps its two Devanagari letters and stays.
- The script letter test (`hasLetterOf`) moves from the pipeline to the engines' line filter, where recognition can use it.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `recognize`: "Lines without enough letters are dropped" now counts only letters of the script whose recognizer read the line.

## Impact

- **Code:**
  - `lib/src/engines/line_filter.dart`: the script-aware letter count, and the script letter test moved here;
  - `lib/src/engines/multi_script_text_engine.dart`: filters each recognizer's lines by its own script;
  - `lib/src/pipeline/line_translator.dart`: imports the moved test;
  - matching tests in `test/engines/` and `test/pipeline/script_test.dart`.
- **Public API:** unchanged.
- **Dependencies:** none.
- **Related:** `lens-style-example-ui` shows the detected language on its source chip, and these misreadings currently skew it. Its on-device check (task 6.1) should run after this change.
- **Out of scope:** on a real bilingual sign, each script's lines still come from alternate frames, so when the phone moves, one script's labels trail by a frame. Only the doubles from cross-script misreadings are fixed here.
