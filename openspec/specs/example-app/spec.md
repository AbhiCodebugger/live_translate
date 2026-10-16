# example-app Specification

## Purpose
Describes the bundled example app: a Google Lens-style camera screen that shows the package translating live. It lets the user pick the source and target languages, freeze the view and copy its text, use the torch, manage the translation models on the phone, and turn on the debug HUD.

## Requirements

### Requirement: Camera screen layout
The example app SHALL show the live translation view full screen. Over it, it SHALL show a top bar with a title, a flash toggle and a menu button, a language pill near the top with a source chip, an arrow and a target chip, and a round shutter button near the bottom. It SHALL NOT show floating action buttons.

#### Scenario: App starts
- **WHEN** the example app starts
- **THEN** the camera view fills the screen, with the title, the flash toggle, the menu button, the source chip, the target chip and the shutter button over it

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
While the source is "Detect language", the source chip SHALL show the view's source status, keeping the auto-detect icon: "Looking for text…" while searching, the language's name with a question mark when guessed, the language's name when downloading or ready, "No supported text found" when not found, "<name> can't be translated" when unsupported (the BCP-47 tag when it has no name), and the language's name with "download failed" when a download failed. Tapping the chip SHALL still open the picker with "Detect language" selected.

#### Scenario: Searching
- **WHEN** the source is "Detect language" and the status is searching
- **THEN** the source chip reads "Looking for text…" with the auto-detect icon

#### Scenario: Guessed
- **WHEN** the source is "Detect language" and the status is guessed for Spanish
- **THEN** the source chip reads "Spanish?"

#### Scenario: Downloading
- **WHEN** the source is "Detect language" and the status is downloading for Spanish
- **THEN** the source chip reads "Spanish" and shows a progress indicator

#### Scenario: French page
- **WHEN** the source is "Detect language" and the status is ready for French
- **THEN** the source chip reads "French" with the auto-detect icon

#### Scenario: Mixed languages
- **WHEN** the source is "Detect language", and a read gives three paragraphs Hindi and one English with both models on the device
- **THEN** the source chip reads "Hindi"

#### Scenario: Nothing shown
- **WHEN** the source chip reads "French" and the labels are cleared by a new scene
- **THEN** the source chip reads "Looking for text…"

#### Scenario: Not found
- **WHEN** the source is "Detect language" and the status is not found
- **THEN** the source chip reads "No supported text found"

#### Scenario: Unsupported
- **WHEN** the source is "Detect language" and the status is unsupported with "la"
- **THEN** the source chip reads "Latin can't be translated"

#### Scenario: Download failed
- **WHEN** the source is "Detect language" and the status is download failed for Spanish
- **THEN** the source chip reads "Spanish · download failed"

#### Scenario: Frozen
- **WHEN** the source chip reads "French" and the user freezes the view
- **THEN** the source chip still reads "French"

#### Scenario: Chosen language wins
- **WHEN** the user chooses Spanish as the source while the status is ready for French
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

### Requirement: Text button after a freeze
While the view is frozen and the frozen picture's translation is shown with at least one paragraph, a "Text" button SHALL appear beside the shutter. It SHALL be hidden while the frozen picture is read, when the frozen picture has no translated paragraphs, and while the view isn't frozen.

#### Scenario: Freeze with text
- **WHEN** the user freezes and the frozen picture's translation shows two paragraphs
- **THEN** the Text button appears beside the shutter

#### Scenario: Reading
- **WHEN** the user freezes and the frozen picture is still being read
- **THEN** no Text button is shown

#### Scenario: Nothing translated
- **WHEN** the user freezes and the frozen picture has no translated paragraphs
- **THEN** no Text button is shown

#### Scenario: Resume
- **WHEN** the Text button is shown and the user resumes
- **THEN** the Text button is hidden

