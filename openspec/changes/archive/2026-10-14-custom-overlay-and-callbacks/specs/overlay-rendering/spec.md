# Spec Delta

## ADDED Requirements

### Requirement: An app overlay replaces the built-in labels
When the app gives the view an `overlayBuilder`, the view SHALL NOT draw its own labels. It SHALL lay the builder's widget over the whole view, above the preview, and rebuild it with the lines the view shows, as the controller reports them, whenever they change. The progress indicator during a frozen read SHALL still be shown above it.

#### Scenario: Custom labels
- **WHEN** a settled read shows one translated paragraph at (17.5, 125)–(142.5, 162.5) and the view has an `overlayBuilder`
- **THEN** no built-in label is drawn, and the builder receives one `TranslatedLine` with that rectangle and translation

#### Scenario: Overlay fills the view
- **WHEN** the view is 360 × 800 and has an `overlayBuilder`
- **THEN** the builder's widget is laid out at (0, 0)–(360, 800), so a line's rectangle can be used as a position inside it

#### Scenario: Labels follow a shift
- **WHEN** the held labels move 10 view pixels to the right
- **THEN** the builder is called again with each rectangle moved 10 to the right

#### Scenario: Fading labels
- **WHEN** a held result fades out after a new scene
- **THEN** the builder receives the lines at decreasing opacity, and finally an empty list

#### Scenario: Untranslated lines
- **WHEN** a paragraph's translation is its own text
- **THEN** the builder doesn't receive it

#### Scenario: Frozen read in progress
- **WHEN** the view has an `overlayBuilder`, freezes and the frozen frame is being read
- **THEN** the builder receives an empty list and the progress indicator is shown

#### Scenario: No builder given
- **WHEN** the view has no `overlayBuilder`
- **THEN** labels are drawn as the other requirements here describe
