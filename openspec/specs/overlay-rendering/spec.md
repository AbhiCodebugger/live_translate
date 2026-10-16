# overlay-rendering Specification

## Purpose

Draws each translation over the camera view, in place of the original line of text, readably and in the app's chosen style.

## Requirements

### Requirement: Untranslated lines are left visible
A line without a translation (undetermined or unsupported language, model still downloading, or translation failed) SHALL NOT be drawn over, so the original text stays visible. The same applies when the translation is the line's own text, ignoring leading, trailing and repeated whitespace.

#### Scenario: Model still downloading
- **WHEN** a Hindi line has no translation because the Hindi model is downloading
- **THEN** nothing is drawn over that line

#### Scenario: Translation returns the original
- **WHEN** the line "एला" comes back from translation as "एला"
- **THEN** nothing is drawn over that line

### Requirement: Style is applied
Labels SHALL use the style's corner radius, padding, minimum font size and font weight, with background and text colours sampled from the page and a font size from the paragraph's line height. The style's background and text colours SHALL be used only for a paragraph whose page colours can't be sampled.

#### Scenario: Still labels ignore the style's colours
- **WHEN** the style has background 0xFFFFEB3B and a paragraph sampled a white page with black ink
- **THEN** that paragraph's label is drawn white with black text

#### Scenario: Custom colours
- **WHEN** the style has background 0xFFFFEB3B and text colour 0xFF000000, and a paragraph's frame can't be sampled
- **THEN** its label is drawn yellow with black text

### Requirement: Right-to-left translations
A translation into a right-to-left language (Arabic, Hebrew, Persian or Urdu) SHALL be laid out right to left. All other translations SHALL be laid out left to right.

#### Scenario: Arabic target
- **WHEN** the target language is Arabic
- **THEN** each translation is laid out right to left

### Requirement: Labels fade with their line
Each label SHALL be drawn at its paragraph's opacity: the background colour's alpha and the text colour's alpha SHALL be multiplied by it. A label at opacity 0 SHALL NOT be drawn.

#### Scenario: Fading line
- **WHEN** a paragraph with an opaque white page colour has opacity 1/2
- **THEN** its background is drawn at alpha 0xFF × 1/2 and its text at its ink's alpha × 1/2

#### Scenario: Fully visible line
- **WHEN** a paragraph has opacity 1
- **THEN** its label is drawn fully opaque in its page colours

### Requirement: Paragraph labels cover the paragraph
A paragraph's label SHALL be drawn as one background covering the rectangle around all of its lines, in its sampled background colour and, at opacity 1, fully opaque, so the original text doesn't show through.

#### Scenario: Two-line paragraph
- **WHEN** a paragraph's lines map to (20, 100)–(300, 120) and (20, 124)–(280, 144)
- **THEN** one background covers (20, 100)–(300, 144)

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

### Requirement: Paragraph labels stay inside the view
A paragraph's label SHALL be limited to the part of its rectangle inside the view, and its translation SHALL be laid out within that part, so no text runs off the screen.

#### Scenario: Paragraph wider than the screen
- **WHEN** a paragraph maps to (40, 600)–(460, 680) in a 360 wide view
- **THEN** its label covers (40, 600)–(360, 680) and its translation wraps within that width

### Requirement: Paragraph labels grow into free space
When a paragraph's translation doesn't fit its label's inner area at the starting font size, the label SHALL first grow to the right, up to the view's edge or the nearest other label beside it, then downwards by up to its own original height, without leaving the view or overlapping another label. Only then SHALL the font size shrink.

#### Scenario: Short heading, longer translation
- **WHEN** a heading's label is (20, 100)–(140, 124), its translation doesn't fit on one line at the starting size, and nothing is to its right in a 360 wide view
- **THEN** the label grows to (20, 100)–(360, 124) and the translation is drawn without shrinking if it now fits

#### Scenario: Neighbour to the right
- **WHEN** a growing label at (20, 100)–(140, 124) has another label at (200, 90)–(340, 130)
- **THEN** it grows right only up to x = 200, then downwards

#### Scenario: Translation that fits
- **WHEN** a translation fits its label at the starting size
- **THEN** the label keeps its original rectangle

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
