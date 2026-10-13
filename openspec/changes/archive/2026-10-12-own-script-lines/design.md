# Design

## Context

See proposal.md for the motivation and the on-device evidence.

`MultiScriptTextEngine.recognize` runs one recognizer per frame, in turn. It stores that recognizer's lines that pass `hasEnoughLetters` (at least two `\p{L}` letters) as `_latest[script]`, then returns the merge of every script's latest lines, minus Latin lines at least half covered by a non-Latin line. `hasLetterOf(text, script)` and its `\p{Script=…}` patterns live in `lib/src/pipeline/line_translator.dart`. The single-hint path uses them, and `test/pipeline/script_test.dart` tests them.

## Goals / Non-Goals

**Goals:**
- No line from the Devanagari recognizer reaches translation unless it holds real Devanagari text.
- Every scenario of the `recognize` delta is a test in `test/engines/`.

**Non-Goals:**
- Changing the turn-taking or the merge of stale lines from the other script (see proposal, Out of scope).
- Changing the overlap filter.

## Decisions

**D1. Filter per recognizer, where `_latest` is stored.** `_latest[script]` keeps lines passing `hasEnoughLettersOf(line.text, script)`. Filtering at the merge instead would need to remember which script read each line. Filtering before storage keeps `_merge` unchanged.

**D2. At least two letters of the script, not one.**
- One letter would let through a Latin line in which the Devanagari reader misread a single character as Devanagari.
- A majority rule would drop real mixed lines such as "पतंजलि Dant Kanti toothpaste", where the Devanagari letters (vowel signs don't count) are the minority, and the Latin reader would turn the Hindi part into gibberish.
- Two matches the existing minimum, so the old any-script check becomes the same rule applied per script, and `hasEnoughLetters` is removed.

**D3. Script letter patterns move to `lib/src/engines/line_filter.dart`.** It will hold:
- `hasEnoughLettersOf(String text, TextScript script)`, which needs ≥ 2 matches of the script's pattern;
- `hasLetterOf(String text, TextScript script)`, moved here.

Both use `(?=\p{L})\p{Script=…}`. `\p{Script=Devanagari}` alone also matches vowel signs, which would let marks count as letters. For `hasLetterOf` this changes nothing in practice, because a vowel sign always follows a Devanagari letter.

`line_translator.dart` imports `hasLetterOf` from there. The pipeline already depends on the engines, so the dependency doesn't invert. `scriptOf` stays in the pipeline because it maps languages, not text. `hasLetterOf`'s tests move from `test/pipeline/script_test.dart` to `test/engines/line_filter_test.dart`.

## Risks / Trade-offs

- [A Devanagari line with only one letter outside vowel signs, such as "है", isn't shown] → It was already dropped by the any-script rule, so nothing changes.
- [When only Devanagari is selected (for example, Hindi chosen as the source), English text is no longer recognized at all] → Before this change, those lines reached the translator but got no source language under a Hindi hint (`detect-language`'s script check), so they were never labelled. Nothing visible changes.
- [ML Kit's Devanagari model might write real Hindi with Latin-lookalike characters] → Unlikely: it outputs Devanagari code points for Devanagari text. The on-device re-check with a Hindi sign in `lens-style-example-ui` 6.1 would catch it.
