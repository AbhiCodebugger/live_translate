# Proposal

## Why

`openspec validate --specs --strict` fails on two requirements whose descriptions run past 500 characters, because each states two behaviours at once:
- `detect-language`'s "Source language hint" (556 characters) covers both the single-language hint and the several-language hint;
- `recognize`'s "Overlapping Latin readings are dropped" (585) covers both which reading wins an overlap and the exception for mostly-Latin misreadings.

Splitting each into one behaviour per requirement makes strict validation pass, and each rule becomes easier to find and test.

## What Changes

- **"Source language hint"** keeps its name and all six scenarios. Its description becomes a short statement that a hint limits the languages a line can be given, pointing to two new requirements:
  - "A single hinted language skips identification": the exactly-one-language rule;
  - "Several hinted languages narrow the guesses": the 0.5 threshold among hinted languages.
- **"Overlapping Latin readings are dropped"** keeps its name and all five scenarios. Its description becomes a short statement that, where readings overlap, the one in the text's own script is kept, pointing to two new requirements:
  - "A non-Latin reading replaces Latin gibberish under it";
  - "A mostly-Latin misreading gives way to the Latin line".
- Scenario wording that still says "turn" ("the Devanagari turn found") is updated to "recognizer", because scripts no longer take turns. The meaning is unchanged.
- **No behaviour changes.** The new requirements' scenarios restate existing behaviour with fresh examples. Where no test covers an example yet, the tasks add one.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `detect-language`: "Source language hint" is split into an overview and two new requirements, one per hint size.
- `recognize`: "Overlapping Latin readings are dropped" is split into an overview and two new requirements, one per direction of the overlap rule.

## Impact

- **Specs only**, plus tests for the new scenarios' examples. No code changes.
- After archiving, `openspec validate --specs --strict` should pass for every main spec.
