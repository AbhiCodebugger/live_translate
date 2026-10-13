# Spec Delta

## MODIFIED Requirements

### Requirement: Dependency types are re-exported
The entry library SHALL re-export the third-party types the public API uses: `TranslateLanguage` and `ResolutionPreset`. It SHALL NOT re-export any other symbols from those dependencies.

#### Scenario: Consumer uses a language without a direct dependency
- **WHEN** a consumer depends only on `live_translate_overlay` and refers to `TranslateLanguage.english`
- **THEN** the code compiles and does not trigger the `depend_on_referenced_packages` lint

#### Scenario: Unrelated dependency symbols stay hidden
- **WHEN** a consumer imports the entry library
- **THEN** ML Kit types such as `OnDeviceTranslator` and `TextRecognizer`, and camera types such as `CameraController` and `CameraLensDirection`, are not visible