### Requirement: Text sheet lists and copies the translation
Tapping the Text button SHALL open a sheet listing each frozen paragraph, in reading order, with its translation and its original text. Each paragraph SHALL have a copy button that copies its translation to the clipboard. A "Copy all" button SHALL copy every translation, separated by blank lines. Each copy SHALL be confirmed with a short message. If the frozen picture is read again while the sheet is open, the sheet SHALL show the new translation.

#### Scenario: Sheet content
- **WHEN** the frozen translation is "Exit" from "Salida" and "Entrance" from "Entrada", and the user taps the Text button
- **THEN** the sheet lists "Exit" with "Salida", then "Entrance" with "Entrada"

#### Scenario: Copy one
- **WHEN** the user taps the copy button beside "Exit"
- **THEN** the clipboard holds "Exit" and a message confirms the copy

#### Scenario: Copy all
- **WHEN** the user taps "Copy all"
- **THEN** the clipboard holds "Exit", a blank line, and "Entrance"

#### Scenario: Target changes while open
- **WHEN** the sheet is open showing English, and the target changes to German so the frozen picture is read again
- **THEN** the sheet shows the German translations

### Requirement: Top bar menu
The menu button SHALL open a menu with "Languages on this phone", which opens the model manager, and a "Debug HUD" item with a check mark showing whether the HUD is on.

#### Scenario: Menu items
- **WHEN** the user taps the menu button
- **THEN** the menu shows "Languages on this phone" and "Debug HUD", the latter unchecked

#### Scenario: Open the model manager
- **WHEN** the user chooses "Languages on this phone"
- **THEN** the model manager page opens

### Requirement: Model manager lists languages
The model manager SHALL be a full-screen page. It SHALL list the languages whose translation model is on the device under "On this phone", each with a delete button, and every other language under "Available", each with a download button. Each section SHALL be in alphabetical order by name.

#### Scenario: Sections
- **WHEN** the English and Hindi models are on the device and the user opens the model manager
- **THEN** English and Hindi are listed under "On this phone", and German is listed under "Available"

### Requirement: Model manager downloads and deletes
Tapping a language's download button SHALL download its model, showing an indeterminate progress indicator in place of the button until the download finishes, and then list the language under "On this phone". Tapping a delete button SHALL delete the model and list the language under "Available". A failed download SHALL show a message and restore the download button. Several downloads SHALL be able to run at once.

#### Scenario: Download
- **WHEN** the user taps German's download button
- **THEN** German shows a progress indicator, and once the model is on the device German is listed under "On this phone"

#### Scenario: Delete
- **WHEN** the user taps Hindi's delete button
- **THEN** the Hindi model is deleted and Hindi is listed under "Available"

#### Scenario: Failed download
- **WHEN** German's download fails
- **THEN** a message says the German download failed, and German shows its download button again

### Requirement: Wi-Fi only downloads
The model manager SHALL show a "Wi-Fi only" switch, off by default. Downloads started while it is on SHALL wait for Wi-Fi. Downloads started while it is off SHALL use any network.

#### Scenario: Default
- **WHEN** the user opens the model manager and downloads German
- **THEN** the switch is off and German is downloaded on any network

#### Scenario: Wi-Fi only
- **WHEN** the user turns the switch on and downloads German
- **THEN** German is downloaded on Wi-Fi only

### Requirement: Debug HUD toggle
Choosing "Debug HUD" in the menu SHALL turn the view's debug HUD on or off. It SHALL be off when the app starts. While on, the HUD SHALL be shown below the top bar and the language pill, not under them.

#### Scenario: Turn on
- **WHEN** the user chooses "Debug HUD" while it is off
- **THEN** the view shows its debug HUD, and the menu item is checked the next time the menu opens

#### Scenario: Turn off
- **WHEN** the user chooses "Debug HUD" while it is on
- **THEN** the debug HUD is hidden

#### Scenario: Placement
- **WHEN** the debug HUD is on
- **THEN** the top of the HUD is below the bottom of the language pill
