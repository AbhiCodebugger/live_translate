# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: Changed lines are reported to the app`
- TO: `### Requirement: Changed paragraphs are reported to the app`

## MODIFIED Requirements

### Requirement: Changed paragraphs are reported to the app
The view SHALL call its `onParagraphsChanged` callback with the paragraphs it shows whenever they change, with the same paragraphs and at the same moments as a controller's `paragraphs` and listeners would see, whether or not a controller is attached. It SHALL NOT be called while the paragraphs stay the same, and SHALL NOT be called for the empty list the view starts with.

#### Scenario: A paragraph is translated
- **WHEN** a settled read shows one translated paragraph at (17.5, 125)–(142.5, 162.5) in a view with `onParagraphsChanged` and no controller
- **THEN** `onParagraphsChanged` is called once with one `TranslatedParagraph` with that rectangle and translation

#### Scenario: Labels follow a shift
- **WHEN** the held labels move 10 view pixels to the right
- **THEN** `onParagraphsChanged` is called with each rectangle moved 10 to the right

#### Scenario: Labels are cleared
- **WHEN** a held result fades out after a new scene and its labels are dropped
- **THEN** `onParagraphsChanged` is called with paragraphs at decreasing opacity, and finally with an empty list

#### Scenario: Nothing changes
- **WHEN** a result is held and the picture doesn't move
- **THEN** `onParagraphsChanged` isn't called again

#### Scenario: Same as the controller
- **WHEN** a view has both a controller and `onParagraphsChanged`
- **THEN** every list `onParagraphsChanged` receives equals the controller's `paragraphs` at that moment, and each controller notification that changes `paragraphs` comes with one `onParagraphsChanged` call

### Requirement: The frozen result is reported to the app
Once the frozen picture's result is shown, the view SHALL call its `onFrozen` callback once with the paragraphs it shows. That is right away when freezing keeps the held labels, after the read otherwise, and again each time the frozen picture is read again. It SHALL NOT be called while a read runs or when the read fails.

#### Scenario: Freezing a held view
- **WHEN** a paragraph is held, the picture hasn't moved, and the view freezes
- **THEN** `onFrozen` is called once with that paragraph, at opacity 1

#### Scenario: Freezing while moving
- **WHEN** no result is held, the view freezes, and the read of the last frame finds one paragraph
- **THEN** `onFrozen` isn't called while the read runs, and is called once with that paragraph when it finishes

#### Scenario: Nothing found
- **WHEN** the view freezes and the frozen frame's read finds no text
- **THEN** `onFrozen` is called once with an empty list

#### Scenario: No frame yet
- **WHEN** the view freezes before any frame has been received
- **THEN** `onFrozen` is called once with an empty list

#### Scenario: Read fails
- **WHEN** the view freezes and the frozen frame's read throws
- **THEN** `onFrozen` isn't called, and `onError` receives a `PipelineFailure`

#### Scenario: Target changes while frozen
- **WHEN** the view is frozen showing English, `onFrozen` has been called, and the target changes to French
- **THEN** `onFrozen` is called again with the French paragraphs once the frozen frame has been read again

#### Scenario: Resumed before the read finishes
- **WHEN** the view freezes, and resumes before the frozen frame's read finishes
- **THEN** `onFrozen` isn't called

### Requirement: Source language hint
The view SHALL pass the expected source languages to language detection, and SHALL detect the language of each line automatically when none are given. The expected languages SHALL be the most recent of the widget's `sourceLanguages` and the controller's `setSourceLanguages`.

#### Scenario: Hindi only
- **WHEN** the app restricts source languages to Hindi
- **THEN** every line is translated from Hindi without running language identification

#### Scenario: Set through the controller
- **WHEN** the widget gives no source languages and the controller sets Hindi
- **THEN** every line is translated from Hindi without running language identification
