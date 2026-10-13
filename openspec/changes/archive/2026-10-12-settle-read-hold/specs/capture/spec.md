# Spec Delta

## REMOVED Requirements

### Requirement: Frames are dropped while one is processing
**Reason**: Frames are no longer processed one by one for text. Every frame is measured for movement, and reads are single-flight.
**Migration**: See "Reads never queue" in `live-translation`.

### Requirement: Frames respect a minimum interval
**Reason**: Reads are triggered by the picture settling, not by a timer. The view's `minFrameInterval` parameter is removed.
**Migration**: Remove `minFrameInterval` from `LiveTranslateView` calls. The view is internal, so only the example and tests are affected.

## MODIFIED Requirements

### Requirement: A failed frame does not stop capture
If a read fails, the failure SHALL be reported as a `PipelineFailure`, no labels from that read SHALL be shown, and the view SHALL read again the next time the picture settles.

#### Scenario: Recognition throws
- **WHEN** recognition throws during a read, and the picture later moves and settles again
- **THEN** the failure is reported as a `PipelineFailure` and the next settled frame is read
