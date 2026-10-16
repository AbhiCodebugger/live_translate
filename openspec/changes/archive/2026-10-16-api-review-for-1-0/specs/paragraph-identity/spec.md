# Spec Delta

## Purpose

Gives each shown paragraph an `id` that stays the same while the view keeps reading the same scene, so apps can key, animate or remember a paragraph across reads.

## ADDED Requirements

### Requirement: Ids are unique within a result
Every `TranslatedParagraph` the view shows at one moment SHALL have a different `id`. An `id` is an opaque string, and apps SHALL NOT rely on its format.

#### Scenario: Two paragraphs
- **WHEN** a read shows two translated paragraphs
- **THEN** their ids differ

### Requirement: A paragraph keeps its id in the same place
When a read replaces a shown result, each new paragraph SHALL take the id of the previously shown paragraph whose rectangle overlaps it most, measured in view coordinates after the labels' shift, provided the overlap covers at least half the area of the smaller of the two rectangles. Each previous id SHALL be taken at most once, with the largest overlaps matched first. Any other new paragraph SHALL get a new id.

#### Scenario: Re-read while the language settles
- **WHEN** a held paragraph "Salida" with id A is read again a second later in the same place
- **THEN** the new paragraph has id A

#### Scenario: Translation changes
- **WHEN** a held paragraph with id A is shown in English and the target changes to French, so the frame is read again
- **THEN** the French paragraph has id A

#### Scenario: Pan by half a paragraph
- **WHEN** the user pans so that a paragraph's new rectangle covers 60% of its previous shifted rectangle, and the view reads again
- **THEN** the paragraph keeps its id

#### Scenario: Different paragraph in view
- **WHEN** after a pan a new paragraph overlaps no previous rectangle by half
- **THEN** it gets an id no paragraph shown before has had

#### Scenario: Two candidates for one id
- **WHEN** two new paragraphs both overlap the previous paragraph A by more than half, one by 90% and one by 55%
- **THEN** the 90% paragraph takes A and the other gets a new id

### Requirement: New scenes get new ids
Ids SHALL NOT be reused for the life of the view. After the labels are cleared by a new scene or fast movement, a camera restart or a resume, the next result's paragraphs SHALL all get new ids.

#### Scenario: Pointing somewhere else
- **WHEN** a paragraph with id A fades out after a new scene and a read of the new scene finds a paragraph in the same place
- **THEN** that paragraph's id is not A

### Requirement: Freezing keeps ids
When freezing keeps the held labels, their ids SHALL stay the same. When freezing reads the last frame, its paragraphs SHALL be matched against the labels shown just before, as for any other read.

#### Scenario: Freeze a held view
- **WHEN** a paragraph with id A is held and the view freezes without reading
- **THEN** `onFrozen` receives the paragraph with id A
