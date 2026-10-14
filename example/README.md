# live_translate example

A Google Lens-style camera that translates text live and offline, built with [`live_translate`](https://pub.dev/packages/live_translate) and only its public API.

## What it shows

- **Live translation.** Hold the phone still over text and each paragraph is translated in place, in the page's colours.
- **Language pill.** Tap the left chip to choose the language to translate from, and the right chip for the language to translate into. "Detect language" names the language it found, and the source choice decides the scripts read:
  - "Detect language" reads Latin and Devanagari;
  - Hindi and Marathi read Devanagari;
  - every other language reads Latin.
- **Shutter.** Freezes the picture and resumes it. Once the frozen picture is translated, the **Text** button opens a sheet listing each translation and its original, with a copy button for each and **Copy all**.
- **Torch.** The flash icon in the top-left corner.
- **Menu** (⋮):
  - **Languages on this phone** lists the translation models on the device. Delete them, or download others, optionally on Wi-Fi only.
  - **Debug HUD** shows the latest read's timings, its paragraph count and the frame rate.
- **Downloads.** A missing model downloads automatically, with a spinner on the language chip until it arrives.

## Running it

ML Kit needs a real device. On iOS the simulator isn't supported.

```sh
flutter run            # debug
flutter run --profile  # for timings in the Debug HUD
```

The first use of each language downloads its model, about 30 MB, so the phone needs a network connection once.

## Files

- `lib/main.dart`: the app.
- `lib/camera_screen.dart`: the camera screen: the view, top bar, language pill, shutter and Text button.
- `lib/language_picker.dart`: the searchable language picker.
- `lib/languages.dart`: language names, and which languages are written in which script.
- `lib/text_sheet.dart`: the sheet of frozen text with its copy buttons.
- `lib/models_screen.dart`: "Languages on this phone".
