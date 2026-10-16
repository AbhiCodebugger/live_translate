# Spec Delta

## MODIFIED Requirements

### Requirement: Paragraph text reflows at the original size
A paragraph's translation SHALL be laid out as wrapping text inside its label's inner area. Its font size SHALL start at 80% of the paragraph's median line height, rounded down to a whole size, but no larger than the style's maximum, and SHALL shrink one size at a time until the text fits the inner area, but not below the style's minimum. If it doesn't fit at the minimum size, it SHALL be cut short with an ellipsis on its last visible line.

#### Scenario: Translation the same length
- **WHEN** a paragraph's lines are 20 high and its translation fits at size 16
- **THEN** it is drawn wrapped at size 16

#### Scenario: Longer translation shrinks
- **WHEN** a translation doesn't fit the inner area at size 16 but does at size 13
- **THEN** it is drawn wrapped at size 13

#### Scenario: Too long even at the minimum
- **WHEN** a translation doesn't fit at the style's minimum size of 10
- **THEN** it is drawn at size 10 and ends in an ellipsis inside the label

#### Scenario: Large heading
- **WHEN** a single-line heading is 50 high and the style's maximum is 28
- **THEN** its translation starts at size 28, not 40

#### Scenario: Larger maximum
- **WHEN** a single-line heading is 50 high and the style's maximum is 48
- **THEN** its translation starts at size 40

### Requirement: An app overlay replaces the built-in labels
When the app gives the view an `overlayBuilder`, the view SHALL NOT draw its own labels. It SHALL lay the builder's widget over the whole view, above the preview, and rebuild it with the paragraphs the view shows, as the controller reports them, whenever they change. The progress indicator during a frozen read SHALL still be shown above it.

#### Scenario: Custom labels
- **WHEN** a settled read shows one translated paragraph at (17.5, 125)–(142.5, 162.5) and the view has an `overlayBuilder`
- **THEN** no built-in label is drawn, and the builder receives one `TranslatedParagraph` with that rectangle and translation

#### Scenario: Overlay fills the view
- **WHEN** the view is 360 × 800 and has an `overlayBuilder`
- **THEN** the builder's widget is laid out at (0, 0)–(360, 800), so a paragraph's rectangle can be used as a position inside it

#### Scenario: Labels follow a shift
- **WHEN** the held labels move 10 view pixels to the right
- **THEN** the builder is called again with each rectangle moved 10 to the right

#### Scenario: Fading labels
- **WHEN** a held result fades out after a new scene
- **THEN** the builder receives the paragraphs at decreasing opacity, and finally an empty list

#### Scenario: Untranslated lines
- **WHEN** a paragraph's translation is its own text
- **THEN** the builder doesn't receive it

#### Scenario: Frozen read in progress
- **WHEN** the view has an `overlayBuilder`, freezes and the frozen frame is being read
- **THEN** the builder receives an empty list and the progress indicator is shown

#### Scenario: No builder given
- **WHEN** the view has no `overlayBuilder`
- **THEN** labels are drawn as the other requirements here describe
