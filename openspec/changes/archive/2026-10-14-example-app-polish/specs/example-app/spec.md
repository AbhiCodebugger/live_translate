# Spec Delta

## MODIFIED Requirements

### Requirement: Camera screen layout
The example app SHALL show the live translation view full screen. Over it, it SHALL show a top bar with a title, a flash toggle and a menu button, a language pill near the top with a source chip, an arrow and a target chip, and a round shutter button near the bottom. It SHALL NOT show floating action buttons.

#### Scenario: App starts
- **WHEN** the example app starts
- **THEN** the camera view fills the screen, with the title, the flash toggle, the menu button, the source chip, the target chip and the shutter button over it

## ADDED Requirements

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
