# Proposal

## Why

The example app is the package's demo and the APK people will try. It shows live translation, language choice, freezing and the torch. It doesn't yet show the 0.2.0 features: you can't copy what a freeze translated, manage models, or see the debug HUD without editing code. On the device, a HUD turned on by hand also landed under the app's torch button and title. Separately, `example/README.md` is still Flutter's "A new Flutter project" boilerplate, and pub.dev shows it on the package's Example tab.

## What Changes

- **Copy what a freeze translated.** While frozen, once the frozen picture's translation is shown (reported through `onFrozen`), a "Text" button appears beside the shutter. It opens a sheet listing each paragraph's translation and original, with a copy button for each and "Copy all". It is hidden while the frozen picture is read, when nothing was translated, and after resuming.
- **Menu in the top bar** with two entries: "Languages on this phone" and a "Debug HUD" toggle.
- **Languages on this phone**: a model manager page built on `TranslationModels`. It lists the downloaded languages with a delete button each, and the other languages with a download button. Each running download shows an indeterminate progress indicator. A "Wi-Fi only" switch is off by default, matching the view's own downloads. A failed download shows a message.
- **Debug HUD toggle**: turns the view's `showDebugHud` on and off. Off by default. The HUD is placed below the app's top controls instead of under them.
- **No script switcher.** The source picker already decides the scripts (Detect reads Latin and Devanagari, Hindi and Marathi read Devanagari, the rest read Latin). The docs say so instead.
- **Docs:** an "Example app" section in `README.md`, and `example/README.md` rewritten to describe the app and how to run it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `example-app`: "Camera screen layout" gains the menu button. New requirements cover the copy button and sheet, the menu, the model manager, and the debug HUD toggle and its placement.

## Impact

- **Changed code (example only):**
  - `example/lib/camera_screen.dart` (menu, Text button, HUD toggle and placement; `ViewBuilder` gains `onFrozen` and `showDebugHud`)
  - `example/lib/text_sheet.dart` (new)
  - `example/lib/models_screen.dart` (new)
- **Tests:**
  - `example/test/camera_screen_test.dart`
  - `example/test/text_sheet_test.dart` (new)
  - `example/test/models_screen_test.dart` (new)
  - `example/test/support/fakes.dart` (`fakeView` passes the new parameters; `FakeModelStore` can fail a download)
- **Docs:** `README.md`, `example/README.md`
- **Package API:** unchanged. The CHANGELOG lists package changes only, so it gets no entry.
- **Dependencies:** none. Copying uses Flutter's `Clipboard`.
