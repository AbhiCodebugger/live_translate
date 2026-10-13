# Spec Delta

## MODIFIED Requirements

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
