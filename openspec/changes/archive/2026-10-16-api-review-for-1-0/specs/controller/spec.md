# Spec Delta

## RENAMED Requirements

- FROM: `### Requirement: The controller exposes the current lines`
- TO: `### Requirement: The controller exposes the current paragraphs`

## MODIFIED Requirements

### Requirement: The controller exposes the current paragraphs
The controller's `paragraphs` SHALL be the paragraphs the view currently shows, as `TranslatedParagraph`s with rectangles in view coordinates (including any shift the labels follow), ids as the paragraph-identity capability defines, and opacity. Listeners SHALL be notified when they change.

#### Scenario: A line is translated
- **WHEN** a settled read shows one translated paragraph at (17.5, 125)–(142.5, 162.5)
- **THEN** `paragraphs` holds one `TranslatedParagraph` with that rectangle and translation, and listeners are notified

#### Scenario: Labels follow a shift
- **WHEN** the held labels move 10 view pixels to the right
- **THEN** each rectangle in `paragraphs` moves 10 to the right, and listeners are notified

#### Scenario: Nothing translated yet
- **WHEN** the camera is running but nothing has been read
- **THEN** `paragraphs` is empty

### Requirement: Freeze keeps the current translation still
`freeze()` SHALL pause the preview, stop measuring and reading live frames, and set the state to `frozen`, keeping or reading a result as `still-translation` describes. While a read runs, `paragraphs` SHALL be empty; otherwise it SHALL hold one `TranslatedParagraph` per shown paragraph. `resume()` SHALL restart the preview and live translation and set the state to `running`. Freezing while frozen, or resuming while running, SHALL have no effect.

#### Scenario: Freeze
- **WHEN** the state is `running`, a held paragraph is shown, the picture hasn't moved, and `freeze()` is called
- **THEN** the state is `frozen`, the preview is paused, and `paragraphs` still holds the same paragraph

#### Scenario: Resume
- **WHEN** the state is `frozen` and `resume()` is called
- **THEN** the state becomes `running` and frames are measured again

#### Scenario: Frame in flight
- **WHEN** a read is running when `freeze()` is called on a view with no held result, and that read finishes afterwards
- **THEN** its result isn't shown; `paragraphs` changes only to the result of reading the frozen frame

#### Scenario: Paragraph lines
- **WHEN** a read finds one paragraph of two lines, translated as "It has long been known that working with readable text"
- **THEN** `paragraphs` holds one `TranslatedParagraph` with that translation, its source text being both lines joined, and a rectangle covering both lines

### Requirement: Settings can be changed through the controller
`setTargetLanguage`, `setScripts` and `setSourceLanguages` SHALL change the view's target language, scripts and expected source languages the same way changing the widget parameters does, without restarting the camera. The most recent change SHALL win, whether it came from the controller or a widget parameter. `setSourceLanguages(null)` SHALL go back to detecting the language.

#### Scenario: New target language
- **WHEN** the view translates into English and `setTargetLanguage(TranslateLanguage.french)` is called
- **THEN** new lines are translated into French and the camera isn't restarted

#### Scenario: Widget changes after the controller
- **WHEN** `setTargetLanguage(TranslateLanguage.french)` was called, and the widget is then rebuilt with a new `targetLanguage` of German
- **THEN** lines are translated into German

#### Scenario: Unchanged widget keeps the controller's choice
- **WHEN** `setTargetLanguage(TranslateLanguage.french)` was called, and the widget is rebuilt with the same `targetLanguage` as before
- **THEN** lines are still translated into French

#### Scenario: Expecting Hindi
- **WHEN** the view detects languages and `setSourceLanguages({TranslateLanguage.hindi})` is called
- **THEN** the engines are replaced, Devanagari lines are translated from Hindi without running language identification, and the camera isn't restarted

#### Scenario: Back to detection
- **WHEN** `setSourceLanguages({TranslateLanguage.hindi})` was called and then `setSourceLanguages(null)` is called
- **THEN** each line's language is detected again

#### Scenario: Widget source languages change after the controller
- **WHEN** `setSourceLanguages({TranslateLanguage.hindi})` was called, and the widget is then rebuilt with new `sourceLanguages` of Spanish
- **THEN** lines are taken to be Spanish

#### Scenario: Same languages again
- **WHEN** the view expects Hindi and `setSourceLanguages({TranslateLanguage.hindi})` is called
- **THEN** the engines are kept
