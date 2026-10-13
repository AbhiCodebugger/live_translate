# Spec Delta

## MODIFIED Requirements

### Requirement: Shutter freezes and resumes
The shutter button SHALL freeze the view while live translation runs and resume it while frozen. Its icon SHALL show which of the two a tap will do.

#### Scenario: Freeze
- **WHEN** the view is running and the user taps the shutter
- **THEN** the view is frozen and shows the still result of the frozen picture, and the shutter shows the resume action

#### Scenario: Resume
- **WHEN** the view is frozen and the user taps the shutter
- **THEN** live translation runs again and the shutter shows the freeze action
