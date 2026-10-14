# pipeline-metrics Specification

## Purpose

Measures each read of the camera picture (how long recognition, translation and colour sampling took, and what it produced) and hands those numbers to apps for benchmarks and debugging.

## Requirements

### Requirement: A read's metrics time each stage
Each read's metrics SHALL give the time spent recognising text (including preparing the frame), translating (language detection, model checks and translation), sampling page colours, and the whole read from start to result. Every duration SHALL be zero or more, and the total SHALL be at least the sum of the three stages.

#### Scenario: Stage timings
- **WHEN** a read's recognition takes 120 ms, its translation 80 ms and its colour sampling 10 ms
- **THEN** its metrics give recognition 120 ms, translation 80 ms, sampling 10 ms, and a total of at least 210 ms

#### Scenario: Nothing to translate
- **WHEN** a read recognises no text
- **THEN** its translation and sampling times are zero, and its total is at least its recognition time

### Requirement: A read's metrics describe its result
Each read's metrics SHALL give the number of paragraphs the read translated, and whether it was the read of a frozen picture.

#### Scenario: Live read
- **WHEN** a settled live read translates two paragraphs
- **THEN** its metrics give two paragraphs and say it wasn't frozen

#### Scenario: Frozen read
- **WHEN** the view freezes while moving and reads the frozen frame
- **THEN** that read's metrics say it was frozen

### Requirement: Metrics are reported for each shown read
The controller's `metrics` stream SHALL emit one `PipelineMetrics` for each read whose result the view shows, live or frozen, after the result is shown. A read that fails, or whose result is discarded because something replaced it, SHALL emit nothing. Freezing that keeps the held labels reads nothing, so it SHALL emit nothing.

#### Scenario: Settled read
- **WHEN** a view with a controller settles and reads one paragraph
- **THEN** `metrics` emits once, with one paragraph

#### Scenario: Holding still
- **WHEN** a result is held and the picture doesn't move for two seconds
- **THEN** `metrics` emits nothing more

#### Scenario: Failed read
- **WHEN** recognition throws during a read
- **THEN** `metrics` emits nothing for it

#### Scenario: Superseded read
- **WHEN** a result is held, the target changes to French, and changes to German before the French re-read finishes
- **THEN** `metrics` emits once more, for the German read only

#### Scenario: Freezing a held view
- **WHEN** a result is held, the picture hasn't moved, and the view freezes
- **THEN** `metrics` emits nothing

### Requirement: The metrics stream follows the controller
The `metrics` stream SHALL accept any number of listeners and SHALL emit only while the controller is attached to a view. Disposing the controller SHALL close the stream.

#### Scenario: Two listeners
- **WHEN** two listeners subscribe to `metrics` and a read is shown
- **THEN** both receive the same `PipelineMetrics`

#### Scenario: Not attached
- **WHEN** a controller has not been passed to a view
- **THEN** listening to `metrics` succeeds and nothing is emitted

#### Scenario: Disposed
- **WHEN** the controller is disposed
- **THEN** the `metrics` stream is done

### Requirement: PipelineMetrics is an immutable value
`PipelineMetrics` SHALL be immutable and SHALL compare equal when all its fields are equal. Its `toString()` SHALL give each duration in whole milliseconds.

#### Scenario: Equal values
- **WHEN** two `PipelineMetrics` are built with the same durations, paragraph count and frozen flag
- **THEN** they are `==` and have the same `hashCode`

#### Scenario: Readable text
- **WHEN** a `PipelineMetrics` with a recognition time of 120 ms is printed
- **THEN** its text contains `120 ms`
