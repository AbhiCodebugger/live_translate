# Design

## Context

See proposal.md for the motivation and specs/example-app/spec.md for the behaviour.

What exists now:

| Piece | Where | Relevant here |
|---|---|---|
| `DebugApp` / `DebugPage` | `example/lib/main.dart` | one stateful page: `LiveTranslateView` plus two FABs (torch, freeze), and `onError` → `SnackBar` |
| `LiveTranslateView` | `lib/src/view/live_translate_view.dart` (internal) | `targetLanguage`, `scripts`, `sourceLanguages`, `onError`, `controller`, and `@visibleForTesting createSession` / `createEngines`. A change to target, scripts or source languages swaps engines without restarting the camera (`live-view` spec). |
| `LiveTranslateController` | `lib/src/controller/` (internal) | `state`, `freeze`, `resume`, `setTorch`. Doesn't report torch state or the target. |
| `deviceTargetLanguage(Locale)` | `lib/src/models/device_language.dart` (internal) | the view's fallback rule: locale language code → `TranslateLanguage`, else English |
| `TranslationModels` | public | `isDownloaded`, `downloaded()`, plus `@visibleForTesting TranslationModels.withStore(ModelStore)` |
| `ModelNotDownloaded(language)` | public | reported once for each download the view starts, both for the target and for confirmed source languages, including ones the app didn't expect (`translate` spec) |
| `example/test/widget_test.dart` | | mocks the translator method channel; tests have no camera plugin, so the view reports `CameraUnavailable` |

