# Spec Delta

## ADDED Requirements

### Requirement: Debug HUD shows the per-frame cost
While the debug HUD is shown, it SHALL also show how long the view's own work took for each live frame it measured in the last second: the mean and the worst, in milliseconds with one decimal. This work runs on the UI thread and covers measuring the frame's motion and deciding whether to read. It excludes the camera preview, the reads themselves and painting. With no live frame in the last second, it SHALL show no frame cost.

#### Scenario: Frames measured
- **WHEN** the HUD is on and, in the last second, the view's work took 2.0 ms for each of 29 frames and 6.5 ms for one
- **THEN** the HUD shows a mean of 2.2 ms and a worst of 6.5 ms

#### Scenario: Before the first read
- **WHEN** the HUD is on, the camera is running and nothing has been read
- **THEN** the HUD shows the frame cost along with the frame rate

#### Scenario: No live frames
- **WHEN** the view has been frozen for two seconds with the HUD on
- **THEN** the HUD shows 0 frames per second and no frame cost

#### Scenario: HUD off
- **WHEN** the view is shown without `showDebugHud`
- **THEN** the view doesn't time its per-frame work
