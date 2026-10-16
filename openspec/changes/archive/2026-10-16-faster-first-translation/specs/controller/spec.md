# Spec Delta

## ADDED Requirements

### Requirement: The controller reports the source status
The controller's `sourceStatus` SHALL be the attached view's source status, as the source-status capability defines. Listeners SHALL be notified whenever it changes, and SHALL NOT be notified while it stays the same. A controller not attached to a view SHALL report searching.

#### Scenario: Language guessed
- **WHEN** a view with a controller reads "Salida" as Spanish 0.9 with the Spanish model missing
- **THEN** the controller's `sourceStatus` is guessed for Spanish and listeners are notified

#### Scenario: Unchanged status
- **WHEN** the status is ready for Spanish and the next read also gives ready for Spanish
- **THEN** listeners are not notified for the status

#### Scenario: Not attached
- **WHEN** a controller has not been passed to a view, or its view has been removed
- **THEN** its `sourceStatus` is searching
