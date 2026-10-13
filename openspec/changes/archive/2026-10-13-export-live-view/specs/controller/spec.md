# Spec Delta

## ADDED Requirements

### Requirement: The controller reports the target language
The controller's `targetLanguage` SHALL be the language the attached view translates into. When the app gives the view no target, it SHALL be the device-language default the view chose. It SHALL follow changes made through the widget or the controller, and listeners SHALL be notified when it changes. A controller not attached to a view SHALL report `null`.

#### Scenario: Default target on a French phone
- **WHEN** a view with a controller and no target language is shown on a phone whose language is French (France)
- **THEN** after the view's first frame, the controller's `targetLanguage` is French and listeners are notified

#### Scenario: Explicit target
- **WHEN** a view with a controller is shown with `targetLanguage: TranslateLanguage.german`
- **THEN** the controller's `targetLanguage` is German

#### Scenario: Changed through the controller
- **WHEN** the view translates into English and `setTargetLanguage(TranslateLanguage.french)` is called
- **THEN** the controller's `targetLanguage` becomes French and listeners are notified

#### Scenario: Changed through the widget
- **WHEN** the view translates into English and is rebuilt with `targetLanguage: TranslateLanguage.german`
- **THEN** the controller's `targetLanguage` becomes German and listeners are notified

#### Scenario: Not attached
- **WHEN** a controller has not been passed to a view, or its view has been removed
- **THEN** its `targetLanguage` is `null`
