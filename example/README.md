# live_translate example

A Google Lens-style camera that translates text live and offline, built with [`live_translate`](https://pub.dev/packages/live_translate) and only its public API.

## What it shows

- **Live translation.** Hold the phone still over text and each paragraph is translated in place, in the page's colours.
- **Language pill.** Tap the left chip to choose the language to translate from, and the right chip for the language to translate into. While on "Detect language", the left chip shows how far detection has got: "Looking for text…", a guess such as "Spanish?", the language with a spinner while its model downloads, then the language. It says "No supported text found" when three reads find nothing it can read, "Latin can't be translated" for a language ML Kit can't translate, and "Spanish · download failed" when a download fails. The source choice also decides the scripts read:
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

## Replay tests

`integration_test/replay_test.dart` runs saved photos of real text through the package's real pipeline: the camera format conversion, ML Kit recognition, language detection and translation, and colour sampling. It checks that each photo's expected paragraphs are found, in the right language, and translated. It also reports how long every read took. It needs a real device, and downloads any missing translation models on its first run.

```sh
# Correctness, in debug mode:
flutter test integration_test/replay_test.dart -d <device>

# Timings fit for publishing, in profile mode. Writes
# build/integration_response_data.json:
flutter drive --profile \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/replay_test.dart -d <device>
```

### Adding a frame

1. Take a photo of public text only: a sign, a menu or a printed page, with no faces or personal details. The repository is public.
2. Prepare it. This turns it upright, removes all EXIF data including location, and resizes and compresses it into `assets/replay_frames/`:

   ```sh
   dart run tool/prepare_replay_frames.dart ~/Photos/station_sign.jpg
   ```

   The script reads JPEG and PNG, not HEIC. Convert an iPhone photo first, at full size: `sips -s format jpeg IMG_1234.HEIC --out station_sign.jpg`.

3. Describe it in `assets/replay_frames/frames.json`:

   ```json
   {
     "file": "station_sign.jpg",
     "note": "Platform sign, Hindi over English",
     "target": "en",
     "scripts": ["latin", "devanagari"],
     "sourceLanguages": null,
     "expect": [
       { "source": "प्लेटफ़ॉर्म", "language": "hi", "translation": ["platform"] }
     ]
   }
   ```

   - `target` is the language to translate into.
   - `scripts` are the scripts to read.
   - `sourceLanguages` is `null` to detect the languages.
   - Each `expect` entry is a paragraph the read must contain:
     - `source` is a short fragment of its text (1–3 distinctive words survive OCR noise best);
     - `language` is the language it should be detected as;
     - `translation` is optional keywords, one of which its translation must contain.

Keep each photo under 300 KB, and the folder under 3 MB: the frames ship with the example.

## Files

- `lib/main.dart`: the app.
- `lib/camera_screen.dart`: the camera screen: the view, top bar, language pill, shutter and Text button.
- `lib/language_picker.dart`: the searchable language picker.
- `lib/languages.dart`: language names, and which languages are written in which script.
- `lib/text_sheet.dart`: the sheet of frozen text with its copy buttons.
- `lib/models_screen.dart`: "Languages on this phone".
- `integration_test/replay_test.dart` and `integration_test/replay/`: the replay tests, and how they build frames, read the manifest and match results.
- `tool/prepare_replay_frames.dart`: prepares photos as replay frames.
