# Spec Delta

## MODIFIED Requirements

### Requirement: Freeze keeps the current translation still
`freeze()` SHALL pause the preview, stop processing live frames and set the state to `frozen`. The view then reads the frozen frame once (see `still-translation`). `lines` SHALL be empty while that reading runs, and SHALL then hold one `TranslatedLine` per translated paragraph, with the paragraph's rectangle and opacity 1. `resume()` SHALL restart the preview and processing and set the state to `running`. Live results from frames in flight when freezing SHALL be discarded. Freezing while frozen, or resuming while running, SHALL have no effect.

#### Scenario: Freeze
- **WHEN** the state is `running`, a line is shown, and `freeze()` is called
- **THEN** the state is `frozen`, the preview is paused, new frames aren't processed, and once the frozen frame is read, `lines` holds its translated paragraphs

#### Scenario: Resume
- **WHEN** the state is `frozen` and `resume()` is called
- **THEN** the state becomes `running` and frames are processed again

#### Scenario: Frame in flight
- **WHEN** a frame is being recognized when `freeze()` is called, and its result arrives afterwards
- **THEN** the live result isn't shown, and `lines` changes only to the still result

#### Scenario: Paragraph lines
- **WHEN** the frozen frame holds one paragraph of two lines, translated as "It has long been known that working with readable text"
- **THEN** `lines` holds one `TranslatedLine` with that translation, its source text being both lines joined, and a rectangle covering both lines
