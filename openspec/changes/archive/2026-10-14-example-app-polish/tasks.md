# Tasks

## 1. Test plumbing

- [x] 1.1 Extend `ViewBuilder` and `_buildView` in `example/lib/camera_screen.dart`, and `fakeView` in `example/test/support/fakes.dart`, with `onFrozen` and `showDebugHud`. Give `FakeModelStore` an optional `downloadError` and a record of each download's `wifiOnly` flag (design D7). Verify that `flutter test` in `example/` still passes unchanged.

## 2. Text button and sheet

- [x] 2.1 Add `example/lib/text_sheet.dart` with `showTextSheet` (design D3). Verify with `example/test/text_sheet_test.dart`:
  - the sheet lists "Exit"/"Salida" then "Entrance"/"Entrada";
  - the copy button puts "Exit" on the clipboard and shows "Copied" in the header, which goes away;
  - "Copy all" puts "Exit\n\nEntrance" on the clipboard;
  - changing the notifier updates the list;
  - setting it to `null` closes the sheet.
- [x] 2.2 In `CameraScreen`, add `_frozenLines`, fed by `onFrozen` and reset on freeze and when leaving `frozen`. Add the Text button left of a still-centred shutter, opening the sheet (design D1, D2). Verify with new cases in `example/test/camera_screen_test.dart`, one per "Text button after a freeze" scenario, plus "Target changes while open" (the sheet shows `[german]` lines after switching the target while frozen). Also check that the shutter's horizontal centre is the same with and without the button.

## 3. Menu and model manager

- [x] 3.1 Add `example/lib/models_screen.dart` (design D5). Verify with `example/test/models_screen_test.dart`, one test per "Model manager lists languages", "Model manager downloads and deletes" and "Wi-Fi only downloads" scenario: sections and order, download with spinner then move, delete, failed download with message, default and on Wi-Fi flags.
- [x] 3.2 Add the menu to `_TopBar` (design D4), opening `ModelsScreen` with the screen's `TranslationModels`. Verify with camera screen tests for "Menu items" and "Open the model manager", and update the "App starts" check in `example/test/widget_test.dart` to find the "More" button.

## 4. Debug HUD toggle

- [x] 4.1 Add `_showHud`, the checked menu item and the `MediaQuery` top-padding offset around the view (design D6). Verify with camera screen tests:
  - off at start (no `DebugHud`, found by type through `package:live_translate/src/view/debug_hud.dart`);
  - turning it on shows it, and the item is checked on reopening;
  - turning it off hides it;
  - the HUD's top is at or below the bottom of the language pill (`tester.getRect`).

## 5. Docs

- [x] 5.1 Add an "Example app" section to `README.md` listing what the app shows: the Lens-style screen, source and target pickers (and that the source choice decides the scripts read), freeze and Text sheet, torch, "Languages on this phone", and the Debug HUD toggle, plus how to run it (`cd example && flutter run`). Rewrite `example/README.md` along the same lines, with a short summary of each file in `example/lib/`. Verify that nothing in either file mentions a script switcher and that the boilerplate text is gone (`grep -c "A new Flutter project" example/README.md` prints 0).

## 6. Integration check

- [x] 6.1 Run `dart format --set-exit-if-changed .`, `flutter analyze` and `flutter test` at the package root and in `example/`, and `openspec validate example-app-polish --strict`. Verify that all pass.

## Workflow follow-up

- On-device check by the user on both test phones:
  - freeze, open the Text sheet, and paste a copied translation elsewhere;
  - download and delete a model from "Languages on this phone";
  - turn on the Debug HUD and confirm it sits below the pill.
- Archive the change once reviewed.
