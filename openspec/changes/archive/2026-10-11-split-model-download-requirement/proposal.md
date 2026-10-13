# Proposal

## Why

The `translate` requirement "Missing models download over Wi-Fi only" grew to 502 characters while `translated-overlay` was fixing the model downloads. That's over OpenSpec's 500-character limit, so `openspec validate translate --type spec --strict` fails. The description now packs three behaviours into one requirement, which also makes each behaviour harder to test and cite on its own.

## What Changes

- Cut the description of "Missing models download over Wi-Fi only" down to one behaviour: models are checked before translating, lines needing a missing model are returned untranslated, translation is never attempted while a model is missing, and source downloads follow the confirmation rule. Its name and all four scenarios stay as they are.
- Move "a missing target model downloads at once" into its own requirement, with its own scenario.
- Move "downloads require Wi-Fi, and each download started is reported once" into its own requirement, with its own scenarios.
- **No behaviour changes.** The meaning of the specification is unchanged; only its structure is. The code already does all three things. Tests are added only where a moved behaviour had no test of its own.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `translate`: "Missing models download over Wi-Fi only" is split into three requirements, one behaviour each, with the same overall meaning.

## Impact

- **Specs:** `openspec/specs/translate/spec.md` (when archived): 8 → 10 requirements.
- **Code:** none.
- **Tests:** possibly `test/pipeline/line_translator_test.dart`, if a moved behaviour lacks a dedicated test.
- **Validation:** `openspec validate translate --type spec --strict` passes again.
