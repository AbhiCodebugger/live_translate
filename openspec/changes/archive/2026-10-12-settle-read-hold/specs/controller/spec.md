# Spec Delta

## MODIFIED Requirements

### Requirement: Freeze keeps the current translation still
`freeze()` SHALL pause the preview, stop measuring and reading live frames, and set the state to `frozen`, keeping or reading a result as `still-translation` describes. While a read runs, `lines` SHALL be empty; otherwise it SHALL hold one `TranslatedLine` per shown paragraph. `resume()` SHALL restart the preview and live translation and set the state to `running`. Freezing while frozen, or resuming while running, SHALL have no effect.

#### Scenario: Freeze
- **WHEN** the state is `running`, a held paragraph is shown, the picture hasn't moved, and `freeze()` is called
- **THEN** the state is `frozen`, the preview is paused, and `lines` still holds the same paragraph

#### Scenario: Resume
- **WHEN** the state is `frozen` and `resume()` is called
- **THEN** the state becomes `running` and frames are measured again

#### Scenario: Frame in flight
- **WHEN** a read is running when `freeze()` is called on a view with no held result, and that read finishes afterwards
- **THEN** its result isn't shown; `lines` changes only to the result of reading the frozen frame

#### Scenario: Paragraph lines
- **WHEN** a read finds one paragraph of two lines, translated as "It has long been known that working with readable text"
- **THEN** `lines` holds one `TranslatedLine` with that translation, its source text being both lines joined, and a rectangle covering both lines

### Requirement: The controller exposes the current lines
The controller's `lines` SHALL be the paragraphs the view currently shows, as `TranslatedLine`s with rectangles in view coordinates (including any shift the labels follow), IDs and opacity. Listeners SHALL be notified when they change.

#### Scenario: A line is translated
- **WHEN** a settled read shows one translated paragraph at (17.5, 125)–(142.5, 162.5)
- **THEN** `lines` holds one `TranslatedLine` with that rectangle and translation, and listeners are notified

#### Scenario: Labels follow a shift
- **WHEN** the held labels move 10 view pixels to the right
- **THEN** each rectangle in `lines` moves 10 to the right, and listeners are notified

#### Scenario: Nothing translated yet
- **WHEN** the camera is running but nothing has been read
- **THEN** `lines` is empty
