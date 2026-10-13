# Tasks

## 1. Languages

- [x] 1.1 Add `example/lib/languages.dart` (design D4, D5) with:
  - `displayName(TranslateLanguage)`: the capitalised enum name, with `haitian` → "Haitian Creole";
  - const `devanagariLanguages` {hindi, marathi} and `latinLanguages` (the 37 Latin-script languages);
  - `sourceOptions`: null ("Detect language"), then the Devanagari and Latin languages;
  - `readingFor(TranslateLanguage? source)` returning `({Set<TranslateLanguage>? sourceLanguages, Set<TextScript> scripts})`.

  Verify with `example/test/languages_test.dart`:
  - null → (null, {latin, devanagari});
  - Hindi → ({hindi}, {devanagari});
  - Spanish → ({spanish}, {latin});
  - "German" and "Haitian Creole" names;
  - every `TranslateLanguage` value is in exactly one of Latin, Devanagari or the other-scripts set;
  - `sourceOptions` contains no Japanese, Arabic or Russian.

## 2. Language picker

- [x] 2.1 Add `example/lib/language_picker.dart` (design D6): a full-screen page with a search `TextField` in the `AppBar`. It shows the selected option first (check-circle icon), then the rest in alphabetical order. It shows a download-done icon for languages in the set from `TranslationModels.downloaded()`, loaded when it opens. It pops `(choice: …)` on tap, and returns null on back. Verify with `example/test/language_picker_test.dart`, using `TranslationModels.withStore` and a fake `ModelStore`:
  - typing "ger" shows German and hides Afrikaans;
  - with Spanish selected, Spanish is the first row and marked;
  - with English and Hindi downloaded, those two are marked and German isn't;
  - tapping German pops `(choice: german)`;
  - tapping "Detect language" pops `(choice: null)`;
  - back pops null.

## 3. Camera screen

- [x] 3.1 Add the test fakes in `example/test/support/`:
  - a fake `CameraSession` that starts, pauses, resumes and records torch calls;
  - `fakeEngines(store)`, engines that see no text and share the fake model store, so the view's own target check reports `ModelNotDownloaded` for a missing model;
  - a fake `ModelStore` whose downloads wait until the test marks the model present.

  Tests check what is read through the `targetLanguage`, `sourceLanguages` and `scripts` the screen passes to `LiveTranslateView`. Engines never see the source languages, so a recording fake couldn't check them.

  Check the fakes against the `src/` interfaces by running `flutter analyze` in `example/`.
- [x] 3.2 Add `example/lib/camera_screen.dart` (design D1–D3, D9–D12): `CameraScreen` with the `@visibleForTesting` `models`, `createSession` and `createEngines` seams; a starting target from `deviceTargetLanguage`; `source` state passed through `readingFor` into `LiveTranslateView`; and the chrome (scrim and top bar with flash toggle and title, the language pill, the shutter). Chips open the picker and apply its result. Rename `DebugApp` to `ExampleApp` in `main.dart`, and remove the FABs. Verify with `example/test/camera_screen_test.dart`:
  - the layout scenario (title, flash toggle, both chips, shutter, no `FloatingActionButton`);
  - a `fr_FR` test locale gives a "French" target chip and the view's target French, and `am_ET` gives English;
  - choosing German updates the chip and the view's target, and the fake session starts only once;
  - going back from the picker changes nothing;
  - choosing Hindi as the source rebuilds engines with ({hindi}, {devanagari}), Spanish with ({spanish}, {latin}), and Detect with (null, {latin, devanagari});
  - the shutter freezes and resumes, with the tooltips "Freeze" and "Resume".
- [x] 3.3 Add the torch reset (design D8): set `_torch` to false when the controller goes from `initializing` to `running`. Verify in `camera_screen_test.dart`: tapping the flash toggle shows "Torch off", and after simulating background then resume (`AppLifecycleState.paused` → `resumed`) it shows "Torch on" again.
- [x] 3.4 Add download indicators and error routing (design D7, D11): a `pending` set, a 2-second polling timer over `isDownloaded`, the target chip's spinner for the target and the source chip's spinner for any other language, and snackbars only for other errors. Verify in `camera_screen_test.dart` with fake time (`tester.pump(Duration(seconds: 2))`):
  - a German target reported missing shows a spinner on the target chip and no `SnackBar`, and the spinner clears after the fake store reports German present and one tick passes;
  - with Detect, Hindi reported missing shows a spinner on the source chip;
  - switching the target from German to French mid-download moves the spinner to the source chip;
  - `UnsupportedLanguagePair` shows a `SnackBar`;
  - no timer is left pending after the downloads clear or the screen is disposed.
- [x] 3.5 Update `example/test/widget_test.dart` for `ExampleApp` (no camera: "No camera available." shown, no FABs). The `src/` imports moved from `main.dart` to `camera_screen.dart`; update the import comment there so it names what they are. Verify that `flutter analyze` and `flutter test` pass in `example/`.

## 4. Integration checks

- [x] 4.1 Run the checks:
  - `dart format --set-exit-if-changed .` makes no changes;
  - `flutter analyze` and `flutter test` pass in the package and in `example/`;
  - `git diff --stat lib/` is empty;
  - `flutter build apk --debug` and `flutter build ios --debug --no-codesign` succeed in `example/`.

## 5. Detected source language

- [x] 5.1 Add `detectedLanguage(List<TranslatedLine> lines, TranslateLanguage? current)` to `example/lib/languages.dart`, and use it for the source chip while `source` is null (design D13). The screen listens to `controller.lines`. Verify with:
  - `example/test/languages_test.dart`:
    - French lines give French;
    - 3 Hindi lines and 1 English line give Hindi;
    - a tie keeps `current` when it is among the tied, and otherwise takes the first in line order;
    - unknown and null tags are skipped;
    - no lines give null.
  - `example/test/camera_screen_test.dart`, delivering frames whose fake lines are identified as French or Hindi:
    - the chip reads "French" with the auto-detect icon;
    - mixed Hindi and English lines read "Hindi";
    - it returns to "Detect language" once the lines are gone (after the tracker's three missed frames);
    - it keeps "French" after freezing;
    - choosing Spanish reads "Spanish";
    - tapping the chip while it reads "French" opens the picker with "Detect language" selected.
- [x] 5.2 Rerun the checks from 4.1, except that `git diff --stat lib/` is checked only for this change's files, because `own-script-lines` may change `lib/` in parallel. Verify that all checks pass.

## 6. On-device check

- [x] 6.1 **Manual, by the user, on the Samsung Galaxy and the iPhone 14:** check that the screen matches the Lens layout. Pick a target and see the chip update. Pick Hindi as the source over a Hindi sign. Freeze and resume with the shutter. Toggle the flash, background the app, and return. Watch a chip spinner during a first download. With "Detect language" on, check that the source chip names French over a French page and Hindi over a Hindi sign. Record the results under "On-device results" in `design.md`. Verify that both devices are listed with each check.
