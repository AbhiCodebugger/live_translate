# live-translation Specification

## Purpose

Decides when the live view reads the camera picture and keeps the result still: it reads once the picture settles, holds the labels on the page while the camera moves a little, and reads again only when the picture has changed.

## Requirements

### Requirement: Nothing is read while the picture moves
The live view SHALL measure, for every frame, how far the picture shifted since the previous frame and how much it changed beyond that shift. It SHALL NOT read a frame while the picture is moving.

#### Scenario: Sweeping the camera
- **WHEN** the camera sweeps across a page and every frame shifts by more than 1% of the frame width
- **THEN** no frame is read

### Requirement: A steady picture is read once
When the picture has been steady for at least 300 ms (each frame shifted by less than 1% of the frame's width and changed little beyond the shift), the live view SHALL read the latest frame once, with every selected script, paragraph by paragraph and in page colours, as freezing does, and show the result.

#### Scenario: Holding the phone over a page
- **WHEN** the picture has been steady for 300 ms over a French page
- **THEN** the latest frame is read once and its paragraphs are shown translated

#### Scenario: Not steady long enough
- **WHEN** the picture has been steady for 200 ms
- **THEN** nothing has been read yet

#### Scenario: Still steady after the read
- **WHEN** the result is shown and the picture stays steady for 10 more seconds
- **THEN** no further frame is read

### Requirement: Held labels follow small movements
While a result is shown, each frame's measured shift SHALL be added up since the frame that was read, and the labels SHALL be drawn moved by that total, so they stay on their text. Frames SHALL NOT be read while the labels follow.

#### Scenario: Hand drifts to the left
- **WHEN** a result is shown and the picture drifts 30 pixels to the left over a few frames
- **THEN** the labels are drawn 30 frame pixels further left, mapped to the view, and no frame is read

#### Scenario: Movement during the read
- **WHEN** the picture shifts 10 pixels down while a frame is being read
- **THEN** that read's labels appear 10 frame pixels lower than where the text was in the frame read

### Requirement: Fast movement or a new scene clears the labels
When a frame shifts by more than 8% of the frame's width, or changes strongly beyond its shift (a new scene, a zoom or a tilt), the shown labels SHALL fade out over 200 ms and the view SHALL wait for the picture to settle again before reading.

#### Scenario: Quick swing to another page
- **WHEN** labels are shown and the next frame shifts by 15% of the frame width
- **THEN** the labels fade out and nothing is read until the picture has been steady for 300 ms

#### Scenario: Pointing at something else
- **WHEN** labels are shown and the picture changes completely without shifting
- **THEN** the labels fade out

### Requirement: Reading again after a pan
When the labels have followed a total shift of more than 10% of the frame's width or height since the frame that was read, and the picture is then steady for 300 ms, the view SHALL read the latest frame again. The shifted labels SHALL stay shown until the new result replaces them.

#### Scenario: Panning down a page
- **WHEN** labels are shown, the user pans down by 20% of the frame height and holds still for 300 ms
- **THEN** the latest frame is read, the old labels stay until its result arrives, and the new result replaces them

#### Scenario: Small drift
- **WHEN** labels have followed a total shift of 4% and the picture is steady
- **THEN** nothing is read again

### Requirement: A completed download refreshes the held result
When the model for a language that the last read lacked finishes downloading, while a result is held or frozen, the view SHALL read the same frame again, so its paragraphs are translated. This SHALL apply to source and target models alike, and SHALL apply when the download finishes while that read is still running.

#### Scenario: Hindi model arrives
- **WHEN** a held result has Hindi paragraphs untranslated because the Hindi model was downloading, and the download completes
- **THEN** the frame is read again and the Hindi paragraphs are shown translated

#### Scenario: Target model arrives after switching language
- **WHEN** a held result shows Spanish paragraphs in English, the target is changed to German whose model isn't downloaded, the re-read finds the paragraphs untranslated, and the German download then completes
- **THEN** the frame is read again without the camera moving, and the paragraphs are shown in German

#### Scenario: Download finishes during a read
- **WHEN** a read finds a Hindi paragraph whose model is downloading and a Spanish paragraph still being translated, and the Hindi download completes before that read finishes
- **THEN** once the read finishes with the Hindi paragraph untranslated, the frame is read again and both paragraphs are shown translated

#### Scenario: Frozen view
- **WHEN** the view is frozen with paragraphs untranslated because the target model was downloading, and the download completes
- **THEN** the frozen frame is read again and its paragraphs are shown translated, while the view stays frozen

### Requirement: Reads never queue
At most one read SHALL run at a time. A frame that would start a read while one is running SHALL NOT start or queue another; frames SHALL keep being measured for movement. A read whose result is no longer wanted (after a settings change, a freeze that reads, a resume, or the camera stopping) SHALL be discarded.

#### Scenario: Settling again during a read
- **WHEN** a read is running and the picture settles again after a small pan
- **THEN** no second read starts until the first finishes

#### Scenario: Camera goes to the background during a read
- **WHEN** the app goes to the background while a read runs, and the read finishes afterwards
- **THEN** its result is not shown
