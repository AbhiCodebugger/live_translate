# Spec Delta

## MODIFIED Requirements

### Requirement: Missing models download over Wi-Fi only
Before translating, both the source and target models SHALL be checked. Lines needing a missing model SHALL be returned untranslated, and translation SHALL never be attempted while a model is missing. A missing source model SHALL be downloaded automatically only as the "Source models download only when expected and confirmed" requirement allows.

#### Scenario: Hindi model missing
- **WHEN** the source languages are restricted to Hindi, Hindi lines are translated to English in three frames, and the Hindi model is missing
- **THEN** one Wi-Fi-only download of Hindi is started, one `ModelNotDownloaded(hindi)` is reported, the lines are untranslated, and the translator is never called

#### Scenario: Download completes
- **WHEN** the Hindi download completes and a Hindi line is translated again
- **THEN** the line is translated

#### Scenario: Download fails
- **WHEN** the Hindi download fails
- **THEN** a later Hindi line starts one new download attempt

#### Scenario: Missing target model
- **WHEN** the English target model is missing and the first Spanish line is translated
- **THEN** a Wi-Fi-only download of English starts at once

## ADDED Requirements

### Requirement: A missing target model downloads at once
When the target language's model is found missing, its download SHALL start straight away, without waiting for the target language to be confirmed, because the app chose it.

#### Scenario: First frame with the target missing
- **WHEN** the English target model is missing, the source languages are restricted to Hindi, and the Hindi model is present
- **THEN** the English download starts on the first frame that contains a Hindi line

### Requirement: Downloads require Wi-Fi and are reported once each
Every automatic model download SHALL require Wi-Fi, and a `ModelNotDownloaded` SHALL be reported once for each download started, including each retry after a failed download.

#### Scenario: Download requested over Wi-Fi only
- **WHEN** an automatic download of the English model starts
- **THEN** it is requested with Wi-Fi required, and one `ModelNotDownloaded(english)` is reported

#### Scenario: Retry is reported again
- **WHEN** the source languages are restricted to Hindi, the Hindi download fails, and a later confirmed Hindi frame starts a new download
- **THEN** a second `ModelNotDownloaded(hindi)` is reported for the retry
