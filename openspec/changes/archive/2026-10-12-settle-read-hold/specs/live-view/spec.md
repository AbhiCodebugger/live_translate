# Spec Delta

## MODIFIED Requirements

### Requirement: Selected scripts are read
The view SHALL read the scripts the app selects, Latin and Devanagari by default, all of them in each read.

#### Scenario: Default script
- **WHEN** the app doesn't select scripts
- **THEN** each read uses both Latin and Devanagari

#### Scenario: Latin and Devanagari
- **WHEN** the app selects Latin and Devanagari
- **THEN** both scripts' paragraphs are translated and shown

#### Scenario: Latin only
- **WHEN** the app selects only Latin
- **THEN** only Latin text is read

### Requirement: Settings apply without restarting the camera
When the target language, the selected scripts or the source languages change, the view SHALL replace its recognition and translation engines, close the old ones, and discard results of reads from before the change. If a result was shown, the view SHALL read the frame it came from again with the new settings. The camera SHALL keep running.

#### Scenario: Target language changes
- **WHEN** a held result is shown in English and the target changes to French
- **THEN** the old engines are closed, the held frame is read again and shown in French, no English result is shown afterwards, and the camera isn't restarted

#### Scenario: Unchanged settings
- **WHEN** the view is rebuilt with the same target language, scripts and source languages
- **THEN** the engines are kept
