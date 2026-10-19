# Spec Delta

## ADDED Requirements

### Requirement: Automatic downloads finish on iOS
On iOS, an automatic model download SHALL count as finished once its model is on the device, even though the platform never reports the end of the download and may report it as cancelled. It SHALL then be treated exactly like a completed download on Android: the source status moves on, and the held picture is read again. A download whose model doesn't arrive within 5 minutes SHALL count as failed and be retried as any failed download is.

#### Scenario: Model arrives while the view checks other models
- **WHEN** on iOS, the Hindi source model is downloading, the view checks models while it downloads, the platform reports the download as cancelled, and the Hindi model is on the device 10 seconds later
- **THEN** the source status becomes ready with Hindi, and the held picture's Hindi paragraphs are translated without moving the camera

#### Scenario: Target model arrives
- **WHEN** on iOS, the view starts with a target whose model is missing, and the model is on the device 20 seconds later
- **THEN** the target download counts as finished, and paragraphs waiting for it are translated

#### Scenario: Model never arrives
- **WHEN** on iOS, the Hindi model still isn't on the device 5 minutes after its automatic download started
- **THEN** the source status becomes download failed with Hindi, and a later confirmed Hindi read starts a new download
