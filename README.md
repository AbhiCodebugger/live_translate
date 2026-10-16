# live_translate

A drop-in Flutter widget that turns the camera into a **live, offline translator**. Text in the camera view is recognised, translated on the device and painted over the original, in place.

```dart
const LiveTranslateView();
```

<img src="https://raw.githubusercontent.com/AbhiCodebugger/live_translate/main/doc/images/demo.gif" alt="A French page translated into Dutch in the camera view" width="280">

## Features

- **One widget.** `LiveTranslateView` runs the camera, reads the text, translates it and draws the translation on the page.
- **Offline.** Recognition and translation use Google ML Kit on the device. Text never leaves the phone.
- **Steady labels.** The view reads once the camera holds still and keeps the result stuck to the page while your hand moves a little, so labels don't flicker.
- **Looks like the page.** Each paragraph is translated whole and drawn in the colours sampled from the page behind it.
- **Latin and Devanagari.** English, Spanish, French, German and the other Latin-script languages, plus Hindi and Marathi, are read at the same time.
- **Automatic languages.** Each paragraph's language is detected, and the models it needs download on their own. The target defaults to the phone's language.
- **Freeze.** Pause on the current picture to read the translation at leisure.
- **Programmatic control.** An optional `LiveTranslateController` reports state, lines and how far language detection has got, and changes the languages, scripts and torch without restarting the camera.
- **Your own look.** Draw the translations yourself with `overlayBuilder`, and show your own screen while the camera starts with `placeholderBuilder`.
- **Measurable.** `controller.metrics` reports how long each read took, stage by stage, and `showDebugHud` shows the numbers over the camera.

## Install

```sh
flutter pub add live_translate
```

Then complete the platform setup below.

## Platform setup

### Android

In `android/app/build.gradle.kts`, set the minimum SDK to 24 or higher and add the Devanagari recognizer:

```kotlin
android {
    defaultConfig {
        minSdk = 24
    }
}

dependencies {
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
}
```

In `android/app/src/main/AndroidManifest.xml`, ask for the camera:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS

ML Kit needs iOS 15.5 or later. In `ios/Podfile`, set the platform and add the Devanagari recognizer:

```ruby
platform :ios, '15.5'

target 'Runner' do
  # ...
  pod 'GoogleMLKit/TextRecognitionDevanagari', '~> 9.0.0'
end
```

In `ios/Runner/Info.plist`, say why you use the camera:

```xml
<key>NSCameraUsageDescription</key>
<string>The camera is used to recognise and translate text.</string>
```

Test on a real iPhone: ML Kit has limited simulator support.

Google distributes ML Kit for iOS through CocoaPods, so iOS builds use CocoaPods and Flutter prints a Swift Package Manager warning for the `google_mlkit_*` plugins. The warning is expected and harmless. Swift Package Manager support is planned for 1.1.

### Latin only

If you don't need Devanagari, pass `scripts: {TextScript.latin}` and skip the Devanagari lines above. Latin recognition is bundled with ML Kit.

When you upgrade, keep the Devanagari versions in step with the ones in [`google_mlkit_text_recognition`'s README](https://pub.dev/packages/google_mlkit_text_recognition).

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:live_translate/live_translate.dart';

void main() => runApp(const MaterialApp(home: TranslateScreen()));

class TranslateScreen extends StatelessWidget {
  const TranslateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Translates into the phone's language, or English when that language
    // can't be translated on the device.
    return const Scaffold(body: LiveTranslateView());
  }
}
```

The view asks for camera permission when it starts, and fills the space it is given.

## Recipes

### Hindi signage into English

Expecting one language skips detection, and reading one script saves work:

```dart
const LiveTranslateView(
  targetLanguage: TranslateLanguage.english,
  sourceLanguages: {TranslateLanguage.hindi},
  scripts: {TextScript.devanagari},
);
```

### Freeze, and read what's shown

```dart
class FreezeScreen extends StatefulWidget {
  const FreezeScreen({super.key});

  @override
  State<FreezeScreen> createState() => _FreezeScreenState();
}

