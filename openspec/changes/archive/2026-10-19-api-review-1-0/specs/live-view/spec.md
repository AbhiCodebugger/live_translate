# Spec Delta

## ADDED Requirements

### Requirement: A resolution change restarts the camera
When the view is rebuilt with a different `resolution`, it SHALL stop the camera and start it again at the new resolution, as it does when the app returns from the background: the placeholder is shown until the camera has started, shown labels are cleared, a frozen view resumes live translation, and the torch is off. A rebuild with the same `resolution` SHALL NOT restart the camera. The recognition and translation engines SHALL be kept.

#### Scenario: Higher resolution
- **WHEN** a running view is rebuilt with `resolution: ResolutionPreset.high` instead of `medium`
- **THEN** the camera is stopped and started again at `high`, and frames are read again once it has started

#### Scenario: Same resolution
- **WHEN** the view is rebuilt with the same `resolution` and a different `targetLanguage`
- **THEN** the camera isn't restarted

#### Scenario: While frozen
- **WHEN** a frozen view is rebuilt with a different `resolution`
- **THEN** the camera restarts at the new resolution, and the state becomes `running`

#### Scenario: Placeholder during the restart
- **WHEN** a view with a `placeholderBuilder` is rebuilt with a different `resolution`
- **THEN** the placeholder is shown until the camera has started again

#### Scenario: Restart fails
- **WHEN** the camera fails to start at the new resolution
- **THEN** the error is reported through `onError` and shown, as for a first start
