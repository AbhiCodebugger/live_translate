# Spec Delta

## MODIFIED Requirements

### Requirement: Single entry library
The package SHALL expose its public API through one library, `package:live_translate/live_translate.dart`. That library SHALL export only the documented public symbols. Implementation details under `lib/src/` SHALL NOT be exported.

#### Scenario: One import is enough
- **WHEN** a consumer imports only `package:live_translate/live_translate.dart`
- **THEN** `LiveTranslateView`, `LiveTranslateController`, `LiveTranslateState`, `OverlayBuilder`, `PipelineMetrics`, `TranslatedLine`, `TextScript`, `OverlayStyle`, `TranslationModels`, `LiveTranslateException` and all its subtypes resolve without further imports

#### Scenario: Internal mapping is not exported
- **WHEN** a consumer imports the entry library
- **THEN** the mapping from `TextScript` to the recognizer's script type is not visible

#### Scenario: Engines are not exported
- **WHEN** a consumer imports the entry library
- **THEN** the text, language and translation engines, the translation cache and the line translator are not visible

#### Scenario: View plumbing is not exported
- **WHEN** a consumer imports the entry library
- **THEN** the camera session, the engines bundle the view is built with, and the functions and interface that connect a controller to its view are not visible
