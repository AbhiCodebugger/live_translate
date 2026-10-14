# Design

## Context

See proposal.md for the motivation. `CameraScreen` (`example/lib/camera_screen.dart`) is a `Stack`:
- the full-screen view, built through a `ViewBuilder` so tests can inject a fake camera and engines;
- a top gradient;
- a `SafeArea` column holding `_TopBar` (torch on the left, title centred), the `_LanguagePill`, a `Spacer` and the `_Shutter`.

The screen owns a `LiveTranslateController` and listens to it for the state, detected source and target. Models are checked through an injectable `TranslationModels`, and tests use `TranslationModels.withStore(FakeModelStore)`. The package's HUD is drawn top-left inside the view's own `SafeArea`, which is where it collided with `_TopBar`.

## Goals / Non-Goals

**Goals:**
- Use the 0.2.0 API the way an app would: `onFrozen` drives the Text button, `showDebugHud` the toggle, and `TranslationModels` the manager.
- No changes to the package. Everything is inside `example/`.

**Non-Goals:**
- A script switcher (dropped; see the proposal).
- Remembering the HUD toggle or the Wi-Fi switch across launches.
- Download progress percentages. The platform reports only completion, as `TranslationModels` documents.
- Selecting text on the frozen picture itself, Lens-style. The sheet is the copy surface.

## Decisions

**D1. `onFrozen` feeds a notifier that the Text button and sheet share.**

The screen holds `final _frozenLines = ValueNotifier<List<TranslatedLine>?>(null)`. `onFrozen` sets it to the lines it receives. It is reset to `null` when the controller's state leaves `frozen`, which the existing controller listener sees, and when a freeze begins, from `_shutter`, so a re-read hides the button until its result arrives.

Because the view calls `onFrozen` again after every re-read, the notifier also updates an open sheet: the sheet is a `ValueListenableBuilder` on the same notifier. The button shows when the value is non-null and non-empty.

Alternative: read `controller.lines` when the button is tapped. Rejected: the button couldn't know when the frozen read has finished, which is exactly what `onFrozen` reports.

**D2. The Text button sits left of the shutter, in a row that keeps the shutter centred.**

The shutter's `Center` becomes a three-slot `Row`:

`[Expanded(align right: Text button or nothing), shutter, Expanded(empty)]`

So the shutter doesn't move when the button appears. The button is a `FilledButton.tonalIcon` with `Icons.notes` and the label "Text", with the tooltip "Show text".

**D3. The sheet lives in `example/lib/text_sheet.dart`.**

`showTextSheet(context, ValueListenable<List<TranslatedLine>?> lines)` opens a `showModalBottomSheet`:
- `isScrollControlled: true`, inside a `DraggableScrollableSheet` (initial 0.5, max 0.9);
- a header row with the title "Text" and a `TextButton` "Copy all";
- one `ListTile` per line: the translation as the title, the original as the subtitle, and an `IconButton(Icons.copy)` with the tooltip "Copy".

Copying calls `Clipboard.setData` and shows "Copied" in the sheet's header for two seconds. A SnackBar would sit behind the modal sheet, and wrapping the sheet in its own `Scaffold` to host one makes the sheet fill the screen and stop closing on outside taps. "Copy all" joins the translations with `'\n\n'`. If the notifier goes `null` (resumed), the sheet closes itself.

**D4. The menu is a `PopupMenuButton` on the right of `_TopBar`.**

The button is `Icons.more_vert` with the tooltip "More". It has two items:
- "Languages on this phone", which pushes `ModelsScreen`;
- a `CheckedPopupMenuItem` "Debug HUD", bound to `_showHud`.

`_TopBar` gains `hud` and `onMenu` parameters. The title stays centred, because the torch and the menu sit in their own aligned slots of the existing `Stack`.

**D5. The model manager lives in `example/lib/models_screen.dart`.**

`ModelsScreen({required TranslationModels models})` is stateful:
- `_downloaded`, loaded from `models.downloaded()`;
- `_busy`, the set of languages downloading;
- `_wifiOnly = false`.

A `ListView` holds:
- a `SwitchListTile` "Wi-Fi only" with the subtitle "Downloads wait for Wi-Fi";
- the header "On this phone", then the downloaded languages sorted by `displayName`, each with an `IconButton(Icons.delete_outline)` and the tooltip "Delete";
- the header "Available", then the rest, each with an `IconButton(Icons.download)` and the tooltip "Download", replaced by a 24 px `CircularProgressIndicator` while in `_busy`.

Download calls `models.download(language, wifiOnly: _wifiOnly)`. On success it adds to `_downloaded`. On any error it shows a SnackBar, "Couldn't download German", and leaves `_downloaded` unchanged. Either way it removes the language from `_busy`. Delete calls `models.delete`, then removes it from `_downloaded`. Each `setState` is guarded by `mounted`, so leaving the page mid-download is safe.

The camera screen's own pending-download polling is left alone. A model downloaded here is picked up the next time the view checks.

**D6. The HUD is moved down by enlarging the view's top padding.**

The view's HUD uses `SafeArea`, which reads `MediaQuery.padding`. The screen wraps the view in a `MediaQuery` whose top padding is the real one plus the height of the controls: the 56 px top bar, the 12 px gap and the pill, about 136 px in all, given as a named constant next to the layout. The camera preview and labels ignore `MediaQuery` padding and still fill the screen, so only the HUD moves.

Alternative: add a HUD position parameter to the package. Rejected: it changes the public API for one app's layout, and the padding approach is the standard way to tell a widget which area is covered.

**D7. Tests reuse the existing fakes.**

- `fakeView` gains `onFrozen` and `showDebugHud` and passes them through.
- `FakeModelStore` gets an optional `downloadError` thrown from `download`, and records the `wifiOnly` flag of each download.
- `downloadGate` is a `final Completer`. Download tests complete it, and a test needing a second gated download uses a fresh store.
- Clipboard tests read the clipboard through `tester.binding.defaultBinaryMessenger`, using a mock handler on `SystemChannels.platform` that records `Clipboard.setData`.

## Risks / Trade-offs

- **[The HUD offset is a hand-kept constant]** → If the controls change height, the HUD could overlap again. The placement test checks that the HUD is below the pill's measured bottom, so it fails if the constant drifts.
- **[Deleting the model in use]** → The next read finds the model missing and the view downloads it again, which shows the chip spinner. That's acceptable for a demo, and it shows the automatic download.
- **[The sheet hides part of the frozen picture]** → It only opens on request (the user's choice). It starts at half height and can be dragged.

## Migration Plan

None. Only the example changes. The package version and CHANGELOG are untouched.