class _FreezeScreenState extends State<FreezeScreen> {
  final _controller = LiveTranslateController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggle() => _controller.state == LiveTranslateState.frozen
      ? _controller.resume()
      : _controller.freeze();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiveTranslateView(controller: _controller),
      floatingActionButton: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => FloatingActionButton(
          onPressed: _toggle,
          child: Icon(
            _controller.state == LiveTranslateState.frozen
                ? Icons.play_arrow
                : Icons.pause,
          ),
        ),
      ),
    );
  }
}
```

While frozen, `_controller.paragraphs` holds one `TranslatedParagraph` per translated paragraph, with its source text, translation, source language and position. `_controller.targetLanguage` is the language being translated into, and `setTargetLanguage`, `setScripts`, `setSourceLanguages` and `setTorch` change the view without restarting the camera. `_controller.metrics` reports how long each read took; see [Measuring performance](#measuring-performance).

### Act on a freeze

`onFrozen` is called once the frozen picture's translation is shown, with its paragraphs. Here it opens a sheet of the translations:

```dart
LiveTranslateView(
  onFrozen: (paragraphs) => showModalBottomSheet<void>(
    context: context,
    builder: (context) => ListView(
      children: [
        for (final paragraph in paragraphs)
          ListTile(
            title: Text(paragraph.translatedText),
            subtitle: Text(paragraph.sourceText),
          ),
      ],
    ),
  ),
);
```

It is called again when the frozen picture is read again, for example after a change of target language, so update what it opened rather than opening it twice. To follow every change instead, including labels moving with the camera and fading, use `onParagraphsChanged`.

### Custom labels

`overlayBuilder` replaces the built-in labels. Its widget is laid over the whole view, and each paragraph's `rect` is a position inside it:

```dart
LiveTranslateView(
  overlayBuilder: (context, paragraphs) => Stack(
    children: [
      for (final paragraph in paragraphs)
        Positioned.fromRect(
          key: ValueKey(paragraph.id),
          rect: paragraph.rect,
          child: Opacity(
            opacity: paragraph.opacity,
            child: Container(
              color: Colors.yellow,
              alignment: Alignment.centerLeft,
              child: Text(paragraph.translatedText),
            ),
          ),
        ),
    ],
  ),
);
```

Honour `opacity`: it is how labels fade out. With an overlay, `OverlayStyle` is unused, and the page's colours aren't available.

A paragraph's `id` stays the same while the view keeps reading it in the same place: when it reads again while the language settles, after a download or a change of target language, after a small pan, and on freeze. A paragraph that now overlaps at least half of one shown before takes its id. Key widgets by it, as above, to keep their state or animate a new translation. A new scene, or a paragraph somewhere new, gets a new id.

To replace the progress indicator shown while the camera starts, pass `placeholderBuilder`:

```dart
LiveTranslateView(
  placeholderBuilder: (context) => const ColoredBox(color: Colors.black),
);
```

### Following language detection

Before the first paragraph is translated, the view has to find the source language, confirm it and, the first time, download its model. `controller.sourceStatus` tells you which stage it has reached, so you can show progress instead of an endless "detecting". `SourceStatus` is a sealed class:

```dart
final controller = LiveTranslateController();

String sourceLabel() => switch (controller.sourceStatus) {
  SourceSearching() => 'Looking for text…',
  SourceGuessed(:final language) => '${language.name}?',
  SourceDownloading(:final language) => 'Downloading ${language.name}…',
  SourceReady(:final language) => language.name,
  SourceUnsupported(:final tag) => "'$tag' can't be translated",
  SourceNotFound() => 'No supported text found',
  SourceDownloadFailed(:final language) =>
    "${language.name} didn't download",
};
```

Listeners are notified when it changes, so rebuild with a `ListenableBuilder`.

- **Searching:** nothing in the current scene has a language yet.
- **Guessed:** text looks like this language, but it isn't confirmed yet, so its model doesn't download. Long text confirms after one read. A short sign confirms after three; while you hold still, the view reads again every second until it does.
- **Downloading** and **Ready:** the model is downloading, or is on the device and paragraphs are translated. ML Kit doesn't report download progress, so there is no percentage. When the page is already in the target language, the status is ready with the target.
- **Unsupported:** the text is confirmed as a language ML Kit can't translate, such as Latin.
- **Not found:** three reads of a steady picture found no language: no text, a script the view doesn't read (such as Cyrillic), or text that can't be identified.
- **Download failed:** the next read retries it.

With several languages in view, the status names the language of the most paragraphs. A new scene or a settings change starts searching again. A controller that isn't attached reports searching.

### Managing models from your own UI

The view downloads the models it needs by itself. To prepare them ahead of time, or to free space:

```dart
final models = TranslationModels();

Future<void> prepare() async {
  if (!await models.isDownloaded(TranslateLanguage.hindi)) {
    // Waits for Wi-Fi unless you pass wifiOnly: false.
    await models.download(TranslateLanguage.hindi);
  }
  final onDevice = await models.downloaded();
  debugPrint('Models on this phone: $onDevice');
}
```

### Measuring performance

Turn on the debug HUD to see the numbers on the phone while you develop:

```dart
const LiveTranslateView(showDebugHud: true);
```

It shows the latest read's total time, the time each stage took, how many paragraphs it translated, and how many camera frames per second the view measures.

To log or benchmark them, listen to the controller's `metrics`. It emits one `PipelineMetrics` for each read the view shows, once the result is on screen:

```dart
final controller = LiveTranslateController();

