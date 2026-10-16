# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: TranslatedLine is an immutable value`
- TO: `### Requirement: TranslatedParagraph is an immutable value`

- FROM: `### Requirement: TranslatedLine opacity is bounded`
- TO: `### Requirement: TranslatedParagraph opacity is bounded`

## MODIFIED Requirements

### Requirement: Single entry library
The package SHALL expose its public API through one library, `package:live_translate/live_translate.dart`. That library SHALL export only the documented public symbols. Implementation details under `lib/src/` SHALL NOT be exported.

#### Scenario: One import is enough
- **WHEN** a consumer imports only `package:live_translate/live_translate.dart`
- **THEN** `LiveTranslateView`, `LiveTranslateController`, `LiveTranslateState`, `OverlayBuilder`, `PipelineMetrics`, `SourceStatus` and all its subtypes, `TranslatedParagraph`, `TextScript`, `OverlayStyle`, `TranslationModels`, `LiveTranslateException` and all its subtypes resolve without further imports, and `TranslatedLine` does not

#### Scenario: Internal mapping is not exported
- **WHEN** a consumer imports the entry library
- **THEN** the mapping from `TextScript` to the recognizer's script type is not visible

#### Scenario: Engines are not exported
- **WHEN** a consumer imports the entry library
- **THEN** the text, language and translation engines, the translation cache and the line translator are not visible

#### Scenario: View plumbing is not exported
- **WHEN** a consumer imports the entry library
- **THEN** the camera session, the engines bundle the view is built with, and the functions and interface that connect a controller to its view are not visible

### Requirement: TranslatedParagraph is an immutable value
`TranslatedParagraph` SHALL hold `id`, `sourceText`, `translatedText`, an optional `sourceLanguage` (a BCP-47 code, or null when undetermined), `rect` (in view coordinates) and `opacity`. Instances SHALL be immutable and SHALL compare equal when all fields are equal.

#### Scenario: Equal fields mean equal values
- **WHEN** two `TranslatedParagraph`s are built with identical field values
- **THEN** they are `==` and have the same `hashCode`

#### Scenario: Any differing field breaks equality
- **WHEN** two `TranslatedParagraph`s differ only in `opacity`
- **THEN** they are not `==`

#### Scenario: Undetermined source language
- **WHEN** a `TranslatedParagraph` is built without a `sourceLanguage`
- **THEN** its `sourceLanguage` is null

### Requirement: TranslatedParagraph opacity is bounded
A `TranslatedParagraph`'s `opacity` SHALL be between 0.0 and 1.0 inclusive. A value outside that range SHALL be rejected in debug builds.

#### Scenario: Out-of-range opacity
- **WHEN** a `TranslatedParagraph` is built with `opacity: 1.5` in a debug build
- **THEN** construction fails with an assertion error
