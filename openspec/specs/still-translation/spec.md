# still-translation Specification

## Purpose
Turns the frozen camera picture into a calm, page-like translation: the frame is read once with every selected script, each paragraph is translated as a whole, and its labels take the page's colours. Nothing moves until live translation resumes.

## Requirements

### Requirement: Freezing reads the frozen frame once
When the view freezes while a result is held and the picture has moved by less than 2% of the frame's width and height since the frame that was read, it SHALL keep showing that result, moved by that shift, without reading. Otherwise it SHALL read the last frame it received before pausing, once, and show that frame's result. Results from reads started before freezing SHALL be ignored unless they are being kept as above.

#### Scenario: Freezing a held view
- **WHEN** a result is held, the picture has moved by 1% since its read, and the user freezes
- **THEN** the same labels stay, nothing is read, and no progress indicator shows

#### Scenario: Freezing while moving
- **WHEN** no result is held because the camera was moving, and the user freezes
- **THEN** the last frame is read once and its result is shown

#### Scenario: Freezing after a pan
- **WHEN** a result is held but the picture has moved by 12% since its read, and the user freezes
- **THEN** the last frame is read once and its result replaces the held labels

#### Scenario: Ghosts are gone
- **WHEN** labels are fading out after a new scene and the user freezes
- **THEN** the result shown is only what the frozen frame's read found, fully opaque

#### Scenario: No frame yet
- **WHEN** the view freezes before any frame has been received
- **THEN** no labels are shown and the view stays frozen without error

### Requirement: Every selected script reads the frozen frame
The frozen frame SHALL be read by every selected script, not one script in turn, and the scripts' results SHALL be merged with the same filters as live recognition.

#### Scenario: Bilingual sign
- **WHEN** Latin and Devanagari are selected and the frozen frame shows "EXIT" and "निकास" on separate lines
- **THEN** the still result has labels for both

### Requirement: Paragraphs are translated whole
In the still result, the lines of each recognized paragraph SHALL be joined in reading order and translated as one text. Lines SHALL be joined with a space, except that a line ending in a hyphen directly after a letter SHALL be joined to the next line without the hyphen or a space. A paragraph's source language SHALL be detected from the joined text.

#### Scenario: Sentence across lines
- **WHEN** a paragraph has the lines "On sait depuis longtemps que travailler" and "avec du texte lisible"
- **THEN** "On sait depuis longtemps que travailler avec du texte lisible" is translated as one text and shown as one label

#### Scenario: Hyphenated word
- **WHEN** a paragraph has the lines "une distri-" and "bution normale"
- **THEN** the text translated is "une distribution normale"

#### Scenario: Separate paragraphs
- **WHEN** a heading and the paragraph below it are separate paragraphs
- **THEN** they are translated separately and shown as two labels

### Requirement: Still labels use the page's colours
Each paragraph's label SHALL take its background colour from the frame's pixels inside the paragraph's area, as the page colour (the most common colour there), and its text colour from the text's ink there. If the sampled text colour contrasts with the background by less than 4.5:1, black or white, whichever contrasts more, SHALL be used instead.

#### Scenario: Black text on a white page
- **WHEN** a paragraph is printed in near-black on a near-white page
- **THEN** its label's background is near-white and its text is near-black

#### Scenario: White text on a blue sign
- **WHEN** a paragraph is white text on a blue sign
- **THEN** its label's background is blue and its text is white

#### Scenario: Low-contrast sample
- **WHEN** the sampled text colour is too close to the sampled background
- **THEN** the label's text is black or white, whichever contrasts more with the background

### Requirement: Reading is shown while it runs
While the frozen frame is being read and translated, the view SHALL show no labels and SHALL show a progress indicator. The indicator SHALL go away when the result is shown, or when reading fails, in which case the failure SHALL be reported through `onError` as a `PipelineFailure` and the view SHALL stay frozen with no labels.

#### Scenario: Reading in progress
- **WHEN** the user freezes and recognition hasn't finished
- **THEN** a progress indicator is shown and no labels are drawn

#### Scenario: Reading fails
- **WHEN** recognition of the frozen frame throws
- **THEN** `onError` receives a `PipelineFailure`, the indicator goes away, and no labels are drawn

### Requirement: Settings changes re-read the frozen frame
When the target language, scripts or source languages change while frozen, the same frozen frame SHALL be read again with the new settings, and only the newest reading's result SHALL be shown.

#### Scenario: New target while frozen
- **WHEN** the view is frozen showing English translations and the target changes to German
- **THEN** the frozen frame is read again and its labels show German translations, and no English result appears afterwards

### Requirement: Resuming discards the still result
Resuming SHALL remove the still result, discard any reading still in progress, and return to live labels.

#### Scenario: Resume during reading
- **WHEN** the user resumes while the frozen frame is still being read
- **THEN** that reading's result is never shown, and live labels return
