# Spec Delta

## ADDED Requirements

### Requirement: Labels fade with their line
Each label SHALL be drawn at its line's opacity: the background colour's alpha and the text colour's alpha SHALL be multiplied by it. A label whose line has opacity 0 SHALL NOT be drawn.

#### Scenario: Fading line
- **WHEN** a line with the default style has opacity 1/3
- **THEN** its background is drawn at alpha 0xCC × 1/3 and its text at alpha 0xFF × 1/3

#### Scenario: Fully visible line
- **WHEN** a line has opacity 1
- **THEN** its label is drawn in the style's colours unchanged
