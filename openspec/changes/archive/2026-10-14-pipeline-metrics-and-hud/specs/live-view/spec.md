# Spec Delta

## ADDED Requirements

### Requirement: Debug HUD
When `showDebugHud` is `true`, the view SHALL show a small panel over the camera, above the labels or the app's overlay. It SHALL show the latest shown read's total, recognition, translation and sampling times in whole milliseconds, its paragraph count, and the number of live frames the view measured in the last second. It SHALL be off by default and SHALL NOT need a controller.

#### Scenario: Off by default
- **WHEN** a view is shown without `showDebugHud`
- **THEN** no HUD is shown

#### Scenario: Before the first read
- **WHEN** the HUD is on, the camera is running and nothing has been read
- **THEN** the HUD says no read has been made yet, and shows the frame rate

#### Scenario: After a read
- **WHEN** the HUD is on and a read whose recognition took 120 ms, translation 80 ms and sampling 10 ms showed one paragraph
- **THEN** the HUD shows the total in milliseconds, 120 ms for recognition, 80 ms for translation, 10 ms for sampling, and one paragraph

#### Scenario: Frame rate
- **WHEN** the HUD is on and frames arrive every 33 ms for two seconds
- **THEN** the HUD shows between 29 and 31 frames per second

#### Scenario: Camera stops sending frames
- **WHEN** the view is frozen for two seconds
- **THEN** the HUD shows 0 frames per second

#### Scenario: Without a controller
- **WHEN** the HUD is on, no controller is attached, and a read is shown
- **THEN** the HUD shows that read's times

#### Scenario: Above a custom overlay
- **WHEN** the HUD is on and the view has an `overlayBuilder`
- **THEN** the HUD is drawn above the overlay

#### Scenario: Clear of the status bar
- **WHEN** the HUD is on and the view fills a screen whose status bar takes the top 40 pixels
- **THEN** the HUD is drawn below the status bar

#### Scenario: While the camera starts
- **WHEN** the HUD is on and the camera hasn't started
- **THEN** no HUD is shown, only the placeholder
