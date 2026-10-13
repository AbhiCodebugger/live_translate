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
- **Programmatic control.** An optional `LiveTranslateController` reports state and lines, and changes the language, scripts and torch without restarting the camera.

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

While frozen, `_controller.lines` holds one `TranslatedLine` per translated paragraph, with its source text, translation, source language and position. `_controller.targetLanguage` is the language being translated into, and `setTargetLanguage`, `setScripts` and `setTorch` change the view without restarting the camera.

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

## Scripts and languages

- **Read:** Latin and Devanagari text, both by default.
- **Translated from:** any of the 59 languages ML Kit translates that is written in those scripts, such as English, Spanish, French, German, Hindi and Marathi.
- **Translated into:** any of ML Kit's 59 languages. Arabic, Hebrew, Persian and Urdu are drawn right to left.

**Model downloads:** each language's translation model is about 30 MB, and downloads once, on any network.
- The target language's model downloads as soon as the view starts.
- A detected language's model downloads once that language is confirmed: straight away for a paragraph of 20 letters or more, or after the language has been seen in a few reads.
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

While the result is held, no more frames are read, and the labels move with the measured camera shift. A fast movement or a new scene fades them out, and the next steady picture is read again. Reads never queue, so the camera never falls behind.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
