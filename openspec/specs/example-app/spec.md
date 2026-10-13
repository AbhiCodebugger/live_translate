# example-app Specification

## Purpose
Describes the bundled example app: a Google Lens-style camera screen that shows the package translating live, and lets the user pick the source and target languages, freeze the view and use the torch.

## Requirements

### Requirement: Camera screen layout
The example app SHALL show the live translation view full screen. Over it, it SHALL show a top bar with a title and a flash toggle, a language pill near the top with a source chip, an arrow and a target chip, and a round shutter button near the bottom. It SHALL NOT show floating action buttons.

#### Scenario: App starts
- **WHEN** the example app starts
- **THEN** the camera view fills the screen, with the title, the flash toggle, the source chip, the target chip and the shutter button over it

### Requirement: Starting target language
At launch the example app SHALL translate into the device language, or into English when the device language has no on-device translation model. The target chip SHALL name the target language.

#### Scenario: French phone
- **WHEN** the example app starts on a phone whose language is French (France)
- **THEN** the target chip reads "French" and lines are translated into French

#### Scenario: Device language without a model
- **WHEN** the example app starts on a phone whose language is Amharic
- **THEN** the target chip reads "English" and lines are translated into English

### Requirement: Choosing the target language
Tapping the target chip SHALL open the language picker with every language the package can translate into. Choosing a language SHALL close the picker, show that language on the target chip, and translate into it without restarting the camera.

#### Scenario: Switch to German
- **WHEN** the target is English, the user taps the target chip and chooses German
- **THEN** the picker closes, the target chip reads "German", and new lines are translated into German

#### Scenario: Back without choosing
- **WHEN** the user opens the target picker and goes back without choosing
- **THEN** the target language is unchanged

### Requirement: Choosing the source language
Tapping the source chip SHALL open the language picker with "Detect language" first, then only the languages written in Latin or Devanagari script. Once the user chooses a language, the source chip SHALL name it. While the choice is "Detect language", the chip SHALL show what the "Detected language on the source chip" requirement describes.

#### Scenario: Source list
- **WHEN** the user taps the source chip
- **THEN** the picker lists "Detect language", Hindi, Marathi, English and French, and doesn't list Japanese, Arabic or Russian

#### Scenario: Choose Hindi
- **WHEN** the user chooses Hindi in the source picker
- **THEN** the picker closes and the source chip reads "Hindi"

### Requirement: Source choice sets what is read
The source choice SHALL decide the expected source languages and the scripts read:
- "Detect language" detects each line's language and reads both Latin and Devanagari.
- Hindi or Marathi expects only that language and reads only Devanagari.
- Any other listed language expects only that language and reads only Latin.

#### Scenario: Detect language
- **WHEN** the source is "Detect language"
- **THEN** no source language is expected, and both Latin and Devanagari are read

#### Scenario: Hindi
- **WHEN** the user chooses Hindi as the source
- **THEN** only Hindi is expected and only Devanagari is read, without restarting the camera

#### Scenario: Spanish
- **WHEN** the user chooses Spanish as the source
- **THEN** only Spanish is expected and only Latin is read

### Requirement: Detected language on the source chip
While the source is "Detect language", the source chip SHALL name the language that most of the shown translated lines came from, keeping the auto-detect icon. With no translated lines shown it SHALL read "Detect language". On a tie it SHALL keep the language it already names, if that one is among the tied. Tapping the chip SHALL still open the picker with "Detect language" selected.

#### Scenario: French page
- **WHEN** the source is "Detect language" and the shown lines were translated from French
- **THEN** the source chip reads "French" with the auto-detect icon

#### Scenario: Mixed languages
- **WHEN** the source is "Detect language" and three shown lines are from Hindi and one from English
- **THEN** the source chip reads "Hindi"

#### Scenario: Nothing shown
- **WHEN** the source chip reads "French" and the translated lines leave the view
- **THEN** the source chip reads "Detect language"

#### Scenario: Frozen
- **WHEN** the source chip reads "French" and the user freezes the view
- **THEN** the source chip still reads "French"

#### Scenario: Chosen language wins
- **WHEN** the user chooses Spanish as the source while French lines are shown
- **THEN** the source chip reads "Spanish"

#### Scenario: Picker after detection
- **WHEN** the source chip reads "French" because it was detected, and the user taps it
- **THEN** the picker opens with "Detect language" selected

### Requirement: Language picker
The language picker SHALL be a full-screen page with a search field, the current choice first, then the other choices in alphabetical order by name. Typing in the search field SHALL show only languages whose name contains the text, ignoring case.

#### Scenario: Search
- **WHEN** the user types "ger" in the target picker
- **THEN** the list shows German and Afrikaans is hidden

#### Scenario: Current choice first
- **WHEN** the target is Spanish and the user opens the target picker
- **THEN** Spanish is listed first, marked as selected

### Requirement: Downloaded models are marked
The language picker SHALL mark each language whose translation model is on the device. Choosing a language SHALL NOT start a download from the picker itself.

#### Scenario: Marks
- **WHEN** the English and Hindi models are on the device and the user opens the target picker
- **THEN** English and Hindi are marked as downloaded and German is not

### Requirement: Shutter freezes and resumes
The shutter button SHALL freeze the view while live translation runs and resume it while frozen. Its icon SHALL show which of the two a tap will do.

#### Scenario: Freeze
- **WHEN** the view is running and the user taps the shutter
- **THEN** the view is frozen and shows the still result of the frozen picture, and the shutter shows the resume action

#### Scenario: Resume
- **WHEN** the view is frozen and the user taps the shutter
- **THEN** live translation runs again and the shutter shows the freeze action

### Requirement: Flash toggle follows the torch
The flash toggle SHALL turn the torch on and off and show whether it is on. When the camera restarts, which turns the torch off, the toggle SHALL show the torch as off.

#### Scenario: Torch on
- **WHEN** the torch is off and the user taps the flash toggle
- **THEN** the torch turns on and the toggle shows it on

#### Scenario: Back from the background
- **WHEN** the torch is on, and the app goes to the background and returns
- **THEN** the toggle shows the torch as off

### Requirement: Model downloads shown on the chips
While a model the view reported missing is not yet on the device, a chip SHALL show a progress indicator: the target chip for the target language's model, and the source chip for any other language's model. The app SHALL NOT show a message for a missing model. The indicator SHALL clear once every reported model is on the device.

#### Scenario: Target model downloading
- **WHEN** the target is German and the view reports the German model missing
- **THEN** the target chip shows a progress indicator until the German model is on the device, and no message is shown

#### Scenario: Detected language downloading
- **WHEN** the source is "Detect language" and the view reports the Hindi model missing
- **THEN** the source chip shows a progress indicator until the Hindi model is on the device

#### Scenario: Language changed during a download
- **WHEN** the German target model is downloading and the user switches the target to French, whose model is on the device
- **THEN** the target chip shows no progress indicator, and the source chip shows one until the German model is on the device

### Requirement: Other problems shown as messages
The example app SHALL show every reported problem other than a missing model as a short message: camera permission denied, no camera, an unsupported language pair, or a pipeline failure.

#### Scenario: Unsupported pair
- **WHEN** the view reports that a source language can't be translated on this device
- **THEN** a message saying so is shown
