# Spec Delta

## ADDED Requirements

### Requirement: The controller reports scripts and source languages
The controller's `scripts` SHALL be the scripts the attached view reads, and its `sourceLanguages` SHALL be the languages the view expects, or `null` while it detects each paragraph's language. Both SHALL follow changes made through the widget or the controller, whichever came last, and listeners SHALL be notified when either changes. Both SHALL be unmodifiable. A controller not attached to a view SHALL report `null` for both.

#### Scenario: Defaults
- **WHEN** a view with a controller and no `scripts` or `sourceLanguages` is shown
- **THEN** after the view's first frame, the controller's `scripts` is {Latin, Devanagari}, and its `sourceLanguages` is `null`

#### Scenario: Changed through the controller
- **WHEN** `setScripts({TextScript.latin})` and `setSourceLanguages({TranslateLanguage.spanish})` are called
- **THEN** the controller's `scripts` becomes {Latin}, its `sourceLanguages` becomes {Spanish}, and listeners are notified

#### Scenario: Changed through the widget
- **WHEN** the view is rebuilt with `scripts: {TextScript.devanagari}` and `sourceLanguages: {TranslateLanguage.hindi}`
- **THEN** the controller's `scripts` becomes {Devanagari}, its `sourceLanguages` becomes {Hindi}, and listeners are notified

#### Scenario: Back to detection
- **WHEN** `setSourceLanguages(null)` is called after a source language was set
- **THEN** the controller's `sourceLanguages` becomes `null`

#### Scenario: Unmodifiable
- **WHEN** consumer code tries to add a script to the controller's `scripts`
- **THEN** it throws, and the view's scripts are unchanged

#### Scenario: Not attached
- **WHEN** a controller has not been passed to a view, or its view has been removed
- **THEN** its `scripts` and `sourceLanguages` are `null`
