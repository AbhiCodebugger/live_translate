# Spec Delta

## MODIFIED Requirements

### Requirement: TranslatedParagraph is an immutable value
`TranslatedParagraph` SHALL hold `id`, `sourceText`, `translatedText`, `sourceLanguage` (the `TranslateLanguage` the paragraph was translated from, always present), `rect` (in view coordinates) and `opacity`. Instances SHALL be immutable and SHALL compare equal when all fields are equal.

#### Scenario: Equal fields mean equal values
- **WHEN** two `TranslatedParagraph`s are built with identical field values
- **THEN** they are `==` and have the same `hashCode`

#### Scenario: Any differing field breaks equality
- **WHEN** two `TranslatedParagraph`s differ only in `opacity`
- **THEN** they are not `==`

#### Scenario: Undetermined source language
- **WHEN** a consumer builds a `TranslatedParagraph` without a `sourceLanguage`
- **THEN** the code doesn't compile, because a translated paragraph always has a source language

#### Scenario: Shown paragraphs name their source language
- **WHEN** the view shows a paragraph translated from Spanish
- **THEN** its `sourceLanguage` is `TranslateLanguage.spanish`

### Requirement: Supported text scripts
`TextScript` SHALL offer exactly `latin` and `devanagari` as constants, and `TextScript.values` SHALL list them. Each script SHALL have a `name` ("latin", "devanagari") and SHALL correspond to an on-device text recognition script available on both Android and iOS. `TextScript` SHALL NOT be an enum, so that scripts can be added in a minor version without breaking consumer code. Scripts SHALL be usable as constants, in const sets and as map keys.

#### Scenario: Script set
- **WHEN** a consumer lists `TextScript.values`
- **THEN** the result is exactly `latin` and `devanagari`

#### Scenario: Every script maps to an on-device recognizer
- **WHEN** any `TextScript` value is mapped to the recognizer's script type
- **THEN** a matching on-device recognizer script exists, and Devanagari maps to the Devanagari recognizer

#### Scenario: Existing usage compiles
- **WHEN** a consumer writes `const LiveTranslateView(scripts: {TextScript.latin})`
- **THEN** the code compiles, and the view reads Latin only

#### Scenario: Names
- **WHEN** a consumer reads `TextScript.devanagari.name` and `TextScript.devanagari.toString()`
- **THEN** they are "devanagari" and "TextScript.devanagari"

#### Scenario: Consumers can't add scripts
- **WHEN** consumer code tries to create, extend or implement a `TextScript`
- **THEN** compilation fails

## ADDED Requirements

### Requirement: Closed hierarchies are stable within a major version
`LiveTranslateException` and `SourceStatus` SHALL stay sealed, so consumers can match on them exhaustively. Their sets of subtypes SHALL change only in a major version. The README SHALL state this policy, and SHALL also state that `TextScript` can gain scripts in a minor version.

#### Scenario: Policy documented
- **WHEN** a consumer reads the README's API section
- **THEN** it says that new `LiveTranslateException` and `SourceStatus` subtypes come only in a major version, and that new scripts can come in a minor version

### Requirement: OverlayStyle can be copied with changes
`OverlayStyle.copyWith` SHALL return a style with the given fields replaced and every other field unchanged, applying the same font-size checks as the constructor. `OverlayStyle.toString` SHALL name every field and its value.

#### Scenario: One field changed
- **WHEN** a consumer calls `const OverlayStyle().copyWith(maxFontSize: 48)`
- **THEN** the result has a maximum font size of 48 and every other field at its default

#### Scenario: No changes
- **WHEN** a consumer calls `copyWith()` with no arguments on a style
- **THEN** the result is `==` to the original

#### Scenario: Inverted bounds through copyWith
- **WHEN** a consumer calls `const OverlayStyle().copyWith(minFontSize: 40)` in a debug build, with the maximum at its default of 28
- **THEN** it fails with an assertion error

#### Scenario: Readable description
- **WHEN** a consumer prints `const OverlayStyle()`
- **THEN** the text names `OverlayStyle` and includes `maxFontSize: 28.0`
