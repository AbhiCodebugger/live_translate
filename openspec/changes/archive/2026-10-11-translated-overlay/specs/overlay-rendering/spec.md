# Spec Delta

## Purpose

Draws each translation over the camera view, in place of the original line of text, readably and in the app's chosen style.

## ADDED Requirements

### Requirement: A translated line is covered by its label
For each line with a translation, a label SHALL be drawn over the line's mapped rectangle: a background in the style's background colour with the style's corner radius, covering the rectangle, and the translation drawn inside it, inset by the style's padding.

#### Scenario: Default style
- **WHEN** a line mapped to (17.5, 125)–(142.5, 162.5) has the translation "Exit"
- **THEN** a rounded rectangle of radius 6 in colour 0xCC000000 covers (17.5, 125)–(142.5, 162.5), and "Exit" is drawn in white inside it

### Requirement: Font size fits the line
The translation SHALL be drawn on a single line at the largest whole font size from the style's maximum down to its minimum that fits within the label's inner width and inner height. If it doesn't fit at the minimum size, it SHALL be drawn at the minimum size and cut short with an ellipsis.

#### Scenario: Short translation uses the largest size that fits
- **WHEN** "Exit" fits a label's inner width at size 28 and the inner height allows 28
- **THEN** it is drawn at size 28

#### Scenario: Long translation shrinks
- **WHEN** a translation is wider than the label at size 28 but fits at size 16
- **THEN** it is drawn at size 16

#### Scenario: Translation too long even at the minimum
- **WHEN** a translation is wider than the label even at size 10
- **THEN** it is drawn at size 10, ending in an ellipsis, without extending past the label

#### Scenario: Short line caps the size
- **WHEN** a line's inner height only allows size 14
- **THEN** the translation is drawn at no more than size 14

### Requirement: Untranslated lines are left visible
A line without a translation (undetermined or unsupported language, model still downloading, or translation failed) SHALL NOT be drawn over, so the original text stays visible. The same applies when the translation is the line's own text, ignoring leading, trailing and repeated whitespace.

#### Scenario: Model still downloading
- **WHEN** a Hindi line has no translation because the Hindi model is downloading
- **THEN** nothing is drawn over that line

#### Scenario: Translation returns the original
- **WHEN** the line "एला" comes back from translation as "एला"
- **THEN** nothing is drawn over that line

### Requirement: Style is applied
Labels SHALL use the style's background colour, text colour, corner radius, padding, font sizes and font weight.

#### Scenario: Custom colours
- **WHEN** the style has background 0xFFFFEB3B and text colour 0xFF000000
- **THEN** labels are drawn yellow with black text

### Requirement: Right-to-left translations
A translation into a right-to-left language (Arabic, Hebrew, Persian or Urdu) SHALL be laid out right to left. All other translations SHALL be laid out left to right.

#### Scenario: Arabic target
- **WHEN** the target language is Arabic
- **THEN** each translation is laid out right to left
