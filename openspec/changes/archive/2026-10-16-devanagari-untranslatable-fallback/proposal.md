# Proposal

## Why

A Hindi sign can show no translation at all. On the Samsung, the replay frame `hi_caution.jpg` ("सावधान! आगे गहरा पानी है") was identified as Nepali at 0.5 or more, with Hindi below 0.5. Guesses under 0.5 don't count, so Nepali was the line's only language, and ML Kit has no Nepali translation model. The read showed nothing, and in the live view the source status would end at "Nepali can't be translated". Short Devanagari signs are easily confused between Hindi, Marathi and Nepali, so this will happen on real signs, not just in the test.

## What Changes

- When a Devanagari line's only language guesses at 0.5 or more are for languages ML Kit can't translate (such as Nepali), the line takes Hindi or Marathi instead: whichever identification ranks higher, or Hindi when it reports neither. The substitute keeps the replaced guess's confidence, so it can confirm the language and start the model download like any confident guess.
- The same applies when the app expects several source languages that include Hindi or Marathi. The substitute is then chosen among the expected Devanagari languages only. Until now, such a line had no source language.
- Latin lines are unchanged. Lorem ipsum identified as Latin stays untranslated.
- README "How it works" gets one sentence on the fallback, and the CHANGELOG an entry.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `detect-language`: two new requirements, the Devanagari fallback and its restriction to the expected languages. "Each line gets a source language" points to it, and the "No hinted language qualifies" scenario under "Source language hint" changes from no source language to Hindi.

## Impact

- `lib/src/pipeline/line_translator.dart`: `_guess` adds the substitute guess. `qualifyingGuesses` is unchanged.
- Tests: `test/pipeline/line_translator_test.dart` gets new cases. The pure `qualifyingGuesses` tests are unchanged.
- The replay frame `hi_caution.jpg` should pass without any change to `frames.json`.
- No public API change.
