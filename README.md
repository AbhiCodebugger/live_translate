# live_translate

[![pub package](https://img.shields.io/pub/v/live_translate.svg?label=pub&color=7d2fd0)](https://pub.dev/packages/live_translate)
[![downloads](https://img.shields.io/pub/dm/live_translate?logo=dart&label=downloads)](https://pub.dev/packages/live_translate/score)
[![likes](https://img.shields.io/pub/likes/live_translate?logo=dart)](https://pub.dev/packages/live_translate/score)
[![pub points](https://img.shields.io/pub/points/live_translate?logo=dart)](https://pub.dev/packages/live_translate/score)
[![CI](https://github.com/AbhiCodebugger/live_translate/actions/workflows/ci.yaml/badge.svg)](https://github.com/AbhiCodebugger/live_translate/actions/workflows/ci.yaml)
[![style: flutter_lints](https://img.shields.io/badge/style-flutter__lints-0175c2.svg)](https://pub.dev/packages/flutter_lints)
[![license: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

A drop-in Flutter widget that turns the camera into a **live, offline translator**. It recognises the text in the camera view, translates it on the device and paints the translation over the original, in place.

```dart
const LiveTranslateView();
```

<img src="https://raw.githubusercontent.com/AbhiCodebugger/live_translate/main/doc/images/demo.gif" alt="A French page translated into Dutch in the camera view" width="280">

## Features

- **One widget.** `LiveTranslateView` runs the camera, reads the text, translates it and draws the translation on the page.
- **Offline and private.** Recognition and translation run on the device with Google ML Kit. Text never leaves the phone.
- **Steady labels.** The view reads once the camera holds still. The result then stays stuck to the page while your hand moves a little, so labels don't flicker.
- **Looks like the page.** Each paragraph is translated whole and drawn in colours sampled from the page behind it.
- **Latin and Devanagari.** English, Spanish, French, German and the other Latin-script languages are read together with Hindi and Marathi.
- **Automatic languages.** The view detects each paragraph's language and downloads the models it needs. The target defaults to the phone's language.
- **Freeze.** Pause on the current picture to read the translation at leisure.
- **Programmatic control.** An optional `LiveTranslateController` reports state, paragraphs and language detection progress. It also changes languages, scripts and the torch without restarting the camera.
- **Your own look.** Draw the translations yourself with `overlayBuilder`, and replace the startup screen with `placeholderBuilder`.
- **Measurable.** `controller.metrics` times each read stage by stage, and `showDebugHud` shows the numbers over the camera.

## Contents

- [Install](#install)
- [Platform setup](#platform-setup): [Android](#android), [iOS](#ios), [Latin only](#latin-only)
- [Quick start](#quick-start)
- [API](#api)
- [Recipes](#recipes)
- [Performance](#performance)
- [Size impact](#size-impact)
- [Example app](#example-app)
- [Scripts and languages](#scripts-and-languages)
- [Limitations](#limitations)
- [How it works](#how-it-works)

## Install

```sh
flutter pub add live_translate
```

Then complete the platform setup below.

## Platform setup

### Android

1. In `android/app/build.gradle.kts`, set the minimum SDK to 24 or higher and add the Devanagari recognizer:

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

2. In `android/app/src/main/AndroidManifest.xml`, ask for the camera:

   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   ```

3. Create `android/app/proguard-rules.pro` with:

   ```
   -dontwarn com.google.mlkit.vision.text.chinese.**
   -dontwarn com.google.mlkit.vision.text.japanese.**
   -dontwarn com.google.mlkit.vision.text.korean.**
   ```

   Release builds shrink the app with R8, which stops at the Chinese, Japanese and Korean recognizers that `google_mlkit_text_recognition` refers to but your app doesn't include. Flutter picks this file up on its own. Without it, `flutter build apk --release` fails with "Missing classes detected while running R8".

### iOS

1. ML Kit needs iOS 15.5 or later. In `ios/Podfile`, set the platform and add the Devanagari recognizer:

   ```ruby
   platform :ios, '15.5'

   target 'Runner' do
     # ...
     pod 'GoogleMLKit/TextRecognitionDevanagari', '~> 9.0.0'
   end
   ```

2. In `ios/Runner/Info.plist`, say why you use the camera:

   ```xml
   <key>NSCameraUsageDescription</key>
   <string>The camera is used to recognise and translate text.</string>
   ```

Test on a real iPhone: ML Kit has limited simulator support.

Google distributes ML Kit for iOS through CocoaPods. So iOS builds use CocoaPods, and Flutter prints a Swift Package Manager warning for the `google_mlkit_*` plugins. The warning is expected and harmless. Swift Package Manager support is planned for 1.1.

### Latin only

If you don't need Devanagari, pass `scripts: {TextScript.latin}` and skip the Devanagari lines above. Latin recognition is bundled with ML Kit.

On Android, also add this line to `proguard-rules.pro`. The plugin refers to the Devanagari recognizer just as it does to the Chinese, Japanese and Korean ones, so without this line release builds fail in R8 the same way:

```
-dontwarn com.google.mlkit.vision.text.devanagari.**
```

Leaving Devanagari out saves little; see [Size impact](#size-impact).

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

The view asks for camera permission when it starts and fills the space it's given. Model downloads happen on their own.

## API

Everything comes from one import: `package:live_translate/live_translate.dart`. It also re-exports `TranslateLanguage` from ML Kit and `ResolutionPreset` from the camera plugin.

### `LiveTranslateView`

Every parameter is optional.

| Parameter | Default | What it does |
|---|---|---|
| `targetLanguage` | the phone's language, or English if it can't be translated | The language to translate into. |
| `sourceLanguages` | `null`: detect each paragraph | The languages the text is in. A single language skips detection. |
| `scripts` | `{TextScript.latin, TextScript.devanagari}` | The scripts to read. Reading fewer is faster. |
| `resolution` | `ResolutionPreset.medium` | The camera's capture resolution. Higher reads smaller text, more slowly. |
| `style` | `OverlayStyle()` | How the built-in labels look. |
| `overlayBuilder` | `null`: built-in labels | Draws the translations yourself; see [Custom labels](#custom-labels). |
| `placeholderBuilder` | a progress indicator | Shown while the camera starts or restarts. |
| `onParagraphsChanged` | | Called with the shown paragraphs whenever they change, including on every frame while labels move or fade. |
| `onFrozen` | | Called with the frozen picture's paragraphs once they're shown; see [Act on a freeze](#act-on-a-freeze). |
| `onError` | | Called with every problem; see [Handling errors](#handling-errors). |
| `showDebugHud` | `false` | Shows read timings and frame cost over the camera; see [Measuring performance](#measuring-performance). |
| `controller` | `null` | A `LiveTranslateController` to drive and observe the view. |

A changed parameter takes effect without restarting the camera. The one exception is `resolution`: it's read only when the camera starts, so give the view a new `key` to apply a new one.

### `LiveTranslateController`

A `ChangeNotifier`: listen to it, for example with a `ListenableBuilder`, and `dispose` it when you're done.

| Member | What it does |
|---|---|
| `state` | A `LiveTranslateState`: `initializing`, `running`, `frozen` or `error`. |
| `paragraphs` | The shown `TranslatedParagraph`s, in the view's coordinates. |
| `targetLanguage` | The language being translated into. `null` until the view shows its first frame. |
| `sourceStatus` | How far finding the source language has got; see [Following language detection](#following-language-detection). |
| `metrics` | A broadcast `Stream<PipelineMetrics>` with one event per read shown. |
| `freeze()` / `resume()` | Pauses on the current picture and translates it, or goes back to live. |
| `setTargetLanguage(language)` | Translates into another language. |
| `setSourceLanguages(languages)` | Expects other languages, or detects again with `null`. |
| `setScripts(scripts)` | Reads other scripts. |
| `setTorch(on)` | Turns the torch on or off. It turns off whenever the camera restarts. |

Changes made through the controller and through the widget's parameters follow whichever came last.

### `TranslatedParagraph`

| Field | What it holds |
|---|---|
| `id` | Stays the same while the view keeps reading this paragraph in the same place. Use it to key widgets. |
| `sourceText` | The recognised text. |
| `translatedText` | Its translation. |
| `sourceLanguage` | The detected language as a BCP-47 code, or `null`. |
| `rect` | Where the paragraph is, in the view's coordinates. |
| `opacity` | From 1.0 down to 0.0 as the label fades out after a fast movement or a new scene. |

### `OverlayStyle`

Labels take their colours from the page. The colours below are used only where the page's colours couldn't be sampled.

| Field | Default | What it does |
|---|---|---|
| `backgroundColor` | `Color(0xCC000000)` | Fallback label fill. |
| `textColor` | `Color(0xFFFFFFFF)` | Fallback text colour. |
| `maxFontSize` | `28` | The largest size a label starts at. Labels start at the original text's size. |
| `minFontSize` | `10` | The smallest size a label shrinks to before its text is ellipsised. |
| `fontWeight` | `FontWeight.w600` | The weight of the translated text. |
| `borderRadius` | `6` | The corner radius of each label. |
| `padding` | `EdgeInsets.symmetric(horizontal: 4, vertical: 2)` | The space between a label's edge and its text. |

### Other types

- `TextScript`: `latin` or `devanagari`.
- `SourceStatus`: a sealed class; see [Following language detection](#following-language-detection).
- `PipelineMetrics`: `recognition`, `translation`, `sampling` and `total` durations, plus `paragraphs` (how many were translated) and `frozen`.
- `LiveTranslateException`: a sealed class; see [Handling errors](#handling-errors).
- `TranslationModels`: checks, downloads and deletes translation models; see [Managing models](#managing-models-from-your-own-ui).

## Recipes

### Hindi signage into English

Naming the one expected language skips detection, and reading one script saves work:

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

While frozen, `_controller.paragraphs` holds one entry per translated paragraph. Changing the language or scripts while frozen reads the same picture again.

### Act on a freeze

`onFrozen` is called with the frozen picture's paragraphs once their translation is shown. Here it opens a sheet of the translations:

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

It's called again whenever the frozen picture is read again, for example after a change of target language. So update what it opened rather than opening it twice. To follow every change instead, including labels moving with the camera and fading, use `onParagraphsChanged`.

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

- **Honour `opacity`:** it's how labels fade out.
- **With an overlay,** `OverlayStyle` is unused and the page's colours aren't available.
- **Key widgets by `id`,** as above, to keep their state or animate a new translation. A paragraph keeps its id across reads of the same scene: while the language settles, after a download or a change of target language, after a small pan, and on freeze. A paragraph that overlaps at least half of one shown before takes its id. A new scene, or a paragraph somewhere new, gets a new id.

To replace the progress indicator shown while the camera starts, pass `placeholderBuilder`:

```dart
LiveTranslateView(
  placeholderBuilder: (context) => const ColoredBox(color: Colors.black),
);
```

### Following language detection

Before the first paragraph is translated, the view has to find the source language, confirm it and, the first time, download its model. `controller.sourceStatus` tells you which stage it's at, so you can show progress instead of an endless "detecting". `SourceStatus` is a sealed class:

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

| Status | Meaning |
|---|---|
| Searching | Nothing in the current scene has a language yet. |
| Guessed | The text looks like this language, but it isn't confirmed yet, so its model doesn't download. Long text confirms after one read. A short sign confirms after three: while you hold still, the view reads again every second until it does. |
| Downloading | The model is downloading. ML Kit doesn't report progress, so there's no percentage. |
| Ready | The model is on the device and paragraphs are translated. A page already in the target language is ready with the target. |
| Unsupported | The text is confirmed as a language ML Kit can't translate, such as Latin. |
| Not found | Three reads of a steady picture found no language: no text, a script the view doesn't read (such as Cyrillic), or text that can't be identified. |
| Download failed | The next read retries the download. |

With several languages in view, the status names the language of the most paragraphs. A new scene or a settings change starts searching again. A controller that isn't attached reports searching.

### Managing models from your own UI

The view downloads the models it needs by itself. To prepare them ahead of time, or to free space, use `TranslationModels`:

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

`delete(language)` removes a model. `download` throws `ModelNotDownloaded` if it fails. It reports completion, not progress, so show an indeterminate indicator while it runs.

### Measuring performance

Turn on the debug HUD to see the numbers on the phone while you develop:

```dart
const LiveTranslateView(showDebugHud: true);
```

It shows the latest read's total time, the time each stage took, how many paragraphs it translated, and the camera frame rate.

The end of its last line, such as `30 fps · frame 1.4 ms avg, 3.2 max`, is the view's own work per camera frame over the last second: measuring how the picture moved and deciding whether to read. That work runs on the UI thread. It doesn't include the reads, which run in ML Kit, or painting the preview and labels. A 60 Hz screen has about 16 ms per frame for everything, so a worst case over 8 ms leaves little room for the rest of your UI.

To log or benchmark reads in code, listen to the controller's `metrics`. It emits one `PipelineMetrics` for each read the view shows, once the result is on screen:

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

- `recognition`: preparing the frame and reading every selected script.
- `translation`: detecting each paragraph's language, checking its models and translating. The first read after a language change includes the model checks, so it's slower.
- `sampling`: picking up the page's colours.

Reads that fail or are replaced before they finish emit nothing. The time from holding the camera still to seeing labels is the settle time (about 300 ms) plus `total`. Measure in profile or release mode, because debug builds are several times slower.

### Handling errors

Every problem reaches `onError` as a `LiveTranslateException`. It's a sealed class, so a `switch` covers every case:

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

`ModelNotDownloaded` is informational. It's reported once when a download starts, and the paragraphs appear once the model arrives.

## Performance

Measured on 2026-10-19 in profile mode with Flutter 3.47.7, using this repository after 0.2.1 (the changes under Unreleased in the changelog). The Samsung is a budget Android phone, and the iPhone 14 is a 2022 flagship.

| | Samsung Galaxy M17, Android 16 | iPhone 14, iOS 26.6.1 |
|---|---:|---:|
| Read: recognition | 72 ms | 35 ms |
| Read: translation | 2 ms | 0 ms |
| Read: colour sampling | 0 ms | 0 ms |
| **Read: total** | **75 ms** | **35 ms** |
| Holding still to labels | about 410 ms | about 395 ms |
| View's work per camera frame | 1.2 ms avg, 2.9 max | 0.8–1.1 ms avg, 2.9 max |
| Janky frames caused by the package | none seen | not profiled |
| Dart memory over 2 minutes of scanning | flat | not profiled |

- **Read** rows are medians over 15 photos of real signs and pages, each read 5 times after a first read, at the size `ResolutionPreset.medium` streams. Translation is near zero because repeat reads hit the translation cache. The first read of new text also pays for translation: a median of 196 ms on the Samsung and 65 ms on the iPhone. Photos have no camera noise or blur, so live reads can be a little slower.
- **Holding still to labels** is the 300 ms settle time plus a live read from the debug HUD, with the example app held over a page with 5 paragraphs. The iPhone was warm after a long session, which made its read take 95 ms. On a cool iPhone, the live read takes about 40 ms.
- **View's work per camera frame** is the HUD's frame cost while panning slowly with labels shown. It's well under 8 ms on both phones.
- **Janky frames** and **memory** come from Flutter DevTools on the Samsung. Its screen ran at 90 Hz, and the view kept 80–85 fps.

Reads slow down with more text in view: framing a page together with the text around it (11 paragraphs instead of 5) made a read about 6 times slower on the Samsung. A warm phone can read up to twice as slowly.

To measure on your own phones:

- **Reads:** from `example/`, run `flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/replay_test.dart -d <device>`. It prints a table and writes the medians to `build/integration_response_data.json` under `summary`.
- **Labels and frame cost:** run the example app with `flutter run --profile` and turn on the debug HUD from its menu.
- **Janky frames and memory:** open DevTools from the same session and use the Performance and Memory tabs.

## Size impact

What the package adds to a release build, measured with Flutter 3.47.7 on 2026-10-17. The app is the example app, without the photos its integration tests use. Sizes are in MB (1,000,000 bytes).

| App | Android APK (arm64) | iOS app, zipped | iOS app, unzipped |
|---|---:|---:|---:|
| Bare Flutter app | 15.5 | 6.2 | 14.4 |
| Example, Latin only | 49.2 | 40.3 | 121.3 |
| Example, Latin and Devanagari | 49.9 | 41.3 | 122.8 |
| **live_translate, Latin only** (over the bare app) | **+33.7** | **+34.1** | **+106.9** |
| **Devanagari recognizer** (over Latin only) | **+0.6** | **+1.0** | **+1.5** |

Nearly all of it is ML Kit's on-device recognition, language identification and translation, plus the camera plugin. The package's own Dart code is a small part. Translation models, about 30 MB each, aren't included: they download on first use.

- **Android:** the arm64 APK from `flutter build apk --release --split-per-abi`. Google Play delivers about this much to a 64-bit phone.
- **iOS, zipped:** `Runner.app` from `flutter build ios --release`, compressed, which is close to an IPA. The App Store's download is smaller after app thinning. The installed size is closer to the unzipped column.

To measure again, for example after upgrading Flutter or ML Kit, run `tool/size_impact.sh` from a checkout of this repository on a Mac with Xcode and the Android SDK. It builds the three apps in a temporary directory and prints this table.

## Example app

The [example app](example/) is a Google Lens-style camera screen built only on the public API:

- **Language pill.** Pick the languages to translate from and to. "Detect language" shows the [source status](#following-language-detection) on its chip: "Looking for text…", "Spanish?", "Spanish" with a spinner while downloading, "No supported text found" and so on. The source choice also sets the scripts: "Detect language" reads Latin and Devanagari, Hindi and Marathi read Devanagari, and every other language reads Latin.
- **Shutter.** Freezes and resumes. Once the frozen picture is translated, a **Text** button opens a sheet of each paragraph's translation and original, to copy one or all of them.
- **Torch** toggle.
- **Menu:** **Languages on this phone** downloads and deletes models with `TranslationModels`. **Debug HUD** turns `showDebugHud` on and off.
- **Downloads.** A spinner on the language chips shows a model downloading.

To run it on a connected phone:

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

**Model downloads:** each language's translation model is about 30 MB and downloads once, on any network.
- The target language's model downloads as soon as the view starts.
- A detected language's model downloads once the language is confirmed. That's straight away for a paragraph of 20 letters or more. Otherwise it's after the language has been seen in three reads, which takes a few seconds on a steady picture.
- Until a model arrives, its paragraphs are left untranslated. They appear as soon as it's ready, without moving the camera.

## Limitations

- Rear camera only.
- Latin and Devanagari scripts only; Chinese, Japanese and Korean are planned.
- Horizontal text only; rotated text is planned.
- The first use of each language needs a network connection to download its model.
- ML Kit needs a real iOS device.
- 0.x releases may change the API. 1.0 will be the stability promise.

## How it works

Every camera frame is used only to measure how the picture moves, from a small brightness thumbnail. When the picture has been steady for about 300 ms, that frame is read once:

1. Every selected script is recognised.
2. The lines are grouped into paragraphs.
3. Each paragraph's language is detected, and the paragraph is translated, with a cache.
4. The page's colours are sampled behind each paragraph.

Each label covers its paragraph in the page's colours. Its text starts at the original text's size, but never above `OverlayStyle.maxFontSize` (28 by default, so large headings get a readable label rather than a giant one). It shrinks towards `minFontSize` until the translation fits. Pass `style: OverlayStyle(maxFontSize: 48)` for bigger headings.

While the result is held, the labels move with the measured camera shift, and no more frames are read once the source language is settled. Until then, while the [source status](#following-language-detection) is searching or guessed, a steady picture is read again a second after each read. So a short sign confirms its language in a few seconds without moving the phone. A fast movement or a new scene fades the labels out, and the next steady picture is read again. Reads never queue, so the camera never falls behind.

Paragraphs in the same script share one language per read, so a stray guess follows the rest of the page. When any paragraph has a language ML Kit can translate, only those languages take part in the vote. That way a block of lorem ipsum identified as Latin doesn't drag a real heading along with it. A Devanagari paragraph identified only as a language ML Kit can't translate, such as Nepali, is translated from Hindi or Marathi instead: whichever ranks higher in the identification, or Hindi. Short Hindi signs are often taken for Nepali.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
