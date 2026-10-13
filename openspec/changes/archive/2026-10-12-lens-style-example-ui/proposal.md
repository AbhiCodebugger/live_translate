# Proposal

## Why

The example app is still a debug screen: a bare camera with two floating buttons, and model downloads shown as snackbars. It can't change languages, so trying another target means editing code. The plan calls for a polished example app with a language picker, and it's the app people will install from GitHub Releases to judge the package. This change gives it a Google Lens-style camera screen.

## What Changes

- **Screen layout** in `example/lib/main.dart`, over the full-screen `LiveTranslateView`:
  - a top bar with a title and a flash toggle;
  - a language pill near the top: `[source] -> [target]`;
  - a round shutter button at the bottom that freezes and resumes.
- **Target chip:** shows the current target language. At launch it is the device language, or English when that has no model, from the package's existing `deviceTargetLanguage`. The app always passes this target to the view explicitly. Tapping the chip opens the language picker.
- **Source chip:** shows "Detect language" or the chosen source language. While detecting, it names the language most shown lines were translated from, such as "French", and returns to "Detect language" when no lines are shown. Tapping it opens the picker, which lists only languages written in Latin or Devanagari, with "Detect language" pinned at the top. Choosing a source sets both `sourceLanguages` and `scripts`:
  - "Detect language": no source hint, both scripts;
  - Hindi or Marathi (the only Devanagari languages ML Kit translates): that language, Devanagari only;
  - any other listed language: that language, Latin only.
- **Language picker:** a full-screen page with a search field, the current choice at the top, then all choices alphabetically. Languages whose model is on the device show a check mark (`TranslationModels.downloaded()`). The picker doesn't start downloads, because the view already downloads the models it needs.
- **Shutter:** calls `freeze()` while running and `resume()` while frozen. Its icon reflects the state.
- **Download status:** while a model downloads (reported as `ModelNotDownloaded` through `onError`), the matching chip shows a spinner instead of a snackbar appearing. Other errors still show a snackbar.
- **Torch:** the flash icon goes back to "off" when the camera restarts, because the view turns the torch off then.
- **Removed:** the debug floating action buttons and the download snackbars.
- **Not included:**
  - a gallery or still-image button, a Search tab, an overflow menu, and a close button;
  - the doubled and misread labels under "Detect language", found during the on-device check. They come from the package (its Devanagari reader also reads Latin text), so they are fixed in the separate change `own-script-lines`.

## Capabilities

### New Capabilities
- `example-app`: What the bundled example app does: screen layout, language selection and how it maps onto the view's target, source languages and scripts, the detected source language, the language picker, freeze through the shutter, the torch state, and how download status and errors are shown.

### Modified Capabilities
<!-- None: the package's behaviour doesn't change. -->

## Impact

- **Code:**
  - `example/lib/main.dart`, split into a few files under `example/lib/` if it grows;
  - `example/test/widget_test.dart`, plus new example tests.
- **Package code and public API:** unchanged. The example keeps importing `LiveTranslateView`, the controller and `deviceTargetLanguage` from `src/`, as it already does for the view.
- **Dependencies:** none added.
- **Platforms:** plain Flutter widgets only, so there's no platform-specific code. The user checks the screen manually on the Samsung Galaxy and the iPhone 14.
