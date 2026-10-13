# Spec Delta

## MODIFIED Requirements

### Requirement: Single entry library
The package SHALL expose its public API through one library, `package:live_translate_overlay/live_translate_overlay.dart`. That library SHALL export only the documented public symbols. Implementation details under `lib/src/` SHALL NOT be exported.

#### Scenario: One import is enough
- **WHEN** a consumer imports only `package:live_translate_overlay/live_translate_overlay.dart`
- **THEN** `LiveTranslateView`, `LiveTranslateController`, `LiveTranslateState`, `TranslatedLine`, `TextScript`, `OverlayStyle`, `TranslationModels`, `LiveTranslateException` and all its subtypes resolve without further imports

#### Scenario: Internal mapping is not exported
- **WHEN** a consumer imports the entry library
- **THEN** the mapping from `TextScript` to the recognizer's script type is not visible

#### Scenario: Engines are not exported
- **WHEN** a consumer imports the entry library
- **THEN** the text, language and translation engines, the translation cache and the line translator are not visible

#### Scenario: View plumbing is not exported
- **WHEN** a consumer imports the entry library
- **THEN** the camera session, the engines bundle the view is built with, and the functions and interface that connect a controller to its view are not visible

## ADDED Requirements

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