ML Kit translates 59 languages. Hindi and Marathi are the only Devanagari ones (there's no Nepali). 37 are written in Latin script.

## Goals / Non-Goals

**Goals:**
- Every scenario in `specs/example-app/spec.md` is covered by a widget test in `example/test/`, except the two device-locale scenarios, which are unit tests of the starting-target function.
- No change under `lib/`.

**Non-Goals:**
- Pixel-matching Google Lens. Same layout and feel, Material widgets, no custom icon assets.
- Localising the example's own UI text. It stays in English.
- Remembering choices across launches.

## Decisions

**D1. Files.** `example/lib/` splits into:
- `main.dart`: `ExampleApp` and `MaterialApp`;
- `camera_screen.dart`: the screen, its state, and the overlay chrome (top bar, pill, shutter);
- `language_picker.dart`: the picker page;
- `languages.dart`: display names, the Latin and Devanagari sets, and the source → (sourceLanguages, scripts) mapping.

`DebugApp` / `DebugPage` are renamed to `ExampleApp` / `CameraScreen`, because the screen is no longer a debug screen.

**D2. The screen's state drives the view through widget parameters, not controller setters.** `CameraScreen` holds `target` (a `TranslateLanguage`) and `source` (a `TranslateLanguage?`, where null means "Detect language"). It derives `scripts` and `sourceLanguages` from `source` with a pure function in `languages.dart`, and rebuilds `LiveTranslateView` with all three. This leaves one source of truth. The view already swaps engines without restarting the camera on these changes. Using `setTargetLanguage` / `setScripts` as well would mean reasoning about the controller-vs-widget "most recent wins" rule for no gain. The controller is used only for state, freeze/resume and the torch.

**D3. Starting target = `deviceTargetLanguage(platformDispatcher.locale)`, computed once in `initState` and always passed explicitly** (option (a) from exploration). The view's own default is then never used, so the chip and the view can't disagree. The function is imported from `src/` next to the view (`implementation_imports` is already ignored in the example). Tests set `tester.platformDispatcher.localeTestValue`.

**D4. Display names.** `TranslateLanguage` has no display name, so `languages.dart` capitalises the enum `name` (`german` → "German"), with one override: `haitian` → "Haitian Creole". This avoids a 59-entry table that could drift from the enum. Search matches on this name, case-insensitively, as a substring.

**D5. Source → what is read** (pure function, unit-tested over the whole enum):

```
 source            sourceLanguages   scripts
 null (Detect)     null              {latin, devanagari}
 hindi / marathi   {source}          {devanagari}
 in latinLanguages {source}          {latin}
```

`latinLanguages` is a const set of the 37 Latin-script languages. The source picker lists `{null} + devanagari + latin`. A unit test checks that each enum value is in exactly one of Latin, Devanagari or "other" (the other-scripts set), so an ML Kit upgrade that adds a language fails loudly.

**D6. Picker = a pushed `MaterialPageRoute` returning a result.** `LanguagePicker` takes `title`, `options` (a list of `TranslateLanguage?`, where null is shown as "Detect language"), `selected`, and the downloaded set. It pops `(choice: TranslateLanguage?)`, a record, so "chose Detect" (`(choice: null)`) differs from "went back" (a null route result). Layout:
- an `AppBar` with a `TextField`;
- the selected option first, with a check-circle icon;
- then the rest in alphabetical order;
- a download-done icon on languages in the downloaded set.

The downloaded set comes from `TranslationModels.downloaded()`, loaded when the picker opens. Until it arrives the list shows without marks. "Detect language" is never marked.

**D7. Download indicators by polling `isDownloaded`.** On `ModelNotDownloaded(language)`, the screen adds `language` to a `pending` set and starts a 2-second periodic timer (one per screen, not per language). Each tick calls `isDownloaded` for every pending language, removes those that are present, and stops the timer when the set is empty. The target chip shows a spinner when `pending.contains(target)`. The source chip shows one when `pending` holds any other language.

Alternatives:
- awaiting `TranslationModels.download(language)`: rejected, because it issues a second download request alongside the view's and fixes `wifiOnly`. Polling is read-only.
- clearing the indicator on the next translated line: rejected, because it isn't tied to a specific language.

**D8. Torch state.** The screen keeps `_torch`, and listens to the controller. When the state goes from `initializing` to `running` (a camera start or restart), it sets `_torch = false`. The view turns the torch off on restart (`controller` spec "Torch").

**D9. Shutter.** A 72 dp white circle inside a translucent ring, enabled only in `running` or `frozen`. `running` shows `Icons.translate` with the tooltip "Freeze", and `frozen` shows `Icons.play_arrow` with the tooltip "Resume". It's built with `ListenableBuilder` on the controller.

**D10. Chrome styling.** It sits over the camera in a `Stack`, inside `SafeArea`:
- top: a dark gradient scrim for legibility, then a row with a flash `IconButton` (`Icons.flash_on` / `Icons.flash_off`, tooltips "Torch on" / "Torch off") and the title "Live Translate" in white;
- below that: the pill, a white rounded container (radius 32) holding two chips filled light blue (`0xFFD3E3FD`, text `0xFF041E49`) and an arrow icon. The source chip shows `Icons.auto_awesome` before "Detect language". A chip's spinner is a 16 dp `CircularProgressIndicator` in place of its leading icon or after its label;
- bottom: the shutter, centred.

Everything is plain Material, so iOS and Android look the same.

**D11. Errors.** `onError` handles the exceptions like this:
- `ModelNotDownloaded`: goes to D7, with no snackbar;
- any other exception: the existing friendly-text `SnackBar`, unchanged.

The camera errors also stay visible in place of the preview (the view does that).

**D13. Detected language on the source chip.** While `source` is null, the screen listens to the controller and counts each shown line's `sourceLanguage`, a BCP-47 tag. The most frequent tag becomes the chip's label, mapped to a `TranslateLanguage` with `BCP47Code.fromRawValue`.

- On a tie, the language already shown stays if it is among the tied, so the label doesn't flicker; otherwise the first tied language in line order wins.
- The package exports `TranslateLanguage` but not this extension, so `languages.dart` imports `google_mlkit_translation` directly, with a `depend_on_referenced_packages` ignore. The package still pins the version. The test fakes make the same trade-off.
- Shown lines always carry a translation, so their tag is a language ML Kit translates. An unknown tag is skipped.
- A pure `detectedLanguage(lines, current)` in `languages.dart` holds the rule, so it can be unit-tested. The chip keeps the auto-detect icon, and the picker still shows "Detect language" as selected.

**D12. Testing seams.** `CameraScreen` takes optional `@visibleForTesting` parameters:
- `models` (`TranslationModels`): tests pass `TranslationModels.withStore(fakeStore)`;
- `createSession`, forwarded to the view: tests supply a small fake `CameraSession` written in `example/test/`, implementing the `src/` interface, so the view reaches `running` and the shutter, freeze and torch-reset scenarios can be tested;
- `createEngines`, forwarded to the view: engines that see no text and share the fake model store, so a missing target model is reported by the view's own check.

Tests check D5 end to end by reading the `targetLanguage`, `sourceLanguages` and `scripts` of the `LiveTranslateView` the screen builds.

Production code passes none of them.

## Risks / Trade-offs

- [A download that keeps failing leaves its spinner up, because the view retries on later frames] → Acceptable for a demo. The spinner's tooltip says "Downloading the language model…". (The view downloads on any network, not only Wi-Fi.)
- [When the target changes mid-download, the old target's spinner moves to the source chip (spec scenario "Language changed during a download")] → This is honest, because a download really is running, and rare. Revisit if it confuses on-device testing.
- [The example depends on four `src/` internals (the view, its controller, the camera session type and the device-language rule)] → It already used the view, and all four become public by 0.1.0. The import comment in `camera_screen.dart` explains this.
- [Under "Detect language", the Devanagari reader also reads Latin text. This doubles and misreads labels on Latin pages, and can skew the detected language (D13).] → A package bug, fixed in the separate change `own-script-lines`. Re-check the detected language on a device after that lands.
- [Polling every 2 s while a download is pending] → It costs one platform call per pending language, and only while something is pending.
- [Capitalised enum names aren't localised and could read oddly for future enum values] → The D5 coverage test flags new enum values, and the name is reviewed then.

## On-device results

Checked by the user on 2026-10-12 on the Samsung Galaxy, against the Google Lens screenshot.
- The Lens-style layout, target and source pickers, Hindi as the source, shutter, flash reset and download spinners all behaved as specified.
- Over a French page, the source chip named "French" while detecting.
- The first check found doubled and misread labels under "Detect language". They came from the package and were fixed in `own-script-lines`.
- The live labels' general messiness led to `still-frame-translation`.
- The user accepted the Samsung check for archiving; separate results for the iPhone 14 weren't reported.
