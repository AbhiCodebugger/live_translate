# Spec Delta

## MODIFIED Requirements

### Requirement: Translates into the target language
The view SHALL translate recognized lines into the app's target language. When the app gives none, it SHALL translate into the device's language, or into English when the device language has no on-device translation model. The device language is read when the view starts.

#### Scenario: Hindi sign to English
- **WHEN** the target language is English, Devanagari is selected, and a frame shows a Hindi sign whose models are downloaded
- **THEN** each Hindi line is shown with its English translation

#### Scenario: No target on an English phone
- **WHEN** the app gives no target language, the device language is English (United States), and a frame shows a Hindi sign whose models are downloaded
- **THEN** each Hindi line is shown with its English translation

#### Scenario: No target on a French phone
- **WHEN** the app gives no target language and the device language is French (France)
- **THEN** lines are translated into French, and the French model is checked as soon as the view starts

#### Scenario: Device language without a model
- **WHEN** the app gives no target language and the device language is one with no on-device translation model, such as Amharic
- **THEN** lines are translated into English

### Requirement: Selected scripts are read
The view SHALL read the scripts the app selects, Latin and Devanagari by default, taking turns between them when more than one is selected.

#### Scenario: Default script
- **WHEN** the app doesn't select scripts
- **THEN** both Latin and Devanagari text are read, taking turns frame by frame

#### Scenario: Latin and Devanagari
- **WHEN** the app selects Latin and Devanagari
- **THEN** both scripts' lines are translated and shown

#### Scenario: Latin only
- **WHEN** the app selects only Latin
- **THEN** only Latin text is read
