# Design

## Context

- `LineTranslator._guess` calls the language engine, which returns every candidate at 0.01 or more (`MlKitLanguageEngine.candidateThreshold`). `qualifyingGuesses` then keeps those at 0.5 or more, excluding "und" and anything outside the hint.
- `_settle` groups lines by script. When any line of a group has a translatable guess, only translatable guesses vote. A line whose guesses are all untranslatable keeps its own best guess, which leaves it untranslated, and the source status reports unsupported once that language is confirmed.
- Confirmation needs guesses at 0.8 or more (`confirmConfidence`): either 20+ letters at once, or three sightings. A source model downloads only for a confirmed language.
- With the hint {Hindi, Marathi}, Nepali is filtered out by `qualifyingGuesses`, so the same sign has no guess at all.

## Goals / Non-Goals

**Goals:**
- A Devanagari line that ML Kit thinks is in an untranslatable language gets translated from Hindi or Marathi, and can confirm that language and download its model like any other line.

**Non-Goals:**
- Lowering the 0.5 threshold, or giving undetermined lines a language. A line with no confident guess at all stays undetermined.
- Any fallback for Latin. Untranslatable Latin guesses are mostly lorem ipsum, which should stay untranslated.
- Translating real Nepali properly. ML Kit has no Nepali model. A real Nepali sign will now be translated with the Hindi model, which is related and gives a rough translation. That's better than showing nothing.

## Decisions

### 1. The substitute is made in `_guess`, from the raw candidates
`_guess` keeps the raw list from `identify`. When `qualifyingGuesses` returns no translatable guess, the line has a Devanagari letter, and the raw list has an untranslatable guess at 0.5 or more (other than "und"), `_guess` returns one guess: the best of Hindi and Marathi in the raw list, restricted to the hint when one is given, at the confidence of the best untranslatable guess. Hindi is used when the raw list has neither. Under a hint without Hindi or Marathi, there's no substitute.
- **Why in `_guess`:** `_settle`, the vote and confirmation then work unchanged. `qualifyingGuesses` stays a pure filter with its existing tests.
- **Why the replaced guess's confidence:** a confident "Nepali" means the identifier is confident the text is a Devanagari-script language. Hindi's own low score would never reach `confirmConfidence`, so the model would never download and the line would stay "guessed" forever.
- **Alternative:** a fixed map from untranslatable languages to Hindi (ne→hi, sa→hi, …). Rejected because it needs a list of languages to keep up to date, and the raw candidates already rank Hindi against Marathi.

### 2. The untranslatable guess is dropped, not kept beside the substitute
The line returns only the substitute. If the untranslatable guess stayed too, the line's own best guess (used when the line keeps its own language) would still be Nepali in some paths. With one guess, the line's language is unambiguous.

## Risks / Trade-offs

- [A Nepali page is now translated as Hindi] → That rough translation is better than nothing, since ML Kit can't translate Nepali at all. The source status says "Hindi", which is honest about which model translated it.
- [A Marathi sign may now be translated as Hindi when identification reports neither] → Hindi is far more common on signage. Lines with any Marathi candidate still choose by rank.
- [Hindi downloads on a confident Nepali sighting] → That's the same 30 MB download a Hindi sign would trigger.