void logReads() {
  controller.metrics.listen((metrics) {
    debugPrint(
      'read ${metrics.total.inMilliseconds} ms: '
      'recognition ${metrics.recognition.inMilliseconds}, '
      'translation ${metrics.translation.inMilliseconds}, '
      'colours ${metrics.sampling.inMilliseconds} '
      '(${metrics.paragraphs} paragraphs, frozen: ${metrics.frozen})',
    );
  });
}
```

- `recognition` covers preparing the frame and reading every selected script.
- `translation` covers detecting each paragraph's language, checking its models and translating. The first read after a language change includes the model checks, so it is slower.
- `sampling` covers picking up the page's colours.

Reads that fail or are replaced before they finish emit nothing. The time from holding the camera still to seeing labels is the settle time (about 300 ms) plus `total`. Measure in profile or release mode: debug builds are several times slower.

### Handling errors

Every problem reaches `onError` as a `LiveTranslateException`. It is a sealed class, so a `switch` covers every case:

```dart
LiveTranslateView(
  onError: (error) {
    final message = switch (error) {
      CameraPermissionDenied() => 'Allow camera access to translate.',
      CameraUnavailable() => 'No camera available.',
      ModelNotDownloaded(:final language) => 'Downloading ${language.name}…',
      UnsupportedLanguagePair(:final source) =>
        "Can't translate from '$source' on this device.",
      PipelineFailure() => 'Something went wrong while translating.',
    };
    debugPrint(message);
  },
);
```

`ModelNotDownloaded` is informational: it is reported once when a download starts, and the paragraphs appear once the model arrives.

## Example app

The [example app](example/) is a Google Lens-style camera screen built only on the public API:

- **Language pill.** Pick the language to translate from and to. "Detect language" shows the [source status](#following-language-detection) on its chip: "Looking for text…", "Spanish?", "Spanish" with a spinner while downloading, "No supported text found" and so on. The source choice also decides which scripts are read: "Detect language" reads Latin and Devanagari, Hindi and Marathi read Devanagari, and every other language reads Latin.
- **Shutter.** Freeze and resume. Once the frozen picture is translated, a **Text** button opens a sheet with each paragraph's translation and original, to copy one or all of them.
- **Torch** toggle.
- **Menu:**
  - **Languages on this phone** downloads and deletes translation models with `TranslationModels`.
  - **Debug HUD** turns `showDebugHud` on and off.
- **Downloads.** A spinner on the language chips shows a model being downloaded.

To run it on a phone connected to your computer:

```sh
cd example
flutter run
```

Use `flutter run --profile` when reading the HUD's timings.

The example also holds replay tests, which run saved photos of real signs and pages through ML Kit on a device. See its [README](example/README.md#replay-tests).

## Scripts and languages

- **Read:** Latin and Devanagari text, both by default.
- **Translated from:** any of the 59 languages ML Kit translates that is written in those scripts, such as English, Spanish, French, German, Hindi and Marathi.
- **Translated into:** any of ML Kit's 59 languages. Arabic, Hebrew, Persian and Urdu are drawn right to left.

**Model downloads:** each language's translation model is about 30 MB, and downloads once, on any network.
- The target language's model downloads as soon as the view starts.
- A detected language's model downloads once that language is confirmed: straight away for a paragraph of 20 letters or more, or after the language has been seen in three reads, which a steady picture makes within a few seconds.
- Until a model arrives, its paragraphs are left untranslated. They appear as soon as it's ready, without moving the camera.

## Limitations

- Rear camera only.
- Latin and Devanagari scripts only; Chinese, Japanese and Korean are planned.
- Horizontal text only; rotated text is planned.
- The first use of each language needs a network connection, to download its model.
- ML Kit needs a real iOS device.
- 0.x releases may change the API. 1.0 will be the stability promise.

## How it works

Every camera frame is used only to measure how the picture moves, from a small brightness thumbnail. When the picture has been steady for about 300 ms, that frame is read once:
1. Every selected script is recognised.
2. The lines are grouped into paragraphs.
3. Each paragraph's language is detected and the paragraph is translated, with a cache.
4. The page's colours are sampled behind each paragraph.

Each label covers its paragraph in the page's colours. Its text starts at the original text's size, but never above `OverlayStyle.maxFontSize` (28 by default, so large headings get a readable label rather than a giant one), and shrinks towards `minFontSize` until the translation fits. Pass `style: OverlayStyle(maxFontSize: 48)` for bigger headings.

While the result is held, the labels move with the measured camera shift, and no more frames are read once the source language is settled. Until then, while the [source status](#following-language-detection) is searching or guessed, a steady picture is read again a second after each read, so a short sign confirms its language in a few seconds without moving the phone. A fast movement or a new scene fades the labels out, and the next steady picture is read again. Reads never queue, so the camera never falls behind.

Paragraphs in the same script share one language per read, so a stray guess follows the rest of the page. Only languages ML Kit can translate take part in that vote when any paragraph has one, so a block of lorem ipsum identified as Latin doesn't drag a real heading along with it.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
