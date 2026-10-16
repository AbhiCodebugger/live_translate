# public-api Specification

## Purpose

Defines the public surface of the `live_translate` package: what one import provides, the value types consumers receive, the errors they handle, and which text scripts are supported.

## Requirements

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

### Requirement: Test-only view parameters are internal
The view's constructor parameters for injecting a camera session, engines and a clock SHALL exist only for the package's own tests. They SHALL be marked internal so that static analysis warns code outside the package that passes them. Their types SHALL NOT be exported. A consumer never needs them to build a working view.

#### Scenario: Consumer passes a test seam
- **WHEN** code in another package, such as the example app, passes the view's camera-session parameter
- **THEN** the analyzer reports a use of an internal member

#### Scenario: Package tests use the seams
- **WHEN** the package's own tests pass fake sessions, engines and a clock to the view
- **THEN** the analyzer reports no warning

#### Scenario: Working view without seams
- **WHEN** a consumer builds `LiveTranslateView()` with only public parameters
- **THEN** it uses the device camera, ML Kit and the system clock

### Requirement: Dependency types are re-exported
The entry library SHALL re-export the third-party types the public API uses: `TranslateLanguage` and `ResolutionPreset`. It SHALL NOT re-export any other symbols from those dependencies.

#### Scenario: Consumer uses a language without a direct dependency
- **WHEN** a consumer depends only on `live_translate` and refers to `TranslateLanguage.english`
- **THEN** the code compiles and does not trigger the `depend_on_referenced_packages` lint

#### Scenario: Unrelated dependency symbols stay hidden
- **WHEN** a consumer imports the entry library
- **THEN** ML Kit types such as `OnDeviceTranslator` and `TextRecognizer`, and camera types such as `CameraController` and `CameraLensDirection`, are not visible

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

### Requirement: OverlayStyle has documented defaults
`OverlayStyle` SHALL be const-constructible with every field optional. The defaults SHALL be: background `0xCC000000`, text colour `0xFFFFFFFF`, border radius 6, padding of 4 horizontal and 2 vertical, minimum font size 10, maximum font size 28, and font weight `w600`. Instances SHALL compare equal when all fields are equal.

#### Scenario: Default style
- **WHEN** a consumer creates `const OverlayStyle()`
- **THEN** every field has the documented default value

#### Scenario: Value equality
- **WHEN** two `OverlayStyle`s are created with the same arguments
- **THEN** they are `==` and have the same `hashCode`

### Requirement: Font size bounds are consistent
`OverlayStyle` SHALL reject a `minFontSize` greater than `maxFontSize`, or a non-positive `minFontSize`, in debug builds.

#### Scenario: Inverted bounds
- **WHEN** an `OverlayStyle` is created with `minFontSize: 30` and `maxFontSize: 20` in a debug build
- **THEN** construction fails with an assertion error

### Requirement: Supported text scripts
`TextScript` SHALL offer exactly `latin` and `devanagari`. Each value SHALL correspond to an on-device text recognition script available on both Android and iOS.

#### Scenario: Script set
- **WHEN** a consumer lists `TextScript.values`
- **THEN** the result is exactly `latin` and `devanagari`

#### Scenario: Every script maps to an on-device recognizer
- **WHEN** any `TextScript` value is mapped to the recognizer's script type
- **THEN** a matching on-device recognizer script exists, and Devanagari maps to the Devanagari recognizer

### Requirement: Errors form a closed hierarchy
Every error the package reports SHALL be a `LiveTranslateException`. The hierarchy SHALL be closed to outside subtypes, and SHALL contain exactly `CameraPermissionDenied`, `CameraUnavailable`, `ModelNotDownloaded`, `UnsupportedLanguagePair` and `PipelineFailure`. Consumers SHALL be able to match on it exhaustively.

#### Scenario: Exhaustive switch
- **WHEN** a consumer writes a `switch` over a `LiveTranslateException` with one case per subtype and no default
- **THEN** the code compiles without a missing-case error

#### Scenario: Subtypes cannot be extended
- **WHEN** consumer code tries to extend or implement any `LiveTranslateException` subtype outside the package
- **THEN** compilation fails

### Requirement: Errors carry their context
`ModelNotDownloaded` SHALL expose the missing `TranslateLanguage`. `UnsupportedLanguagePair` SHALL expose the source language as a BCP-47 code and the target `TranslateLanguage`. `PipelineFailure` SHALL expose the underlying `cause` and, when available, its stack trace. Each error's `toString()` SHALL name the error type and include this context.

#### Scenario: Missing model names the language
- **WHEN** a `ModelNotDownloaded` is created for `TranslateLanguage.hindi`
- **THEN** its `language` is `TranslateLanguage.hindi`, and its `toString()` contains `ModelNotDownloaded` and `hindi`

#### Scenario: Pipeline failure keeps the cause
- **WHEN** a `PipelineFailure` wraps a `StateError`
- **THEN** its `cause` is that `StateError`, and its `toString()` includes the cause's message
